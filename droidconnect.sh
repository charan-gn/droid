#!/bin/bash
# DroidSpaces connector — opens a terminal into the Debian container
# Bind: bind = $mainMod SHIFT, G, exec, ~/scripts/droidconnect.sh
# Usage: droidconnect.sh [--x11] [--cmd "command"]

SERIAL="a82419c7"
CONTAINER="debian"
DROID="/data/local/Droidspaces/bin/droidspaces"
SOCAT_PORT=6001
ADB="adb -s $SERIAL"

# X11 bridge (only start if not already running)
if ! pgrep -f "socat.*:$SOCAT_PORT.*X1" > /dev/null; then
  socat TCP-LISTEN:$SOCAT_PORT,reuseaddr,fork UNIX-CONNECT:/tmp/.X11-unix/X1 &
  $ADB reverse tcp:$SOCAT_PORT tcp:$SOCAT_PORT 2>/dev/null
fi

# Wait for device if needed
$ADB wait-for-device 2>/dev/null || {
  notify-send "DroidSpaces" "Device not connected"
  exit 1
}

# Parse args
case "$1" in
  --x11)
    shift
    kitty --title "droidspaces - $CONTAINER" \
      -e $ADB exec-out "$DROID --name=$CONTAINER run env DISPLAY=:1 ${1:-bash}"
    ;;
  --cmd)
    shift
    $ADB exec-out "$DROID --name=$CONTAINER run sh -c '$*'"
    ;;
  *)
    kitty --title "droidspaces - $CONTAINER" \
      -e $ADB exec-out "$DROID --name=$CONTAINER enter"
    ;;
esac
