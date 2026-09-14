#!/data/data/com.termux/files/usr/bin/bash
# Termo-Kali — Kali Linux installer for Termux
# Reliable banner rendering + correct Termux paths + readable logging.

set -Eeuo pipefail

readonly KALI_HOME="$HOME"
readonly STATE_DIR="$HOME/.termo-kali"
readonly LOGFILE="$STATE_DIR/install.log"
readonly LOCKFILE="$STATE_DIR/lock"
readonly HELP_FILE="$HOME/kali-help.txt"
readonly START_SCRIPT="$KALI_HOME/start-kali.sh"
readonly KALI_INSTALLER_URL="https://raw.githubusercontent.com/EXALAB/AnLinux-Resources/master/Scripts/Installer/Kali/kali.sh"
readonly MIN_FREE_MB=2048

readonly REQUIRED_PKGS=(
  "bash:bash"
  "coreutils:"
  "curl:curl"
  "wget:wget"
  "proot:proot"
  "tar:tar"
  "xz-utils:xz"
  "openssl-tool:openssl"
  "bc:bc"
)

readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly PURPLE='\033[1;35m'
readonly CYAN='\033[1;36m'
readonly WHITE='\033[1;37m'
readonly RESET='\033[0m'

SPIN_PID=""
TMP_DIR=""

