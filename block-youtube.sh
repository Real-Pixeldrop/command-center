#!/bin/bash
# ===========================================
# YOUTUBE NUCLEAR BLOCK V2 - IMPOSSIBLE A ENLEVER
# Par Claudia pour Akli - 13 mars 2026 = liberation
# ===========================================

set -e
echo "🚫 BLOCAGE YOUTUBE NUCLÉAIRE V2"
echo "================================"

# --- 1. BLOCAGE /etc/hosts ---
echo "[1/6] Blocage DNS via /etc/hosts..."
sudo sed -i '' '/# YOUTUBE-BLOCK-START/,/# YOUTUBE-BLOCK-END/d' /etc/hosts

cat << 'HOSTS' | sudo tee -a /etc/hosts > /dev/null

# YOUTUBE-BLOCK-START
127.0.0.1 youtube.com
127.0.0.1 www.youtube.com
127.0.0.1 m.youtube.com
127.0.0.1 youtu.be
127.0.0.1 www.youtu.be
127.0.0.1 youtube-nocookie.com
127.0.0.1 www.youtube-nocookie.com
127.0.0.1 youtubei.googleapis.com
127.0.0.1 youtube.googleapis.com
127.0.0.1 ytimg.com
127.0.0.1 i.ytimg.com
127.0.0.1 i9.ytimg.com
127.0.0.1 s.ytimg.com
127.0.0.1 yt3.ggpht.com
127.0.0.1 yt4.ggpht.com
127.0.0.1 googlevideo.com
127.0.0.1 www.googlevideo.com
127.0.0.1 manifest.googlevideo.com
127.0.0.1 redirector.googlevideo.com
127.0.0.1 accounts.youtube.com
127.0.0.1 studio.youtube.com
127.0.0.1 tv.youtube.com
127.0.0.1 music.youtube.com
127.0.0.1 gaming.youtube.com
127.0.0.1 kids.youtube.com
# YOUTUBE-BLOCK-END
HOSTS

sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true
echo "  ✅ DNS bloqué"

# --- 2. FICHIER HOSTS VERROUILLÉ (immutable) ---
echo "[2/6] Verrouillage fichier hosts (immutable)..."
sudo chflags schg /etc/hosts
echo "  ✅ /etc/hosts verrouillé (meme root ne peut pas modifier sans chflags noschg)"

# --- 3. PAC FILE POUR SAFARI ---
echo "[3/6] Blocage Safari via proxy PAC..."
sudo mkdir -p /Library/WebServer/Documents
cat << 'PAC' | sudo tee /Library/WebServer/Documents/block-yt.pac > /dev/null
function FindProxyForURL(url, host) {
    var dominated = [
        "youtube.com", "www.youtube.com", "m.youtube.com",
        "youtu.be", "music.youtube.com", "tv.youtube.com",
        "gaming.youtube.com", "kids.youtube.com",
        "studio.youtube.com", "accounts.youtube.com",
        "youtubei.googleapis.com", "youtube.googleapis.com",
        "googlevideo.com", "ytimg.com",
        "i.ytimg.com", "i9.ytimg.com", "s.ytimg.com",
        "yt3.ggpht.com", "yt4.ggpht.com",
        "manifest.googlevideo.com", "redirector.googlevideo.com",
        "youtube-nocookie.com"
    ];
    for (var i = 0; i < dominated.length; i++) {
        if (dnsDomainIs(host, dominated[i]) || host == dominated[i]) {
            return "PROXY 127.0.0.1:9";
        }
    }
    return "DIRECT";
}
PAC
sudo chflags schg /Library/WebServer/Documents/block-yt.pac

# Activer le PAC sur toutes les interfaces réseau
for iface in $(networksetup -listallnetworkservices | tail -n +2); do
    sudo networksetup -setautoproxyurl "$iface" "file:///Library/WebServer/Documents/block-yt.pac" 2>/dev/null || true
    sudo networksetup -setautoproxystate "$iface" on 2>/dev/null || true
done
echo "  ✅ Proxy PAC activé (Safari bloqué)"

# --- 4. FIREWALL PF ---
echo "[4/6] Blocage firewall..."
cat << 'PFRULES' | sudo tee /etc/pf.anchors/com.apple.yt-filter > /dev/null
block drop quick proto tcp from any to 208.65.152.0/22
block drop quick proto tcp from any to 208.117.224.0/19
block drop quick proto udp from any to 208.65.152.0/22
block drop quick proto udp from any to 208.117.224.0/19
PFRULES

if ! grep -q "com.apple.yt-filter" /etc/pf.conf 2>/dev/null; then
    echo 'anchor "com.apple.yt-filter"' | sudo tee -a /etc/pf.conf > /dev/null
    echo 'load anchor "com.apple.yt-filter" from "/etc/pf.anchors/com.apple.yt-filter"' | sudo tee -a /etc/pf.conf > /dev/null
fi
sudo pfctl -f /etc/pf.conf 2>/dev/null || true
sudo pfctl -e 2>/dev/null || true
sudo chflags schg /etc/pf.anchors/com.apple.yt-filter
echo "  ✅ Firewall activé + verrouillé"

# --- 5. DAEMON GARDIEN #1 ---
echo "[5/6] Installation daemon gardien principal..."
cat << 'GUARDIAN' | sudo tee /usr/local/bin/.com.apple.nsurlsessiond-check > /dev/null
#!/bin/bash
# Gardien YouTube - vérifie toutes les 30s

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

