# droid — Unified Android Device Management CLI

A unified command-line tool for managing Android devices from Linux — ADB, SSH, screen mirroring (scrcpy), app management, debloat, KDE Connect, and more.

## Features

- **Device control** — SSH, shell, wake/sleep, reboot, mount, home key
- **Screen mirroring** — scrcpy with bitrate/workspace options, DeX mode
- **App management** — list, install, uninstall, launch via fuzzel picker
- **Debloat** — profile-based package removal (generic, samsung)
- **Modules** — list, flash, remove Magisk/KSU modules
- **Network** — ADB tunnel toggle, Kiwix offline wiki, KDE Connect
- **Clipboard** — push/pull to/from device
- **Info & monitoring** — device info, host info, one-shot status dashboard
- **Keyboard-navigable menu** — default interactive interface with arrow/jk navigation

## Quick start

```bash
git clone https://github.com/charan-gn/droid
cd droid
python3 droid --help
```

First run will auto-detect your device. Run `droid init` to probe connection settings and create `~/.config/droid/config.json`.

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

## Usage

```text
droid                          Keyboard-navigable menu (default)
droid dashboard                Textual TUI dashboard
droid info                     Extended device info
droid mirror [--bitrate 8M]   Screen mirroring with scrcpy
droid init                     Auto-detect and save config
droid host                     Show local machine info
droid devices                  List ADB devices
droid switch                   Switch active device via fzf
```

## Config

Config at `~/.config/droid/config.json` — auto-created by `droid init`. See `config.example.json` for the full structure.

## License

MIT
