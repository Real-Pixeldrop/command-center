#!/bin/bash
# ===========================================
# ADULT SITES NUCLEAR BLOCK - PERMANENT
# Meme systeme que YouTube : /etc/hosts + /etc/resolver + daemon
# ===========================================

set -e
echo "🚫 BLOCAGE SITES ADULTES - PERMANENT"
echo "======================================"

# Liste des domaines (les 3 demandés + les plus courants)
DOMAINS="pimpbunny.com beeg.com sexyporn.com pornhub.com www.pornhub.com xvideos.com www.xvideos.com xnxx.com www.xnxx.com xhamster.com www.xhamster.com redtube.com www.redtube.com youporn.com www.youporn.com tube8.com www.tube8.com spankbang.com www.spankbang.com brazzers.com www.brazzers.com chaturbate.com www.chaturbate.com stripchat.com www.stripchat.com livejasmin.com www.livejasmin.com onlyfans.com www.onlyfans.com fansly.com www.fansly.com"

# --- 1. /etc/hosts ---
echo "[1/3] Blocage DNS /etc/hosts..."
sudo chflags noschg /etc/hosts 2>/dev/null || true

# Supprimer ancien bloc si existant
sudo sed -i '' '/# ADULT-BLOCK-START/,/# ADULT-BLOCK-END/d' /etc/hosts

echo "" | sudo tee -a /etc/hosts > /dev/null
echo "# ADULT-BLOCK-START - PERMANENT" | sudo tee -a /etc/hosts > /dev/null
for domain in $DOMAINS; do
    echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts > /dev/null
done
echo "# ADULT-BLOCK-END" | sudo tee -a /etc/hosts > /dev/null

sudo chflags schg /etc/hosts
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true
echo "  ✅ /etc/hosts bloqué ($(echo $DOMAINS | wc -w | tr -d ' ') domaines)"

# --- 2. /etc/resolver ---
echo "[2/3] Blocage /etc/resolver (Safari fix)..."
sudo chflags noschg /etc/resolver 2>/dev/null || true
for domain in $DOMAINS; do
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/$domain > /dev/null
    sudo chflags schg /etc/resolver/$domain
done
sudo chflags schg /etc/resolver
echo "  ✅ /etc/resolver bloqué"

# --- 3. Mise a jour daemon gardien ---
echo "[3/3] Mise a jour daemon gardien..."

# Lire le script gardien existant et ajouter le check adult
GUARDIAN_SCRIPT="/usr/local/bin/.com.apple.nsurlsessiond-check"
if [ -f "$GUARDIAN_SCRIPT" ]; then
    # Ajouter le check adult au gardien existant
    sudo chflags noschg "$GUARDIAN_SCRIPT" 2>/dev/null || true
    
    # Vérifier si le check adult est déjà présent
    if ! grep -q "ADULT-BLOCK" "$GUARDIAN_SCRIPT" 2>/dev/null; then
        cat << 'ADULTCHECK' | sudo tee -a "$GUARDIAN_SCRIPT" > /dev/null

# 6. Vérifier blocage adult (PERMANENT)
if ! grep -q "ADULT-BLOCK-START" /etc/hosts 2>/dev/null; then
    chflags noschg /etc/hosts 2>/dev/null || true
    echo "" >> /etc/hosts
    echo "# ADULT-BLOCK-START - PERMANENT" >> /etc/hosts
    for d in pimpbunny.com beeg.com sexyporn.com pornhub.com www.pornhub.com xvideos.com www.xvideos.com xnxx.com www.xnxx.com xhamster.com www.xhamster.com redtube.com www.redtube.com youporn.com www.youporn.com tube8.com www.tube8.com spankbang.com www.spankbang.com brazzers.com www.brazzers.com chaturbate.com www.chaturbate.com stripchat.com www.stripchat.com livejasmin.com www.livejasmin.com onlyfans.com www.onlyfans.com fansly.com www.fansly.com; do
        echo "127.0.0.1 $d" >> /etc/hosts
    done
    echo "# ADULT-BLOCK-END" >> /etc/hosts
    chflags schg /etc/hosts
    dscacheutil -flushcache
    killall -HUP mDNSResponder 2>/dev/null || true
fi

# Vérifier /etc/resolver adult
for d in pimpbunny.com beeg.com sexyporn.com pornhub.com www.pornhub.com xvideos.com www.xvideos.com xnxx.com www.xnxx.com xhamster.com www.xhamster.com redtube.com www.redtube.com youporn.com www.youporn.com tube8.com www.tube8.com spankbang.com www.spankbang.com brazzers.com www.brazzers.com chaturbate.com www.chaturbate.com stripchat.com www.stripchat.com livejasmin.com www.livejasmin.com onlyfans.com www.onlyfans.com fansly.com www.fansly.com; do
    if [ ! -f /etc/resolver/$d ]; then
        chflags noschg /etc/resolver 2>/dev/null || true
        mkdir -p /etc/resolver
        echo "nameserver 127.0.0.1" > /etc/resolver/$d
        chflags schg /etc/resolver/$d
        chflags schg /etc/resolver
    fi
done
ADULTCHECK
        sudo chflags schg "$GUARDIAN_SCRIPT" 2>/dev/null || true
        echo "  ✅ Daemon gardien mis à jour"
    else
        echo "  ℹ️  Daemon déjà configuré pour adult"
    fi
else
    echo "  ⚠️  Daemon gardien pas trouvé, installe d'abord block-youtube-v3.sh"
fi

echo ""
echo "========================================="
echo "🔒 SITES ADULTES BLOQUÉS - PERMANENT"
echo "========================================="
echo "Ferme tes navigateurs et reouvre-les."
