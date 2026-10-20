#!/usr/bin/env bash
# Check the prepared images and seeds in the cache (default ~/iac-lab-images, or IAC_LAB_IMAGES).
set -u
CACHE=${IAC_LAB_IMAGES:-$HOME/iac-lab-images}
rc=0
for img in ubuntu-24.04-cloudimg-amd64.vhdx rocky-9-cloudimg-amd64.vhdx; do
  if qemu-img info "$CACHE/$img" 2>/dev/null | grep -q '^file format: vhdx$'; then
    echo "ok   $img is a VHDX"
  else
    echo "FAIL $img missing or not a VHDX"; rc=1
  fi
done
tmp=$(mktemp -d)
for vm in ubuntu-lab-01 rocky-lab-01 vault-lab-01; do
  iso=$CACHE/seeds/$vm-seed.iso
  if xorriso -indev "$iso" -pvd_info 2>/dev/null | grep -Eq '^Volume Id[[:space:]]*:[[:space:]]*cidata$'; then
    echo "ok   $vm-seed.iso volume id is cidata"
  else
    echo "FAIL $vm-seed.iso missing or volume id is not cidata"; rc=1; continue
  fi
  mkdir -p "$tmp/$vm"
  xorriso -osirrox on -indev "$iso" -extract / "$tmp/$vm" >/dev/null 2>&1
  if grep -q 'name: sysadmin' "$tmp/$vm/user-data" 2>/dev/null && grep -q "^hostname: $vm$" "$tmp/$vm/user-data" 2>/dev/null; then
    echo "ok   $vm-seed.iso user-data creates sysadmin on $vm"
  else
    echo "FAIL $vm-seed.iso user-data lacks sysadmin/hostname"; rc=1
  fi
done
rm -rf "$tmp"
[ "$rc" -eq 0 ] && echo "images: PASS" || echo "images: FAIL"
exit "$rc"
