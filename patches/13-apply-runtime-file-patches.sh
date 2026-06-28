#!/usr/bin/env bash
set -euo pipefail

APPID="${APPID:-216150}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
COMMON_DIR="${COMMON_DIR:-$STEAM_ROOT/steamapps/common}"
PFX="${PFX:-$STEAM_ROOT/steamapps/compatdata/$APPID/pfx}"
BUNDLE_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PAYLOAD_DIR="${PAYLOAD_DIR:-$BUNDLE_ROOT/files}"

copy_file() {
  local src="$1"
  local dst="$2"
  mkdir -p -- "$(dirname -- "$dst")"
  cp -a -- "$src" "$dst"
}

echo "Using prefix: $PFX"

if [ ! -d "$PFX/drive_c" ]; then
  echo "ERROR: Proton prefix drive_c not found: $PFX/drive_c" >&2
  exit 1
fi

echo "Generating MapleStory app-name mapping (.mappings.ini)"
printf '%s\n' 'MapleStory.exe=MapleStory' \
  'nexon_client.exe=Nexon Launcher' \
  'nexon_updater.exe=Nexon Updater' \
  > "$PFX/drive_c/.mappings.ini"

echo "Generating NexonLauncher apps-settings.db (locale=en_US)"
mkdir -p -- "$PFX/drive_c/users/steamuser/AppData/Roaming/NexonLauncher"
printf '%s' '{"locale":"en_US"}' > "$PFX/drive_c/users/steamuser/AppData/Roaming/NexonLauncher/apps-settings.db"

echo "Applying required patch VC++ 2022 runtime DLLs"
for dll in \
  concrt140.dll \
  msvcp140.dll \
  msvcp140_1.dll \
  msvcp140_2.dll \
  msvcp140_atomic_wait.dll \
  msvcp140_codecvt_ids.dll \
  ucrtbase.dll \
  vccorlib140.dll \
  vcomp140.dll \
  vcruntime140.dll \
  vcruntime140_1.dll \
  vcruntime140_threads.dll
 do
  copy_file "$PAYLOAD_DIR/vc_runtime/system32/$dll" "$PFX/drive_c/windows/system32/$dll"
  echo "  system32/$dll"
done

for dll in \
  concrt140.dll \
  msvcp140.dll \
  msvcp140_1.dll \
  msvcp140_2.dll \
  msvcp140_atomic_wait.dll \
  msvcp140_codecvt_ids.dll \
  ucrtbase.dll \
  vccorlib140.dll \
  vcomp140.dll \
  vcruntime140.dll \
  vcruntime140_threads.dll
 do
  copy_file "$PAYLOAD_DIR/vc_runtime/syswow64/$dll" "$PFX/drive_c/windows/syswow64/$dll"
  echo "  syswow64/$dll"
done

echo "Done. Import patches/10-nexon-launcher-protocol.reg and patches/11-wine-direct3d-dll-overrides.reg next."