log_info(){ echo -e "${BLUE}[INFO]${RESET} $*"; }
log_ok(){ echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn(){ echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_err(){ echo -e "${RED}[ERROR]${RESET} $*" >&2; }
log_to_file(){ [[ -d "$STATE_DIR" ]] && printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"; }

die(){ local code="$1"; shift; log_err "$*"; log_to_file "FATAL: $*"; exit "$code"; }

# ASCII-only banner: avoids broken boxes/glyphs on Termux fonts/terminals.
display_banner(){
  clear 2>/dev/null || true
  printf '\n'
  printf '%b============================================================%b\n' "$YELLOW" "$RESET"
  printf '%b                    TERMO-KALI%b\n' "$WHITE" "$RESET"
  printf '%b============================================================%b\n' "$YELLOW" "$RESET"
  printf '%b      Advanced Kali Linux Installation for Termux%b\n' "$CYAN" "$RESET"
  printf '%b============================================================%b\n\n' "$YELLOW" "$RESET"
}

progress_spinner(){
  local message="$1"
  (
    while true; do
      printf '\r%b[+]%b %s' "$PURPLE" "$RESET" "$message"
      sleep 0.5
      printf '\r%b[. ]%b %s' "$PURPLE" "$RESET" "$message"
      sleep 0.5
    done
  ) &
  SPIN_PID=$!
}

stop_spinner(){
  if [[ -n "$SPIN_PID" ]]; then
    kill "$SPIN_PID" 2>/dev/null || true
    wait "$SPIN_PID" 2>/dev/null || true
    SPIN_PID=""
  fi
  printf '\r\033[K'
}

cleanup_and_exit(){
  local code=$?
  stop_spinner
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
  rm -f "$LOCKFILE" 2>/dev/null || true
  if (( code != 0 )); then
    log_err "Installation aborted (exit code $code)."
    [[ -f "$LOGFILE" ]] && log_warn "See $LOGFILE for details."
  fi
  exit "$code"
}
trap cleanup_and_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

require_termux(){
  [[ -d /data/data/com.termux ]] || die 10 "This script must be run inside Termux."
  command -v pkg >/dev/null 2>&1 || die 10 "Termux package manager (pkg) was not found."
}

acquire_lock(){
  mkdir -p "$STATE_DIR"
  if [[ -e "$LOCKFILE" ]]; then
    local pid=""
    pid=$(cat "$LOCKFILE" 2>/dev/null || true)
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      die 11 "Another instance is already running (pid $pid)."
    fi
    rm -f "$LOCKFILE"
  fi
  printf '%s\n' "$$" > "$LOCKFILE"
}

check_disk_space(){
  local free_mb
  free_mb=$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
  if [[ -z "$free_mb" ]]; then
    log_warn "Could not determine free disk space; continuing."
    return
  fi
  (( free_mb >= MIN_FREE_MB )) || die 12 "Only ${free_mb}MB free; at least ${MIN_FREE_MB}MB is recommended."
  log_ok "Disk space: ${free_mb}MB free."
}

pkg_is_installed(){
  local pkg="$1" bin="$2"
  [[ -n "$bin" ]] && command -v "$bin" >/dev/null 2>&1 && return 0
  command -v dpkg >/dev/null 2>&1 && dpkg -s "$pkg" >/dev/null 2>&1
}

check_dependencies(){
  progress_spinner "Checking Termux dependencies"
  local missing=() entry pkg bin
  for entry in "${REQUIRED_PKGS[@]}"; do
    pkg="${entry%%:*}"
    bin="${entry#*:}"
    pkg_is_installed "$pkg" "$bin" || missing+=("$pkg")
  done
  stop_spinner

  if ((${#missing[@]} == 0)); then
    log_ok "All dependencies are installed."
    return
  fi

  log_warn "Installing: ${missing[*]}"
  pkg update -y >> "$LOGFILE" 2>&1 || die 13 "pkg update failed."
  pkg install -y "${missing[@]}" >> "$LOGFILE" 2>&1 || die 13 "Dependency installation failed."

  local still_missing=()
  for entry in "${REQUIRED_PKGS[@]}"; do
    pkg="${entry%%:*}"
    bin="${entry#*:}"
    pkg_is_installed "$pkg" "$bin" || still_missing+=("$pkg")
  done
  ((${#still_missing[@]} == 0)) || die 13 "Still missing: ${still_missing[*]}"
  log_ok "Dependencies installed successfully."
}

check_network(){
  progress_spinner "Checking network connectivity"
  local ok=1
  if command -v curl >/dev/null 2>&1; then
    curl -fsSLI --connect-timeout 15 --max-time 20 "$KALI_INSTALLER_URL" >/dev/null 2>&1 || ok=0
  elif command -v wget >/dev/null 2>&1; then
    wget --spider --timeout=15 "$KALI_INSTALLER_URL" >/dev/null 2>&1 || ok=0
  else
    ok=0
  fi
  stop_spinner
  (( ok == 1 )) || die 14 "Cannot reach the Kali installer URL."
  log_ok "Network reachable."
}

download_file(){
  local url="$1" dest="$2" attempt
  for attempt in 1 2 3; do
    if command -v curl >/dev/null 2>&1 && curl -fsSL --connect-timeout 15 --max-time 180 -o "$dest" "$url" >> "$LOGFILE" 2>&1; then
      return 0
    fi
    if command -v wget >/dev/null 2>&1 && wget -q --timeout=15 -O "$dest" "$url" >> "$LOGFILE" 2>&1; then
      return 0
    fi
    log_warn "Download attempt $attempt/3 failed."
    sleep 2
  done
  return 1
}

validate_shell_script(){
  local file="$1"
  [[ -s "$file" ]] || return 1
  head -c 2048 "$file" 2>/dev/null | grep -qiE '<html|<!doctype' && return 1
  bash -n "$file" >> "$LOGFILE" 2>&1
}

install_kali(){
  if [[ -f "$START_SCRIPT" ]]; then
    chmod +x "$START_SCRIPT" 2>/dev/null || true
    log_ok "Kali launcher already exists: $START_SCRIPT"
    return
  fi

  check_network
  TMP_DIR=$(mktemp -d "$STATE_DIR/kali.XXXXXX") || die 15 "Could not create temporary directory."
  local kali_script="$TMP_DIR/kali.sh"

  progress_spinner "Downloading Kali installer"
  local ok=1
  download_file "$KALI_INSTALLER_URL" "$kali_script" || ok=0
  stop_spinner
  (( ok == 1 )) || die 15 "Failed to download Kali installer."

  validate_shell_script "$kali_script" || die 15 "Downloaded installer failed validation."
  log_ok "Installer downloaded and validated."

  progress_spinner "Installing Kali Linux (this may take several minutes)"
  local install_ok=1
  ( cd "$KALI_HOME" && bash "$kali_script" ) >> "$LOGFILE" 2>&1 || install_ok=0
  stop_spinner

  if (( install_ok != 1 )); then
    die 16 "Kali installer returned an error."
  fi
  [[ -f "$START_SCRIPT" ]] || die 16 "Kali installer finished but $START_SCRIPT was not created."

  chmod +x "$START_SCRIPT" || die 16 "Could not make $START_SCRIPT executable."
  log_ok "Kali installed: $START_SCRIPT"
}

write_help_file(){
  cat > "$HELP_FILE" <<EOF
TERMO-KALI QUICK REFERENCE

Start Kali:
  $START_SCRIPT

If permission is denied:
  chmod +x "$START_SCRIPT"
  "$START_SCRIPT"

Exit Kali:
  exit

Installer log:
  $LOGFILE

Optional XFCE4 desktop:
  See termo.txt in the repository.

Kali documentation:
  https://www.kali.org/docs/
EOF
  log_ok "Wrote help file: $HELP_FILE"
}

prompt_launch(){
  local reply=""
  printf '%b[*]%b Launch Kali now? [Y/n]: ' "$PURPLE" "$RESET"
  IFS= read -r -t 10 reply || true
  echo
  case "${reply,,}" in
    n|no) log_info "Skipping launch. Run: $START_SCRIPT" ;;
    *) exec "$START_SCRIPT" ;;
  esac
}

main(){
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        printf 'Usage: %s [--help]\n' "$(basename "$0")"
        exit 0
        ;;
    esac
  done

  mkdir -p "$STATE_DIR"
  : > "$LOGFILE"
  display_banner
  require_termux
  acquire_lock
  check_disk_space
  log_info "Starting installation process..."
  check_dependencies
  install_kali
  write_help_file

  printf '\n%b============================================================%b\n' "$GREEN" "$RESET"
  printf '%b Installation complete!%b\n' "$GREEN" "$WHITE"
  printf ' Start Kali: %b%s%b\n' "$CYAN" "$START_SCRIPT" "$RESET"
  printf ' Help:       %bcat %s%b\n' "$CYAN" "$HELP_FILE" "$RESET"
  printf '%b============================================================%b\n\n' "$GREEN" "$RESET"

  prompt_launch
}

main "$@"
