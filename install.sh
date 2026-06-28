#!/usr/bin/env bash
set -euo pipefail

APPID="${APPID:-216150}"
STEAM_ROOT="${STEAM_ROOT:-}"
PREFIX_DIR="${PREFIX_DIR:-}"
COMMON_DIR="${COMMON_DIR:-}"
PROTON="${PROTON:-}"
DESKTOP_SIZE="${VIRTUAL_DESKTOP_SIZE:-1920x1080}"
USE_VIRTUAL_DESKTOP="${USE_VIRTUAL_DESKTOP:-0}"
PAYLOAD_ZIP="${PAYLOAD_ZIP:-${PATCH_ZIP:-}}"
PAYLOAD_DIR="${PAYLOAD_DIR:-${PATCH_FILES_DIR:-}}"
APPLY_RUNTIME=1
APPLY_ALT_TAB=1
APPLY_FKEYS=1
PERSIST_FKEYS=1
KILL_RUNNING=0
DRY_RUN=0

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PATCH_DIR="$SCRIPT_DIR/patches"
PAYLOAD_DIR="${PAYLOAD_DIR:-$SCRIPT_DIR/files}"
FILES_DIR="$PAYLOAD_DIR"
PAYLOAD_CACHE_DIR="$SCRIPT_DIR/.payload"
PAYLOAD_URLS=(
  "https://files.catbox.moe/qaxsw6.zip"
  "https://x0.at/96Ia.zip"
  "https://l.station307.com/23wXxZg1fohbhAkbHN8wMj/files.zip"
  "https://limewire.com/d/lzRB1#nDRoOiUHPA"
  "https://drive.google.com/file/d/1ybJcwEGPQF3heLJnafpPX7H7kezwcvqF/view?usp=sharing"
)

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Applies the Linux MapleStory Proton patch bundle to the local Steam prefix.
Steam must already have MapleStory installed and launched once so compatdata/216150/pfx exists.

Options:
  --steam-root PATH              Steam root (default: auto-detect ~/.local/share/Steam or ~/.steam/steam)
  --appid ID                     Steam app id (default: 216150)
  --prefix-dir PATH              compatdata app directory (default: $STEAM_ROOT/steamapps/compatdata/$APPID)
  --proton PATH                  Proton executable to use for regedit imports
  --virtual-desktop              Enable the Wine virtual desktop (OFF by default). Needed only if you hit the
                                 BadWindow/X_CreateWindow launch crash or lose input after alt-tab (common under XWayland: Hyprland/Mint).
  --desktop-size WIDTHxHEIGHT    Set the virtual desktop size for --virtual-desktop (default: 1920x1080);
                                 does NOT enable the virtual desktop on its own.
  --resolution WIDTHxHEIGHT      Alias for --desktop-size
  --patch-zip PATH               Use a local patch zip instead of downloading one
  --patch-dir PATH               Use an already-extracted patch directory containing drive_c/ and vc_runtime/
  --fix-fkeys                   Set hid_apple fnmode=2 for this boot so Apple-compatible keyboards send F1-F12
  --persist-fkeys               Also persist hid_apple fnmode=2 across reboots; implies --fix-fkeys
  --skip-runtime                 Skip runtime/DLL file patches and runtime registry imports
  --skip-alt-tab                 Skip UseTakeFocus/virtual-desktop registry patches
  --kill                         Terminate running MapleStory/Nexon helper processes before patching
  --dry-run                      Print actions without modifying files or registry
  -h, --help                     Show this help
  --payload-zip PATH             Backward-compatible alias for --patch-zip
  --payload-dir PATH             Backward-compatible alias for --patch-dir

Environment overrides: APPID, STEAM_ROOT, PREFIX_DIR, PROTON,
VIRTUAL_DESKTOP_SIZE, PATCH_ZIP, PATCH_FILES_DIR.
EOF
}

