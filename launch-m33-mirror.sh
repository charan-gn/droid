#!/bin/bash
# M33 External Display — virtual display, 1920x1080, workspace 2
# Usage: launch-m33-mirror.sh

M33_SERIAL="RZCT90QFNAV"

cleanup() {
  adb -s $M33_SERIAL shell cmd power set-fixed-performance-mode-enabled false 2>/dev/null
}
trap cleanup EXIT

pkill -f "scrcpy.*M33_EXTERNAL"

hyprctl keyword windowrule "workspace 2,          match:title ^(M33_EXTERNAL)$"
hyprctl keyword windowrule "fullscreen 2,         match:title ^(M33_EXTERNAL)$"
hyprctl keyword windowrule "border_size 0,        match:title ^(M33_EXTERNAL)$"
hyprctl keyword windowrule "rounding 0,           match:title ^(M33_EXTERNAL)$"
hyprctl keyword windowrule "no_anim on,           match:title ^(M33_EXTERNAL)$"

adb -s $M33_SERIAL shell cmd power set-fixed-performance-mode-enabled true 2>/dev/null
adb -s $M33_SERIAL shell settings put global policy_control immersive.navigation=* 2>/dev/null
adb -s $M33_SERIAL shell settings put global window_animation_scale 0 2>/dev/null
adb -s $M33_SERIAL shell settings put global transition_animation_scale 0 2>/dev/null
adb -s $M33_SERIAL shell settings put global animator_duration_scale 0 2>/dev/null

env SDL_VIDEODRIVER=wayland scrcpy -s $M33_SERIAL \
  --new-display=1920x1080/284 \
  --video-codec=h264 \
  --video-bit-rate=8M \
  --max-fps=60 \
  --keyboard=uhid \
  --video-buffer=0 \
  --no-audio \
  --window-borderless \
  --turn-screen-off \
  --no-clipboard-autosync \
  --window-title="M33_EXTERNAL" \
  --fullscreen &

SCRCPY_PID=$!
sleep 1.5
hyprctl dispatch workspace 2
wait $SCRCPY_PID
