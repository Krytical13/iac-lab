#!/usr/bin/env bash
# Unit tests for the Terraform code: terraform test in the Hyper-V root module.
# Every provider is mocked in the test files, so this needs no Hyper-V host,
# no credentials and no state, and it creates nothing.
set -u
cd "$(dirname "$0")/../terraform/environments/hyperv"
log=$(mktemp)
trap 'rm -f "$log"' EXIT
# init also installs the module copies that the test files load directly.
terraform init -backend=false -input=false -no-color >"$log" 2>&1 || { tail -n 8 "$log"; echo "tf-test: init FAIL"; exit 1; }
terraform test -no-color || { echo "tf-test: FAIL"; exit 1; }
echo "tf-test: PASS"
