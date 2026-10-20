#!/usr/bin/env bash
# Fail if anything that belongs only on the owner's control node shows up in the tree.
# Examples in this repo use 192.168.1.x and "hyperv-host".
cd "$(dirname "$0")/.."
# Tracked files plus untracked files that are not gitignored (so tfvars/host.env stay out of scope).
if git ls-files --cached --others --exclude-standard -z | grep -zv 'no-private-values.sh$' | xargs -0 grep -nE '192\.168\.13\.|KRYTICAL|krytical|kRyTiCaL|58-11-22'; then
  echo "no-private-values: FAIL (private values above)"; exit 1
fi
echo "no-private-values: PASS"
