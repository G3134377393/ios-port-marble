#!/bin/bash
# Pull the SWEETLOG ring that the kernel keeps in the last 4 MiB+4 KiB of the
# userdata partition.  Works in TWRP/recovery (adbd is root there) and in
# Android (uses su).
#
#   ./scripts/pull_logs.sh [label]
#
# Output:
#   logs/raw/ring-<label>.bin   raw region
#   logs/ring-<label>.txt       decoded log
#
# The three dd constants match this phone's userdata geometry:
#   partition tail offset 58771962 * 4096 (~224.5 GiB), 1025 blocks.
# If your partition table differs, read them from
#   /sys/class/block/sda33/start and /sys/class/block/sda33/size
# or adjust here.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
LABEL="${1:-latest}"
SERIAL="${SERIAL:-}"
SKIP=58771962
COUNT=1025
BS=4096

if [ -z "$SERIAL" ]; then
  SERIAL=$(adb devices 2>/dev/null | awk '$2=="device"||$2=="recovery"{print $1; exit}')
fi
[ -n "$SERIAL" ] || { echo "no adb device (expected recovery/TWRP is fine)" >&2; exit 1; }

STATE=""
for _ in $(seq 1 120); do
  STATE=$(adb -s "$SERIAL" get-state 2>/dev/null || true)
  [ "$STATE" = "recovery" ] || [ "$STATE" = "device" ] && break
  sleep 5
done
[ -n "$STATE" ] || { echo "device never answered adb" >&2; exit 1; }
echo "adb state: $STATE"

mkdir -p "$ROOT/logs/raw"
RAW="$ROOT/logs/raw/ring-$LABEL.bin"
if [ "$STATE" = "recovery" ]; then
  adb -s "$SERIAL" exec-out \
    "dd if=/dev/block/sda33 bs=$BS skip=$SKIP count=$COUNT 2>/dev/null" > "$RAW"
else
  # Android: userdata is root-only.
  adb -s "$SERIAL" exec-out \
    "su -c 'dd if=/dev/block/sda33 bs=$BS skip=$SKIP count=$COUNT 2>/dev/null'" > "$RAW"
fi
ls -lh "$RAW"

OUT="$ROOT/logs/ring-$LABEL.txt"
python3 - "$RAW" "$OUT" <<'PY'
import sys, struct
d = open(sys.argv[1], 'rb').read()
hdr = d[:4096]
magic = hdr[:8]
ver, size = struct.unpack_from('<II', hdr, 8)
total, seq = struct.unpack_from('<QQ', hdr, 16)
print(f"magic={magic} ver={ver} total={total} seq={seq}")
if magic != b'SWEETLOG':
    sys.exit("not a SWEETLOG ring (wrong partition offset?)")
ring = d[4096:4096 + size]
start = max(0, total - size)
buf = bytes(ring[n % size] for n in range(start, total))
open(sys.argv[2], 'wb').write(buf)
print("wrote", sys.argv[2], len(buf))
PY

grep -aE "SWEET (ADSP|GLINK|I2C)|graph_|shm_|map_probe|data_buffer|pcm|panic" \
  "$OUT" | tail -40
