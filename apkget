#!/usr/bin/env bash
# apkget — search, download & sideload Android apps from your terminal
# Usage: apkget install [name] | apkget local | apkget uninstall <name> | apkget list [filter]
#        apkget modules [flash]

set -euo pipefail

# ── Config ────────────────────────────────────────────────────────────────────
APK_DIR="${APKGET_DIR:-$HOME/apkget/apks}"
MODULES_DIR="${APKGET_MODULES_DIR:-$HOME/apkget/modules}"
mkdir -p "$APK_DIR" "$MODULES_DIR"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

# ── Helpers ───────────────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}  →${RESET} $*"; }
success() { echo -e "${GREEN}  ✓${RESET} $*"; }
err()     { echo -e "${RED}  ✗${RESET} $*" >&2; }
bold()    { echo -e "${BOLD}$*${RESET}"; }

usage() {
    bold "apkget — Android app & module manager from your terminal"
    echo ""
    echo "  Usage:"
    echo "    apkget install   [app name]    Search & install from Play Store (or pick local if no name)"
    echo "    apkget local                   List and install downloaded APKs from your local dir"
    echo "    apkget uninstall <app name>    Uninstall an app from your phone"
    echo "    apkget list      [filter]      List installed apps (optional filter)"
    echo "    apkget modules                 List and flash Magisk modules from local dir"
    echo "    apkget modules list            List installed Magisk modules on device"
    echo "    apkget modules remove          Remove an installed Magisk module"
    echo ""
    echo "  Examples:"
    echo "    apkget install vlc"
    echo "    apkget install                 # opens local package picker"
    echo "    apkget uninstall vlc"
    echo "    apkget list google"
    echo "    apkget modules"
    echo "    apkget modules list"
    echo "    apkget modules remove"
    echo ""
    echo "  Config:"
    echo "    APK downloads go to:    ${APK_DIR}"
    echo "    Modules directory:      ${MODULES_DIR}"
    echo "    Override APKs with:     export APKGET_DIR=/your/path"
    echo "    Override modules with:  export APKGET_MODULES_DIR=/your/path"
}

check_deps() {
    local mode="${1:-all}"
    local missing=()
    local req=(adb)
    
    # Only require apkeep and python3 if we are doing a web search
    [[ "$mode" == "all" ]] && req+=(apkeep python3)

    for cmd in "${req[@]}"; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        err "Missing tools: ${missing[*]}"
        echo ""
        echo "  Install hints:"
        [[ " ${missing[*]} " =~ " apkeep " ]] && echo "    cargo install apkeep"
        [[ " ${missing[*]} " =~ " adb " ]]    && echo "    sudo pacman -S android-tools"
        exit 1
    fi
}

check_device() {
    local devices
    devices=$(adb devices 2>/dev/null | grep -v "List of devices" | grep "device$" || true)
    if [[ -z "$devices" ]]; then
        err "No ADB device connected."
        echo "  Make sure USB debugging / wireless ADB is enabled."
        exit 1
    fi
    local dev_id
    dev_id=$(echo "$devices" | awk '{print $1}' | head -1)
    success "Device: ${dev_id}"
}

check_root() {
    if ! adb shell "su -c 'id'" 2>/dev/null | grep -q "uid=0"; then
        err "Root access not available via ADB shell."
        echo "  Make sure Magisk has granted ADB root, or enable 'ADB Shell' in Magisk settings."
        exit 1
    fi
}

