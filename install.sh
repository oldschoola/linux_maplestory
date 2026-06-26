#!/usr/bin/env bash
set -euo pipefail

APPID="${APPID:-216150}"
STEAM_ROOT="${STEAM_ROOT:-}"
PREFIX_DIR="${PREFIX_DIR:-}"
COMMON_DIR="${COMMON_DIR:-}"
PROTON="${PROTON:-}"
MAC_BOTTLE="${MAC_BOTTLE:-}"
DESKTOP_SIZE="${VIRTUAL_DESKTOP_SIZE:-3840x2160}"
NEXON_LAUNCHER_SOURCE="${NEXON_LAUNCHER_SOURCE:-}"
PAYLOAD_ZIP="${PAYLOAD_ZIP:-${PATCH_ZIP:-}}"
PAYLOAD_DIR="${PAYLOAD_DIR:-${PATCH_FILES_DIR:-}}"
APPLY_RUNTIME=1
APPLY_ALT_TAB=1
INSTALL_PROTON_SETTINGS=0
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
  --desktop-size WIDTHxHEIGHT    Wine virtual desktop size (default: 3840x2160)
  --resolution WIDTHxHEIGHT      Alias for --desktop-size
  --patch-zip PATH               Use a local patch zip instead of downloading one
  --patch-dir PATH               Use an already-extracted patch directory containing drive_c/ and vc_runtime/
  --launcher-source PATH         Path to a Nexon Launcher directory containing nexon_launcher.exe
  --mac-bottle PATH              Mac bottle root containing drive_c/Nexon/Launcher
  --install-proton-settings      Add a marked linux_maplestory block to Proton's user_settings.py
  --skip-runtime                 Skip runtime/DLL/Nexon launcher file patches and runtime registry imports
  --skip-alt-tab                 Skip UseTakeFocus/virtual-desktop registry patches
  --kill                         Terminate running MapleStory/Nexon helper processes before patching
  --dry-run                      Print actions without modifying files or registry
  -h, --help                     Show this help
  --payload-zip PATH             Backward-compatible alias for --patch-zip
  --payload-dir PATH             Backward-compatible alias for --patch-dir

Environment overrides: APPID, STEAM_ROOT, PREFIX_DIR, PROTON, MAC_BOTTLE,
VIRTUAL_DESKTOP_SIZE, NEXON_LAUNCHER_SOURCE, PATCH_ZIP, PATCH_FILES_DIR.
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
    --desktop-size|--resolution) DESKTOP_SIZE="${2:?missing value for $1}"; shift 2 ;;
    --patch-zip|--payload-zip) PAYLOAD_ZIP="${2:?missing value for $1}"; shift 2 ;;
    --patch-dir|--payload-dir) PAYLOAD_DIR="${2:?missing value for $1}"; shift 2 ;;
    --launcher-source) NEXON_LAUNCHER_SOURCE="${2:?missing value for --launcher-source}"; shift 2 ;;
    --mac-bottle) MAC_BOTTLE="${2:?missing value for --mac-bottle}"; shift 2 ;;
    --install-proton-settings) INSTALL_PROTON_SETTINGS=1; shift ;;
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
  else
    die "could not auto-detect Steam root; pass --steam-root PATH"
  fi
fi

COMMON_DIR="${COMMON_DIR:-$STEAM_ROOT/steamapps/common}"
PREFIX_DIR="${PREFIX_DIR:-$STEAM_ROOT/steamapps/compatdata/$APPID}"
PFX="$PREFIX_DIR/pfx"
MAC_BOTTLE_DEFAULT="$COMMON_DIR/MapleStory Mac/MapleStory.app/Contents/SharedSupport/maplestoryna/support/maplestory"
MAC_BOTTLE="${MAC_BOTTLE:-$MAC_BOTTLE_DEFAULT}"
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