# 2. Vérifier le PAC proxy
for iface in $(networksetup -listallnetworkservices | tail -n +2); do
    state=$(networksetup -getautoproxyurl "$iface" 2>/dev/null | grep "Enabled" | awk '{print $2}')
    if [ "$state" != "Yes" ]; then
        networksetup -setautoproxyurl "$iface" "file:///Library/WebServer/Documents/block-yt.pac" 2>/dev/null || true
        networksetup -setautoproxystate "$iface" on 2>/dev/null || true
    fi
done

# 3. Vérifier PAC file existe
if [ ! -f /Library/WebServer/Documents/block-yt.pac ]; then
    mkdir -p /Library/WebServer/Documents
    cat << 'PACEOF' > /Library/WebServer/Documents/block-yt.pac
function FindProxyForURL(url, host) {
    var d=["youtube.com","www.youtube.com","m.youtube.com","youtu.be","music.youtube.com","tv.youtube.com","gaming.youtube.com","kids.youtube.com","studio.youtube.com","accounts.youtube.com","youtubei.googleapis.com","youtube.googleapis.com","googlevideo.com","ytimg.com","i.ytimg.com","i9.ytimg.com","s.ytimg.com","yt3.ggpht.com","yt4.ggpht.com","manifest.googlevideo.com","redirector.googlevideo.com","youtube-nocookie.com"];
    for(var i=0;i<d.length;i++){if(dnsDomainIs(host,d[i])||host==d[i])return "PROXY 127.0.0.1:9";}
    return "DIRECT";
}
PACEOF
    chflags schg /Library/WebServer/Documents/block-yt.pac
fi

# 4. Vérifier firewall
pfctl -s info 2>/dev/null | grep -q "Status: Enabled" || pfctl -e 2>/dev/null || true

# 5. Vérifier daemon #2 existe toujours
if ! launchctl list 2>/dev/null | grep -q "com.apple.cfnetwork-diag"; then
    launchctl load /Library/LaunchDaemons/com.apple.cfnetwork-diag.plist 2>/dev/null || true
fi
GUARDIAN
sudo chmod +x /usr/local/bin/.com.apple.nsurlsessiond-check

cat << 'PLIST1' | sudo tee /Library/LaunchDaemons/com.apple.nsurlsessiond-check.plist > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.apple.nsurlsessiond-check</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/.com.apple.nsurlsessiond-check</string>
    </array>
    <key>StartInterval</key>
    <integer>30</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
</dict>
</plist>
PLIST1
sudo launchctl load /Library/LaunchDaemons/com.apple.nsurlsessiond-check.plist 2>/dev/null || true
echo "  ✅ Daemon gardien #1 installé"

# --- 6. DAEMON GARDIEN #2 (surveille le #1) ---
echo "[6/6] Installation daemon gardien secondaire..."
cat << 'GUARDIAN2' | sudo tee /usr/local/bin/.com.apple.cfnetwork-diag > /dev/null
#!/bin/bash
# Gardien secondaire - surveille le gardien principal
if ! launchctl list 2>/dev/null | grep -q "com.apple.nsurlsessiond-check"; then
    launchctl load /Library/LaunchDaemons/com.apple.nsurlsessiond-check.plist 2>/dev/null || true
fi
# Re-vérifier hosts rapidement
if ! grep -q "YOUTUBE-BLOCK-START" /etc/hosts 2>/dev/null; then
    /usr/local/bin/.com.apple.nsurlsessiond-check
fi
GUARDIAN2
sudo chmod +x /usr/local/bin/.com.apple.cfnetwork-diag

cat << 'PLIST2' | sudo tee /Library/LaunchDaemons/com.apple.cfnetwork-diag.plist > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.apple.cfnetwork-diag</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/.com.apple.cfnetwork-diag</string>
    </array>
    <key>StartInterval</key>
    <integer>45</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
</dict>
</plist>
PLIST2
sudo launchctl load /Library/LaunchDaemons/com.apple.cfnetwork-diag.plist 2>/dev/null || true
echo "  ✅ Daemon gardien #2 installé"

# --- NETTOYAGE V1 ---
echo ""
echo "Nettoyage ancienne version..."
sudo launchctl unload /Library/LaunchDaemons/com.system.dns-integrity.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.system.dns-integrity.plist 2>/dev/null || true
sudo rm -f /usr/local/bin/.dns-integrity-check 2>/dev/null || true

# --- FLUSH FINAL ---
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo ""
echo "========================================="
echo "🔒 YOUTUBE NUCLÉAIRE V2 ACTIVÉ"
echo "========================================="
echo ""
echo "COUCHES DE PROTECTION :"
echo "  1. /etc/hosts bloqué + IMMUTABLE (chflags schg)"
echo "  2. Proxy PAC : Safari redirigé vers un proxy mort"  
echo "  3. Firewall pf : serveurs vidéo bloqués"
echo "  4. Daemon #1 : remet tout toutes les 30s"
echo "  5. Daemon #2 : surveille le daemon #1 toutes les 45s"
echo "  6. Noms de daemons camouflés en services Apple"
echo ""
echo "POUR CONTOURNER IL FAUDRAIT :"
echo "  - chflags noschg sur 3 fichiers"
echo "  - Désactiver 2 daemons"  
echo "  - Supprimer le proxy PAC"
echo "  - Désactiver le firewall"
echo "  - Et tout ça en moins de 30 secondes"
echo ""
echo "Déblocage le 13 mars 2026 : demande à Claudia."
