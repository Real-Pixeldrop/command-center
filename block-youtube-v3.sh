#!/bin/bash
# ===========================================
# YOUTUBE NUCLEAR BLOCK V3 - SAFARI + CHROME
# /etc/resolver = force macOS a bloquer YouTube
# pour TOUS les navigateurs, y compris Safari
# ===========================================

set -e
echo "🚫 BLOCAGE YOUTUBE V3 - SAFARI FIX"
echo "===================================="

# --- 1. /etc/resolver (BLOQUE SAFARI) ---
echo "[1/3] Blocage DNS systeme via /etc/resolver..."
sudo mkdir -p /etc/resolver

DOMAINS="youtube.com www.youtube.com m.youtube.com youtu.be youtube-nocookie.com youtubei.googleapis.com youtube.googleapis.com googlevideo.com ytimg.com yt3.ggpht.com yt4.ggpht.com music.youtube.com tv.youtube.com gaming.youtube.com kids.youtube.com studio.youtube.com accounts.youtube.com"

for domain in $DOMAINS; do
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/$domain > /dev/null
    sudo chflags schg /etc/resolver/$domain
done
sudo chflags schg /etc/resolver
echo "  ✅ /etc/resolver configure + verrouille ($(echo $DOMAINS | wc -w | tr -d ' ') domaines)"

# --- 2. Mise a jour daemon gardien ---
echo "[2/3] Mise a jour du daemon gardien..."
cat << 'GUARDIAN' | sudo tee /usr/local/bin/.com.apple.nsurlsessiond-check > /dev/null
#!/bin/bash
# Gardien YouTube V3

# 1. Vérifier /etc/hosts
if ! grep -q "YOUTUBE-BLOCK-START" /etc/hosts 2>/dev/null; then
    chflags noschg /etc/hosts 2>/dev/null || true
    cat << 'INNEREOF' >> /etc/hosts

# YOUTUBE-BLOCK-START
127.0.0.1 youtube.com
127.0.0.1 www.youtube.com
127.0.0.1 m.youtube.com
127.0.0.1 youtu.be
127.0.0.1 youtube-nocookie.com
127.0.0.1 youtubei.googleapis.com
127.0.0.1 youtube.googleapis.com
127.0.0.1 googlevideo.com
127.0.0.1 www.googlevideo.com
127.0.0.1 manifest.googlevideo.com
127.0.0.1 redirector.googlevideo.com
127.0.0.1 ytimg.com
127.0.0.1 i.ytimg.com
127.0.0.1 s.ytimg.com
127.0.0.1 yt3.ggpht.com
127.0.0.1 music.youtube.com
127.0.0.1 tv.youtube.com
127.0.0.1 gaming.youtube.com
127.0.0.1 kids.youtube.com
127.0.0.1 accounts.youtube.com
127.0.0.1 studio.youtube.com
# YOUTUBE-BLOCK-END
INNEREOF
    chflags schg /etc/hosts
    dscacheutil -flushcache
    killall -HUP mDNSResponder 2>/dev/null || true
fi

# 2. Vérifier /etc/resolver
DOMAINS="youtube.com www.youtube.com m.youtube.com youtu.be youtube-nocookie.com youtubei.googleapis.com youtube.googleapis.com googlevideo.com ytimg.com yt3.ggpht.com yt4.ggpht.com music.youtube.com tv.youtube.com gaming.youtube.com kids.youtube.com studio.youtube.com accounts.youtube.com"

chflags noschg /etc/resolver 2>/dev/null || true
for domain in $DOMAINS; do
    if [ ! -f /etc/resolver/$domain ]; then
        mkdir -p /etc/resolver
        echo "nameserver 127.0.0.1" > /etc/resolver/$domain
        chflags schg /etc/resolver/$domain
    fi
done
chflags schg /etc/resolver

# 3. Vérifier proxy PAC
for iface in $(networksetup -listallnetworkservices | tail -n +2); do
    state=$(networksetup -getautoproxyurl "$iface" 2>/dev/null | grep "Enabled" | awk '{print $2}')
    if [ "$state" != "Yes" ]; then
        networksetup -setautoproxyurl "$iface" "file:///Library/WebServer/Documents/block-yt.pac" 2>/dev/null || true
        networksetup -setautoproxystate "$iface" on 2>/dev/null || true
    fi
done

# 4. Vérifier firewall
pfctl -s info 2>/dev/null | grep -q "Status: Enabled" || pfctl -e 2>/dev/null || true

# 5. Vérifier daemon #2
if ! launchctl list 2>/dev/null | grep -q "com.apple.cfnetwork-diag"; then
    launchctl load /Library/LaunchDaemons/com.apple.cfnetwork-diag.plist 2>/dev/null || true
fi
GUARDIAN
sudo chmod +x /usr/local/bin/.com.apple.nsurlsessiond-check
echo "  ✅ Daemon mis a jour avec /etc/resolver check"

# --- 3. FLUSH DNS ---
echo "[3/3] Flush DNS..."
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo ""
echo "========================================="
echo "🔒 YOUTUBE V3 ACTIVÉ - SAFARI FIXÉ"
echo "========================================="
echo ""
echo "Ferme Safari (Cmd+Q) et reouvre-le."
echo "YouTube doit maintenant etre bloque partout."
