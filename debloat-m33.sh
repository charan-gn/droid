#!/bin/bash
set -e

echo "=== Debloating Samsung M33 5G (M336BU) ==="
echo "Device: $(adb shell getprop ro.build.fingerprint)"
echo ""

# -- Facebook / Meta (4 packages) --
echo "[1/5] Meta bloat"
adb shell pm uninstall -k --user 0 com.facebook.katana        # Facebook app
adb shell pm uninstall -k --user 0 com.facebook.appmanager     # FB app manager
adb shell pm uninstall -k --user 0 com.facebook.system         # FB system provider
adb shell pm uninstall -k --user 0 com.facebook.services       # FB background services

# -- Instagram + LinkedIn --
echo "[2/5] Social bloat"
adb shell pm uninstall -k --user 0 com.instagram.android       # Instagram
adb shell pm uninstall -k --user 0 com.linkedin.android         # LinkedIn

# -- Microsoft suite --
echo "[3/5] Microsoft bloat"
adb shell pm uninstall -k --user 0 com.microsoft.office.officehubrow  # Office Hub
adb shell pm uninstall -k --user 0 com.microsoft.office.outlook       # Outlook
adb shell pm uninstall -k --user 0 com.microsoft.skydrive             # OneDrive
adb shell pm uninstall -k --user 0 com.microsoft.appmanager           # MS App Manager

# -- Samsung bloat (safe to remove) --
echo "[4/5] Samsung bloat"
# Bixby / AI
adb shell pm uninstall -k --user 0 com.samsung.android.app.spage              # Samsung Free / Bixby Home
adb shell pm uninstall -k --user 0 com.samsung.android.visionintelligence      # Bixby Vision
adb shell pm uninstall -k --user 0 com.samsung.android.intellivoiceservice     # Bixby Voice
adb shell pm uninstall -k --user 0 com.samsung.android.bixbyvision.framework   # Bixby Vision framework
# Samsung Pass (disables fingerprint/pass auto-fill)
adb shell pm uninstall -k --user 0 com.samsung.android.samsungpass             # Samsung Pass
adb shell pm uninstall -k --user 0 com.samsung.android.samsungpassautofill     # Pass autofill
# Game stuff
adb shell pm uninstall -k --user 0 com.samsung.android.game.gamehome          # Game Launcher
adb shell pm uninstall -k --user 0 com.samsung.android.game.gametools          # Game Tools
adb shell pm uninstall -k --user 0 com.samsung.android.game.gos                # Game Optimizing Service
# Misc Samsung
adb shell pm uninstall -k --user 0 com.samsung.android.app.reminder            # Reminder
adb shell pm uninstall -k --user 0 com.samsung.android.forest                  # Digital Wellbeing (Samsung)
adb shell pm uninstall -k --user 0 com.samsung.android.rubin.app               # Content suggestion engine
adb shell pm uninstall -k --user 0 com.samsung.android.app.dressroom           # AR Dress Room
adb shell pm uninstall -k --user 0 com.samsung.android.tvplus                  # Samsung TV Plus
adb shell pm uninstall -k --user 0 com.samsung.android.smartswitchassistant    # Smart Switch
adb shell pm uninstall -k --user 0 com.samsung.android.voc                      # Voice of Customer (feedback)
adb shell pm uninstall -k --user 0 com.samsung.sree                             # Samsung REE
adb shell pm uninstall -k --user 0 com.sec.android.app.kidshome                # Kids Home
adb shell pm uninstall -k --user 0 com.samsung.android.kidsinstaller            # Kids Installer
adb shell pm uninstall -k --user 0 com.sec.android.emergencylauncher            # Emergency mode launcher
adb shell pm uninstall -k --user 0 com.samsung.android.emergency                # Emergency device config
# Samsung Internet (can reinstall from Galaxy Store)
adb shell pm uninstall -k --user 0 com.sec.android.app.sbrowser                # Samsung Internet

# -- Carrier bloat --
echo "[5/5] Carrier bloat"
adb shell pm uninstall -k --user 0 com.rsupport.rs.activity.rsupport.aas2       # Remote support (Airtel)

# -- Google bloat --
echo ""
echo "--- Google extra bloat ---"
adb shell pm uninstall -k --user 0 com.google.android.apps.youtube.music        # YT Music
adb shell pm uninstall -k --user 0 com.google.android.videos                    # Play Movies
adb shell pm uninstall -k --user 0 com.spotify.music                            # Spotify

echo ""
echo "=== Done. Reboot device for clean state. ==="
echo "Run: adb reboot"
