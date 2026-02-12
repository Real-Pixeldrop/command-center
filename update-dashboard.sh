#!/bin/bash
# Script de mise à jour automatique du Control Center Pixel Drop
# Sources : GA4, Brevo, Notion, Pennylane, Search Console, Pixel Space API

set -e
cd "$(dirname "$0")"
HTML_FILE="index.html"

echo "=== Control Center Update $(date) ==="

# ===== 1. GA4 - Trafic pixel-drop.com (30j) =====
echo "GA4 trafic..."
ACCESS_TOKEN=$(curl -s -X POST https://oauth2.googleapis.com/token \
  -d "refresh_token=$(jq -r .refresh_token ~/.config/ga4/config.json)" \
  -d "client_id=$(jq -r .client_id ~/.config/ga4/config.json)" \
  -d "client_secret=$(jq -r .client_secret ~/.config/ga4/config.json)" \
  -d "grant_type=refresh_token" | jq -r '.access_token')

TRAFIC=$(curl -s -X POST "https://analyticsdata.googleapis.com/v1beta/properties/474885507:runReport" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"dateRanges":[{"startDate":"30daysAgo","endDate":"today"}],"metrics":[{"name":"sessions"}]}' \
  | jq -r '.rows[0].metricValues[0].value // "0"')
echo "Trafic: $TRAFIC sessions"

# ===== 2. Brevo - Contacts newsletter Pixel Drop =====
echo "Brevo contacts..."
BREVO_KEY=$(cat ~/.config/brevo/api_key 2>/dev/null || echo "")
if [ -n "$BREVO_KEY" ]; then
  NL_CONTACTS=$(curl -s "https://api.brevo.com/v3/contacts?limit=1" \
    -H "api-key: $BREVO_KEY" | jq -r '.count // "0"')
  
  # Dernières campagnes
  NL_CAMPAIGNS=$(curl -s "https://api.brevo.com/v3/emailCampaigns?status=sent&limit=5" \
    -H "api-key: $BREVO_KEY")
  NL_TOTAL=$(echo "$NL_CAMPAIGNS" | jq -r '.count // "0"')
else
  NL_CONTACTS="0"
  NL_TOTAL="0"
fi
echo "Newsletter: $NL_CONTACTS contacts, $NL_TOTAL campagnes"

