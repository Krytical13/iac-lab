#!/usr/bin/env bash
# The host holds the prepared images and seeds, with the same SHA256 as the local cache.
. "$(dirname "$0")/host-lib.sh"
CACHE=${IAC_LAB_IMAGES:-$HOME/iac-lab-images}
rc=0
check() { # local file, remote path
  local lsum rsum
  lsum=$(sha256sum "$1" 2>/dev/null | cut -d' ' -f1); lsum=${lsum:-missing}
  rsum=$(psrun "(Get-FileHash -Algorithm SHA256 -Path '$2' -ErrorAction SilentlyContinue).Hash.ToLower()")
  if [ "$lsum" != missing ] && [ "$lsum" = "$rsum" ]; then echo "ok   $2 (sha256 ${rsum:0:12}…)"
  else echo "FAIL $2: remote '${rsum:0:12}' vs local '${lsum:0:12}'"; rc=1; fi
}
for img in ubuntu-24.04-cloudimg-amd64.vhdx rocky-9-cloudimg-amd64.vhdx; do
  check "$CACHE/$img" "$IMAGE_ROOT\\Images\\$img"
done
for vm in ubuntu-lab-01 rocky-lab-01 vault-lab-01; do
  check "$CACHE/seeds/$vm-seed.iso" "$IMAGE_ROOT\\Images\\seeds\\$vm-seed.iso"
done
[ "$rc" -eq 0 ] && echo "host-images: PASS" || echo "host-images: FAIL"
exit "$rc"