reg_import() {
  local patch="$1"
  require_file "$patch"
  log "Importing registry patch: ${patch#$SCRIPT_DIR/}"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] STEAM_COMPAT_DATA_PATH=%q STEAM_COMPAT_CLIENT_INSTALL_PATH=%q SteamAppId=%q SteamGameId=%q %q run regedit /S %q\n' \
      "$PREFIX_DIR" "$STEAM_ROOT" "$APPID" "$APPID" "$PROTON" "$patch"
  else
    STEAM_COMPAT_DATA_PATH="$PREFIX_DIR" \
    STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
    SteamAppId="$APPID" SteamGameId="$APPID" \
    "$PROTON" run regedit /S "$patch"
  fi
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
  [ -f "$FILES_DIR/drive_c/Nexon/Launcher/nexon_launcher.exe" ] || return 1
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
  require_file "$PATCH_DIR/10-nexon-launcher-protocol.reg"
  require_file "$PATCH_DIR/11-wine-direct3d-dll-overrides.reg"
  require_file "$PATCH_DIR/12-proton-user-settings.py"
  require_file "$PATCH_DIR/13-apply-runtime-file-patches.sh"
  require_file "$PATCH_DIR/make-virtual-desktop-patch.sh"
  if [ "$APPLY_RUNTIME" -eq 1 ] && [ "$DRY_RUN" -eq 0 ]; then
    payload_ready || die "payload files are missing; rerun with network access or --payload-zip /path/to/files.zip"
  fi
}

check_processes() {
  command -v pgrep >/dev/null 2>&1 || return 0
  local matches
  matches="$(pgrep -af -i "SteamLaunch AppId=$APPID|MapleStory.exe|nxsteam|BlackCipher|DwarfAxe" || true)"
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
    die "MapleStory appears to be running. Close it first or rerun with --kill."
  fi
}

preflight_runtime_sources() {
  [ "$APPLY_RUNTIME" -eq 1 ] || return 0

  if [ -x "$PFX/drive_c/Nexon/Launcher/nexon_launcher.exe" ]; then
    return 0
  fi
  if [ -n "$NEXON_LAUNCHER_SOURCE" ] && [ -x "$NEXON_LAUNCHER_SOURCE/nexon_launcher.exe" ]; then
    return 0
  fi
  if [ -x "$FILES_DIR/drive_c/Nexon/Launcher/nexon_launcher.exe" ]; then
    return 0
  fi
  if [ -x "$MAC_BOTTLE/drive_c/Nexon/Launcher/nexon_launcher.exe" ]; then
    return 0
  fi

  die "runtime patch set needs Nexon Launcher, but the packaged copy is missing. Restore files/drive_c/Nexon/Launcher or provide --launcher-source PATH / --mac-bottle PATH."
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
    printf '[dry-run] APPID=%q STEAM_ROOT=%q PFX=%q COMMON_DIR=%q MAC_BOTTLE=%q NEXON_LAUNCHER_SOURCE=%q PAYLOAD_DIR=%q %q\n' \
      "$APPID" "$STEAM_ROOT" "$PFX" "$COMMON_DIR" "$MAC_BOTTLE" "$NEXON_LAUNCHER_SOURCE" "$FILES_DIR" "$PATCH_DIR/13-apply-runtime-file-patches.sh"
  else
    APPID="$APPID" STEAM_ROOT="$STEAM_ROOT" PFX="$PFX" COMMON_DIR="$COMMON_DIR" \
    MAC_BOTTLE="$MAC_BOTTLE" NEXON_LAUNCHER_SOURCE="$NEXON_LAUNCHER_SOURCE" PAYLOAD_DIR="$FILES_DIR" \
    "$PATCH_DIR/13-apply-runtime-file-patches.sh"
  fi
}