# ===== 3. Notion - Pipeline prospects =====
echo "Notion pipeline..."
NOTION_TOKEN=$(cat ~/.notion_token 2>/dev/null || echo "")
if [ -n "$NOTION_TOKEN" ]; then
  PIPELINE_RAW=$(curl -s -X POST "https://api.notion.com/v1/databases/2d6b3040-214f-81e5-a73c-cf8d0421aed3/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{}')
  
  PIPELINE_CONTACT=$(echo "$PIPELINE_RAW" | jq '[.results[] | select(.properties.Statut.select.name == "🎯 À contacter")] | length')
  PIPELINE_DISCUSSION=$(echo "$PIPELINE_RAW" | jq '[.results[] | select(.properties.Statut.select.name == "📞 En discussion")] | length')
  PIPELINE_DEVIS=$(echo "$PIPELINE_RAW" | jq '[.results[] | select(.properties.Statut.select.name == "📋 Devis envoyé")] | length')
  PIPELINE_SIGNES=$(echo "$PIPELINE_RAW" | jq '[.results[] | select(.properties.Statut.select.name == "✅ Signé")] | length')
  
  # Extraire la liste pour le tableau
  PIPELINE_TABLE=$(echo "$PIPELINE_RAW" | jq -r '.results[] | select(.properties.Statut.select.name != "✅ Signé" and .properties.Statut.select.name != "❌ Perdu") | "<tr><td>" + (.properties.Entreprise.title[0].text.content // "N/A") + "</td><td>" + (.properties.Dirigeant.rich_text[0].text.content // "N/A") + "</td><td>--</td><td><span class=\"badge badge-blue\">" + (.properties.Statut.select.name // "N/A") + "</span></td></tr>"' 2>/dev/null || echo "")
else
  PIPELINE_CONTACT="0"
  PIPELINE_DISCUSSION="0"
  PIPELINE_DEVIS="0"
  PIPELINE_SIGNES="0"
  PIPELINE_TABLE=""
fi
echo "Pipeline: $PIPELINE_CONTACT a contacter, $PIPELINE_DISCUSSION en discussion, $PIPELINE_DEVIS devis, $PIPELINE_SIGNES signes"

# ===== 4. Pennylane - CA mensuel =====
echo "Pennylane CA..."
PENNY_TOKEN="BOFpoGNI-TGyO6F9qx0nSdzXy_Da_7OGDf6s6mMiZIY"
MONTH_START=$(date +"%Y-%m-01")
INVOICES=$(curl -s "https://app.pennylane.com/api/external/v2/customer_invoices" \
  -H "Authorization: Bearer $PENNY_TOKEN" 2>/dev/null)
CA_MENSUEL=$(echo "$INVOICES" | jq -r "[.invoices[] | select(.date >= \"$MONTH_START\") | .amount] | add // 0" 2>/dev/null || echo "0")
CA_DISPLAY=$(echo "$CA_MENSUEL" | awk '{printf "%.0f", $1/100}' 2>/dev/null || echo "0")
DEVIS_ATTENTE=$(echo "$INVOICES" | jq '[.invoices[] | select(.status == "pending")] | length' 2>/dev/null || echo "0")
echo "CA: ${CA_DISPLAY}€, Devis en attente: $DEVIS_ATTENTE"

# ===== 5. Search Console - SEO pixel-drop.com =====
echo "Search Console..."
TODAY=$(date +"%Y-%m-%d")
START_30=$(date -v-30d +"%Y-%m-%d" 2>/dev/null || date -d "30 days ago" +"%Y-%m-%d")
SC_DATA=$(curl -s -X POST "https://www.googleapis.com/webmasters/v3/sites/https%3A%2F%2Fpixel-drop.com%2F/searchAnalytics/query" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"startDate\":\"$START_30\",\"endDate\":\"$TODAY\",\"dimensions\":[\"query\"],\"rowLimit\":10}" 2>/dev/null)

SEO_CLICKS=$(echo "$SC_DATA" | jq -r '[.rows[].clicks] | add // 0' 2>/dev/null || echo "0")
SEO_IMPRESSIONS=$(echo "$SC_DATA" | jq -r '[.rows[].impressions] | add // 0' 2>/dev/null || echo "0")
SEO_POSITION=$(echo "$SC_DATA" | jq -r '[.rows[].position] | (add / length) | . * 10 | round / 10' 2>/dev/null || echo "0")
SEO_CTR=$(echo "$SC_DATA" | jq -r '[.rows[].ctr] | (add / length) * 100 | . * 10 | round / 10' 2>/dev/null || echo "0")

# Top queries pour le tableau
SEO_TABLE=$(echo "$SC_DATA" | jq -r '.rows[:8][] | "<tr><td>" + .keys[0] + "</td><td>" + (.clicks | tostring) + "</td><td>" + (.impressions | tostring) + "</td><td>" + ((.position * 10 | round / 10) | tostring) + "</td></tr>"' 2>/dev/null || echo "")
echo "SEO: $SEO_CLICKS clics, $SEO_IMPRESSIONS impressions, pos $SEO_POSITION"

# ===== 6. Sites WordPress (Pixel Space API) =====
echo "Sites WordPress..."
# Lire le Google Sheet pour les sites (on utilise les sites connus)
SITES_HTML=""
SITES_TOTAL=0
SITES_UPDATES=0
SITES_OK=0

for SITE_URL in "pixel-drop.com" "dernieredispo.com" "black-trombone.fr" "awayexpedition.com" "cine-loges.fr" "collectivitesterritoriales.fr"; do
  STATUS_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$SITE_URL" --connect-timeout 5 2>/dev/null || echo "000")
  SITES_TOTAL=$((SITES_TOTAL + 1))
  if [ "$STATUS_CODE" = "200" ] || [ "$STATUS_CODE" = "301" ] || [ "$STATUS_CODE" = "302" ]; then
    BADGE="<span class=\"badge badge-green\">OK</span>"
    SITES_OK=$((SITES_OK + 1))
  else
    BADGE="<span class=\"badge badge-red\">Down ($STATUS_CODE)</span>"
  fi
  SITES_HTML="${SITES_HTML}<tr><td>$SITE_URL</td><td>$BADGE</td><td>--</td><td>$(date '+%d/%m %Hh%M')</td></tr>"
done
echo "Sites: $SITES_TOTAL total, $SITES_OK OK"

# ===== 7. Clients (Notion CRM) =====
echo "Notion clients..."
if [ -n "$NOTION_TOKEN" ]; then
  CRM_RAW=$(curl -s -X POST "https://api.notion.com/v1/databases/bd6b3439-a6de-4e8d-af31-aa5db85d5cb4/query" \
    -H "Authorization: Bearer $NOTION_TOKEN" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{}')
  CLIENTS_TOTAL=$(echo "$CRM_RAW" | jq '.results | length' 2>/dev/null || echo "0")
else
  CLIENTS_TOTAL="0"
fi
echo "Clients: $CLIENTS_TOTAL"

# ===== MISE A JOUR HTML =====
echo "Mise a jour HTML..."

# Dashboard - KPIs principaux
sed -i '' "s/id=\"ca-mensuel\">[^<]*/id=\"ca-mensuel\">${CA_DISPLAY}€/" "$HTML_FILE"
sed -i '' "s/id=\"clients-actifs\">[^<]*/id=\"clients-actifs\">$CLIENTS_TOTAL/" "$HTML_FILE"
sed -i '' "s/id=\"trafic-pd\">[^<]*/id=\"trafic-pd\">$TRAFIC/" "$HTML_FILE"
sed -i '' "s/id=\"devis-attente\">[^<]*/id=\"devis-attente\">$DEVIS_ATTENTE/" "$HTML_FILE"

# Marketing - barres de progression (trafic)
TRAFIC_PCT=$(python3 -c "print(min(round($TRAFIC / 1000 * 100, 1), 100))")
sed -i '' "s/id=\"mkt-trafic\">[^<]*/id=\"mkt-trafic\">$TRAFIC/" "$HTML_FILE"
sed -i '' "s/id=\"mkt-tr-val\">[^<]*/id=\"mkt-tr-val\">$TRAFIC/" "$HTML_FILE"
sed -i '' "s/id=\"mkt-tr-pct\">[^<]*/id=\"mkt-tr-pct\">$TRAFIC_PCT/" "$HTML_FILE"
sed -i '' "s/id=\"mkt-tr-bar\" style=\"width:[^\"]*\"/id=\"mkt-tr-bar\" style=\"width:${TRAFIC_PCT}%\"/" "$HTML_FILE"

# Newsletter
sed -i '' "s/id=\"mkt-newsletter\">[^<]*/id=\"mkt-newsletter\">$NL_CONTACTS/" "$HTML_FILE"
sed -i '' "s/id=\"mkt-nl-val\">[^<]*/id=\"mkt-nl-val\">$NL_CONTACTS/" "$HTML_FILE"
NL_PCT=$(python3 -c "print(min(round($NL_CONTACTS / 200 * 100, 1), 100))")
sed -i '' "s/id=\"mkt-nl-pct\">[^<]*/id=\"mkt-nl-pct\">$NL_PCT/" "$HTML_FILE"
sed -i '' "s/id=\"mkt-nl-bar\" style=\"width:[^\"]*\"/id=\"mkt-nl-bar\" style=\"width:${NL_PCT}%\"/" "$HTML_FILE"
sed -i '' "s/id=\"nl-contacts\">[^<]*/id=\"nl-contacts\">$NL_CONTACTS/" "$HTML_FILE"
sed -i '' "s/id=\"nl-campaigns\">[^<]*/id=\"nl-campaigns\">$NL_TOTAL/" "$HTML_FILE"

# Pipeline
sed -i '' "s/id=\"pipeline-contact\">[^<]*/id=\"pipeline-contact\">$PIPELINE_CONTACT/" "$HTML_FILE"
sed -i '' "s/id=\"pipeline-discussion\">[^<]*/id=\"pipeline-discussion\">$PIPELINE_DISCUSSION/" "$HTML_FILE"
sed -i '' "s/id=\"pipeline-devis\">[^<]*/id=\"pipeline-devis\">$PIPELINE_DEVIS/" "$HTML_FILE"
sed -i '' "s/id=\"pipeline-signes\">[^<]*/id=\"pipeline-signes\">$PIPELINE_SIGNES/" "$HTML_FILE"

# SEO
sed -i '' "s/id=\"seo-clicks\">[^<]*/id=\"seo-clicks\">$SEO_CLICKS/" "$HTML_FILE"
sed -i '' "s/id=\"seo-impressions\">[^<]*/id=\"seo-impressions\">$SEO_IMPRESSIONS/" "$HTML_FILE"
sed -i '' "s/id=\"seo-position\">[^<]*/id=\"seo-position\">$SEO_POSITION/" "$HTML_FILE"
sed -i '' "s/id=\"seo-ctr\">[^<]*/id=\"seo-ctr\">${SEO_CTR}%/" "$HTML_FILE"

# Sites WordPress
sed -i '' "s/id=\"sites-total\">[^<]*/id=\"sites-total\">$SITES_TOTAL/" "$HTML_FILE"
sed -i '' "s/id=\"sites-updates\">[^<]*/id=\"sites-updates\">$SITES_UPDATES/" "$HTML_FILE"
sed -i '' "s/id=\"sites-ok\">[^<]*/id=\"sites-ok\">$SITES_OK/" "$HTML_FILE"

# Tableaux dynamiques - SEO queries
if [ -n "$SEO_TABLE" ]; then
  python3 -c "
import re
with open('$HTML_FILE', 'r') as f:
    content = f.read()
seo_rows = '''$SEO_TABLE'''
content = re.sub(r'(<tbody id=\"seo-queries\">).*?(</tbody>)', r'\1' + seo_rows + r'\2', content, flags=re.DOTALL)
with open('$HTML_FILE', 'w') as f:
    f.write(content)
" 2>/dev/null || echo "SEO table update skipped"
fi

# Tableaux dynamiques - Sites
# DESACTIVE: le data.json + renderSites() gere deja l'affichage correct des 31 sites
# if [ -n "$SITES_HTML" ]; then
#   python3 -c "
# import re
# with open('$HTML_FILE', 'r') as f:
#     content = f.read()
# sites_rows = '''$SITES_HTML'''
# content = re.sub(r'(<tbody id=\"sites-list\">).*?(</tbody>)', r'\1' + sites_rows + r'\2', content, flags=re.DOTALL)
# with open('$HTML_FILE', 'w') as f:
#     f.write(content)
# " 2>/dev/null || echo "Sites table update skipped"
# fi

# Tableaux dynamiques - Pipeline
if [ -n "$PIPELINE_TABLE" ]; then
  python3 -c "
import re
with open('$HTML_FILE', 'r') as f:
    content = f.read()
pipeline_rows = '''$PIPELINE_TABLE'''
content = re.sub(r'(<tbody id=\"pipeline-list\">).*?(</tbody>)', r'\1' + pipeline_rows + r'\2', content, flags=re.DOTALL)
with open('$HTML_FILE', 'w') as f:
    f.write(content)
" 2>/dev/null || echo "Pipeline table update skipped"
fi

# Dashboard marketing bars (dans le dashboard principal)
# Update les valeurs textuelles
sed -i '' "s/>62 \/ 500</>$( [ -n \"\" ] && echo \"\" || echo \"62\" ) \/ 500</" "$HTML_FILE" 2>/dev/null || true
sed -i '' "s/>$TRAFIC \/ 1000</>${TRAFIC} \/ 1000</" "$HTML_FILE" 2>/dev/null || true
sed -i '' "s/>$NL_CONTACTS \/ 200</>${NL_CONTACTS} \/ 200</" "$HTML_FILE" 2>/dev/null || true

# ===== COHERENCE CHECK - Recalcul KPIs depuis données brutes =====
echo "Cohérence KPIs..."
python3 << 'COHERENCE_EOF'
import json

with open('data.json', 'r') as f:
    data = json.load(f)

# Recalcul pipeline_kpis depuis pipeline
offres = [p for p in data['pipeline'] if p.get('etape') == 'offre_envoyee']
signes = [p for p in data['pipeline'] if p.get('etape') in ('signe', 'livre')]
perdus = [p for p in data['pipeline'] if p.get('etape') == 'perdu']

# Calculer montant signé
montant_signe = 0
for p in signes:
    m = p.get('montant', '0').replace('€', '').replace(' ', '').replace('HT', '').replace('TTC', '').replace('(', '').replace(')', '').strip()
    try:
        montant_signe += int(m.split(',')[0])
    except:
        pass

data['pipeline_kpis'] = {
    "offres_envoyees": {"count": len(offres), "montant": f"{len(offres)} offres en jeu"},
    "en_discussion": {"count": 0, "detail": ""},
    "signes": {"count": len(signes), "montant": f"{montant_signe:,}€".replace(",", " ")},
    "perdus": {"count": len(perdus), "detail": "ce mois"}
}

# Recalcul devis_attente
devis_attente = len([d for d in data['devis'] if d.get('statut') == 'en_attente'])
data['kpis']['devis_attente'] = devis_attente

# Recalcul devis_kpis depuis devis 2026
devis_2026 = [d for d in data['devis'] if '2026' in d.get('date_envoi','')]
en_att = [d for d in devis_2026 if d.get('statut') == 'en_attente']
acceptes = [d for d in devis_2026 if d.get('statut') == 'accepte']
m_att = sum(d.get('montant_num', 0) for d in en_att)
m_acc = sum(d.get('montant_num', 0) for d in acceptes)
data['devis_kpis'] = {
    "en_attente": {"count": len(en_att), "montant": f"{m_att:,.0f}€ potentiels".replace(",", " ")},
    "acceptes": {"count": len(acceptes), "montant": f"{m_acc:,.0f}€".replace(",", " ")},
    "factures_payees": data.get('devis_kpis', {}).get('factures_payees', {"count": 0, "montant": "0€"})
}

# Sync dash_projets_en_cours depuis projets
en_cours = [p for p in data['projets'] if p.get('statut') == 'En cours']
data['dash_projets_en_cours'] = [
    {"projet": p['nom'], "client": p['client'], "statut": "En cours"}
    for p in en_cours
]

# Refresh PDF links from Pennylane
import subprocess, os
try:
    result = subprocess.run([
        'curl', '-s', 'https://app.pennylane.com/api/external/v2/quotes',
        '-H', 'Authorization: Bearer 2aCuX5vMMmW8hFgyFCnlDIEPWXSqSV4vPe_KsdlU6uQ'
    ], capture_output=True, text=True, timeout=15)
    quotes_data = json.loads(result.stdout)
    items = quotes_data.get('items', [])
    
    # Build map: subject+amount -> pdf url
    pdf_map = {}
    for q in items:
        label = q.get('label', '')
        pdf = q.get('public_file_url', '')
        if pdf and '2026' in q.get('date', ''):
            pdf_map[label] = pdf
    
    # Update devis PDF links by matching label
    for d in data['devis']:
        nom = d.get('nom', '')
        if nom in pdf_map:
            d['pdf'] = pdf_map[nom]
except Exception as e:
    print(f"PDF refresh skipped: {e}")

with open('data.json', 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)

print(f"KPIs: {devis_attente} devis attente, {len(signes)} signés ({montant_signe}€), {len(offres)} offres")
COHERENCE_EOF

# ===== CLAUDIA SYNC =====
echo "Claudia sync..."
bash ./claudia-sync.sh 2>/dev/null || echo "Claudia sync skipped"

# ===== GIT PUSH =====
git add -A
if ! git diff --quiet --staged; then
  git commit -m "Auto-update: trafic=$TRAFIC, contacts=$NL_CONTACTS, clients=$CLIENTS_TOTAL, seo=$SEO_CLICKS clics"
  git push
  echo "Dashboard pousse"
else
  echo "Pas de changement"
fi

echo "=== Update terminee ==="
