#!/usr/bin/env bash
set -euo pipefail

APPID="${APPID:-216150}"
STEAM_ROOT="${STEAM_ROOT:-$HOME/.local/share/Steam}"
COMMON_DIR="${COMMON_DIR:-$STEAM_ROOT/steamapps/common}"
PFX="${PFX:-$STEAM_ROOT/steamapps/compatdata/$APPID/pfx}"
MAC_BOTTLE="${MAC_BOTTLE:-$COMMON_DIR/MapleStory Mac/MapleStory.app/Contents/SharedSupport/maplestoryna/support/maplestory}"
NEXON_LAUNCHER_SOURCE="${NEXON_LAUNCHER_SOURCE:-}"
BUNDLE_ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
PAYLOAD_DIR="${PAYLOAD_DIR:-${PATCH_FILES_DIR:-$BUNDLE_ROOT/files}}"
PACKAGED_NEXON_LAUNCHER="$PAYLOAD_DIR/drive_c/Nexon/Launcher"

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

echo "Applying patch MapleStory app-name mapping"
copy_file "$PAYLOAD_DIR/drive_c/.mappings.ini" "$PFX/drive_c/.mappings.ini"

echo "Applying patch NexonLauncher apps-settings.db"
copy_file "$PAYLOAD_DIR/drive_c/users/steamuser/AppData/Roaming/NexonLauncher/apps-settings.db" \
  "$PFX/drive_c/users/steamuser/AppData/Roaming/NexonLauncher/apps-settings.db"

if [ -x "$PFX/drive_c/Nexon/Launcher/nexon_launcher.exe" ]; then
  echo "Nexon Launcher already exists in prefix; leaving it in place"
elif [ -x "$PACKAGED_NEXON_LAUNCHER/nexon_launcher.exe" ]; then
  echo "Copying patch Nexon Launcher"
  mkdir -p -- "$PFX/drive_c/Nexon"
  cp -a -- "$PACKAGED_NEXON_LAUNCHER" "$PFX/drive_c/Nexon/Launcher"
elif [ -n "$NEXON_LAUNCHER_SOURCE" ] && [ -x "$NEXON_LAUNCHER_SOURCE/nexon_launcher.exe" ]; then
  echo "Copying Nexon Launcher from NEXON_LAUNCHER_SOURCE"
  mkdir -p -- "$PFX/drive_c/Nexon"
  cp -a -- "$NEXON_LAUNCHER_SOURCE" "$PFX/drive_c/Nexon/Launcher"
elif [ -x "$MAC_BOTTLE/drive_c/Nexon/Launcher/nexon_launcher.exe" ]; then
  echo "Copying Nexon Launcher from Mac bottle"
  mkdir -p -- "$PFX/drive_c/Nexon"
  cp -a -- "$MAC_BOTTLE/drive_c/Nexon/Launcher" "$PFX/drive_c/Nexon/Launcher"
else
  echo "ERROR: Nexon Launcher is missing from prefix and no source was found." >&2
  echo "Expected one of:" >&2
  echo "  $PFX/drive_c/Nexon/Launcher/nexon_launcher.exe" >&2
  echo "  $PACKAGED_NEXON_LAUNCHER/nexon_launcher.exe" >&2
  [ -n "$NEXON_LAUNCHER_SOURCE" ] && echo "  $NEXON_LAUNCHER_SOURCE/nexon_launcher.exe" >&2
  echo "  $MAC_BOTTLE/drive_c/Nexon/Launcher/nexon_launcher.exe" >&2
  exit 1
fi

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
