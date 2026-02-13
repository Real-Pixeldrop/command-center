#!/bin/bash
set -e
echo "🚫 BLOCAGE X/TWITTER - PERMANENT"

DOMAINS="x.com www.x.com twitter.com www.twitter.com mobile.twitter.com"

echo "[1/2] Blocage /etc/hosts..."
sudo chflags noschg /etc/hosts 2>/dev/null || true
sudo sed -i '' '/# X-BLOCK-START/,/# X-BLOCK-END/d' /etc/hosts
echo "" | sudo tee -a /etc/hosts > /dev/null
echo "# X-BLOCK-START - PERMANENT" | sudo tee -a /etc/hosts > /dev/null
for d in $DOMAINS; do
    echo "127.0.0.1 $d" | sudo tee -a /etc/hosts > /dev/null
done
echo "# X-BLOCK-END" | sudo tee -a /etc/hosts > /dev/null
sudo chflags schg /etc/hosts
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder 2>/dev/null || true
echo "  ✅ /etc/hosts OK"

echo "[2/2] Blocage /etc/resolver (Safari)..."
sudo chflags -R noschg /etc/resolver 2>/dev/null || true
for d in $DOMAINS; do
    echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/$d > /dev/null
done
sudo chflags -R schg /etc/resolver
echo "  ✅ /etc/resolver OK"

echo ""
echo "🔒 X/TWITTER BLOQUÉ - PERMANENT"
echo "Ferme tes navigateurs et reouvre-les."
