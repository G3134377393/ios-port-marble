#!/bin/bash
# Boot the shim image with `fastboot boot` — RAM ONLY.
# Nothing is written to the phone: boot/vendor_boot/userdata/GPT stay untouched.
#
#   SERIAL=2aa26095 ./scripts/boot_ram.sh [image]
#
# Default image: images/shim-iosroot-adsp.img
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
IMAGE="${1:-$ROOT/images/shim-iosroot-adsp.img}"
SERIAL="${SERIAL:-}"

[ -f "$IMAGE" ] || { echo "missing image: $IMAGE" >&2; exit 1; }

if [ -z "$SERIAL" ]; then
  SERIAL=$(adb devices 2>/dev/null | awk '$2=="device"||$2=="recovery"{print $1; exit}')
fi
if [ -z "$SERIAL" ]; then
  SERIAL=$(fastboot devices 2>/dev/null | awk 'NF{print $1; exit}')
fi
[ -n "$SERIAL" ] || { echo "no device in adb/fastboot" >&2; exit 1; }
echo "device: $SERIAL"

# Get into the bootloader.  Ignore failures: the phone may already be there.
adb -s "$SERIAL" reboot bootloader >/dev/null 2>&1 || true
for _ in $(seq 1 60); do
  fastboot -s "$SERIAL" getvar product 2>&1 | grep -q "product:" && break
  sleep 1
done

echo "booting $IMAGE (RAM-only; nothing is flashed)"
fastboot -s "$SERIAL" boot "$IMAGE"
echo "kernel running.  It resets itself when done; pull logs with scripts/pull_logs.sh"
