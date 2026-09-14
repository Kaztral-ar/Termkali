#!/data/data/com.termux/files/usr/bin/bash
# Termo-Kali - Kali Linux installer for Termux / Android
# Rootless PRoot environment with safe installation, repair, diagnostics and launcher tools.

set -Eeuo pipefail

readonly APP_NAME="Termo-Kali"
readonly KALI_HOME="$HOME"
readonly ROOTFS="$KALI_HOME/kali-fs"
readonly BINDS="$KALI_HOME/kali-binds"
readonly START_SCRIPT="$KALI_HOME/start-kali.sh"
readonly HELP_FILE="$KALI_HOME/kali-help.txt"
readonly STATE_DIR="$KALI_HOME/.termo-kali"
readonly LOGFILE="$STATE_DIR/install.log"
readonly LOCKFILE="$STATE_DIR/lock"
readonly MIN_FREE_MB=2048
readonly ROOTFS_BASE_URL="${KALI_ROOTFS_BASE_URL:-https://raw.githubusercontent.com/EXALAB/AnLinux-Resources/master/Rootfs/Kali}"

readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[1;36m'
readonly WHITE='\033[1;37m'
readonly RESET='\033[0m'

LOCK_HELD=0
TMP_DIR=""

mkdir -p "$STATE_DIR"
touch "$LOGFILE"

log_info(){ printf '%b[INFO]%b %s\n' "$CYAN" "$RESET" "$*"; }
log_ok(){ printf '%b[OK]%b %s\n' "$GREEN" "$RESET" "$*"; }
log_warn(){ printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$*"; }
log_err(){ printf '%b[ERROR]%b %s\n' "$RED" "$RESET" "$*" >&2; }
log_file(){ printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"; }
fail(){ local code="$1"; shift; log_err "$*"; log_file "FATAL[$code]: $*"; return "$code"; }

cleanup(){
  local code="${1:-0}"
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
  if (( LOCK_HELD )); then rm -f "$LOCKFILE" 2>/dev/null || true; LOCK_HELD=0; fi
  if (( code != 0 )); then
    log_err "Operation failed with exit code $code."
    log_warn "Log: $LOGFILE"
  fi
}
on_exit(){ local code=$?; trap - EXIT; cleanup "$code"; exit "$code"; }
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

banner(){
  clear 2>/dev/null || true
  printf '\n%b============================================================%b\n' "$YELLOW" "$RESET"
  printf '%b                         TERMO-KALI%b\n' "$WHITE" "$RESET"
  printf '%b============================================================%b\n' "$YELLOW" "$RESET"
  printf '%b              Kali Linux for Termux / Android%b\n' "$CYAN" "$RESET"
  printf '%b                     Rootless • PRoot%b\n' "$CYAN" "$RESET"
  printf '%b============================================================%b\n\n' "$YELLOW" "$RESET"
}

require_termux(){
  [[ -d /data/data/com.termux ]] || { fail 10 "Run this installer inside Termux."; return 10; }
  command -v pkg >/dev/null 2>&1 || { fail 10 "Termux package manager 'pkg' was not found."; return 10; }
}

acquire_lock(){
  mkdir -p "$STATE_DIR"
  if [[ -f "$LOCKFILE" ]]; then
    local pid
    pid=$(cat "$LOCKFILE" 2>/dev/null || true)
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      fail 11 "Another Termo-Kali process is already running (PID $pid)."
      return 11
    fi
    rm -f "$LOCKFILE"
  fi
  printf '%s\n' "$$" > "$LOCKFILE"
  LOCK_HELD=1
}

check_disk_space(){
  local free_mb
  free_mb=$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2 {print $4}') || true
  if [[ ! "$free_mb" =~ ^[0-9]+$ ]]; then
    log_warn "Could not determine free storage; continuing."
    return 0
  fi
  if (( free_mb < MIN_FREE_MB )); then
    fail 12 "Only ${free_mb}MB free. At least ${MIN_FREE_MB}MB is recommended for the base installation."
    return 12
  fi
  log_ok "Storage available: ${free_mb}MB."
}

install_dependencies(){
  local required=(wget proot tar xz-utils) missing=() item
  for item in "${required[@]}"; do
    if [[ "$item" == "xz-utils" ]]; then
      command -v xz >/dev/null 2>&1 || missing+=("xz-utils")
    else
      command -v "$item" >/dev/null 2>&1 || missing+=("$item")
    fi
  done
  if ((${#missing[@]} == 0)); then log_ok "Termux dependencies are ready."; return 0; fi
  log_info "Installing Termux dependencies: ${missing[*]}"
  pkg update -y >>"$LOGFILE" 2>&1 || { fail 13 "Termux package index update failed."; return 13; }
  pkg install -y "${missing[@]}" >>"$LOGFILE" 2>&1 || { fail 13 "Failed to install required Termux packages."; return 13; }
  log_ok "Termux dependencies installed."
}

get_arch(){
  case "$(dpkg --print-architecture 2>/dev/null || true)" in
    aarch64|arm64) printf 'arm64\n' ;;
    arm|armhf) printf 'armhf\n' ;;
    amd64|x86_64) printf 'amd64\n' ;;
    i386|i686|x86) printf 'i386\n' ;;
    *) return 1 ;;
  esac
}

rootfs_url(){ printf '%s/%s/kali-rootfs-%s.tar.xz\n' "$ROOTFS_BASE_URL" "$1" "$1"; }

download_rootfs(){
  local arch="$1" dest="$2" url attempt
  url="$(rootfs_url "$arch")"
  log_info "Downloading Kali ${arch} rootfs..."
  log_file "Rootfs URL: $url"
  for attempt in 1 2 3; do
    rm -f "$dest"
    log_info "Download attempt ${attempt}/3"
    if wget --timeout=30 --tries=1 --show-progress -O "$dest" "$url" >>"$LOGFILE" 2>&1 && [[ -s "$dest" ]]; then return 0; fi
    log_warn "Download attempt ${attempt}/3 failed."
    sleep 2
  done
  fail 15 "Unable to download the Kali rootfs. Check your network or set KALI_ROOTFS_BASE_URL."
  return 15
}

extract_rootfs(){
  local archive="$1" staging="$ROOTFS.new"
  log_info "Validating rootfs archive..."
  tar -tJf "$archive" >/dev/null 2>>"$LOGFILE" || { fail 16 "The downloaded Kali rootfs is corrupted or invalid."; return 16; }
  rm -rf "$staging"; mkdir -p "$staging"
  log_info "Extracting Kali rootfs. Please wait..."
  if ! proot --link2symlink tar -xJf "$archive" -C "$staging" >>"$LOGFILE" 2>&1; then
    rm -rf "$staging"; fail 16 "Rootfs extraction failed."; return 16
  fi
  [[ -x "$staging/bin/bash" && -f "$staging/etc/os-release" ]] || { rm -rf "$staging"; fail 16 "The extracted rootfs is incomplete."; return 16; }
  grep -q '^ID=kali' "$staging/etc/os-release" 2>/dev/null || { rm -rf "$staging"; fail 16 "The downloaded rootfs does not identify itself as Kali Linux."; return 16; }
  if [[ -d "$ROOTFS" ]]; then
    rm -rf "$ROOTFS.previous"
    mv "$ROOTFS" "$ROOTFS.previous"
  fi
  mv "$staging" "$ROOTFS"
  rm -rf "$ROOTFS.previous" 2>/dev/null || true
  log_ok "Kali rootfs extracted successfully."
}

configure_kali_sources(){
  [[ -d "$ROOTFS/etc/apt" ]] || return 0
  mkdir -p "$ROOTFS/etc/apt/sources.list.d"
  if [[ -f "$ROOTFS/usr/share/keyrings/kali-archive-keyring.gpg" ]]; then
    cat > "$ROOTFS/etc/apt/sources.list.d/kali.sources" <<'EOF2'
Types: deb
URIs: http://http.kali.org/kali/
Suites: kali-rolling
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/kali-archive-keyring.gpg
EOF2
    [[ -f "$ROOTFS/etc/apt/sources.list" ]] && mv "$ROOTFS/etc/apt/sources.list" "$ROOTFS/etc/apt/sources.list.termokali-backup"
    log_ok "Configured modern Kali APT sources."
  else
    cat > "$ROOTFS/etc/apt/sources.list" <<'EOF2'
deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
EOF2
    rm -f "$ROOTFS/etc/apt/sources.list.d/kali.sources"
    log_warn "Kali archive keyring not found; using legacy APT source format."
  fi
}

run_kali(){
  local command_string="$1"
  HOME=/root \
  USER=root \
  LOGNAME=root \
  PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games \
  TERM="${TERM:-xterm-256color}" \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8 \
  proot --link2symlink -0 \
    -r "$ROOTFS" \
    -b /dev \
    -b /proc \
    -b /sys \
    -b "$ROOTFS/root:/dev/shm" \
    -w /root \
    /bin/bash --login -c "$command_string"
}

create_launcher(){
  mkdir -p "$BINDS"
  cat > "$START_SCRIPT" <<'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail
cd "$(dirname "$0")"
unset LD_PRELOAD
ROOTFS="$HOME/kali-fs"
[[ -x "$ROOTFS/bin/bash" ]] || { echo "Kali rootfs is missing. Run ~/termo-kali.sh --repair or reinstall." >&2; exit 1; }
PROOT_ARGS=(--link2symlink -0 -r "$ROOTFS" -b /dev -b /proc -b /sys -b "$ROOTFS/root:/dev/shm" -w /root)
if [[ "${TERMO_KALI_SHARED_HOME:-0}" == "1" ]]; then PROOT_ARGS+=( -b "$HOME:/termux-home" ); fi
if command -v pulseaudio >/dev/null 2>&1; then pulseaudio --start >/dev/null 2>&1 || true; fi
HOME=/root \
USER=root \
LOGNAME=root \
PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games \
TERM="${TERM:-xterm-256color}" \
LANG=C.UTF-8 \
LC_ALL=C.UTF-8 \
exec proot "${PROOT_ARGS[@]}" /bin/bash --login "$@"
LAUNCHER
  chmod 700 "$START_SCRIPT"
  log_ok "Created launcher: $START_SCRIPT"
}

write_guest_helpers(){
  mkdir -p "$ROOTFS/usr/local/bin"
  cat > "$ROOTFS/usr/local/bin/termokali-info" <<'EOF2'
#!/bin/sh
printf 'Termo-Kali environment\n-----------------------\n'
if [ -f /etc/os-release ]; then . /etc/os-release; printf 'OS: %s\n' "${PRETTY_NAME:-${NAME:-Kali Linux}}"; fi
printf 'Architecture: %s\n' "$(dpkg --print-architecture 2>/dev/null || echo unknown)"
printf 'PRoot: rootless Android environment\n'
printf '\nUseful commands:\n  termokali-info\n  termokali-repair\n  kali-desktop (if installed)\n'
EOF2
  chmod +x "$ROOTFS/usr/local/bin/termokali-info"
  cat > "$ROOTFS/usr/local/bin/termokali-repair" <<'EOF2'
#!/bin/sh
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
if [ ! -x /usr/share/debconf/frontend ]; then
  tmp=$(mktemp -d)
  cd "$tmp"
  apt-get download debconf
  dpkg --unpack ./debconf_*.deb
  cd /
  rm -rf "$tmp"
fi
dpkg --configure -a
apt-get -f install -y
apt-get update
printf '\nTermo-Kali package repair completed.\n'
EOF2
  chmod +x "$ROOTFS/usr/local/bin/termokali-repair"
}

repair_kali(){
  require_termux || return $?
  [[ -x "$ROOTFS/bin/bash" ]] || { fail 20 "Kali is not installed. Run the installer first."; return 20; }
  configure_kali_sources; write_guest_helpers
  log_info "Repairing Kali package state..."
  run_kali '
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
if [ ! -x /usr/share/debconf/frontend ]; then
  echo "[INFO] debconf frontend is missing; bootstrapping debconf package..."
  tmp=$(mktemp -d); cd "$tmp"; apt-get download debconf; dpkg --unpack ./debconf_*.deb; cd /; rm -rf "$tmp"
fi
dpkg --configure -a
apt-get -f install -y
apt-get update
'
  log_ok "Kali package state repaired."
}

status(){
  if [[ -x "$ROOTFS/bin/bash" && -f "$ROOTFS/etc/os-release" ]]; then
    local name version termux_arch
    name=$(awk -F= '$1=="PRETTY_NAME" {gsub(/"/,"",$2); print $2}' "$ROOTFS/etc/os-release" 2>/dev/null || true)
    version=$(awk -F= '$1=="VERSION_ID" {gsub(/"/,"",$2); print $2}' "$ROOTFS/etc/os-release" 2>/dev/null || true)
    termux_arch=$(dpkg --print-architecture 2>/dev/null || echo unknown)
    log_ok "Installed: ${name:-Kali Linux} ${version:-}"
    log_info "Termux architecture: $termux_arch"
    log_info "Rootfs: $ROOTFS"
    [[ -x "$START_SCRIPT" ]] && log_info "Launcher: $START_SCRIPT" || log_warn "Launcher is missing. Run ./termo-kali.sh --repair."
    return 0
  fi
  log_warn "Kali is not installed."
  return 1
}

doctor(){
  banner
  local bad=0 value
  printf '%bTermo-Kali diagnostics%b\n\n' "$WHITE" "$RESET"
  if [[ -d /data/data/com.termux ]]; then log_ok "Termux environment detected"; else log_err "Not running in Termux"; bad=1; fi
  for value in pkg proot tar xz wget; do
    if command -v "$value" >/dev/null 2>&1; then log_ok "$value: available"; else log_warn "$value: missing"; bad=1; fi
  done
  if [[ -d "$ROOTFS" ]]; then log_ok "Rootfs directory: present"; else log_warn "Rootfs directory: missing"; bad=1; fi
  [[ -x "$ROOTFS/bin/bash" ]] && log_ok "Kali /bin/bash: present" || { log_warn "Kali /bin/bash: missing"; bad=1; }
  [[ -x "$ROOTFS/usr/bin/dpkg" ]] && log_ok "Kali dpkg: present" || { log_warn "Kali dpkg: missing"; bad=1; }
  [[ -x "$ROOTFS/usr/bin/env" ]] && log_ok "Kali /usr/bin/env: present" || log_warn "Kali /usr/bin/env: missing (launcher does not depend on it)"
  [[ -x "$START_SCRIPT" ]] && log_ok "Launcher: present" || { log_warn "Launcher: missing"; bad=1; }
  if [[ -f "$ROOTFS/etc/os-release" ]]; then
    value=$(awk -F= '$1=="PRETTY_NAME" {gsub(/"/,"",$2); print $2}' "$ROOTFS/etc/os-release" 2>/dev/null || true)
    log_info "Kali release: ${value:-unknown}"
  fi
  if [[ -f "$ROOTFS/usr/share/debconf/frontend" ]]; then log_ok "debconf frontend: present"; else log_warn "debconf frontend: missing; run ./termo-kali.sh --repair"; bad=1; fi
  if [[ -f "$ROOTFS/var/lib/dpkg/status" ]]; then log_ok "dpkg database: present"; else log_warn "dpkg database: missing"; bad=1; fi
  if [[ -f "$ROOTFS/etc/apt/sources.list.d/kali.sources" ]]; then log_ok "Kali modern APT source: present"; elif [[ -f "$ROOTFS/etc/apt/sources.list" ]]; then log_ok "Kali legacy APT source: present"; else log_warn "Kali APT source: missing"; bad=1; fi
  value=$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2 {print $4}') || true
  [[ "$value" =~ ^[0-9]+$ ]] && log_info "Free storage: ${value}MB"
  printf '\n'
  if (( bad == 0 )); then log_ok "Diagnostics completed: no blocking issue detected."; else log_warn "Diagnostics found one or more issues. Check the messages above and the log: $LOGFILE"; fi
  return 0
}

write_help(){
  cat > "$HELP_FILE" <<EOF2
$APP_NAME

Base commands:
  ./termo-kali.sh             Install or refresh Kali
  ./termo-kali.sh --status    Show installation status
  ./termo-kali.sh --doctor    Diagnose common problems
  ./termo-kali.sh --repair    Repair APT/dpkg and refresh helpers
  ./termo-kali.sh --help      Show this help

Kali:
  ~/start-kali.sh
  termokali-info
  termokali-repair

Desktop:
  ./termo-kali-desktop.sh install
  ./termo-kali-desktop.sh start

Log:
  $LOGFILE
EOF2
}

install_kali(){
  require_termux || return $?
  acquire_lock
  check_disk_space || return $?
  install_dependencies || return $?
  local arch archive
  arch=$(get_arch) || { fail 14 "Unsupported Termux architecture: $(dpkg --print-architecture 2>/dev/null || echo unknown)."; return 14; }
  log_info "Detected architecture: $arch"
  TMP_DIR=$(mktemp -d "$STATE_DIR/tmp.XXXXXX")
  archive="$TMP_DIR/kali-rootfs-${arch}.tar.xz"
  if [[ -x "$ROOTFS/bin/bash" && -f "$ROOTFS/etc/os-release" ]]; then
    log_ok "Existing Kali rootfs detected; preserving it."
  else
    download_rootfs "$arch" "$archive" || return $?
    extract_rootfs "$archive" || return $?
  fi
  configure_kali_sources
  write_guest_helpers
  create_launcher
  write_help
  log_ok "Kali Linux installation completed successfully."
  log_info "Start Kali with: $START_SCRIPT"
  log_info "Run diagnostics with: $0 --doctor"
}

show_help(){
  cat <<'EOF2'
Termo-Kali - Kali Linux for Termux / Android

Usage:
  ./termo-kali.sh                 Install or refresh Kali
  ./termo-kali.sh --status        Show installation status
  ./termo-kali.sh --doctor        Diagnose common issues
  ./termo-kali.sh --repair        Repair APT/dpkg state
  ./termo-kali.sh --help          Show help

Environment:
  KALI_ROOTFS_BASE_URL=...        Override the rootfs download base URL
  TERMO_KALI_SHARED_HOME=1        Bind Termux home as /termux-home inside Kali
EOF2
}

main(){
  case "${1:-install}" in
    install|--install) banner; install_kali ;;
    --repair|repair) repair_kali ;;
    --status|status) status ;;
    --doctor|doctor) doctor ;;
    --help|-h|help) show_help ;;
    *) log_err "Unknown option: $1"; show_help; return 2 ;;
  esac
}

main "$@"