log() { printf '==> %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --steam-root) STEAM_ROOT="${2:?missing value for --steam-root}"; shift 2 ;;
    --appid) APPID="${2:?missing value for --appid}"; shift 2 ;;
    --prefix-dir) PREFIX_DIR="${2:?missing value for --prefix-dir}"; shift 2 ;;
    --proton) PROTON="${2:?missing value for --proton}"; shift 2 ;;
    --virtual-desktop) USE_VIRTUAL_DESKTOP=1; shift ;;
    --desktop-size|--resolution) DESKTOP_SIZE="${2:?missing value for $1}"; shift 2 ;;
    --patch-zip|--payload-zip) PAYLOAD_ZIP="${2:?missing value for $1}"; shift 2 ;;
    --patch-dir|--payload-dir) PAYLOAD_DIR="${2:?missing value for $1}"; shift 2 ;;
    --fix-fkeys) APPLY_FKEYS=1; shift ;;
    --persist-fkeys) APPLY_FKEYS=1; PERSIST_FKEYS=1; shift ;;
    --skip-runtime) APPLY_RUNTIME=0; shift ;;
    --skip-alt-tab) APPLY_ALT_TAB=0; shift ;;
    --kill) KILL_RUNNING=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

if ! [[ "$DESKTOP_SIZE" =~ ^[0-9]+x[0-9]+$ ]]; then
  die "desktop size must be WIDTHxHEIGHT, got: $DESKTOP_SIZE"
fi

if [ -z "$STEAM_ROOT" ]; then
  if [ -d "$HOME/.local/share/Steam" ]; then
    STEAM_ROOT="$HOME/.local/share/Steam"
  elif [ -d "$HOME/.steam/steam" ]; then
    STEAM_ROOT="$HOME/.steam/steam"
  elif [ -d "$HOME/.steam/debian-installation" ]; then
    STEAM_ROOT="$HOME/.steam/debian-installation"
  else
    die "could not auto-detect Steam root; pass --steam-root PATH"
  fi
fi

COMMON_DIR="${COMMON_DIR:-$STEAM_ROOT/steamapps/common}"
PREFIX_DIR="${PREFIX_DIR:-$STEAM_ROOT/steamapps/compatdata/$APPID}"
PFX="$PREFIX_DIR/pfx"
BACKUP_DIR="$PREFIX_DIR/linux_maplestory-backups/$(date +%Y%m%d-%H%M%S)"

require_file() { [ -f "$1" ] || die "missing required file: $1"; }
require_dir() { [ -d "$1" ] || die "missing required directory: $1"; }

resolve_proton() {
  if [ -n "$PROTON" ]; then
    [ -x "$PROTON" ] || die "PROTON is not executable: $PROTON"
    return
  fi

  local proton_name=""
  if [ -f "$PREFIX_DIR/version" ]; then
    proton_name="$(tr -d '\r\n' < "$PREFIX_DIR/version")"
  fi

  if [ -n "$proton_name" ]; then
    local custom="$STEAM_ROOT/compatibilitytools.d/$proton_name/proton"
    local common="$COMMON_DIR/$proton_name/proton"
    if [ -x "$custom" ]; then
      PROTON="$custom"
      return
    fi
    if [ -x "$common" ]; then
      PROTON="$common"
      return
    fi
  fi

  die "could not find Proton executable. Pass --proton PATH or set compatibility in Steam and launch once."
}

