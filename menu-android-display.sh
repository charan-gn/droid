#!/bin/bash

# Launch Android apps directly on external display via am start.
# No scrcpy, no laptop window — app just opens on the monitor.

if ! command -v rofi &>/dev/null; then
    notify-send -u critical "Android Display" "rofi not found."
    exit 1
fi

PHONE_IP=$(ip -4 route show dev eno1 | awk '/^default/ {print $3}' | head -n 1)
[ -z "$PHONE_IP" ] && PHONE_IP=$(ip -4 neighbor show dev eno1 | awk '{print $1}' | grep -v 'FAILED' | head -n 1)
[ -z "$PHONE_IP" ] && { notify-send -u critical "Android Display" "Phone IP not found."; exit 1; }

ADB="adb -s $PHONE_IP:5555"
adb connect "$PHONE_IP:5555" >/dev/null 2>&1

DISP_ID=$($ADB shell dumpsys display \
    | grep -A2 "mDisplayId" \
    | grep -v "mDisplayId=0" \
    | grep -o "mDisplayId=[0-9]*" \
    | head -1 \
    | cut -d= -f2)
[ -z "$DISP_ID" ] && DISP_ID=1

# -3 = user installed only, no system/background services
RAW_APPS=$($ADB shell "pm list packages -3" 2>/dev/null | tr -d '\r')

[ -z "$RAW_APPS" ] && { notify-send -u critical "Android Display" "Could not fetch app list."; exit 1; }

declare -a DISPLAY_NAMES
declare -a PACKAGES

while IFS= read -r line; do
    PKG=$(echo "$line" | sed 's/package://')
    LABEL=$(echo "$PKG" | awk -F. '{print $NF}')
    DISPLAY_NAMES+=("$LABEL  [$PKG]")
    PACKAGES+=("$PKG")
done <<< "$RAW_APPS"

SELECTION=$(printf '%s\n' "${DISPLAY_NAMES[@]}" | rofi -dmenu -p "📺 App on Monitor: " -i)
[ -z "$SELECTION" ] && exit 0

TARGET_PKG=""
for i in "${!DISPLAY_NAMES[@]}"; do
    if [ "${DISPLAY_NAMES[$i]}" = "$SELECTION" ]; then
        TARGET_PKG="${PACKAGES[$i]}"
        break
    fi
done

[ -z "$TARGET_PKG" ] && { notify-send -u normal "Android Display" "Could not resolve package."; exit 0; }

APP_LABEL=$(echo "$SELECTION" | sed 's/  \[.*//')
notify-send -u low "Android Display" "Launching $APP_LABEL on monitor..."

# Resolve the actual launcher activity for the package
ACTIVITY=$($ADB shell "cmd package resolve-activity --brief -c android.intent.category.LAUNCHER $TARGET_PKG" 2>/dev/null | grep "/" | head -1 | tr -d '\r')

if [ -n "$ACTIVITY" ]; then
    $ADB shell am start \
        --display "$DISP_ID" \
        -n "$ACTIVITY" \
        -f 0x10200000 \
        >/dev/null 2>&1
else
    # Fallback: monkey sends a launcher intent to the package
    $ADB shell "ANDROID_DATA=/data monkey --display $DISP_ID -p $TARGET_PKG -c android.intent.category.LAUNCHER 1" >/dev/null 2>&1
fi
