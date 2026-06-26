#!/usr/bin/env bash
set -euo pipefail

param="/sys/module/hid_apple/parameters/fnmode"
conf="/etc/modprobe.d/hid_apple.conf"

usage() {
  cat <<'EOF'
Usage: patches/20-hid-apple-fkeysfirst.sh [--persist]

Sets Linux hid_apple fnmode=2 so Apple-compatible keyboards send real F1-F12
by default instead of media keys. This affects keyboards that report an Apple
USB vendor id even when they are not Apple-branded.

Options:
  --persist   Also write /etc/modprobe.d/hid_apple.conf for reboot persistence.
EOF
}

persist=0
case "${1:-}" in
  "") ;;
  --persist) persist=1 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

if [ ! -e "$param" ]; then
  echo "hid_apple is not loaded; no hid_apple fnmode change is needed."
  exit 0
fi

current="$(cat "$param")"
echo "Current hid_apple fnmode: $current"

if [ "$current" != "2" ]; then
  echo "Setting temporary hid_apple fnmode=2 (F1-F12 first)."
  printf '2\n' | sudo tee "$param" >/dev/null
else
  echo "Temporary hid_apple fnmode is already 2."
fi

if [ "$persist" -eq 1 ]; then
  echo "Writing persistent modprobe config: $conf"
  printf 'options hid_apple fnmode=2\n' | sudo tee "$conf" >/dev/null
  echo "Persistent config written. If your distro loads hid_apple from initramfs, rebuild it before rebooting."
fi

echo "New hid_apple fnmode: $(cat "$param")"
