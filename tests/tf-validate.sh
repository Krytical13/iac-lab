#!/usr/bin/env bash
# Format check for the whole repo, then init (no backend) + validate the Hyper-V root module.
set -u
cd "$(dirname "$0")/.."
rc=0
terraform fmt -check -recursive . || { echo "tf-validate: fmt FAIL"; rc=1; }
cd terraform/environments/hyperv
terraform init -backend=false -input=false -no-color >/tmp/tf-init.$$ 2>&1 || { tail -n 8 /tmp/tf-init.$$; echo "tf-validate: init FAIL"; rc=1; }
rm -f /tmp/tf-init.$$
if [ "$rc" -eq 0 ]; then
  terraform validate -no-color || { echo "tf-validate: validate FAIL"; rc=1; }
fi
[ "$rc" -eq 0 ] && echo "tf-validate: PASS"
exit "$rc"
