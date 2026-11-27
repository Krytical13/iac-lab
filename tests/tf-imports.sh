#!/usr/bin/env bash
# Checks the import blocks the pipeline uses to plan the Azure network layer
# without a state file (terraform/environments/azure-network/pipeline/imports.tf).
#   1. every resource in the layer has exactly one import block, and no block
#      names a resource the layer does not have
#   2. the layer still validates with the blocks copied in
# Needs no Azure account, no sign-in and no state, and it creates nothing.
set -u
cd "$(dirname "$0")/../terraform/environments/azure-network" || { echo "tf-imports: no azure-network environment"; exit 1; }
rc=0

resources=$(grep -hoE '^resource "[a-z0-9_]+" "[a-z0-9_]+"' ./*.tf | sed -E 's/^resource "([^"]+)" "([^"]+)"$/\1.\2/' | sort)
targets=$(grep -hoE '^\s*to\s*=\s*[a-z0-9_]+\.[a-z0-9_]+' pipeline/imports.tf | sed -E 's/^\s*to\s*=\s*//' | sort)
if [ "$resources" != "$targets" ]; then
  echo "tf-imports: the import blocks do not match the resources of the layer"
  diff <(echo "$resources") <(echo "$targets") | sed 's/^</  resource without an import block:/; s/^>/  import block without a resource:  /' | grep '^  '
  rc=1
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp ./*.tf .terraform.lock.hcl pipeline/imports.tf "$tmp"/
cd "$tmp" || exit 1
terraform init -backend=false -input=false -no-color >init.log 2>&1 || { tail -n 8 init.log; echo "tf-imports: init FAIL"; exit 1; }
terraform validate -no-color >validate.log 2>&1 || { cat validate.log; echo "tf-imports: validate FAIL"; rc=1; }

[ "$rc" -eq 0 ] && echo "tf-imports: PASS ($(echo "$targets" | wc -l) import blocks for $(echo "$resources" | wc -l) resources)"
exit "$rc"
