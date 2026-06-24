#!/usr/bin/env python3

import sys
import time
import json
import subprocess
import shutil
import socket
import os
import threading

DEBUG = "--debug" in sys.argv

def debug(msg):
    if DEBUG:
        print(f"[DEBUG] {msg}")

def check_dependencies():
    if not shutil.which("ydotool"):
        print("ydotool not found. Please install it: sudo pacman -S ydotool")
        sys.exit(1)
    status = subprocess.run(
        ["systemctl", "--user", "is-active", "ydotool"],
        capture_output=True, text=True
    ).stdout.strip()
    if status != "active":
        print("ydotool daemon is not active. Please start it: systemctl --user enable --now ydotool")
        sys.exit(1)

# Configuration
WINDOW_TITLE  = "Android-Input"
LOG           = "/tmp/scrcpy-kvm.log"
NULL          = subprocess.DEVNULL
EDGE_DEBOUNCE = 3
POLL_INTERVAL = 0.016

def notify(icon, title, msg, urgency="normal"):
    subprocess.Popen(
        ["notify-send", "-u", urgency, "-a", "Android KVM", title, f"{icon} {msg}"],
        stdout=NULL, stderr=NULL
    )
    debug(f"Notify: {icon} {msg}")

_rctrl_event = threading.Event()

def _rctrl_listener(stop_flag: threading.Event):
    try:
        import evdev
        from evdev import ecodes
    except ImportError:
        debug("python-evdev not found")
        return

    KEY_RIGHTCTRL = ecodes.KEY_RIGHTCTRL

    def open_keyboards():
        boards = []
        for path in evdev.list_devices():
            try:
                dev = evdev.InputDevice(path)
                cap = dev.capabilities()
                if ecodes.EV_KEY in cap and KEY_RIGHTCTRL in cap[ecodes.EV_KEY]:
                    boards.append(dev)
                    debug(f"Monitoring {dev.name} ({path})")
            except Exception:
                pass
        return boards

    keyboards = open_keyboards()
    if not keyboards:
        debug("No keyboard devices found.")
        return

    import selectors
    sel = selectors.DefaultSelector()
    for kb in keyboards:
        sel.register(kb, selectors.EVENT_READ)

    while not stop_flag.is_set():
        ready = sel.select(timeout=0.5)
        for key, _ in ready:
            dev = key.fileobj
            try:
                for event in dev.read():
                    if (event.type == ecodes.EV_KEY
                            and event.code == KEY_RIGHTCTRL
                            and event.value == 1):
                        debug("RCtrl keydown detected")
                        _rctrl_event.set()
            except Exception:
                pass

    sel.close()
    for kb in keyboards:
        try:
            kb.close()
        except Exception:
            pass

def _find_hypr_socket():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not sig:
        return None
    xdg = os.environ.get("XDG_RUNTIME_DIR", "/run/user/1000")
    for p in [f"{xdg}/hypr/{sig}/.socket.sock", f"/tmp/hypr/{sig}/.socket.sock"]:
        if os.path.exists(p):
            return p
    return None

_HYPR_SOCK = _find_hypr_socket()

def hyprctl_request(cmd):
    if _HYPR_SOCK:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(_HYPR_SOCK)
                s.sendall(f"-j/{cmd}".encode())
                chunks = []
                while True:
                    data = s.recv(8192)
                    if not data:
                        break
                    chunks.append(data)
                return b"".join(chunks).decode()
        except Exception:
            pass
    return subprocess.check_output(["hyprctl", "-j", cmd]).decode()

def get_active_workspace():
    try:
        return json.loads(hyprctl_request("activeworkspace")).get("id", 1)
    except Exception:
        return 1

def get_monitors():
    try:
        return json.loads(hyprctl_request("monitors"))
    except Exception:
        return []

_mon_cache = {"data": [], "ts": 0.0}
_MON_TTL   = 30.0

def cached_monitors():
    now = time.monotonic()
    if not _mon_cache["data"] or now - _mon_cache["ts"] > _MON_TTL:
        _mon_cache["data"] = get_monitors()
        _mon_cache["ts"]   = now
    return _mon_cache["data"]

def get_focused_monitor_bounds():
    for m in cached_monitors():
        if m.get("focused"):
            scale = m.get("scale", 1.0)
            return int(m["width"] / scale), int(m["height"] / scale), int(m["x"]), int(m["y"])
    return 1920, 1080, 0, 0

def get_right_edge():
    mons = cached_monitors()
    if not mons:
        return 1920
    return max(m["x"] + int(m["width"] / m.get("scale", 1.0)) for m in mons)

def get_cursor_pos():
    try:
        data = json.loads(hyprctl_request("cursorpos"))
        return int(data.get("x", 0)), int(data.get("y", 0))
    except Exception:
        try:
            out = subprocess.check_output(["hyprctl", "cursorpos"]).decode()
            x_str, y_str = out.strip().split(",")
            return int(x_str.strip()), int(y_str.strip())
        except Exception:
            return 0, 0

def get_adb_device_serial():
    result = subprocess.run(
        ["adb", "devices"], capture_output=True, text=True, timeout=5
    )
    for line in result.stdout.strip().splitlines()[1:]:
        if not line.strip():
            continue
        parts = line.split()
        if len(parts) >= 2 and parts[1] == "device":
            return parts[0]
    notify("X", "Android KVM", "No ADB device found. Connect via USB.", "critical")
    sys.exit(1)

