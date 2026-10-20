#!/usr/bin/env bash
# End-to-end check of the Ansible guide against the running lab, in the guide's order.
# Needs: the lab up (terraform apply), ansible/.vault_pass, snmpwalk, jq, curl.
# Checks, stopping at the first failure:
#   1. ansible linux -m ping                      -> 3 pong
#   2. playbooks/base.yml twice; the second recap shows changed=0 failed=0 for every host
#   3. ssh with the lab key still works on all three after SSH hardening
#   4. snmpd answers snmpwalk from the control node with the vault community (ubuntu, rocky)
#   5. node_exporter answers on 9100 on all three
#   6. playbooks/docker.yml; docker --version; a container's published port answers from here
#   7. base.yml again on the Docker host: still changed=0, ip_forward stays 1, the port still answers
set -uo pipefail
cd "$(dirname "$0")/../ansible" || exit 2
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
die() { echo "FAIL: $*"; echo "ansible-lab: FAIL"; exit 1; }
ok() { echo "ok   $*"; }
ip_of() { ansible-inventory --host "$1" | jq -r .ansible_host; }
sshq() { ssh -i ~/.ssh/lab_key -o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=10 "sysadmin@$(ip_of "$1")" "${@:2}"; }
recap_ok() { # recap_ok LOG HOSTS: every host line shows changed=0 and failed=0
  local recap; recap=$(sed -n '/PLAY RECAP/,/^$/p' "$1"); echo "$recap"
  [ "$(echo "$recap" | grep -c 'changed=0 ')" -eq "$2" ] || return 1
  [ "$(echo "$recap" | grep -c 'failed=0 ')" -eq "$2" ] || return 1
}
hosts="ubuntu-lab-01 rocky-lab-01 vault-lab-01"
docker_host=ubuntu-lab-01

# 1. ping
n=$(ansible linux -m ansible.builtin.ping 2>&1 | grep -c '"ping": "pong"')
[ "$n" -eq 3 ] || die "ansible ping: $n pong (expected 3)"
ok "ansible ping: 3 pong"

# 2. the baseline, twice
ansible-playbook playbooks/base.yml >"$tmp/run1.log" 2>&1 || { tail -20 "$tmp/run1.log"; die "base.yml run 1"; }
ansible-playbook playbooks/base.yml >"$tmp/run2.log" 2>&1 || { tail -20 "$tmp/run2.log"; die "base.yml run 2"; }
recap_ok "$tmp/run2.log" 3 || die "second base.yml run is not idempotent or had failures"
ok "base.yml second run: changed=0 on 3 hosts"

# 3. still reachable after hardening
for h in $hosts; do
  sshq "$h" true || die "ssh sysadmin@$h with the lab key after hardening"
  ok "ssh sysadmin@$h still works"
done

# 4. snmp with the community string from the vault
community=$(ansible ubuntu-lab-01 -m ansible.builtin.debug -a var=vault_snmpd_community 2>/dev/null \
  | grep -o '"vault_snmpd_community": "[^"]*"' | cut -d'"' -f4)
[ -n "$community" ] || die "could not read vault_snmpd_community (is .vault_pass present?)"
for h in ubuntu-lab-01 rocky-lab-01; do
  # numeric OID for sysName.0, so this works without MIBs on the control node
  got=$(snmpwalk -v2c -c "$community" -t 3 -r 1 "$(ip_of "$h")" 1.3.6.1.2.1.1.5 2>&1 | head -1)
  case "$got" in *"STRING: "*"$h"*) ok "snmpwalk $h: $got" ;; *) die "snmpwalk $h: $got" ;; esac
done

# 5. node_exporter
for h in $hosts; do
  c=$(curl -s -m 5 "http://$(ip_of "$h"):9100/metrics" | grep -c '^node_exporter_build_info')
  [ "$c" -ge 1 ] || die "node_exporter on $h: no build_info metric on :9100"
  ok "node_exporter $h answers on 9100"
done

# 6. Galaxy role, and a published port reachable from the control node
ansible-playbook playbooks/docker.yml >"$tmp/docker.log" 2>&1 || { tail -20 "$tmp/docker.log"; die "docker.yml"; }
v=$(sshq "$docker_host" docker --version 2>&1)
case "$v" in "Docker version"*) ok "$docker_host: $v" ;; *) die "docker --version on $docker_host: $v" ;; esac
sshq "$docker_host" 'docker rm -f labtest >/dev/null 2>&1; docker run -d --name labtest -p 8080:80 nginx:alpine >/dev/null' || die "could not start the test container"
sleep 2
code=$(curl -s -m 5 -o /dev/null -w '%{http_code}' "http://$(ip_of "$docker_host"):8080/")
[ "$code" = "200" ] || { sshq "$docker_host" 'docker rm -f labtest >/dev/null'; die "published port 8080 on $docker_host answered '$code' (expected 200)"; }
ok "published port 8080 on $docker_host answers 200"

# 7. the baseline re-applied on the Docker host must not break Docker networking
ansible-playbook playbooks/base.yml --limit "$docker_host" >"$tmp/run3.log" 2>&1 || { tail -20 "$tmp/run3.log"; die "base.yml run 3"; }
recap_ok "$tmp/run3.log" 1 || die "base.yml on the Docker host changed something on a re-run"
fwd=$(sshq "$docker_host" sysctl -n net.ipv4.ip_forward)
[ "$fwd" = "1" ] || { sshq "$docker_host" 'docker rm -f labtest >/dev/null'; die "net.ipv4.ip_forward is $fwd on $docker_host after base.yml (Docker needs 1)"; }
code=$(curl -s -m 5 -o /dev/null -w '%{http_code}' "http://$(ip_of "$docker_host"):8080/")
sshq "$docker_host" 'docker rm -f labtest >/dev/null'
[ "$code" = "200" ] || die "published port 8080 answered '$code' after base.yml re-ran on the Docker host"
ok "base.yml re-run on $docker_host: changed=0, ip_forward=1, port 8080 still answers"

echo "ansible-lab: PASS"
