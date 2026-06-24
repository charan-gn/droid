# droid — Unified Companion Device Interface

Turn your Android device into a tightly integrated companion — offload tasks,
mirror its screen, manage apps, tap into its network, and control it remotely
as if it were part of your workstation.

## Features

- **Companion status** — one-shot overview of device health, data link, and offload capabilities
- **Remote shell & exec** — run commands on device via SSH or ADB
- **Screen mirroring** — scrcpy with bitrate/workspace config, DeX mode
- **App management** — list, install, uninstall, launch via fuzzel picker
- **Debloat** — profile-based package removal (generic, samsung)
- **Modules** — list, flash, remove Magisk/KSU modules
- **Network offload** — ADB tunnel, Kiwix offline wiki, KDE Connect
- **Clipboard** — push/pull to/from device
- **Mount** — access phone filesystem via SSHFS
- **DroidSpaces containers** — run Linux containers on device
- **Info & monitoring** — device info, host info, companion status
- **Keyboard-navigable menu** — default interactive interface with arrow/jk navigation

## Quick start

```bash
git clone https://github.com/charan-gn/droid
cd droid
python3 droid --help
```

First run will auto-detect your device. Run `droid init` to probe connection
settings and create `~/.config/droid/config.json`.

## Usage

```text
droid                          Keyboard-navigable menu (default)
droid dashboard                Textual TUI dashboard
droid companion                Companion status overview
droid companion shell          Open shell on device
droid companion exec <cmd>     Run command on device
droid companion share file     Send file to device
droid companion tunnel on|off  Route traffic through device
droid info                     Extended device info
droid mirror [--bitrate 8M]   Screen mirroring with scrcpy
droid init                     Auto-detect and save config
droid host                     Show local machine info
droid devices                  List ADB devices
droid switch                   Switch active device via fzf
```

## Menu sections

| Section      | Purpose |
|-------------|---------|
| **Link**    | SSH, shell, mount — establish a connection to the companion |
| **Mirror**  | scrcpy sessions, DeX mode, screen recording |
| **Offload** | Run commands, manage apps, debloat, modules |
| **Control** | Wake, sleep, home, reboot, info |
| **Network** | Tunnel, Kiwix, KDE Connect — companion network services |
| **Container** | DroidSpaces container access |
| **System**  | Device/host info, companion status, clipboard |

## Dependencies

| Tool | Required for | Install |
|------|-------------|---------|
| `adb` | Core device communication | `sudo pacman -S android-tools` |
| `scrcpy` | Screen mirroring | `sudo pacman -S scrcpy` |
| `fuzzel` | App picker | `sudo pacman -S fuzzel` |
| `kdeconnect-cli` | KDE Connect features | `sudo pacman -S kdeconnect` |
| `kitty` | Terminal for interactive commands | `sudo pacman -S kitty` |

### Optional Python packages

- `rich` — Default panel output (installed with `pip install rich`)
- `textual` — TUI dashboard (`droid dashboard`)

## Config

Config at `~/.config/droid/config.json` — auto-created by `droid init`.
See `config.example.json` for the full structure.

## License

MIT