def setup_hyprland_rules():
    title_match = f"title:^({WINDOW_TITLE})$"
    class_match = "class:^(scrcpy)$"

    invisible = [
        f"noanim,{m}" for m in (title_match, class_match)
    ] + [
        f"opacity 0.0 override 0.0 override,{m}" for m in (title_match, class_match)
    ] + [
        f"noborder,{title_match}",
        f"noblur,{title_match}",
        f"noshadow,{title_match}",
    ]

    placement = [
        f"move -9999 -9999,{title_match}",
        f"move -9999 -9999,{class_match}",
        f"size 200 200,{title_match}",
        f"float,{title_match}",
    ]

    workspace = [
        f"workspace special:kvm silent,{title_match}",
        f"workspace special:kvm silent,{class_match}",
    ]

    focus_suppression = [
        f"suppressevent activate activatefocus,{title_match}",
        f"suppressevent activate activatefocus,{class_match}",
        f"noinitialfocus,{title_match}",
        f"noinitialfocus,{class_match}",
    ]

    for rule in invisible + placement + workspace + focus_suppression:
        subprocess.run(["hyprctl", "keyword", "windowrulev2", rule], stdout=NULL, stderr=NULL)

def launch_scrcpy_backbone(serial):
    setup_hyprland_rules()
    cmd = [
        "scrcpy",
        f"--serial={serial}",
        "--no-video",
        "--no-audio",
        "--keyboard=sdk",
        #"--prefer-text",
        "--mouse=uhid",
        "--mouse-bind=++++:++++",
        "--stay-awake",
        f"--window-title={WINDOW_TITLE}",
        "--shortcut-mod=rctrl",
    ]
    log_file = open(LOG, "w")
    proc = subprocess.Popen(cmd, stdout=log_file, stderr=log_file)
    return proc, log_file

def switch_to_android(active_ws, center_x, center_y):
    debug(f"Activating Android -- ws={active_ws}, warp=({center_x},{center_y})")
    batch = (
        f"dispatch movetoworkspacesilent {active_ws},title:^({WINDOW_TITLE})$ ; "
        f"dispatch focuswindow title:^({WINDOW_TITLE})$ ; "
        f"dispatch movecursor {center_x} {center_y}"
    )
    subprocess.run(["hyprctl", "--batch", batch], stdout=NULL, stderr=NULL)
    time.sleep(0.04)
    subprocess.run(["ydotool", "click", "0xC0"], stdout=NULL, stderr=NULL)

def switch_to_pc():
    debug("Returning to PC")
    subprocess.run(
        ["hyprctl", "dispatch", "movetoworkspacesilent",
         f"special:kvm,title:^({WINDOW_TITLE})$"],
        stdout=NULL, stderr=NULL
    )

def main():
    if DEBUG:
        print("DEBUG MODE ENABLED")

    check_dependencies()
    subprocess.run(["adb", "connect", "10.42.0.1:5555"], capture_output=True, timeout=5)
    serial = get_adb_device_serial()
    scrcpy_proc, log_file = launch_scrcpy_backbone(serial)

    time.sleep(1.5)
    notify("*", "Android KVM", "Seamless KVM active! Move mouse to right edge.", "normal")

    _stop_flag = threading.Event()
    listener_thread = threading.Thread(
        target=_rctrl_listener, args=(_stop_flag,), daemon=True
    )
    listener_thread.start()

    is_on_android = False
    right_edge    = get_right_edge()
    EDGE_TRIGGER  = right_edge - 2
    edge_count    = 0

    debug(f"Right edge={right_edge}, trigger at x>={EDGE_TRIGGER}, debounce={EDGE_DEBOUNCE}")

    try:
        while scrcpy_proc.poll() is None:
            x, y = get_cursor_pos()

            if not is_on_android:
                if x >= EDGE_TRIGGER:
                    edge_count += 1
                    debug(f"Edge count {edge_count}/{EDGE_DEBOUNCE} at x={x}")
                    if edge_count >= EDGE_DEBOUNCE:
                        is_on_android = True
                        edge_count    = 0
                        _rctrl_event.clear()
                        notify("*", "Android KVM", "Switched to Android! (RCtrl to return)", "low")
                        active_ws    = get_active_workspace()
                        w, h, mx, my = get_focused_monitor_bounds()
                        switch_to_android(active_ws, mx + w // 2, my + h // 2)
                else:
                    edge_count = 0

            elif _rctrl_event.is_set():
                _rctrl_event.clear()
                is_on_android = False
                edge_count    = 0
                switch_to_pc()
                notify("*", "Android KVM", "Returned to PC (RCtrl)", "low")

            elif is_on_android:
                w, h, mx, my = get_focused_monitor_bounds()
                if x < (mx + w // 2) - 250:
                    is_on_android = False
                    edge_count    = 0
                    switch_to_pc()
                    notify("*", "Android KVM", "Returned to PC", "low")

            time.sleep(POLL_INTERVAL)

    except KeyboardInterrupt:
        debug("Keyboard interrupt -- shutting down.")
    finally:
        _stop_flag.set()
        scrcpy_proc.terminate()
        log_file.close()
        notify("*", "Android KVM", "Session ended cleanly.", "low")

if __name__ == "__main__":
    main()
