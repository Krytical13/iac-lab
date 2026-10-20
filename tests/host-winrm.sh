#!/usr/bin/env bash
# The Hyper-V host is ready for Terraform: HTTPS WinRM listener answers and the lab directories exist.
. "$(dirname "$0")/host-lib.sh"
rc=0
code=$(curl -sk -m 10 -o /dev/null -w '%{http_code}' "https://$HOST:5986/wsman")
case "$code" in
  405|401) echo "ok   WinRM HTTPS listener answers on $HOST:5986 ($code)" ;;
  *)       echo "FAIL WinRM HTTPS on $HOST:5986 returned '$code' (want 405 or 401)"; rc=1 ;;
esac
for d in 'Images' 'Images\seeds' 'VHDs' 'VMs'; do
  out=$(psrun "Test-Path '$IMAGE_ROOT\\$d'")
  if [ "$out" = "True" ]; then echo "ok   $IMAGE_ROOT\\$d exists"; else echo "FAIL $IMAGE_ROOT\\$d missing (got '$out')"; rc=1; fi
done
[ "$rc" -eq 0 ] && echo "host-winrm: PASS" || echo "host-winrm: FAIL"
exit "$rc"
