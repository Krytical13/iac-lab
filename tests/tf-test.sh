#!/usr/bin/env bash
# Unit tests for the Terraform code: terraform test in one root module.
#   tests/tf-test.sh          the Hyper-V environment (the default)
#   tests/tf-test.sh azure    the Azure environment
# Every provider is mocked in the test files, so this needs no Hyper-V host,
# no Azure account, no credentials and no state, and it creates nothing.
set -u
env="${1:-hyperv}"
cd "$(dirname "$0")/../terraform/environments/$env" 2>/dev/null || { echo "tf-test: no environment named '$env'"; exit 1; }
log=$(mktemp)
trap 'rm -f "$log"' EXIT
# init also installs the module copies that the test files load directly.
terraform init -backend=false -input=false -no-color >"$log" 2>&1 || { tail -n 8 "$log"; echo "tf-test: init FAIL"; exit 1; }
terraform test -no-color || { echo "tf-test: FAIL"; exit 1; }
echo "tf-test: PASS"
