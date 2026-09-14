#!/data/data/com.termux/files/usr/bin/bash
#
# Termo-Kali — Kali Linux installer for Termux
# Reliable rootfs installation, Termux-safe paths, ASCII UI and useful errors.
#
set -Eeuo pipefail

readonly KALI_HOME="$HOME"
readonly KALI_ROOTFS="$KALI_HOME/kali-fs"
readonly KALI_BINDS="$KALI_HOME/kali-binds"
readonly START_SCRIPT="$KALI_HOME/start-kali.sh"
readonly HELP_FILE="$KALI_HOME/kali-help.txt"
readonly STATE_DIR="$KALI_HOME/.termo-kali"
readonly LOGFILE="$STATE_DIR/install.log"
readonly LOCKFILE="$STATE_DIR/lock"
readonly MIN_FREE_MB=2048
readonly ROOTFS_BASE_URL="https://raw.githubusercontent.com/EXALAB/AnLinux-Resources/master/Rootfs/Kali"

readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[1;36m'
readonly WHITE='\033[1;37m'
readonly RESET='\033[0m'

SPIN_PID=""
TMP_DIR=""

log_info(){ printf '%b[INFO]%b %s\n' "$CYAN" "$RESET" "$*"; }
log_ok(){ printf '%b[OK]%b %s\n' "$GREEN" "$RESET" "$*"; }
log_warn(){ printf '%b[WARN]%b %s\n' "$YELLOW" "$RESET" "$*"; }
log_err(){ printf '%b[ERROR]%b %s\n' "$RED" "$RESET" "$*" >&2; }
log_file(){ printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOGFILE"; }

die(){
  local code="$1"
  shift
  log_err "$*"
  log_file "FATAL: $*"
  return "$code"
}

display_banner(){
  clear 2>/dev/null || true
  printf '\n'
  printf '%b============================================================%b\n' "$YELLOW" "$RESET"
  printf '%b                    TERMO-KALI%b\n' "$WHITE" "$RESET"
  printf '%b============================================================%b\n' "$YELLOW" "$RESET"
  printf '%b       Advanced Kali Linux Installation for Termux%b\n' "$CYAN" "$RESET"
  printf '%b============================================================%b\n\n' "$YELLOW" "$RESET"
}

progress_spinner(){
  local message="$1"
  (
    while :; do
      printf '\r%b[+]%b %s' "$CYAN" "$RESET" "$message"
      sleep 0.5
      printf '\r%b[.]%b %s' "$CYAN" "$RESET" "$message"
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

cleanup(){
  local code="$1"
  stop_spinner
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
  rm -f "$LOCKFILE" 2>/dev/null || true
  if (( code != 0 )); then
    log_err "Installation aborted (exit code $code)."
    [[ -f "$LOGFILE" ]] && log_warn "See $LOGFILE for details."
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

require_termux(){
  [[ -d /data/data/com.termux ]] || { die 10 "This script must be run inside Termux."; return 10; }
  command -v pkg >/dev/null 2>&1 || { die 10 "Termux package manager (pkg) was not found."; return 10; }
}

acquire_lock(){
  mkdir -p "$STATE_DIR"
  if [[ -e "$LOCKFILE" ]]; then
    local pid=""
    pid=$(cat "$LOCKFILE" 2>/dev/null || true)
    if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
      die 11 "Another Termo-Kali installation is already running (pid $pid)."
      return 11
    fi
    rm -f "$LOCKFILE"
  fi
  printf '%s\n' "$$" > "$LOCKFILE"
}

check_disk_space(){
  local free_mb
  free_mb=$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2{print $4}') || true
  if [[ ! "$free_mb" =~ ^[0-9]+$ ]]; then
    log_warn "Could not determine free disk space; continuing."
    return 0
  fi
  if (( free_mb < MIN_FREE_MB )); then
    die 12 "Only ${free_mb}MB free; at least ${MIN_FREE_MB}MB is recommended for Kali."
    return 12
  fi
  log_ok "Disk space: ${free_mb}MB free."
}

install_dependencies(){
  local required=(wget proot tar xz-utils)
  local missing=()
  local pkg
  for pkg in "${required[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done

  if ((${#missing[@]} == 0)); then
    log_ok "Required Termux packages are installed."
    return 0
  fi

  log_info "Installing required packages: ${missing[*]}"
  if ! pkg update -y >>"$LOGFILE" 2>&1; then
    die 13 "Termux package index update failed. Check your Termux repository/mirror."
    return 13
  fi
  if ! pkg install -y "${missing[@]}" >>"$LOGFILE" 2>&1; then
    die 13 "Failed to install required Termux packages. See $LOGFILE."
    return 13
  fi
  log_ok "Required packages installed."
}

get_arch(){
  local arch
  arch=$(dpkg --print-architecture 2>/dev/null || true)
  case "$arch" in
    aarch64|arm64) printf 'arm64\n' ;;
    arm|armhf) printf 'armhf\n' ;;
    amd64|x86_64) printf 'amd64\n' ;;
    i386|i686|x86) printf 'i386\n' ;;
    *) return 1 ;;
  esac
}

download_rootfs(){
  local arch="$1"
  local dest="$2"
  local url="${ROOTFS_BASE_URL}/${arch}/kali-rootfs-${arch}.tar.xz"
  local attempt

  log_info "Downloading Kali rootfs for ${arch}. This can take a while."
  log_file "Rootfs URL: $url"

  for attempt in 1 2 3; do
    rm -f "$dest"
    if command -v wget >/dev/null 2>&1; then
      if wget --show-progress --timeout=30 --tries=1 -O "$dest" "$url" >>"$LOGFILE" 2>&1; then
        [[ -s "$dest" ]] && return 0
      fi
    elif command -v curl >/dev/null 2>&1; then
      if curl -fL --connect-timeout 20 --max-time 1800 -o "$dest" "$url" >>"$LOGFILE" 2>&1; then
        [[ -s "$dest" ]] && return 0
      fi
    fi
    log_warn "Rootfs download attempt ${attempt}/3 failed."
    sleep 2
  done

  die 15 "Could not download the Kali rootfs. Check $LOGFILE for the HTTP/network error."
  return 15
}

extract_rootfs(){
  local archive="$1"

  log_info "Validating Kali rootfs archive..."
  if ! tar -tJf "$archive" >/dev/null 2>>"$LOGFILE"; then
    die 15 "Downloaded Kali rootfs is corrupted or invalid."
    return 15
  fi

  rm -rf "$KALI_ROOTFS.new"
  mkdir -p "$KALI_ROOTFS.new"

  log_info "Extracting Kali rootfs. Please wait..."
  if ! proot --link2symlink tar -xJf "$archive" -C "$KALI_ROOTFS.new" >>"$LOGFILE" 2>&1; then
    rm -rf "$KALI_ROOTFS.new"
    die 16 "Kali rootfs extraction failed. See $LOGFILE."
    return 16
  fi

  if [[ ! -x "$KALI_ROOTFS.new/bin/bash" ]]; then
    rm -rf "$KALI_ROOTFS.new"
    die 16 "Rootfs extraction completed but /bin/bash was not found."
    return 16
  fi

  rm -rf "$KALI_ROOTFS"
  mv "$KALI_ROOTFS.new" "$KALI_ROOTFS"
  log_ok "Kali rootfs extracted successfully."
}

create_launcher(){
  mkdir -p "$KALI_BINDS"

  cat > "$START_SCRIPT" <<'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
set -e
cd "$(dirname "$0")"
unset LD_PRELOAD

if command -v pulseaudio >/dev/null 2>&1; then
  pulseaudio --start >/dev/null 2>&1 || true
fi

exec proot --link2symlink -0 \
  -r "$HOME/kali-fs" \
  -b /dev \
  -b /proc \
  -b "$HOME/kali-fs/root:/dev/shm" \
  -w /root \
  /usr/bin/env -i \
  HOME=/root \
  PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games \
  TERM="${TERM:-xterm-256color}" \
  LANG=C.UTF-8 \
  /bin/bash --login "$@"
LAUNCHER

  chmod +x "$START_SCRIPT"
  log_ok "Created launcher: $START_SCRIPT"
}

configure_optional_audio(){
  # Audio is optional. The old AnLinux installer made PulseAudio configuration
  # part of the critical install path, which could make the entire installation
  # fail even when the Kali rootfs was valid. Termo-Kali deliberately does not
  # fail the installation because PulseAudio is unavailable.
  if command -v pulseaudio >/dev/null 2>&1; then
    log_ok "PulseAudio detected; audio support is available."
  else
    log_info "PulseAudio not installed; continuing without audio configuration."
  fi
}

write_help(){
  cat > "$HELP_FILE" <<EOF
TERMO-KALI QUICK REFERENCE

Start Kali:
  ~/start-kali.sh

Exit Kali:
  exit

Installer log:
  $LOGFILE

Kali rootfs:
  $KALI_ROOTFS

Optional XFCE4 desktop:
  See termo.txt in the Termo-Kali repository.

Troubleshooting:
  If installation fails, run:
    tail -n 80 "$LOGFILE"

Kali documentation:
  https://www.kali.org/docs/
EOF
  log_ok "Wrote help file: $HELP_FILE"
}

install_kali(){
  if [[ -x "$START_SCRIPT" && -x "$KALI_ROOTFS/bin/bash" ]]; then
    log_ok "Kali is already installed: $START_SCRIPT"
    return 0
  fi

  # Remove an incomplete installation but preserve a valid existing rootfs.
  if [[ -d "$KALI_ROOTFS" && ! -x "$KALI_ROOTFS/bin/bash" ]]; then
    log_warn "Found an incomplete Kali rootfs; removing it before reinstalling."
    rm -rf "$KALI_ROOTFS"
  fi

  local arch
  arch=$(get_arch) || {
    die 14 "Unsupported Termux architecture: $(dpkg --print-architecture 2>/dev/null || echo unknown)"
    return 14
  }

  TMP_DIR=$(mktemp -d "$STATE_DIR/install.XXXXXX") || {
    die 15 "Could not create temporary installation directory."
    return 15
  }

  local archive="$TMP_DIR/kali-rootfs-${arch}.tar.xz"

  if [[ ! -x "$KALI_ROOTFS/bin/bash" ]]; then
    download_rootfs "$arch" "$archive" || return $?
    extract_rootfs "$archive" || return $?
  fi

  create_launcher
  configure_optional_audio

  [[ -x "$START_SCRIPT" ]] || {
    die 16 "Launcher was not created correctly."
    return 16
  }
  [[ -x "$KALI_ROOTFS/bin/bash" ]] || {
    die 16 "Kali rootfs is incomplete."
    return 16
  }

  log_ok "Kali Linux installation completed successfully."
}

prompt_launch(){
  local reply=""
  printf '%b[*]%b Launch Kali now? [Y/n]: ' "$CYAN" "$RESET"
  IFS= read -r -t 10 reply || true
  echo
  case "${reply,,}" in
    n|no) log_info "Skipping launch. Run: $START_SCRIPT" ;;
    *) exec "$START_SCRIPT" ;;
  esac
}

main(){
  case "${1:-}" in
    -h|--help)
      printf 'Usage: %s [--help]\n' "$(basename "$0")"
      exit 0
      ;;
  esac

  mkdir -p "$STATE_DIR"
  : > "$LOGFILE"
  display_banner
  require_termux || return $?
  acquire_lock || return $?
  check_disk_space || return $?

  log_info "Starting Termo-Kali installation..."
  install_dependencies || return $?
  install_kali || return $?
  write_help || return $?

  printf '\n%b============================================================%b\n' "$GREEN" "$RESET"
  printf '%b Installation complete!%b\n' "$GREEN" "$RESET"
  printf ' Start Kali: %b%s%b\n' "$CYAN" "$START_SCRIPT" "$RESET"
  printf ' Help:       %bcat %s%b\n' "$CYAN" "$HELP_FILE" "$RESET"
  printf '%b============================================================%b\n\n' "$GREEN" "$RESET"

  prompt_launch
}

main "$@"
