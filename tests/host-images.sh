#!/usr/bin/env bash
# The host holds the prepared images and seeds, byte-for-byte the same size as the local cache.
. "$(dirname "$0")/host-lib.sh"
CACHE=${IAC_LAB_IMAGES:-$HOME/iac-lab-images}
rc=0
check() { # local file, remote path
  local lsize rsize
  lsize=$(stat -c %s "$1" 2>/dev/null || echo missing)
  rsize=$(psrun "(Get-Item '$2' -ErrorAction SilentlyContinue).Length")
  if [ "$lsize" != missing ] && [ "$lsize" = "$rsize" ]; then echo "ok   $2 ($rsize bytes)"
  else echo "FAIL $2: remote '$rsize' vs local '$lsize'"; rc=1; fi
}
for img in ubuntu-24.04-cloudimg-amd64.vhdx rocky-9-cloudimg-amd64.vhdx; do
  check "$CACHE/$img" "$IMAGE_ROOT\\Images\\$img"
done
for vm in ubuntu-lab-01 rocky-lab-01 vault-lab-01; do
  check "$CACHE/seeds/$vm-seed.iso" "$IMAGE_ROOT\\Images\\seeds\\$vm-seed.iso"
done
[ "$rc" -eq 0 ] && echo "host-images: PASS" || echo "host-images: FAIL"
exit "$rc"