# ── Search ────────────────────────────────────────────────────────────────────
search_packages() {
    local query="$1"
    info "Searching Play Store for '${query}'..." >/dev/tty

    python3 - "$query" <<'PYEOF'
import sys, re, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor

query = sys.argv[1]
encoded = urllib.parse.quote(query)
UA = 'Mozilla/5.0 (X11; Linux x86_64; rv:124.0) Gecko/20100101 Firefox/124.0'

def fetch(url):
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    return urllib.request.urlopen(req, timeout=10).read().decode('utf-8', errors='ignore')

try:
    html = fetch(f'https://play.google.com/store/search?q={encoded}&c=apps&hl=en_US')
except Exception:
    sys.exit(1)

packages, seen =[], set()
for pkg in re.findall(r'details\?id=([a-zA-Z][a-zA-Z0-9_.]+)', html):
    if '.' in pkg and pkg not in seen:
        seen.add(pkg)
        packages.append(pkg)
    if len(packages) >= 8:
        break

def get_name(pkg):
    try:
        h = fetch(f'https://play.google.com/store/apps/details?id={pkg}&hl=en_US')
        m = re.search(r'<title>(.+?) - Apps on Google Play</title>', h)
        if m:
            return pkg, m.group(1).strip()
    except Exception:
        pass
    return pkg, pkg

with ThreadPoolExecutor(max_workers=6) as ex:
    results = list(ex.map(get_name, packages))

for pkg, name in results:
    print(f"{name}\t{pkg}")
PYEOF
}

# ── Pickers ───────────────────────────────────────────────────────────────────

pick_app() {
    local -a names=()
    local -a pkgs=()
    while IFS=$'\t' read -r name pkg; do
        [[ -n "$pkg" ]] && { names+=("$name"); pkgs+=("$pkg"); }
    done

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        err "No results." >/dev/tty
        exit 1
    fi

    echo "" >/dev/tty
    echo -e "${BOLD}Results:${RESET}" >/dev/tty
    local i=1
    for name in "${names[@]}"; do
        printf "  ${YELLOW}[%d]${RESET} %s ${DIM}(%s)${RESET}\n" "$i" "$name" "${pkgs[$((i-1))]}" >/dev/tty
        ((i++))
    done
    echo "" >/dev/tty

    local choice
    read -rp "  Pick a number (q to quit): " choice </dev/tty
    [[ "$choice" == "q" || "$choice" == "Q" ]] && exit 0

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#pkgs[@]} )); then
        err "Invalid choice." >/dev/tty
        exit 1
    fi

    echo "${pkgs[$((choice - 1))]}"
}

