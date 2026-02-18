#!/bin/bash
# Sync Pennylane → data.json (Control Center)
# Source de vérité financière : Pennylane
# Tourne automatiquement via le cron update-control-center

set -e
cd "$(dirname "$0")"

PENNY_FULL="2aCuX5vMMmW8hFgyFCnlDIEPWXSqSV4vPe_KsdlU6uQ"
PENNY_READ="BOFpoGNI-TGyO6F9qx0nSdzXy_Da_7OGDf6s6mMiZIY"

echo "=== Sync Pennylane → data.json $(date) ==="

# Fetch quotes and invoices from Pennylane
QUOTES_FILE=$(mktemp)
INVOICES_FILE=$(mktemp)

curl -s "https://app.pennylane.com/api/external/v2/quotes" \
  -H "Authorization: Bearer $PENNY_FULL" > "$QUOTES_FILE" 2>/dev/null || echo '{"items":[]}' > "$QUOTES_FILE"

curl -s "https://app.pennylane.com/api/external/v2/customer_invoices" \
  -H "Authorization: Bearer $PENNY_READ" > "$INVOICES_FILE" 2>/dev/null || echo '{"items":[]}' > "$INVOICES_FILE"

# Update data.json with Pennylane data
python3 - "$QUOTES_FILE" "$INVOICES_FILE" << 'SYNC_EOF'
import json, sys
from datetime import datetime

quotes_file = sys.argv[1]
invoices_file = sys.argv[2]

# Load current data
with open('data.json', 'r') as f:
    data = json.load(f)

# Load Pennylane data
try:
    with open(quotes_file) as f:
        quotes = json.load(f)
except:
    quotes = {"items": []}

try:
    with open(invoices_file) as f:
        invoices = json.load(f)
except:
    invoices = {"items": []}

penny_quotes = quotes.get('items', [])
penny_invoices = invoices.get('items', [])

# --- SYNC DEVIS STATUS + PDF from Pennylane quotes ---
existing_devis = {d.get('nom', ''): d for d in data.get('devis', [])}

status_map = {
    'pending': 'en_attente',
    'accepted': 'accepte',
    'invoiced': 'paye',
    'expired': 'expire',
    'refused': 'refuse'
}

for q in penny_quotes:
    label = q.get('label', '')
    if not label:
        continue
    
    penny_status = status_map.get(q.get('status', ''), q.get('status', ''))
    penny_pdf = q.get('public_file_url', '')
    
    if label in existing_devis:
        d = existing_devis[label]
        # Update status if changed (but don't downgrade paye -> en_attente)
        if penny_status and d.get('statut') != 'paye':
            if penny_status != d.get('statut'):
                print(f"  Status: {label} {d.get('statut')} -> {penny_status}")
                d['statut'] = penny_status
        elif penny_status == 'paye' and d.get('statut') != 'paye':
            d['statut'] = 'paye'
            print(f"  Paid: {label}")
        if penny_pdf:
            d['pdf'] = penny_pdf

# --- SYNC FACTURES from Pennylane invoices ---
# Match invoices to devis by Pennylane label (D-2026-XXXX)
# Only mark paid if the devis label matches the invoice's source quote
for inv in penny_invoices:
    inv_status = inv.get('status', '')
    inv_amount = float(inv.get('currency_amount', '0'))
    inv_date = inv.get('date', '')
    inv_label = inv.get('label', '')
    
    if inv_status == 'paid':
        matched = False
        for d in data.get('devis', []):
            d_nom = d.get('nom', '')
            # Match by Pennylane devis label (nom field contains "D-2026-XXXX" or similar)
            # Also match by "Devis D-2026-XXXX" format
            clean_nom = d_nom.replace('Devis ', '')
            if clean_nom and clean_nom in inv_label:
                if d.get('statut') != 'paye':
                    d['statut'] = 'paye'
                    d['date_paiement'] = inv_date
                    print(f"  Marked paid: {d_nom} ({inv_amount}€)")
                matched = True
                break
        
        if not matched:
            # Fallback: match by exact amount + same date, but ONLY if unique match
            candidates = [d for d in data.get('devis', []) 
                         if abs(d.get('montant_ttc_num', d.get('montant_num', 0)) - inv_amount) < 1 
                         and d.get('statut') != 'paye']
            if len(candidates) == 1:
                candidates[0]['statut'] = 'paye'
                candidates[0]['date_paiement'] = inv_date
                print(f"  Marked paid (amount match): {candidates[0].get('nom', '')} ({inv_amount}€)")

# --- RECALC KPIs ---
now = datetime.now()
month_str = now.strftime('%Y-%m')

# CA mensuel from Pennylane invoices
ca_mensuel = 0
for inv in penny_invoices:
    if inv.get('status') == 'paid' and inv.get('date', '').startswith(month_str):
        ca_mensuel += float(inv.get('currency_amount', '0'))

# Devis stats
devis_attente = [d for d in data.get('devis', []) if d.get('statut') == 'en_attente']
devis_acceptes = [d for d in data.get('devis', []) if d.get('statut') in ('accepte', 'paye')]
devis_payes = [d for d in data.get('devis', []) if d.get('statut') == 'paye']

m_attente = sum(d.get('montant_num', 0) for d in devis_attente)
m_acceptes = sum(d.get('montant_num', 0) for d in devis_acceptes)
m_payes = sum(d.get('montant_ttc_num', d.get('montant_num', 0)) for d in devis_payes)

# Update KPIs
if ca_mensuel > 0:
    data['kpis']['ca_mensuel'] = int(ca_mensuel)
data['kpis']['devis_attente'] = len(devis_attente)
data['kpis']['ca_mensuel_mois'] = now.strftime('%B %Y').capitalize()

data['devis_kpis'] = {
    "en_attente": {"count": len(devis_attente), "montant": f"{m_attente:,.0f}€ potentiels".replace(",", " ")},
    "acceptes": {"count": len(devis_acceptes), "montant": f"{m_acceptes:,.0f}€".replace(",", " ")},
    "factures_payees": {"count": len(devis_payes), "montant": f"{m_payes:,.0f}€ encaissés".replace(",", " ")}
}

data['pennylane_last_sync'] = now.strftime('%Y-%m-%d %H:%M')

print(f"  CA mensuel: {ca_mensuel}€")
print(f"  Devis attente: {len(devis_attente)} ({m_attente}€)")
print(f"  Factures payées: {len(devis_payes)} ({m_payes}€)")

with open('data.json', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print("Sync Pennylane OK")
SYNC_EOF

# Cleanup
rm -f "$QUOTES_FILE" "$INVOICES_FILE"

echo "=== Sync terminée ==="
