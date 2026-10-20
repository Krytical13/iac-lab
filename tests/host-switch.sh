#!/usr/bin/env bash
# After the External switch exists: it is bound to $NIC with management OS access, the host
# kept its MAC and IPv4 address on "vEthernet (<switch>)", and $NIC's advanced/power settings,
# default gateway and DNS servers match the snapshot taken before (scripts/host-snapshot.ps1).
#
#   BEFORE=path/to/before.txt AFTER=path/to/after.txt tests/host-switch.sh
#   (defaults: newest *-before.txt / *-after.txt in $SNAP_DIR, default ~/projects/docs/host-snapshots)
. "$(dirname "$0")/host-lib.sh"
SWITCH=${SWITCH:-Lab-External}
SNAP_DIR=${SNAP_DIR:-$HOME/projects/docs/host-snapshots}
BEFORE=${BEFORE:-$(ls -1 "$SNAP_DIR"/*-before.txt 2>/dev/null | tail -n1)}
AFTER=${AFTER:-$(ls -1 "$SNAP_DIR"/*-after.txt 2>/dev/null | tail -n1)}
rc=0
ok()   { echo "ok   $*"; }
fail() { echo "FAIL $*"; rc=1; }

sw=$(psrun "\$s = Get-VMSwitch -Name '$SWITCH' -ErrorAction SilentlyContinue; if (\$s) { \$s.SwitchType.ToString() + '|' + \$s.AllowManagementOS + '|' + (Get-NetAdapter -InterfaceDescription \$s.NetAdapterInterfaceDescription -ErrorAction SilentlyContinue).Name }")
case "$sw" in
  "External|True|$NIC") ok "switch $SWITCH is External on '$NIC' with management OS access" ;;
  *) fail "switch $SWITCH: got '$sw' (want External|True|$NIC)" ;;
esac

valias="vEthernet ($SWITCH)"
mac=$(psrun "(Get-NetAdapter -Name '$valias' -ErrorAction SilentlyContinue).MacAddress")
[ "$mac" = "$EXPECT_MAC" ] && ok "'$valias' carries MAC $EXPECT_MAC" || fail "'$valias' MAC is '$mac' (want $EXPECT_MAC)"
ip=$(psrun "(Get-NetIPAddress -InterfaceAlias '$valias' -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress")
[ "$ip" = "$EXPECT_IP" ] && ok "'$valias' has $EXPECT_IP" || fail "'$valias' IPv4 is '$ip' (want $EXPECT_IP)"

if [ -r "$BEFORE" ] && [ -r "$AFTER" ]; then
  settings() { sed -n '/^--- Advanced properties/,$p' "$1"; }
  if diff -u <(settings "$BEFORE") <(settings "$AFTER") >/tmp/host-switch.diff.$$; then
    ok "advanced properties and power management of '$NIC' unchanged"
  else
    fail "adapter settings changed:"; cat /tmp/host-switch.diff.$$
  fi
  rm -f /tmp/host-switch.diff.$$
  gw()  { sed -n '/^--- IPv4 default routes/,/^---/p' "$1" | sed -n 's/^.*: via \([0-9.]*\) .*/\1/p' | sort -u | tr '\n' ' '; }
  dns() { sed -n '/^--- DNS servers/,/^---/p' "$1" | grep -E "^($NIC|vEthernet \($SWITCH\)): " | sed 's/^[^:]*: //' | sort -u | tr '\n' ' '; }
  [ "$(gw "$BEFORE")" = "$(gw "$AFTER")" ] && ok "default gateway unchanged ($(gw "$AFTER"))" || fail "default gateway changed: '$(gw "$BEFORE")' → '$(gw "$AFTER")'"
  [ "$(dns "$BEFORE")" = "$(dns "$AFTER")" ] && ok "DNS servers unchanged ($(dns "$AFTER"))" || fail "DNS servers changed: '$(dns "$BEFORE")' → '$(dns "$AFTER")'"
else
  fail "snapshots missing (BEFORE='$BEFORE' AFTER='$AFTER')"
fi

[ "$rc" -eq 0 ] && echo "host-switch: PASS" || echo "host-switch: FAIL"
exit "$rc"
