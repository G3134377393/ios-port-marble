#!/bin/bash
# Pull the ADSP firmware segments from YOUR OWN phone into ./adsp-fw/.
# These files are proprietary Qualcomm/Xiaomi blobs and are NOT part of this
# repository; the kernel needs them only to start the audio DSP.
#
#   SERIAL=2aa26095 ./scripts/extract_adsp_fw.sh [outdir]
#
# A rooted phone is required for a reliable copy (the project's marble uses
# SukiSU Ultra: `su` is in PATH).  Without root, adb pull usually still works
# because /vendor/firmware is world-readable; the script tries that first.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
OUT="${1:-$ROOT/adsp-fw}"
SERIAL="${SERIAL:-}"
SRC="${FW_SRC:-/vendor/firmware}"

if [ -z "$SERIAL" ]; then
  SERIAL=$(adb devices 2>/dev/null | awk '$2=="device"||$2=="recovery"{print $1; exit}')
fi
[ -n "$SERIAL" ] || { echo "no adb device" >&2; exit 1; }
mkdir -p "$OUT"

echo "listing $SRC/adsp2.* on $SERIAL"
LIST=$(adb -s "$SERIAL" shell "su -c 'ls $SRC/adsp2.*'" 2>/dev/null | tr -d '\r')
if [ -z "$LIST" ]; then
  LIST=$(adb -s "$SERIAL" shell "ls $SRC/adsp2.*" 2>/dev/null | tr -d '\r')
fi
[ -n "$LIST" ] || { echo "no adsp2.* under $SRC" >&2; exit 1; }

for path in $LIST; do
  name=$(basename "$path")
  echo "  $name"
  adb -s "$SERIAL" exec-out "su -c 'cat $path'" > "$OUT/$name" 2>/dev/null ||
    adb -s "$SERIAL" exec-out "cat $path" > "$OUT/$name"
done
ls -lh "$OUT" | head
echo "done: $OUT"
echo "now run: ADSP_FW_DIR=$OUT ./scripts/mkimage.sh"
