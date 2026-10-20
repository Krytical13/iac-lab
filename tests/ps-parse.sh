#!/usr/bin/env bash
# Wrapper: needs pwsh on the control node (sudo snap install powershell --classic).
cd "$(dirname "$0")/.." && exec pwsh -NoProfile -NonInteractive -File tests/ps-parse.ps1