resolve_wine() {
  # Resolve the Wine binary shipped with the selected Proton tool. Used as a
  # ProtonFixes-bypassing fallback for regedit (this is effectively what
  # Protontricks does). GE-Proton ships a unified 'wine'; 'wine64' is a fallback.
  local proton_dir c
  proton_dir="$(dirname -- "$PROTON")"
  for c in \
    "$proton_dir/files/bin/wine" \
    "$proton_dir/files/bin/wine64" \
    "$proton_dir/dist/bin/wine" \
    "$proton_dir/dist/bin/wine64"
  do
    [ -x "$c" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

reg_value_present() {
  # $1 = a distinctive literal the patch writes into user.reg or system.reg.
  local marker="$1"
  [ -n "$marker" ] || return 0
  grep -F -q -- "$marker" "$PFX/user.reg" 2>/dev/null && return 0
  grep -F -q -- "$marker" "$PFX/system.reg" 2>/dev/null && return 0
  return 1
}

reg_import() {
  local patch="$1"
  local marker="${2:-}"
  require_file "$patch"
  log "Importing registry patch: ${patch#$SCRIPT_DIR/}"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] STEAM_COMPAT_DATA_PATH=%q STEAM_COMPAT_CLIENT_INSTALL_PATH=%q SteamAppId=%q SteamGameId=%q %q run regedit /S %q\n' \
      "$PREFIX_DIR" "$STEAM_ROOT" "$APPID" "$APPID" "$PROTON" "$patch"
    return
  fi

  local err_tmp rc
  rc=0
  err_tmp="$(mktemp)"
  # `proton run regedit` is not a game launch, so GE-Proton's protonfixes logs
  # "Skipping fix execution. We are probably running a unit test." That line is
  # harmless (regedit still runs), but it reads like a failure. Capture stderr,
  # drop only that one line, and pass everything else through.
  STEAM_COMPAT_DATA_PATH="$PREFIX_DIR" \
  STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
  SteamAppId="$APPID" SteamGameId="$APPID" \
  "$PROTON" run regedit /S "$patch" 2>"$err_tmp" || rc=$?
  grep -F -v 'Skipping fix execution. We are probably running a unit test.' "$err_tmp" >&2 || true
  rm -f "$err_tmp"
  # `proton run` returns as soon as the regedit process exits, but the prefix's
  # wineserver may not have flushed the registry to user.reg/system.reg yet.
  # Wait for it to go idle so the verify step below actually sees the keys.
  local _pdir _ws
  _pdir="$(dirname -- "$PROTON")"
  for _ws in "$_pdir/files/bin/wineserver" "$_pdir/dist/bin/wineserver"; do
    [ -x "$_ws" ] && { WINEPREFIX="$PFX" "$_ws" -w 2>/dev/null || true; break; }
  done

  # When a verify marker is provided, success is defined by the key actually
  # landing in the prefix registry -- not regedit's exit status alone. If
  # `proton run` did not write it, retry with the bundled Wine binary directly
  # (the ProtonFixes-free path Protontricks uses) and fail loudly if the key is
  # still missing, instead of printing a false "Install complete".
  if [ -n "$marker" ]; then
    if ! reg_value_present "$marker"; then
      local wine_bin
      if wine_bin="$(resolve_wine 2>/dev/null)"; then
        log "Key not found after 'proton run'; retrying with bundled Wine binary: $wine_bin"
        WINEPREFIX="$PFX" "$wine_bin" regedit /S "$patch" 2>/dev/null || rc=$?
      else
        rc=1
      fi
    fi
    reg_value_present "$marker" \
      || die "registry patch did not apply: ${patch#$SCRIPT_DIR/} (expected '$marker' in $PFX/user.reg or $PFX/system.reg). If this keeps failing, import the .reg via Protontricks for Steam app $APPID."
    return 0
  fi

  return "$rc"
}

backup_path() {
  local path="$1"
  [ -e "$path" ] || return 0
  local rel="${path#/}"
  run mkdir -p "$BACKUP_DIR/$(dirname -- "$rel")"
  run cp -a -- "$path" "$BACKUP_DIR/$rel"
}

payload_ready() {
  [ -f "$FILES_DIR/drive_c/.mappings.ini" ] || return 1
  [ -f "$FILES_DIR/drive_c/users/steamuser/AppData/Roaming/NexonLauncher/apps-settings.db" ] || return 1
  [ -f "$FILES_DIR/vc_runtime/system32/vcruntime140_threads.dll" ] || return 1
  [ -f "$FILES_DIR/vc_runtime/syswow64/vcruntime140_threads.dll" ] || return 1
  return 0
}

extract_payload_zip_file() {
  local zip_path="$1"
  log "Extracting payload zip: $zip_path"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] extract %q into %q\n' "$zip_path" "$SCRIPT_DIR"
    return 0
  fi
  require_file "$zip_path"
  python3 - "$zip_path" "$SCRIPT_DIR" <<'PY'
import pathlib, shutil, sys, tempfile, zipfile
zip_path = pathlib.Path(sys.argv[1])
bundle = pathlib.Path(sys.argv[2])
tmp = pathlib.Path(tempfile.mkdtemp(prefix="linux-maplestory-payload-"))
try:
    with zipfile.ZipFile(zip_path) as z:
        z.extractall(tmp)
    src = tmp / "files"
    if not src.exists():
        src = tmp
    dest = bundle / "files"
    if dest.exists():
        shutil.rmtree(dest)
    shutil.copytree(src, dest)
finally:
    shutil.rmtree(tmp, ignore_errors=True)
PY
}

