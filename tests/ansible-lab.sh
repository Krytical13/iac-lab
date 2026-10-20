#!/usr/bin/env bash
# End-to-end check of the Ansible guide against the running lab.
# Needs: the lab up (terraform apply), ansible/.vault_pass, snmpwalk, jq, curl.
# Checks, in order, stopping at the first failure:
#   1. ansible linux -m ping                      -> 3 pong
#   2. snmpd answers snmpwalk from the control node with the vault community (ubuntu, rocky)
#   3. node_exporter answers on 9100 on all three
#   4. playbooks/base.yml twice; the second recap shows changed=0 failed=0 for every host
#   5. ssh with the lab key still works on all three after SSH hardening
#   6. playbooks/docker.yml, then docker --version on the docker_servers host
set -uo pipefail
cd "$(dirname "$0")/../ansible" || exit 2
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
die() { echo "FAIL: $*"; echo "ansible-lab: FAIL"; exit 1; }
ok() { echo "ok   $*"; }
ip_of() { ansible-inventory --host "$1" | jq -r .ansible_host; }
sshq() { ssh -i ~/.ssh/lab_key -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10 "sysadmin@$(ip_of "$1")" "${@:2}"; }
hosts="ubuntu-lab-01 rocky-lab-01 vault-lab-01"

# 1. ping
n=$(ansible linux -m ansible.builtin.ping 2>&1 | grep -c '"ping": "pong"')
[ "$n" -eq 3 ] || die "ansible ping: $n pong (expected 3)"
ok "ansible ping: 3 pong"

# 2. snmp with the community string from the vault
community=$(ansible ubuntu-lab-01 -m ansible.builtin.debug -a var=vault_snmpd_community 2>/dev/null \
  | grep -o '"vault_snmpd_community": "[^"]*"' | cut -d'"' -f4)
[ -n "$community" ] || die "could not read vault_snmpd_community (is .vault_pass present?)"
for h in ubuntu-lab-01 rocky-lab-01; do
  # numeric OID for sysName.0, so this works without MIBs on the control node
  got=$(snmpwalk -v2c -c "$community" -t 3 -r 1 "$(ip_of "$h")" 1.3.6.1.2.1.1.5 2>&1 | head -1)
  case "$got" in *"STRING: "*"$h"*) ok "snmpwalk $h: $got" ;; *) die "snmpwalk $h: $got" ;; esac
done

# 3. node_exporter
for h in $hosts; do
  c=$(curl -s -m 5 "http://$(ip_of "$h"):9100/metrics" | grep -c '^node_exporter_build_info')
  [ "$c" -ge 1 ] || die "node_exporter on $h: no build_info metric on :9100"
  ok "node_exporter $h answers on 9100"
done

# 4. idempotency
ansible-playbook playbooks/base.yml >"$tmp/run1.log" 2>&1 || { tail -20 "$tmp/run1.log"; die "base.yml run 1"; }
ansible-playbook playbooks/base.yml >"$tmp/run2.log" 2>&1 || { tail -20 "$tmp/run2.log"; die "base.yml run 2"; }
recap=$(sed -n '/PLAY RECAP/,/^$/p' "$tmp/run2.log")
echo "$recap"
[ "$(echo "$recap" | grep -c 'changed=0 ')" -eq 3 ] || die "second base.yml run is not idempotent"
[ "$(echo "$recap" | grep -c 'failed=0 ')" -eq 3 ] || die "second base.yml run had failures"
ok "base.yml second run: changed=0 on 3 hosts"

# 5. still reachable after hardening
for h in $hosts; do
  sshq "$h" true || die "ssh sysadmin@$h with the lab key after hardening"
  ok "ssh sysadmin@$h still works"
done

# 6. Galaxy role
ansible-playbook playbooks/docker.yml >"$tmp/docker.log" 2>&1 || { tail -20 "$tmp/docker.log"; die "docker.yml"; }
v=$(sshq ubuntu-lab-01 docker --version 2>&1)
case "$v" in "Docker version"*) ok "ubuntu-lab-01: $v" ;; *) die "docker --version on ubuntu-lab-01: $v" ;; esac

echo "ansible-lab: PASS"
