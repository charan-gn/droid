  GNU nano 9.0                                                      /data/data/com.termux/files/usr/bin/tx11start
  1 #!/data/data/com.termux/files/usr/bin/bash
  2
  3 # ─── Config ───────────────────────────────────────────────────────────────────
  4 ARCH=/data/local/chroot-distro/installed-rootfs/archlinux
  5 TERMUX_TMP=/data/data/com.termux/files/usr/tmp
  6 USER=charan
  7 RUNTIME_DIR=/tmp/runtime-charan
  8
  9 # ─── 0. Wake lock ─────────────────────────────────────────────────────────────
 10 termux-wake-lock
 11
 12 # ─── 1. Kill stale sessions ───────────────────────────────────────────────────
 13 echo "[tx11] Cleaning up stale sessions..."
 14 pkill -9 termux-x11              2>/dev/null
 15 pkill -9 pulseaudio               2>/dev/null
 16 pkill -9 pipewire                 2>/dev/null
 17 pkill -9 pipewire-pulse           2>/dev/null
 18 pkill -9 -f "i3"                  2>/dev/null
 19 pkill -9 picom                    2>/dev/null
 20 pkill -9 virgl_test_server        2>/dev/null
 21 pkill -9 virgl_test_server_android 2>/dev/null
 22 sleep 0.5
 23 rm -rf "$TMPDIR/.X11-unix/X0" "$TMPDIR/.X0-lock"
 24
 25 # ─── 2. ADB ───────────────────────────────────────────────────────────────────
 26 echo "[tx11] Starting ADB..."
 27 adb kill-server
 28 adb start-server
 29 adb connect localhost:5555
 30 sleep 2
 31
 32 # ─── 3. PulseAudio (Replacing PipeWire) ───────────────────────────────────────
 33 echo "[tx11] Starting PulseAudio..."
 34 # We load the TCP module so the chroot can connect to Termux's PulseAudio
 35 pulseaudio --start --exit-idle-time=-1
 36 pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null
 37 sleep 1
 38
 39 # ─── 4. VirGL server ──────────────────────────────────────────────────────────
 40 echo "[tx11] Starting VirGL server..."
 41 virgl_test_server_android &
 42 sleep 1
 43 chmod 777 "$TMPDIR/.virgl_test"
 44
 45 # ─── 5. Termux-X11 ────────────────────────────────────────────────────────────
 46 echo "[tx11] Starting Termux-X11..."
 47 XDG_RUNTIME_DIR=${TMPDIR} termux-x11 :0 -ac &
 48 sleep 3
 49
 50 # ─── 6. Find external display ID ──────────────────────────────────────────────
 51 DISP_ID=$(adb -s localhost:5555 shell dumpsys display \
 52   | grep -A2 "mDisplayId" \
 53   | grep -v "mDisplayId=0" \
 54   | grep -o "mDisplayId=[0-9]*" \
 55   | head -1 \
 56   | cut -d= -f2)
 57 [ -z "$DISP_ID" ] && DISP_ID=13
 58 echo "[tx11] Using display ID: $DISP_ID"
 59
 60 # ─── 7. Launch Termux:X11 on external display ─────────────────────────────────
 61 adb -s localhost:5555 shell am force-stop com.termux.x11
 62 sleep 0.5
 63 adb -s localhost:5555 shell am start \
 64   --display "$DISP_ID" \
 65   --windowingMode 1 \
 66   -n com.termux.x11/.MainActivity
 67 sleep 1
 68
 69 # ─── 8. Fix Termux tmp permissions ────────────────────────────────────────────
 70 chmod -R 1777 "$TERMUX_TMP" 2>/dev/null
 71
 72 # ─── 9. Chroot + i3 ───────────────────────────────────────────────────────────
 73 echo "[tx11] Entering chroot..."
 74 su -c "
 75   ARCH='$ARCH'
 76   TERMUX_TMP='$TERMUX_TMP'
 77   USER='$USER'
 78   RUNTIME_DIR='$RUNTIME_DIR'
 79
 80   mount -o remount,rw,exec,suid,dev /data
 81   mount --bind /dev      \$ARCH/dev
 82   mount --bind /dev/pts  \$ARCH/dev/pts
 83   mount --bind /proc     \$ARCH/proc
 84   mount --bind /sys      \$ARCH/sys
 85
 86   mkdir -p \$ARCH/dev/shm
 87   mount -t tmpfs -o mode=1777,nosuid,nodev tmpfs \$ARCH/dev/shm
 88
 89   mount --bind \$TERMUX_TMP \$ARCH/tmp
 90
 91   mkdir -p \$ARCH/home/\$USER/android-storage
 92   mount --bind /sdcard \$ARCH/home/\$USER/android-storage
 93
 94   chmod 666 /dev/kgsl-3d0 2>/dev/null || true
 95   chmod 666 /dev/dri/*    2>/dev/null || true
 96
 97   chroot \$ARCH /usr/sbin/sshd -p 2222
 98
 99   chroot \$ARCH /bin/su - \$USER -c '
100     export DISPLAY=:0
101     export PULSE_SERVER=127.0.0.1
102     export XDG_RUNTIME_DIR=/tmp/runtime-charan
103
104     # OpenGL / Vulkan Exports
105     export GALLIUM_DRIVER=virpipe
106     export MESA_GL_VERSION_OVERRIDE=4.3COMPAT
107     export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/freedreno_icd.aarch64.json
108
109     rm -rf /tmp/runtime-charan
110     mkdir -p /tmp/runtime-charan
111     chmod 0700 /tmp/runtime-charan
112
113     exec dbus-run-session i3
114   '
115 "
116
117 # ─── 10. Cleanup on exit ──────────────────────────────────────────────────────
118 echo "[tx11] Session ended. Cleaning up..."
119 termux-wake-unlock
120 pkill -9 virgl_test_server_android 2>/dev/null
121 pulseaudio --kill 2>/dev/null
122
123 su -c "
124   ARCH='$ARCH'
125   chroot \$ARCH /usr/bin/pkill -u charan 2>/dev/null
126   sleep 1
127   umount -l \$ARCH/tmp \$ARCH/home/charan/android-storage \$ARCH/dev/shm \
128             \$ARCH/sys \$ARCH/proc \$ARCH/dev/pts \$ARCH/dev 2>/dev/null
129 "
130 echo "[tx11] Done."
131