apply_alt_tab_patches() {
  [ "$APPLY_ALT_TAB" -eq 1 ] || return 0
  local desktop_patch="$PATCH_DIR/02-virtual-desktop-$DESKTOP_SIZE.reg"

  log "Generating virtual desktop patch for $DESKTOP_SIZE"
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %q %q\n' "$PATCH_DIR/make-virtual-desktop-patch.sh" "$DESKTOP_SIZE"
  else
    "$PATCH_DIR/make-virtual-desktop-patch.sh" "$DESKTOP_SIZE" >/dev/null
  fi

  reg_import "$PATCH_DIR/01-usetakefocus.reg"
  if [ "$DRY_RUN" -eq 1 ] && [ ! -f "$desktop_patch" ]; then
    printf '[dry-run] would import generated patch: %s\n' "$desktop_patch"
  else
    reg_import "$desktop_patch"
  fi
}

apply_runtime_registry() {
  [ "$APPLY_RUNTIME" -eq 1 ] || return 0
  reg_import "$PATCH_DIR/10-nexon-launcher-protocol.reg"
  reg_import "$PATCH_DIR/11-wine-direct3d-dll-overrides.reg"
}

install_proton_settings() {
  [ "$INSTALL_PROTON_SETTINGS" -eq 1 ] || return 0
  local proton_dir target tmp
  proton_dir="$(dirname -- "$PROTON")"
  target="$proton_dir/user_settings.py"
  log "Installing marked linux_maplestory block into $target"
  backup_path "$target"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] update %q with linux_maplestory user_settings block\n' "$target"
    return 0
  fi

  if [ ! -f "$target" ]; then
    printf 'user_settings = {}\n' > "$target"
  fi

  tmp="$(mktemp)"
  awk '
    /# BEGIN linux_maplestory installer/ { skip=1; next }
    /# END linux_maplestory installer/ { skip=0; next }
    skip == 0 { print }
  ' "$target" > "$tmp"
  cat "$tmp" > "$target"
  rm -f "$tmp"

  cat >> "$target" <<'PY'

# BEGIN linux_maplestory installer
import os
try:
    user_settings
except NameError:
    user_settings = {}
_lm_appid = os.environ.get("SteamAppId") or os.environ.get("SteamGameId") or "216150"
_lm_prefix = os.environ.get("STEAM_COMPAT_DATA_PATH") or os.path.expanduser(f"~/.local/share/Steam/steamapps/compatdata/{_lm_appid}")
user_settings.update({
    "PROTON_LOG": "1",
    "RAW_AUDIO_PARSE": "1",
    "WINE_APPNAME_INI": os.path.join(_lm_prefix, "pfx", "drive_c", ".mappings.ini"),
})
# END linux_maplestory installer
PY
}

verify_install() {
  [ "$DRY_RUN" -eq 0 ] || return 0
  log "Verifying installed files"
  if [ "$APPLY_RUNTIME" -eq 1 ]; then
    require_file "$PFX/drive_c/windows/system32/vcruntime140_threads.dll"
    require_file "$PFX/drive_c/windows/syswow64/vcruntime140_threads.dll"
    require_file "$PFX/drive_c/.mappings.ini"
    require_file "$PFX/drive_c/users/steamuser/AppData/Roaming/NexonLauncher/apps-settings.db"
    require_file "$PFX/drive_c/Nexon/Launcher/nexon_launcher.exe"
  fi
}

ensure_payload
preflight_bundle
require_dir "$STEAM_ROOT"
require_dir "$COMMON_DIR"
require_dir "$PFX/drive_c"
resolve_proton
check_processes
preflight_runtime_sources
backup_targets
apply_runtime_files
apply_alt_tab_patches
apply_runtime_registry
install_proton_settings
verify_install

log "Install complete"
log "Backups: $BACKUP_DIR"
log "Relaunch MapleStory through Steam and test input + alt-tab."
if [ "$INSTALL_PROTON_SETTINGS" -eq 0 ]; then
  log "Proton user_settings.py was not changed. Use --install-proton-settings only if you need those env vars."
fi
