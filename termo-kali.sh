#!/data/data/com.termux/files/usr/bin/bash
# Termo-Kali - Kali Linux installer for Termux / Android
# Rootless PRoot environment with safe installation, repair and launcher tools.
#
# Usage:
#   ./termo-kali.sh
#   ./termo-kali.sh --repair
#   ./termo-kali.sh --status
#   ./termo-kali.sh --help

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

SPIN_PID=""
TMP_DIR=""
LOCK_HELD=0

log_info(){ printf '%b[INFO]%b %s\n' "$CYAN" "$RESET" "$*"; }
log_ok(){ printf '%b[OK]%b %s\n' "$GREEN" "$RESET" "$*"; }
log_warn(){ printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$*"; }
log_err(){ printf '%b[ERROR]%b %s\n' "$RED" "$RESET" "$*" >&2; }
log_file(){ printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"; }

fail(){
  local code="$1"; shift
  log_err "$*"
  log_file "FATAL[$code]: $*"
  return "$code"
}

cleanup(){
  local code="${1:-0}"
  [[ -n "$SPIN_PID" ]] && kill "$SPIN_PID" 2>/dev/null || true
  [[ -n "$SPIN_PID" ]] && wait "$SPIN_PID" 2>/dev/null || true
  SPIN_PID=""
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
  if (( LOCK_HELD )); then
    rm -f "$LOCKFILE" 2>/dev/null || true
    LOCK_HELD=0
  fi
  if (( code != 0 )); then
    log_err "Operation failed with exit code $code."
    [[ -f "$LOGFILE" ]] && log_warn "Log: $LOGFILE"
  fi
}

on_exit(){
  local code=$?
  trap - EXIT
  cleanup "$code"
  exit "$code"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

banner(){
  clear 2>/dev/null || true
  printf '\n%b============================================================%b\n' "$YELLOW" "$RESET"
  printf '%b                    TERMO-KALI%b\n' "$WHITE" "$RESET"
  printf '%b============================================================%b\n' "$YELLOW" "$RESET"
  printf '%b       Kali Linux for Termux / Android - No Root%b\n' "$CYAN" "$RESET"
  printf '%b============================================================%b\n\n' "$YELLOW" "$RESET"
}

require_termux(){
  [[ -d /data/data/com.termux ]] || { fail 10 "Run this installer inside Termux."; return 10; }
  command -v pkg >/dev/null 2>&1 || { fail 10 "Termux package manager 'pkg' was not found."; return 10; }
  command -v proot >/dev/null 2>&1 || { log_info "PRoot is not installed yet; it will be installed automatically."; }
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
    fail 12 "Only ${free_mb}MB free. At least ${MIN_FREE_MB}MB is recommended for the base Kali installation." || true
    return 12
  fi
  log_ok "Storage available: ${free_mb}MB."
}

install_dependencies(){
  local required=(wget proot tar xz-utils)
  local missing=()
  local item

  for item in "${required[@]}"; do
    if [[ "$item" == "xz-utils" ]]; then
      command -v xz >/dev/null 2>&1 || missing+=("xz-utils")
    else
      command -v "$item" >/dev/null 2>&1 || missing+=("$item")
    fi
  done

  if ((${#missing[@]} == 0)); then
    log_ok "Termux dependencies are ready."
    return 0
  fi

  log_info "Installing Termux dependencies: ${missing[*]}"
  if ! pkg update -y >>"$LOGFILE" 2>&1; then
    fail 13 "Termux package index update failed. Check your Termux mirror/network."
    return 13
  fi
  if ! pkg install -y "${missing[@]}" >>"$LOGFILE" 2>&1; then
    fail 13 "Failed to install required Termux packages."
    return 13
  fi
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

rootfs_url(){
  printf '%s/%s/kali-rootfs-%s.tar.xz\n' "$ROOTFS_BASE_URL" "$1" "$1"
}

download_rootfs(){
  local arch="$1" dest="$2" url attempt
  url="$(rootfs_url "$arch")"
  log_info "Downloading Kali ${arch} rootfs..."
  log_file "Rootfs URL: $url"

  for attempt in 1 2 3; do
    rm -f "$dest"
    log_info "Download attempt ${attempt}/3"
    if wget --timeout=30 --tries=1 --show-progress -O "$dest" "$url" >>"$LOGFILE" 2>&1 && [[ -s "$dest" ]]; then
      return 0
    fi
    log_warn "Download attempt ${attempt}/3 failed."
    sleep 2
  done

  fail 15 "Unable to download the Kali rootfs. Check your network or set KALI_ROOTFS_BASE_URL."
  return 15
}

extract_rootfs(){
  local archive="$1"
  local staging="$ROOTFS.new"

  log_info "Validating rootfs archive..."
  if ! tar -tJf "$archive" >/dev/null 2>>"$LOGFILE"; then
    fail 16 "The downloaded Kali rootfs is corrupted or invalid."
    return 16
  fi

  rm -rf "$staging"
  mkdir -p "$staging"
  log_info "Extracting Kali rootfs. Please wait..."

  if ! proot --link2symlink tar -xJf "$archive" -C "$staging" >>"$LOGFILE" 2>&1; then
    rm -rf "$staging"
    fail 16 "Rootfs extraction failed."
    return 16
  fi

  if [[ ! -x "$staging/bin/bash" || ! -f "$staging/etc/os-release" ]]; then
    rm -rf "$staging"
    fail 16 "The extracted rootfs is incomplete. /bin/bash or /etc/os-release is missing."
    return 16
  fi

  if ! grep -q '^ID=kali' "$staging/etc/os-release" 2>/dev/null; then
    rm -rf "$staging"
    fail 16 "The downloaded rootfs does not identify itself as Kali Linux."
    return 16
  fi

  rm -rf "$ROOTFS"
  mv "$staging" "$ROOTFS"
  log_ok "Kali rootfs extracted successfully."
}

configure_kali_sources(){
  [[ -d "$ROOTFS/etc/apt" ]] || return 0
  mkdir -p "$ROOTFS/etc/apt/sources.list.d"

  # Kali 2026.2+ uses kali.sources with Signed-By. Keep a legacy fallback
  # for older/minimal rootfs images where the archive keyring is unavailable.
  if [[ -f "$ROOTFS/usr/share/keyrings/kali-archive-keyring.gpg" ]]; then
    cat > "$ROOTFS/etc/apt/sources.list.d/kali.sources" <<'EOF'
Types: deb
URIs: http://http.kali.org/kali/
Suites: kali-rolling
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/kali-archive-keyring.gpg
EOF
    if [[ -f "$ROOTFS/etc/apt/sources.list" ]]; then
      mv "$ROOTFS/etc/apt/sources.list" "$ROOTFS/etc/apt/sources.list.termokali-backup"
    fi
    log_ok "Configured modern Kali APT sources."
  else
    cat > "$ROOTFS/etc/apt/sources.list" <<'EOF'
deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware
EOF
    rm -f "$ROOTFS/etc/apt/sources.list.d/kali.sources"
    log_warn "Kali archive keyring not found; using the legacy repository format."
  fi
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

PROOT_ARGS=(
  --link2symlink
  -0
  -r "$ROOTFS"
  -b /dev
  -b /proc
  -b /sys
  -b "$ROOTFS/root:/dev/shm"
  -w /root
)

# Bind Termux home only when explicitly requested by the user.
if [[ "${TERMO_KALI_SHARED_HOME:-0}" == "1" ]]; then
  PROOT_ARGS+=( -b "$HOME:/termux-home" )
fi

if command -v pulseaudio >/dev/null 2>&1; then
  pulseaudio --start >/dev/null 2>&1 || true
fi

exec proot "${PROOT_ARGS[@]}" \
  /usr/bin/env -i \
  HOME=/root \
  USER=root \
  LOGNAME=root \
  PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games \
  TERM="${TERM:-xterm-256color}" \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8 \
  /bin/bash --login "$@"
LAUNCHER

  chmod 700 "$START_SCRIPT"
  log_ok "Created launcher: $START_SCRIPT"
}

write_guest_helpers(){
  mkdir -p "$ROOTFS/usr/local/bin"

  cat > "$ROOTFS/usr/local/bin/termokali-info" <<'EOF'
#!/bin/sh
printf 'Termo-Kali environment\n'
printf '%s\n' '-----------------------'
if [ -f /etc/os-release ]; then
  . /etc/os-release
  printf 'OS: %s\n' "${PRETTY_NAME:-${NAME:-Kali Linux}}"
  printf 'Architecture: %s\n' "$(dpkg --print-architecture 2>/dev/null || echo unknown)"
fi
printf 'PRoot: rootless Android environment\n'
printf '\nUseful commands:\n'
printf '  termokali-repair   Repair APT/dpkg issues\n'
printf '  kali-desktop       Desktop controls (if installed)\n'
EOF
  chmod +x "$ROOTFS/usr/local/bin/termokali-info"

  cat > "$ROOTFS/usr/local/bin/termokali-repair" <<'EOF'
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
printf '\nTermo-Kali package repair completed.\n'
EOF
  chmod +x "$ROOTFS/usr/local/bin/termokali-repair"
}

repair_kali(){
  require_termux || return $?
  [[ -x "$ROOTFS/bin/bash" ]] || { fail 20 "Kali is not installed. Run the installer first."; return 20; }

  configure_kali_sources
  write_guest_helpers
  log_info "Repairing Kali package state..."

  proot --link2symlink -0 \
    -r "$ROOTFS" \
    -b /dev -b /proc -b /sys \
    -b "$ROOTFS/root:/dev/shm" \
    -w /root \
    /usr/bin/env -i \
    HOME=/root USER=root LOGNAME=root \
    PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin \
    TERM="${TERM:-xterm-256color}" LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    DEBIAN_FRONTEND=noninteractive \
    /bin/bash --login -c '
set -e
apt-get update
if [ ! -x /usr/share/debconf/frontend ]; then
  echo "[INFO] debconf frontend is missing; bootstrapping debconf package..."
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
'

  log_ok "Kali package state repaired."
}

status(){
  if [[ -x "$ROOTFS/bin/bash" && -f "$ROOTFS/etc/os-release" ]]; then
    local name version arch
    name=$(awk -F= '$1=="PRETTY_NAME" {gsub(/"/,"",$2); print $2}' "$ROOTFS/etc/os-release" 2>/dev/null || echo "Kali Linux")
    version=$(awk -F= '$1=="VERSION_ID" {gsub(/"/,"",$2); print $2}' "$ROOTFS/etc/os-release" 2>/dev/null || echo unknown)
    arch=$(dpkg --print-architecture 2>/dev/null || echo unknown)
    log_ok "Installed: ${name:-Kali Linux} ${version:-}"
    log_info "Termux architecture: $arch"
    log_info "Rootfs: $ROOTFS"
    log_info "Launcher: $START_SCRIPT"
    return 0
  fi
  log_warn "Kali is not installed."
  return 1
}

write_help(){
  cat > "$HELP_FILE" <<EOF
TERMO-KALI QUICK REFERENCE

Start Kali:
  ~/start-kali.sh

Verify Kali:
  termokali-info
  cat /etc/os-release

Repair APT/dpkg:
  ~/termo-kali.sh --repair
  OR inside Kali: termokali-repair

Shared Termux home (optional):
  TERMO_KALI_SHARED_HOME=1 ~/start-kali.sh
  Then access it at /termux-home inside Kali.

Desktop (if installed):
  ~/termo-kali-desktop.sh install
  ~/termo-kali-desktop.sh start

Installer log:
  $LOGFILE

Kali rootfs:
  $ROOTFS
EOF
  log_ok "Wrote help file: $HELP_FILE"
}

install_kali(){
  if [[ -x "$ROOTFS/bin/bash" && -f "$ROOTFS/etc/os-release" ]]; then
    log_ok "Existing Kali rootfs detected; skipping re-download."
    configure_kali_sources
    write_guest_helpers
    create_launcher
    return 0
  fi

  if [[ -e "$ROOTFS" ]]; then
    log_warn "Removing incomplete Kali rootfs."
    rm -rf "$ROOTFS"
  fi

  local arch archive
  arch=$(get_arch) || { fail 14 "Unsupported Termux architecture."; return 14; }
  TMP_DIR=$(mktemp -d "$STATE_DIR/install.XXXXXX") || { fail 15 "Unable to create temporary directory."; return 15; }
  archive="$TMP_DIR/kali-rootfs-${arch}.tar.xz"

  download_rootfs "$arch" "$archive" || return $?
  extract_rootfs "$archive" || return $?
  configure_kali_sources
  write_guest_helpers
  create_launcher

  log_ok "Kali Linux installation completed successfully."
}

main(){
  mkdir -p "$STATE_DIR"
  touch "$LOGFILE"

  case "${1:-install}" in
    --help|-h)
      cat <<'HELP'
Termo-Kali

Usage:
  ./termo-kali.sh             Install or repair the base environment
  ./termo-kali.sh --repair    Repair Kali APT/dpkg and refresh repositories
  ./termo-kali.sh --status    Show installation status
  ./termo-kali.sh --help      Show this help

Environment:
  KALI_ROOTFS_BASE_URL=...    Override the Kali rootfs mirror/base URL
  TERMO_KALI_SHARED_HOME=1    Share Termux home when launching Kali
HELP
      ;;
    --status)
      status
      ;;
    --repair)
      banner
      acquire_lock || return $?
      repair_kali || return $?
      ;;
    install)
      banner
      require_termux || return $?
      acquire_lock || return $?
      check_disk_space || return $?
      install_dependencies || return $?
      install_kali || return $?
      write_help || return $?
      printf '\n%b============================================================%b\n' "$GREEN" "$RESET"
      printf '%b Installation complete!%b\n' "$GREEN" "$RESET"
      printf ' Start Kali: %b%s%b\n' "$CYAN" "$START_SCRIPT" "$RESET"
      printf ' Help:       %bcat %s%b\n' "$CYAN" "$HELP_FILE" "$RESET"
      printf '%b============================================================%b\n\n' "$GREEN" "$RESET"
      printf '%b[*]%b Launch Kali now? [Y/n]: ' "$CYAN" "$RESET"
      local reply=""
      IFS= read -r reply || true
      case "${reply,,}" in
        n|no) log_info "Run ~/start-kali.sh when ready." ;;
        *) exec "$START_SCRIPT" ;;
      esac
      ;;
    *)
      fail 2 "Unknown option: $1. Use --help."
      return 2
      ;;
  esac
}

main "$@"