download_payload_zip() {
  local dest="$PAYLOAD_CACHE_DIR/files.zip"
  PAYLOAD_ZIP="$dest"
  log "Downloading payload archive"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] download payload from mirrors into %q\n' "$dest"
    return 0
  fi
  mkdir -p -- "$PAYLOAD_CACHE_DIR"
  python3 - "$dest" "${PAYLOAD_URLS[@]}" <<'PY'
import sys, urllib.request
from pathlib import Path
out = Path(sys.argv[1])
urls = sys.argv[2:]
errors = []
for url in urls:
    try:
        print(f"trying {url}")
        req = urllib.request.Request(url, headers={"User-Agent": "linux-maplestory-installer"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        if len(data) < 1024:
            raise RuntimeError(f"download too small: {len(data)} bytes")
        out.write_bytes(data)
        print(f"downloaded {out} ({len(data)} bytes)")
        raise SystemExit(0)
    except SystemExit:
        raise
    except Exception as exc:
        errors.append(f"{url}: {exc}")
print("failed to download payload from all mirrors", file=sys.stderr)
for err in errors:
    print(err, file=sys.stderr)
raise SystemExit(1)
PY
  PAYLOAD_ZIP="$dest"
}

ensure_payload() {
  [ "$APPLY_RUNTIME" -eq 1 ] || return 0
  if payload_ready; then
    return 0
  fi
  if [ -n "$PAYLOAD_ZIP" ]; then
    extract_payload_zip_file "$PAYLOAD_ZIP"
  else
    download_payload_zip
    extract_payload_zip_file "$PAYLOAD_ZIP"
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    return 0
  fi
  payload_ready || die "payload files are still missing after extraction"
}

preflight_bundle() {
  require_file "$PATCH_DIR/01-usetakefocus.reg"
  require_file "$PATCH_DIR/90-disable-virtual-desktop.reg"
  require_file "$PATCH_DIR/10-nexon-launcher-protocol.reg"
  require_file "$PATCH_DIR/11-wine-direct3d-dll-overrides.reg"
  require_file "$PATCH_DIR/04-input-fixes.reg"
  require_file "$PATCH_DIR/05-appdefaults-winver.reg"
  require_file "$PATCH_DIR/13-apply-runtime-file-patches.sh"
  require_file "$PATCH_DIR/make-virtual-desktop-patch.sh"
  if [ "$APPLY_FKEYS" -eq 1 ]; then
    require_file "$PATCH_DIR/20-hid-apple-fkeysfirst.sh"
  fi
  if [ "$APPLY_RUNTIME" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    require_file "$PATCH_DIR/patch-wine-binaries.sh"
    payload_ready || die "payload files are missing; rerun with network access or --payload-zip /path/to/files.zip"
  fi
}

check_processes() {
  command -v pgrep >/dev/null 2>&1 || return 0
  local matches
  matches="$(pgrep -af -i "SteamLaunch AppId=$APPID|MapleStory.exe|nxsteam|BlackCipher|DwarfAxe" | grep -vE "^($$|$PPID) " || true)"
  [ -n "$matches" ] || return 0

  if [ "$KILL_RUNNING" -eq 1 ]; then
    log "Terminating running MapleStory/Nexon helper processes"
    printf '%s\n' "$matches"
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '[dry-run] pkill -TERM matching MapleStory/Nexon helper processes\n'
    else
      pkill -TERM -f "MapleStory.exe|nxsteam|BlackCipher|DwarfAxe|SteamLaunch AppId=$APPID" || true
      sleep 2
    fi
  else
    printf '%s\n' "$matches" >&2
    die "MapleStory or its helpers (BlackCipher/DwarfAxe) appear to be running -- these often linger after a crash. Fully close the game, or rerun with --kill to terminate them before patching."
  fi
}

check_dependencies() {
  # python3 is needed to download or extract the payload zip. It is NOT needed
  # when the payload is already laid out (files/ present) and no zip is given.
  local need_python=0
  if [ "$APPLY_RUNTIME" -eq 1 ]; then
    [ -n "$PAYLOAD_ZIP" ] && need_python=1
    payload_ready || need_python=1
  fi
  if [ "$need_python" -eq 1 ]; then
    command -v python3 >/dev/null 2>&1 \
      || die "python3 is required to obtain the patch payload. Install it and retry:
  Debian/Ubuntu/Mint:  sudo apt install python3
  Fedora:             sudo dnf install python3
  Arch/CachyOS:       sudo pacman -S python"
  fi
}

backup_targets() {
  log "Backing up touched prefix files to $BACKUP_DIR"
  backup_path "$PFX/user.reg"
  backup_path "$PFX/system.reg"
  backup_path "$PFX/userdef.reg"
  backup_path "$PFX/drive_c/.mappings.ini"
  backup_path "$PFX/drive_c/users/steamuser/AppData/Roaming/NexonLauncher/apps-settings.db"

  local dll
  for dll in \
    concrt140.dll msvcp140.dll msvcp140_1.dll msvcp140_2.dll \
    msvcp140_atomic_wait.dll msvcp140_codecvt_ids.dll ucrtbase.dll \
    vccorlib140.dll vcomp140.dll vcruntime140.dll vcruntime140_1.dll \
    vcruntime140_threads.dll
  do
    backup_path "$PFX/drive_c/windows/system32/$dll"
  done

  for dll in \
    concrt140.dll msvcp140.dll msvcp140_1.dll msvcp140_2.dll \
    msvcp140_atomic_wait.dll msvcp140_codecvt_ids.dll ucrtbase.dll \
    vccorlib140.dll vcomp140.dll vcruntime140.dll vcruntime140_threads.dll
  do
    backup_path "$PFX/drive_c/windows/syswow64/$dll"
  done
}

apply_runtime_files() {
  [ "$APPLY_RUNTIME" -eq 1 ] || return 0
  log "Applying required runtime/DLL file payloads"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] APPID=%q STEAM_ROOT=%q PFX=%q COMMON_DIR=%q PAYLOAD_DIR=%q %q\n' \
      "$APPID" "$STEAM_ROOT" "$PFX" "$COMMON_DIR" "$FILES_DIR" "$PATCH_DIR/13-apply-runtime-file-patches.sh"
  else
    APPID="$APPID" STEAM_ROOT="$STEAM_ROOT" PFX="$PFX" COMMON_DIR="$COMMON_DIR" \
    PAYLOAD_DIR="$FILES_DIR" \
    "$PATCH_DIR/13-apply-runtime-file-patches.sh"
  fi
}

apply_alt_tab_patches() {
  [ "$APPLY_ALT_TAB" -eq 1 ] || return 0

  reg_import "$PATCH_DIR/01-usetakefocus.reg" '"UseTakeFocus"'

  if [ "$USE_VIRTUAL_DESKTOP" -eq 1 ]; then
    local desktop_patch="$PATCH_DIR/02-virtual-desktop-$DESKTOP_SIZE.reg"
    log "Generating virtual desktop patch for $DESKTOP_SIZE"
    if [ "$DRY_RUN" -eq 1 ]; then
      printf '[dry-run] %q %q\n' "$PATCH_DIR/make-virtual-desktop-patch.sh" "$DESKTOP_SIZE"
    else
      "$PATCH_DIR/make-virtual-desktop-patch.sh" "$DESKTOP_SIZE" >/dev/null
    fi
    if [ "$DRY_RUN" -eq 1 ] && [ ! -f "$desktop_patch" ]; then
      printf '[dry-run] would import generated patch: %s\n' "$desktop_patch"
    else
      reg_import "$desktop_patch" "\"Default\"=\"$DESKTOP_SIZE\""
    fi
  else
    log "Wine virtual desktop disabled (default); removing any prior virtual-desktop keys"
    reg_import "$PATCH_DIR/90-disable-virtual-desktop.reg"
    log "Pass --virtual-desktop to enable it (optionally with --desktop-size WxH for a custom size); needed for the BadWindow/X_CreateWindow launch crash and alt-tab input loss under XWayland."
  fi
}

apply_runtime_registry() {
  [ "$APPLY_RUNTIME" -eq 1 ] || return 0
  reg_import "$PATCH_DIR/10-nexon-launcher-protocol.reg" 'URL:nxl protocol'
  reg_import "$PATCH_DIR/11-wine-direct3d-dll-overrides.reg" 'cb_access_map_w'
  reg_import "$PATCH_DIR/04-input-fixes.reg" '"UseLinuxInputEvents"'
  reg_import "$PATCH_DIR/05-appdefaults-winver.reg" '"Version"="win10"'
}

apply_wine_patches() {
  [ "$APPLY_RUNTIME" -eq 1 ] || return 0
  local proton_dir ver
  proton_dir="$(CDPATH= cd -- "$(dirname -- "$PROTON")" && pwd)"
  ver="$(tr -d '\r\n' < "$proton_dir/version" 2>/dev/null || true)"
  case "$ver" in
    *GE-Proton11-1*) ;;
    *) log "Skipping Wine binary patches: Proton tool ($ver) is not GE-Proton11-1; these patches are build-specific."; return 0 ;;
  esac
  log "Applying Wine binary patches to $proton_dir (offset-based; targets backed up to $BACKUP_DIR)"
  [ "$DRY_RUN" -eq 0 ] && backup_path "$proton_dir/files/lib/wine/x86_64-windows/kernelbase.dll"
  [ "$DRY_RUN" -eq 0 ] && backup_path "$proton_dir/files/lib/wine/x86_64-unix/win32u.so"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %q %q\n' "$PATCH_DIR/patch-wine-binaries.sh" "$proton_dir"
  else
    "$PATCH_DIR/patch-wine-binaries.sh" "$proton_dir" \
      || log "WARNING: a Wine binary patch did not apply (see lines above); if the kernelbase CharPrevExA patch failed, the 0xc0000005 launch crash may recur."
  fi
}


