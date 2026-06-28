#!/usr/bin/env bash
# Byte-patch GE-Proton11-1's Wine in place to fix MapleStory launch/input,
# as an alternative to shipping pre-patched binaries. Each patch reads at a
# FIXED offset (these are specific to the GE-Proton11-1 Wine build), verifies
# the current bytes are the expected stock pattern (or already patched), and
# replaces them only on an exact stock match. This is unambiguous and safe:
# offset-based means no risk of patching a random short-byte match elsewhere,
# and it errors loudly if the bytes at the offset are neither stock nor patched
# (different build) instead of silently mis-patching.
#
# Covers kernelbase.dll + win32u.so (the byte-level patches). It does NOT touch
# dinput8.dll — that one is a whole-file substitute from a different Wine build,
# not a byte patch, so it must be supplied as a file (or dropped).
#
# Caller must version-guard: only run this against GE-Proton11-1.
# Usage: patches/patch-wine-binaries.sh <GE-Proton11-1 tool dir>
set -euo pipefail

PROTON_DIR="${1:?usage: $0 <GE-Proton11-1 tool dir>}"
KB="$PROTON_DIR/files/lib/wine/x86_64-windows/kernelbase.dll"
WU="$PROTON_DIR/files/lib/wine/x86_64-unix/win32u.so"

patch_at() {
  # $1=file $2=offset(hex) $3=stock(hex) $4=patched(hex) $5=label
  local file="$1" offset="$2" stock="$3" patched="$4" label="$5"
  [ -f "$file" ] || { echo "  skip (target absent): $file" >&2; return 0; }
  chmod u+w -- "$file" 2>/dev/null || true   # Wine ships these read-only on some setups
  python3 - "$file" "$offset" "$stock" "$patched" "$label" <<'PY'
import sys
path, offset, stock, patched, label = sys.argv[1:6]
off = int(offset, 16)
sb = bytes.fromhex(stock.replace(' ', ''))
pb = bytes.fromhex(patched.replace(' ', ''))
n = len(sb)
data = open(path, 'rb').read()
if off + n > len(data):
    print(f"  ERROR: offset {offset} beyond end of {path}; not patched", file=sys.stderr); sys.exit(1)
cur = data[off:off + n]
if cur == pb:
    print(f"  already patched: {label}"); sys.exit(0)
if cur != sb:
    print(f"  ERROR: bytes at {offset} are {cur.hex(' ')}, expected stock {stock} "
          f"or patched {patched} (wrong Wine build?); not patched", file=sys.stderr); sys.exit(1)
open(path, 'wb').write(data[:off] + pb + data[off + n:])
print(f"  patched: {label}")
PY
}

echo "Patching kernelbase.dll (CharPrevExA + HeapSetInformation + SetLastError):"
patch_at "$KB" 0x11413 "0f b7 f9 eb 2d 0f 1f 84 00 00 00 00 00" "48 85 db 74 35 0f b7 f9 eb 28 90 90 90" "CharPrevExA NULL-check (0xc0000005 launch crash)"
patch_at "$KB" 0x33443 "31 db" "31 c0" "HeapSetInformation return-TRUE (xor)"
patch_at "$KB" 0x3344e "89 d8" "ff c0" "HeapSetInformation return-TRUE (inc)"
patch_at "$KB" 0x335a9 "c7 40 68 7b 00 00 00" "c7 40 68 00 00 00 00" "SetLastError(0)"

echo "Patching win32u.so (SPI_SETSTICKYKEYS + SPI_SETFILTERKEYS):"
patch_at "$WU" 0x122fa7 "0f 84 53 ee ff ff" "e9 24 ee ff ff 90" "SPI_SETSTICKYKEYS force-success"
patch_at "$WU" 0x122c1c "0f 84 de f2 ff ff" "e9 af f1 ff ff 90" "SPI_SETFILTERKEYS force-success"

echo "Wine binary patches complete."
