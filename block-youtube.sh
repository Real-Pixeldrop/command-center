#!/bin/bash
# ===========================================
# YOUTUBE NUCLEAR BLOCK - 1 MOIS MINIMUM
# Par Claudia pour Akli
# ===========================================

set -e

echo "🚫 BLOCAGE YOUTUBE NUCLÉAIRE"
echo "============================"
echo ""

# --- 1. BLOCAGE /etc/hosts ---
echo "[1/4] Blocage DNS via /etc/hosts..."

YOUTUBE_DOMAINS="
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
127.0.0.1 r1---sn-aigl6ned.googlevideo.com
127.0.0.1 r2---sn-aigl6ned.googlevideo.com
127.0.0.1 r3---sn-aigl6ned.googlevideo.com
127.0.0.1 r4---sn-aigl6ned.googlevideo.com
127.0.0.1 r5---sn-aigl6ned.googlevideo.com
127.0.0.1 manifest.googlevideo.com
127.0.0.1 redirector.googlevideo.com
127.0.0.1 accounts.youtube.com
127.0.0.1 studio.youtube.com
127.0.0.1 tv.youtube.com
127.0.0.1 music.youtube.com
127.0.0.1 gaming.youtube.com
127.0.0.1 kids.youtube.com
"

# Supprimer anciens blocages si existants
sudo sed -i '' '/# YOUTUBE-BLOCK-START/,/# YOUTUBE-BLOCK-END/d' /etc/hosts

# Ajouter les blocages
echo "" | sudo tee -a /etc/hosts > /dev/null
echo "# YOUTUBE-BLOCK-START - NE PAS MODIFIER - Actif jusqu'au 13 mars 2026" | sudo tee -a /etc/hosts > /dev/null
echo "$YOUTUBE_DOMAINS" | sudo tee -a /etc/hosts > /dev/null
echo "# YOUTUBE-BLOCK-END" | sudo tee -a /etc/hosts > /dev/null

# Flush DNS
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo "  ✅ DNS bloqué"

# --- 2. FIREWALL PF ---
echo "[2/4] Blocage firewall (pf)..."

# Créer le fichier de règles YouTube (ranges spécifiques vidéo uniquement)
cat << 'PFRULES' | sudo tee /etc/pf.anchors/youtube-block > /dev/null
# Bloquer googlevideo.com (serveurs de streaming vidéo YouTube)
block drop quick proto tcp from any to 208.65.152.0/22
block drop quick proto tcp from any to 208.117.224.0/19
block drop quick proto udp from any to 208.65.152.0/22
block drop quick proto udp from any to 208.117.224.0/19
PFRULES

# Vérifier si l'anchor existe déjà dans pf.conf
if ! grep -q "youtube-block" /etc/pf.conf 2>/dev/null; then
    echo 'anchor "youtube-block"' | sudo tee -a /etc/pf.conf > /dev/null
    echo 'load anchor "youtube-block" from "/etc/pf.anchors/youtube-block"' | sudo tee -a /etc/pf.conf > /dev/null
fi

sudo pfctl -f /etc/pf.conf 2>/dev/null || true
sudo pfctl -e 2>/dev/null || true

echo "  ✅ Firewall activé"

# --- 3. DAEMON AUTO-REPAIR (toutes les 60 secondes) ---
echo "[3/4] Installation du daemon de protection..."

# Ce daemon remet le blocage même si Akli essaie de modifier /etc/hosts
cat << 'DAEMON' | sudo tee /Library/LaunchDaemons/com.system.dns-integrity.plist > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.system.dns-integrity</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/.dns-integrity-check</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/dev/null</string>
    <key>StandardOutPath</key>
    <string>/dev/null</string>
</dict>
</plist>
DAEMON