apply_fkey_patch() {
  [ "$APPLY_FKEYS" -eq 1 ] || return 0
  local script="$PATCH_DIR/20-hid-apple-fkeysfirst.sh"
  local mode_message="for this boot"
  local args=()
  if [ "$PERSIST_FKEYS" -eq 1 ]; then
    mode_message="with reboot persistence"
    args=(--persist)
  fi

  log "Applying F1-F12 hardware-mode patch $mode_message"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] bash %q' "$script"
    if [ "${#args[@]}" -gt 0 ]; then
      printf ' %q' "${args[@]}"
    fi
    printf '\n'
    return 0
  fi

  if bash "$script" "${args[@]}"; then
    return 0
  fi

  if [ "$APPLY_RUNTIME" -eq 0 ] && [ "$APPLY_ALT_TAB" -eq 0 ]; then
    die "F1-F12 hardware-mode patch failed or was cancelled"
  fi

  log "F1-F12 hardware-mode patch failed or was cancelled; the prefix install remains applied."
  log "Run patches/20-hid-apple-fkeysfirst.sh manually from a terminal if F1-F12 still fail."
}

warn_hid_apple_fnmode() {
  local param="/sys/module/hid_apple/parameters/fnmode"
  [ -r "$param" ] || return 0
  local mode
  mode="$(cat "$param" 2>/dev/null || true)"
  [ "$mode" = "2" ] && return 0
  log "Notice: hid_apple fnmode is $mode, not 2. Some Apple-compatible keyboards send media keys instead of F1-F12 in this mode."
  log "If F1-F12 do not reach MapleStory, run: ./install.sh --skip-runtime --skip-alt-tab --fix-fkeys"
  log "For reboot persistence after testing, run: ./install.sh --skip-runtime --skip-alt-tab --persist-fkeys"
}

