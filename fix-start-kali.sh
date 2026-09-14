#!/data/data/com.termux/files/usr/bin/bash
# Termo-Kali launcher hotfix
# Fixes: ~/start-kali.sh: exec: proot: not found

set -Eeuo pipefail

START_SCRIPT="$HOME/start-kali.sh"
PROOT_BIN="${PREFIX:-/data/data/com.termux/files/usr}/bin/proot"

if [[ ! -x "$PROOT_BIN" ]]; then
  echo "[ERROR] Termux proot was not found at: $PROOT_BIN" >&2
  echo "Install it with: pkg install proot" >&2
  exit 1
fi

if [[ ! -f "$START_SCRIPT" ]]; then
  echo "[ERROR] $START_SCRIPT does not exist." >&2
  echo "Run the Termo-Kali installer first." >&2
  exit 1
fi

cp "$START_SCRIPT" "$START_SCRIPT.bak"

python - "$START_SCRIPT" "$PROOT_BIN" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
proot = sys.argv[2]
text = path.read_text()

# Replace the launcher command without changing the Kali-side PATH.
text = text.replace('exec proot "${PROOT_ARGS[@]}" /bin/bash --login "$@"',
                    'exec "$PROOT_BIN" "${PROOT_ARGS[@]}" /bin/bash --login "$@"')

# Insert a stable Termux proot path before PROOT_ARGS if the launcher has not
# already been patched.
if 'PROOT_BIN=' not in text:
    marker = 'PROOT_ARGS=(--link2symlink'
    replacement = 'PROOT_BIN="${PREFIX:-/data/data/com.termux/files/usr}/bin/proot"\n[[ -x "$PROOT_BIN" ]] || { echo "proot is not installed. Run: pkg install proot" >&2; exit 1; }\n' + marker
    text = text.replace(marker, replacement, 1)

path.write_text(text)
PY

chmod 700 "$START_SCRIPT"

echo "[OK] Termo-Kali launcher fixed."
echo "[OK] proot: $PROOT_BIN"
echo "[OK] Backup: $START_SCRIPT.bak"
echo "Run: ~/start-kali.sh"
