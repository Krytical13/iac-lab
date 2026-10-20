# tests/host-lib.sh — shared by the tests/host-*.sh checks. Source it; it loads tests/host.env.
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 2
[ -r tests/host.env ] || { echo "tests/host.env missing: copy tests/host.env.example and fill it in" >&2; exit 2; }
# shellcheck disable=SC1091
. tests/host.env
SSH_KEY="${SSH_KEY/#\~/$HOME}"
# Run a PowerShell snippet on the host over SSH (the snippet is base64 UTF-16LE encoded,
# so quoting survives the SSH command line). Output has Windows line endings stripped.
psrun() {
  ssh -i "$SSH_KEY" -o BatchMode=yes -o ConnectTimeout=10 "$SSH_USER@$HOST" \
    powershell -NoProfile -NonInteractive -EncodedCommand \
    "$(printf '%s' "$1" | iconv -f UTF-8 -t UTF-16LE | base64 -w0)" 2>/dev/null | tr -d '\r'
}