pick_from_list() {
    local -a items=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && items+=("$line")
    done

    if [[ ${#items[@]} -eq 0 ]]; then
        err "No results." >/dev/tty
        exit 1
    fi

    echo "" >/dev/tty
    echo -e "${BOLD}Results:${RESET}" >/dev/tty
    local i=1
    for item in "${items[@]}"; do
        printf "  ${YELLOW}[%d]${RESET} %s\n" "$i" "$item" >/dev/tty
        ((i++))
    done
    echo "" >/dev/tty

    local choice
    read -rp "  Pick a number (q to quit): " choice </dev/tty
    [[ "$choice" == "q" || "$choice" == "Q" ]] && exit 0

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#items[@]} )); then
        err "Invalid choice." >/dev/tty
        exit 1
    fi

    echo "${items[$((choice - 1))]}"
}

# ── Installation Engine ───────────────────────────────────────────────────────

install_local_file() {
    local target="$1"
    local filename="$(basename "$target")"

    if [[ "$target" == *.apk ]]; then
        info "Installing ${filename}..."
        if adb install -r "$target"; then
            success "${filename} installed successfully!"
        else
            err "Installation failed."
            exit 1
        fi
    elif [[ "$target" == *.xapk || "$target" == *.apkm ]]; then
        info "Archive detected (${filename##*.}), extracting split APKs..."
        local extract_dir="${APK_DIR}/.tmp_extract_$$"
        rm -rf "$extract_dir"
        mkdir -p "$extract_dir"

        if ! command -v unzip &>/dev/null; then
            err "unzip not found: sudo pacman -S unzip"
            exit 1
        fi

        unzip -q "$target" -d "$extract_dir"

        local -a split_apks=()
        while IFS= read -r f; do
            split_apks+=("$f")
        done < <(find "$extract_dir" -name "*.apk")

        if [[ ${#split_apks[@]} -eq 0 ]]; then
            err "No APKs found inside archive."
            rm -rf "$extract_dir"
            exit 1
        fi

        info "Installing ${#split_apks[@]} split APK(s)..."
        if adb install-multiple -r "${split_apks[@]}"; then
            success "${filename} installed successfully!"
        else
            err "Split APK installation failed."
            rm -rf "$extract_dir"
            exit 1
        fi

        rm -rf "$extract_dir"
    else
        err "Unsupported file type: ${filename}"
        exit 1
    fi
}

# ── Module Engine ─────────────────────────────────────────────────────────────

flash_module() {
    local target="$1"
    local filename
    filename="$(basename "$target")"
    local remote_path="/sdcard/Download/${filename}"

    info "Pushing ${filename} to device..."
    if ! adb push "$target" "$remote_path"; then
        err "Push failed. Check that /sdcard/Download is accessible."
        exit 1
    fi
    success "Pushed to ${remote_path}"

    info "Flashing module via Magisk..."
    local output
    if output=$(adb shell "su -c 'magisk --install-module \"${remote_path}\"'" 2>&1); then
        echo "$output"
        success "${filename} flashed successfully!"
    else
        echo "$output"
        err "Module installation failed. Check Magisk logs on device."
        adb shell "su -c 'rm -f \"${remote_path}\"'" 2>/dev/null || true
        exit 1
    fi

    # Clean up the zip from /sdcard after install
    adb shell "su -c 'rm -f \"${remote_path}\"'" 2>/dev/null || true

    echo ""
    local reboot_confirm
    read -rp "  Reboot now to apply module? [y/N] " reboot_confirm </dev/tty
    if [[ "$reboot_confirm" == "y" || "$reboot_confirm" == "Y" ]]; then
        info "Rebooting device..."
        adb reboot
    else
        echo -e "  ${DIM}Reboot skipped. Module will apply on next boot.${RESET}"
    fi
}

cmd_modules() {
    local subcmd="${1:-flash}"

    case "$subcmd" in
        list)
            # List Magisk modules installed on the device
            check_deps "local"
            check_device
            check_root

            info "Fetching installed Magisk modules..."
            echo ""

            local mod_list
            mod_list=$(adb shell "su -c 'ls /data/adb/modules/'" 2>/dev/null | tr -d '\r' | sort || true)

            if [[ -z "$mod_list" ]]; then
                err "No modules found at /data/adb/modules/ — or Magisk isn't installed."
                exit 1
            fi

            bold "Installed Magisk modules:"
            while IFS= read -r mod; do
                # Try to read the module name from module.prop
                local mod_name
                mod_name=$(adb shell "su -c 'cat /data/adb/modules/${mod}/module.prop 2>/dev/null'" \
                    | tr -d '\r' \
                    | grep -m1 "^name=" \
                    | sed 's/^name=//' || true)

                # Check for disable/remove flags
                local flags=""
                adb shell "su -c 'test -f /data/adb/modules/${mod}/disable'" &>/dev/null && flags="${flags} ${YELLOW}[disabled]${RESET}"
                adb shell "su -c 'test -f /data/adb/modules/${mod}/remove'" &>/dev/null  && flags="${flags} ${RED}[pending remove]${RESET}"

                if [[ -n "$mod_name" ]]; then
                    echo -e "  ${DIM}•${RESET} ${mod_name} ${DIM}(${mod})${RESET}${flags}"
                else
                    echo -e "  ${DIM}•${RESET} ${mod}${flags}"
                fi
            done <<< "$mod_list"

            echo ""
            echo -e "  ${DIM}Total: $(echo "$mod_list" | wc -l)${RESET}"
            ;;

        remove)
            # Mark a module for removal (takes effect after reboot)
            check_deps "local"
            check_device
            check_root

            info "Fetching installed Magisk modules..."

            local mod_list
            mod_list=$(adb shell "su -c 'ls /data/adb/modules/'" 2>/dev/null | tr -d '\r' | sort || true)

            if [[ -z "$mod_list" ]]; then
                err "No modules found on device."
                exit 1
            fi

            # Build display list with friendly names
            local -a display_items=()
            local -a mod_ids=()
            while IFS= read -r mod; do
                local mod_name
                mod_name=$(adb shell "su -c 'cat /data/adb/modules/${mod}/module.prop 2>/dev/null'" \
                    | tr -d '\r' \
                    | grep -m1 "^name=" \
                    | sed 's/^name=//' || true)
                if [[ -n "$mod_name" ]]; then
                    display_items+=("${mod_name} (${mod})")
                else
                    display_items+=("${mod}")
                fi
                mod_ids+=("$mod")
            done <<< "$mod_list"

            echo "" >/dev/tty
            bold "Installed Magisk modules:" >/dev/tty
            local i=1
            for item in "${display_items[@]}"; do
                printf "  ${YELLOW}[%d]${RESET} %s\n" "$i" "$item" >/dev/tty
                ((i++))
            done
            echo "" >/dev/tty

            local choice
            read -rp "  Pick a number (q to quit): " choice </dev/tty
            [[ "$choice" == "q" || "$choice" == "Q" ]] && exit 0

            if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#mod_ids[@]} )); then
                err "Invalid choice."
                exit 1
            fi

            local selected_mod="${mod_ids[$((choice - 1))]}"
            local selected_display="${display_items[$((choice - 1))]}"

            echo ""
            local confirm
            read -rp "  Mark ${BOLD}${selected_display}${RESET} for removal? [y/N] " confirm </dev/tty
            [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "  Cancelled."; exit 0; }

            adb shell "su -c 'touch /data/adb/modules/${selected_mod}/remove'" && \
                success "${selected_display} marked for removal. It will be uninstalled on next reboot." || \
                err "Failed to mark module for removal."

            echo ""
            local reboot_confirm
            read -rp "  Reboot now? [y/N] " reboot_confirm </dev/tty
            if [[ "$reboot_confirm" == "y" || "$reboot_confirm" == "Y" ]]; then
                adb reboot
            else
                echo -e "  ${DIM}Reboot when ready to apply.${RESET}"
            fi
            ;;

        flash|*)
            # Flash a module zip from the local modules directory
            check_deps "local"
            check_device
            check_root

            info "Scanning ${MODULES_DIR} for module zips..."
            local -a files=()
            mapfile -t files < <(find "$MODULES_DIR" -maxdepth 1 -type f -name "*.zip" | sort)

            if [[ ${#files[@]} -eq 0 ]]; then
                err "No .zip files found in ${MODULES_DIR}"
                echo "  Drop your Magisk module zips there and try again."
                exit 1
            fi

            echo "" >/dev/tty
            bold "Local Modules:" >/dev/tty
            local i=1
            for f in "${files[@]}"; do
                printf "  ${YELLOW}[%d]${RESET} %s\n" "$i" "$(basename "$f")" >/dev/tty
                ((i++))
            done
            echo "" >/dev/tty

            local choice
            read -rp "  Pick a number (q to quit): " choice </dev/tty
            [[ "$choice" == "q" || "$choice" == "Q" ]] && exit 0

            if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#files[@]} )); then
                err "Invalid choice."
                exit 1
            fi

            flash_module "${files[$((choice - 1))]}"
            ;;
    esac
}

# ── Commands ──────────────────────────────────────────────────────────────────

cmd_local() {
    check_deps "local"
    check_device

    info "Scanning ${APK_DIR} for packages..."
    local -a files=()
    mapfile -t files < <(find "$APK_DIR" -maxdepth 1 -type f \( -name "*.apk" -o -name "*.xapk" -o -name "*.apkm" \) | sort)

    if [[ ${#files[@]} -eq 0 ]]; then
        err "No packages found in ${APK_DIR}"
        exit 1
    fi

    echo "" >/dev/tty
    echo -e "${BOLD}Local Packages:${RESET}" >/dev/tty
    local i=1
    for f in "${files[@]}"; do
        printf "  ${YELLOW}[%d]${RESET} %s\n" "$i" "$(basename "$f")" >/dev/tty
        ((i++))
    done
    echo "" >/dev/tty

    local choice
    read -rp "  Pick a number (q to quit): " choice </dev/tty
    [[ "$choice" == "q" || "$choice" == "Q" ]] && exit 0

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#files[@]} )); then
        err "Invalid choice." >/dev/tty
        exit 1
    fi

    install_local_file "${files[$((choice - 1))]}"
}

cmd_install() {
    local query="$*"
    # If no argument is passed to install, drop into the local picker mode
    if [[ -z "$query" ]]; then
        cmd_local
        return
    fi

    check_deps "all"
    check_device

    local results
    results=$(search_packages "$query") || true

    if [[ -z "$results" ]]; then
        err "No apps found for '${query}'. Try a shorter search term."
        exit 1
    fi

    local selected
    selected=$(echo "$results" | pick_app)
    echo ""

    info "Downloading ${BOLD}${selected}${RESET}..."

    if ! apkeep -a "$selected" -d apk-pure "$APK_DIR" 2>&1; then
        err "Download failed. The app may not be on APKPure."
        exit 1
    fi

    # Find the downloaded file
    local dl_file
    dl_file=$(find "$APK_DIR" -maxdepth 1 \( -name "${selected}*.apk" -o -name "${selected}*.xapk" -o -name "${selected}*.apkm" \) 2>/dev/null | sort | tail -1)

    if [[ -z "$dl_file" ]]; then
        dl_file=$(find "$APK_DIR" -maxdepth 1 \( -name "*.apk" -o -name "*.xapk" -o -name "*.apkm" \) -newer "$APK_DIR" 2>/dev/null | head -1)
    fi

    if [[ -z "$dl_file" ]]; then
        err "Could not find downloaded file in ${APK_DIR}"
        exit 1
    fi

    install_local_file "$dl_file"
}

cmd_uninstall() {
    local query="$*"
    [[ -z "$query" ]] && { usage; exit 1; }

    check_deps "local"
    check_device

    info "Searching installed packages for '${query}'..."

    local matches
    matches=$(adb shell pm list packages 2>/dev/null \
        | sed 's/package://' \
        | tr -d '\r' \
        | grep -i "$query" \
        | sort || true)

    if [[ -z "$matches" ]]; then
        err "No installed packages match '${query}'"
        echo "  Tip: use 'apkget list' to browse all packages."
        exit 1
    fi

    local selected
    selected=$(echo "$matches" | pick_from_list)
    echo ""

    local confirm
    read -rp "  Uninstall ${BOLD}${selected}${RESET}?[y/N] " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && { echo "  Cancelled."; exit 0; }

    info "Uninstalling ${selected}..."
    if adb shell pm uninstall "$selected" 2>&1 | grep -q "Success"; then
        success "${selected} uninstalled."
    else
        info "Retrying with --user 0 (system app)..."
        adb shell pm uninstall --user 0 "$selected" && \
            success "${selected} uninstalled for current user." || \
            err "Could not uninstall. It may be a protected system app."
    fi
}

cmd_list() {
    local filter="${1:-}"
    check_deps "local"
    check_device

    info "Fetching package list..."
    echo ""

    local list
    list=$(adb shell pm list packages 2>/dev/null | sed 's/package://' | tr -d '\r' | sort)

    if [[ -n "$filter" ]]; then
        list=$(echo "$list" | grep -i "$filter" || true)
        bold "Packages matching '${filter}':"
    else
        bold "All installed packages:"
    fi

    if [[ -z "$list" ]]; then
        err "No packages found."
        exit 1
    fi

    echo "$list" | while IFS= read -r pkg; do
        echo -e "  ${DIM}•${RESET} $pkg"
    done

    local count
    count=$(echo "$list" | wc -l)
    echo ""
    echo -e "  ${DIM}Total: ${count}${RESET}"
}

# ── Entry point ───────────────────────────────────────────────────────────────
case "${1:-}" in
    install|ins) shift; cmd_install "$@" ;;
    local)       shift; cmd_local "$@"   ;;
    uninstall)   shift; cmd_uninstall "$@" ;;
    list)        shift; cmd_list "$@"    ;;
    modules|mod) shift; cmd_modules "$@" ;;
    -h|--help)   usage ;;
    *)           usage; exit 1 ;;
esac
