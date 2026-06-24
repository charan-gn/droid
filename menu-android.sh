#!/bin/bash
# Launch Android apps on Hyprland via scrcpy --new-display.
# Requires: scrcpy >= 2.1, adb, rofi-wayland, jq

if ! command -v rofi &>/dev/null; then
    notify-send -u critical "Android KVM" "rofi not found. Run: sudo pacman -S rofi-wayland"; exit 1
fi
if ! command -v scrcpy &>/dev/null; then
    notify-send -u critical "Android KVM" "scrcpy not found. Run: sudo pacman -S scrcpy"; exit 1
fi
if ! command -v jq &>/dev/null; then
    notify-send -u critical "Android KVM" "jq not found. Run: sudo pacman -S jq"; exit 1
fi

# --- IP detection ---
PHONE_IP=$(ip -4 route show dev eno1 | awk '/^default/ {print $3}' | head -n 1)
if [ -z "$PHONE_IP" ]; then
    PHONE_IP=$(ip -4 neighbor show dev eno1 | awk '{print $1}' | grep -v 'FAILED' | head -n 1)
fi
if [ -z "$PHONE_IP" ]; then
    notify-send -u critical "Android KVM" "Phone IP not found. Is Tethering ON?"; exit 1
fi

ADB="adb -s $PHONE_IP:5555"
adb connect "$PHONE_IP:5555" >/dev/null 2>&1
$ADB wait-for-device

# --- Mode selection ---
MODE=$(printf '📱 Portrait  (phone size)\n🖥️  Tile-fit  (no black bars)' \
    | rofi -dmenu -p "Display mode: " -i -no-custom)
[ -z "$MODE" ] && exit 0

if [[ "$MODE" == 📱* ]]; then
    DISPLAY_SIZE="1080x1920/420"
else
    FOCUSED_MON=$(hyprctl monitors -j | jq -r '[.[] | select(.focused == true)][0]')
    MON_W=$(echo "$FOCUSED_MON" | jq -r '.width')
    MON_H=$(echo "$FOCUSED_MON" | jq -r '.height')
    WORKSPACE_ID=$(hyprctl activewindow -j 2>/dev/null | jq -r '.workspace.id // 1')
    WIN_COUNT=$(hyprctl clients -j | jq --argjson ws "$WORKSPACE_ID" \
        '[.[] | select(.workspace.id == $ws and .floating == false)] | length')
    TILE_W=$(( MON_W / (WIN_COUNT + 1) ))
    DISPLAY_SIZE="${TILE_W}x${MON_H}/240"
fi

# --- Fetch app list ---
RAW_APPS=$($ADB shell "pm list packages -3" 2>/dev/null | tr -d '\r')
if [ -z "$RAW_APPS" ]; then
    notify-send -u critical "Android KVM" "Could not fetch app list via ADB."; exit 1
fi

declare -a DISPLAY_NAMES
declare -a PACKAGES
while IFS= read -r line; do
    PKG=$(echo "$line" | sed 's/package://')
    LABEL=$(echo "$PKG" | awk -F. '{print $NF}')
    DISPLAY_NAMES+=("$LABEL  [$PKG]")
    PACKAGES+=("$PKG")
done <<< "$RAW_APPS"

SELECTION=$(printf '%s\n' "${DISPLAY_NAMES[@]}" | rofi -dmenu -p "🤖 Android App: " -i)
[ -z "$SELECTION" ] && exit 0

TARGET_PKG=""
for i in "${!DISPLAY_NAMES[@]}"; do
    if [ "${DISPLAY_NAMES[$i]}" = "$SELECTION" ]; then
        TARGET_PKG="${PACKAGES[$i]}"
        break
    fi
done

[ -z "$TARGET_PKG" ] && { notify-send -u normal "Android KVM" "Could not resolve package."; exit 0; }

APP_LABEL=$(echo "$SELECTION" | sed 's/  \[.*//')
notify-send -u low "Android KVM" "Launching $APP_LABEL ($DISPLAY_SIZE)..."

scrcpy \
    --serial="$PHONE_IP:5555" \
    --new-display=$DISPLAY_SIZE \
    --start-app="$TARGET_PKG" \
    --window-title="Android: $APP_LABEL" \
    --audio-source=output \
    >/dev/null 2>&1 &
