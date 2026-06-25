#!/usr/bin/env bash
set -euo pipefail

size="${1:-${VIRTUAL_DESKTOP_SIZE:-3840x2160}}"
case "$size" in
  [0-9]*x[0-9]*) ;;
  *)
    echo "usage: $0 WIDTHxHEIGHT" >&2
    echo "example: $0 2560x1440" >&2
    exit 2
    ;;
esac

bundle_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
out="$bundle_root/patches/02-virtual-desktop-$size.reg"

cat > "$out" <<REG
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\\Software\\Wine\\Explorer]
"Desktop"="Default"

[HKEY_CURRENT_USER\\Software\\Wine\\Explorer\\Desktops]
"Default"="$size"
REG

echo "Wrote $out"