ensure_sudo() {
  sudo -n true 2>/dev/null && return 0
  log "Some steps need sudo (input group, hid_apple F-key mode). Enter your password when prompted."
  sudo -v || die "sudo authentication is required but failed."
}

ensure_input_group() {
  # Wine DirectInput (UseLinuxInputEvents) must read /dev/input/event* to deliver
  # raw scancodes for in-game skill keys (Q/W/E/R, 1-0, Enter). That needs
  # membership in the 'input' group; without it those keys silently don't register.
  id -nG 2>/dev/null | grep -qw input && return 0
  if getent group input 2>/dev/null | grep -qw "$USER"; then
    log "Note: you are in the 'input' group but must log out and back in for it to take effect (needed for in-game skill keys)."
    return 0
  fi
  [ "$DRY_RUN" -eq 1 ] && { log "[dry-run] would: sudo usermod -aG input $USER"; return 0; }
  ensure_sudo
  log "Adding $USER to the 'input' group (needed for in-game skill keys)."
  if sudo usermod -aG input "$USER"; then
    log "Added to 'input'. IMPORTANT: log out and back in (or reboot) for in-game skill keys to work."
  else
    log "WARNING: could not add to 'input' group. Run 'sudo usermod -aG input $USER', then re-login."
  fi
}

