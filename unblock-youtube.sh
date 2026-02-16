#!/bin/bash
# ===========================================
# YOUTUBE UNBLOCK - Déblocage complet
# À exécuter le 13 mars 2026 ou après
# ===========================================

echo "🔓 DÉBLOCAGE YOUTUBE"
echo "===================="

# 1. Arrêter les daemons
echo "[1/5] Arrêt des daemons gardiens..."
sudo launchctl unload /Library/LaunchDaemons/com.apple.nsurlsessiond-check.plist 2>/dev/null || true
sudo launchctl unload /Library/LaunchDaemons/com.apple.cfnetwork-diag.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.apple.nsurlsessiond-check.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.apple.cfnetwork-diag.plist 2>/dev/null || true
sudo rm -f /usr/local/bin/.com.apple.nsurlsessiond-check 2>/dev/null || true
sudo rm -f /usr/local/bin/.com.apple.cfnetwork-diag 2>/dev/null || true
echo "  ✅ Daemons supprimés"

# 2. Débloquer /etc/hosts
echo "[2/5] Nettoyage /etc/hosts..."
sudo chflags noschg /etc/hosts 2>/dev/null || true
sudo sed -i '' '/# YOUTUBE-BLOCK-START/,/# YOUTUBE-BLOCK-END/d' /etc/hosts
echo "  ✅ /etc/hosts nettoyé"

# 3. Supprimer /etc/resolver
echo "[3/5] Suppression /etc/resolver YouTube..."
sudo chflags noschg /etc/resolver 2>/dev/null || true
DOMAINS="youtube.com www.youtube.com m.youtube.com youtu.be youtube-nocookie.com youtubei.googleapis.com youtube.googleapis.com googlevideo.com ytimg.com yt3.ggpht.com yt4.ggpht.com music.youtube.com tv.youtube.com gaming.youtube.com kids.youtube.com studio.youtube.com accounts.youtube.com"
for domain in $DOMAINS; do
    sudo chflags noschg /etc/resolver/$domain 2>/dev/null || true
    sudo rm -f /etc/resolver/$domain
done
echo "  ✅ /etc/resolver nettoyé"

# 4. Supprimer proxy PAC
echo "[4/5] Suppression proxy PAC..."
sudo chflags noschg /Library/WebServer/Documents/block-yt.pac 2>/dev/null || true
sudo rm -f /Library/WebServer/Documents/block-yt.pac
for iface in $(networksetup -listallnetworkservices | tail -n +2); do
    sudo networksetup -setautoproxystate "$iface" off 2>/dev/null || true
done
echo "  ✅ Proxy PAC supprimé"

# 5. Nettoyer firewall
echo "[5/5] Nettoyage firewall..."
sudo chflags noschg /etc/pf.anchors/com.apple.yt-filter 2>/dev/null || true
sudo rm -f /etc/pf.anchors/com.apple.yt-filter
sudo sed -i '' '/com.apple.yt-filter/d' /etc/pf.conf 2>/dev/null || true
sudo pfctl -f /etc/pf.conf 2>/dev/null || true
echo "  ✅ Firewall nettoyé"

# Flush DNS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo ""
echo "========================================="
echo "✅ YOUTUBE DÉBLOQUÉ"
echo "========================================="
echo "Ferme et reouvre tes navigateurs."