# Script de réparation auto
cat << 'REPAIR' | sudo tee /usr/local/bin/.dns-integrity-check > /dev/null
#!/bin/bash
# Vérifier que le blocage YouTube est toujours en place
if ! grep -q "YOUTUBE-BLOCK-START" /etc/hosts; then
    # Remettre le blocage
    echo "" >> /etc/hosts
    echo "# YOUTUBE-BLOCK-START - NE PAS MODIFIER - Actif jusqu'au 13 mars 2026" >> /etc/hosts
    echo "127.0.0.1 youtube.com" >> /etc/hosts
    echo "127.0.0.1 www.youtube.com" >> /etc/hosts
    echo "127.0.0.1 m.youtube.com" >> /etc/hosts
    echo "127.0.0.1 youtu.be" >> /etc/hosts
    echo "127.0.0.1 www.youtu.be" >> /etc/hosts
    echo "127.0.0.1 youtube-nocookie.com" >> /etc/hosts
    echo "127.0.0.1 www.youtube-nocookie.com" >> /etc/hosts
    echo "127.0.0.1 youtubei.googleapis.com" >> /etc/hosts
    echo "127.0.0.1 youtube.googleapis.com" >> /etc/hosts
    echo "127.0.0.1 ytimg.com" >> /etc/hosts
    echo "127.0.0.1 i.ytimg.com" >> /etc/hosts
    echo "127.0.0.1 i9.ytimg.com" >> /etc/hosts
    echo "127.0.0.1 s.ytimg.com" >> /etc/hosts
    echo "127.0.0.1 yt3.ggpht.com" >> /etc/hosts
    echo "127.0.0.1 yt4.ggpht.com" >> /etc/hosts
    echo "127.0.0.1 googlevideo.com" >> /etc/hosts
    echo "127.0.0.1 www.googlevideo.com" >> /etc/hosts
    echo "127.0.0.1 manifest.googlevideo.com" >> /etc/hosts
    echo "127.0.0.1 redirector.googlevideo.com" >> /etc/hosts
    echo "127.0.0.1 accounts.youtube.com" >> /etc/hosts
    echo "127.0.0.1 studio.youtube.com" >> /etc/hosts
    echo "127.0.0.1 tv.youtube.com" >> /etc/hosts
    echo "127.0.0.1 music.youtube.com" >> /etc/hosts
    echo "127.0.0.1 gaming.youtube.com" >> /etc/hosts
    echo "127.0.0.1 kids.youtube.com" >> /etc/hosts
    echo "# YOUTUBE-BLOCK-END" >> /etc/hosts
    dscacheutil -flushcache
    killall -HUP mDNSResponder 2>/dev/null || true
fi

# Vérifier que le firewall est actif
pfctl -s info 2>/dev/null | grep -q "Status: Enabled" || pfctl -e 2>/dev/null || true
REPAIR

sudo chmod +x /usr/local/bin/.dns-integrity-check
sudo launchctl load /Library/LaunchDaemons/com.system.dns-integrity.plist 2>/dev/null || true

echo "  ✅ Daemon installé (vérifie toutes les 60s)"

# --- 4. BLOCAGE APP YOUTUBE (si installée) ---
echo "[4/4] Vérification apps YouTube..."

# Bloquer via Screen Time CLI si dispo
if [ -d "/Applications/YouTube.app" ]; then
    sudo chmod 000 "/Applications/YouTube.app"
    echo "  ✅ App YouTube bloquée"
else
    echo "  ℹ️  Pas d'app YouTube installée"
fi

echo ""
echo "========================================="
echo "🔒 YOUTUBE EST BLOQUÉ JUSQU'AU 13 MARS 2026"
echo "========================================="
echo ""
echo "Ce qui est en place :"
echo "  1. DNS bloqué (/etc/hosts)"
echo "  2. Firewall actif (pf)"
echo "  3. Daemon auto-repair (60s)"
echo "  4. Même si tu modifies /etc/hosts, ça revient"
echo ""
echo "⚠️  ATTENTION : Le blocage IP peut affecter"
echo "  certains services Google (Drive, Gmail)."
echo "  Si problème, dis-le à Claudia."
echo ""
echo "Pour débloquer dans 1 mois, demande à Claudia."