prompt_virtual_desktop() {
  # Ask which virtual-desktop size to use instead of assuming a hardcoded default.
  # Skipped (VD stays off) when: already opted in via --virtual-desktop, alt-tab
  # patches skipped, dry-run, or non-interactive stdin.
  [ "$USE_VIRTUAL_DESKTOP" -eq 1 ] && return 0
  [ "$APPLY_ALT_TAB" -eq 0 ] && return 0
  [ "$DRY_RUN" -eq 0 ] || return 0
  [ -t 0 ] || return 0
  cat <<'MSG'
Wine virtual desktop is optional (it helps with the BadWindow/X_CreateWindow
launch crash under some XWayland compositors). Pick a size to enable it, or
press Enter to leave it off.
  1) Off (default)
  2) 1920x1080
  3) 2560x1440
  4) 3840x2160
MSG
  printf "Choice [1-4 or WxH, default 1]: "
  local choice
  read -r choice || choice=""
  case "$choice" in
    1|"") ;;
    2) USE_VIRTUAL_DESKTOP=1; DESKTOP_SIZE=1920x1080 ;;
    3) USE_VIRTUAL_DESKTOP=1; DESKTOP_SIZE=2560x1440 ;;
    4) USE_VIRTUAL_DESKTOP=1; DESKTOP_SIZE=3840x2160 ;;
    *)
      if [[ "$choice" =~ ^[0-9]+x[0-9]+$ ]]; then
        USE_VIRTUAL_DESKTOP=1; DESKTOP_SIZE="$choice"
      else
        log "Invalid choice '$choice'; leaving the virtual desktop off."
      fi
      ;;
  esac
}

verify_install() {
  [ "$DRY_RUN" -eq 0 ] || return 0
  log "Verifying installed files"
  if [ "$APPLY_RUNTIME" -eq 1 ]; then
    require_file "$PFX/drive_c/windows/system32/vcruntime140_threads.dll"
    require_file "$PFX/drive_c/windows/syswow64/vcruntime140_threads.dll"
    require_file "$PFX/drive_c/.mappings.ini"
    require_file "$PFX/drive_c/users/steamuser/AppData/Roaming/NexonLauncher/apps-settings.db"
  fi
}

if [ "$APPLY_FKEYS" -eq 1 ] && [ "$APPLY_RUNTIME" -eq 0 ] && [ "$APPLY_ALT_TAB" -eq 0 ]; then
  require_file "$PATCH_DIR/20-hid-apple-fkeysfirst.sh"
  ensure_input_group
  apply_fkey_patch
  log "F1-F12 hardware-mode patch complete"
  exit 0
fi

check_dependencies
ensure_payload
preflight_bundle
require_dir "$STEAM_ROOT"
require_dir "$COMMON_DIR"
require_dir "$PFX/drive_c"
resolve_proton
check_processes
backup_targets
apply_runtime_files
prompt_virtual_desktop
apply_alt_tab_patches
apply_runtime_registry
apply_wine_patches
verify_install
ensure_input_group
apply_fkey_patch
warn_hid_apple_fnmode

log "Install complete"
log "Backups: $BACKUP_DIR"
log "Relaunch MapleStory through Steam and test input + alt-tab."
