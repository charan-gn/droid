#!/bin/bash
# Configuration
ZIM_DIR="/run/media/charan/New Volume/Kiwix"
PORT=8080
LOG_FILE="/tmp/kiwix-serve.log"

# 1. HARD TOGGLE
if ss -tulpn | grep -q ":$PORT "; then
    echo "Stopping existing server..."
    fuser -k $PORT/tcp > /dev/null 2>&1
    notify-send "📚 Kiwix" "Server Stopped"
    exit 0
fi

# 2. IP DISCOVERY
LAPTOP_IP=$(ip addr show eno1 2>/dev/null | awk '/inet /{print $2}' | cut -d/ -f1 | head -n 1)
[ -z "$LAPTOP_IP" ] && LAPTOP_IP=$(hostname -I | awk '{print $1}')
if [ -z "$LAPTOP_IP" ]; then
    notify-send "❌ Error" "No network IP found on eno1." -u critical
    exit 1
fi
URL="http://$LAPTOP_IP:$PORT"

# 3. START SERVER
shopt -s nullglob
ZIM_FILES=("$ZIM_DIR"/*.zim)
shopt -u nullglob
if [ ${#ZIM_FILES[@]} -eq 0 ]; then
    notify-send "❌ Error" "No .zim files found in $ZIM_DIR" -u critical
    exit 1
fi
kiwix-serve --port "$PORT" "${ZIM_FILES[@]}" > "$LOG_FILE" 2>&1 &

# 4. VERIFY & CLIPBOARD
TIMEOUT=10
ELAPSED=0
while ! ss -tulpn | grep -q ":$PORT "; do
    sleep 0.5
    ELAPSED=$((ELAPSED + 1))
    [ $ELAPSED -ge $((TIMEOUT * 2)) ] && break
done

if ss -tulpn | grep -q ":$PORT "; then
    echo -n "$URL" | wl-copy
    notify-send "✅ Kiwix Online" "Library: $URL\nCopied to clipboard."
    echo "Server started: $URL"
else
    ERROR_MSG=$(tail -n 2 "$LOG_FILE")
    notify-send "❌ Kiwix Crash" "$ERROR_MSG" -u critical
fi
