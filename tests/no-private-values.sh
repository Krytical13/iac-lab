#!/usr/bin/env bash
# Fail if anything that belongs only on the owner's control node shows up in the tree.
# Examples in this repo use 192.168.1.x and "hyperv-host".
cd "$(dirname "$0")/.."
if grep -rnE '192\.168\.13\.|KRYTICAL|krytical|kRyTiCaL|58-11-22' --exclude-dir=.git --exclude-dir=.superpowers --exclude-dir=.terraform --exclude=no-private-values.sh .; then
  echo "no-private-values: FAIL (private values above)"; exit 1
fi
echo "no-private-values: PASS"
