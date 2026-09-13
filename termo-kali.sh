#!/data/data/com.termux/files/usr/bin/bash
#
# =============================================================================
# Termo-Kali — Kali Linux installer for Termux
# =============================================================================
#
# Installs Kali Linux (via proot, using the EXALAB/AnLinux-Resources
# bootstrap) directly into $HOME, so the result always lives at
# ~/start-kali.sh regardless of which directory this script is run from.
#
# Exit codes:
#   0  success
#   1  generic/unexpected failure
#   10 not running inside Termux
#   11 another instance is already running
#   12 insufficient free disk space
#   13 dependency install failed
#   14 network unreachable
#   15 download failed / invalid downloaded file
#   16 Kali bootstrap install failed
#
set -Eeuo pipefail

# ---- Paths ------------------------------------------------------------------
readonly KALI_HOME="$HOME"                       # where start-kali.sh must end up
readonly STATE_DIR="$HOME/.termo-kali"           # our own bookkeeping, kept out of $HOME clutter
readonly LOGFILE="$STATE_DIR/install.log"
readonly LOCKFILE="$STATE_DIR/lock"
readonly HELP_FILE="$HOME/kali-help.txt"
readonly START_SCRIPT="$KALI_HOME/start-kali.sh"

# ---- Remote resources --------------------------------------------------------
readonly KALI_INSTALLER_URL="https://raw.githubusercontent.com/EXALAB/AnLinux-Resources/master/Scripts/Installer/Kali/kali.sh"

# ---- Requirements -------------------------------------------------------------
readonly MIN_FREE_MB=2048   # conservative floor for a Kali rootfs + package cache

# package_name:representative_binary  (binary left empty -> checked via dpkg only)
readonly REQUIRED_PKGS=(
    "bash:bash"
    "coreutils:"
    "curl:curl"
    "wget:wget"
    "proot:proot"
    "tar:tar"
    "xz-utils:xz"
    "openssl-tool:openssl"   # package is openssl-tool; the binary it ships is `openssl`
    "bc:bc"
)

# ---- Colors -------------------------------------------------------------------
readonly RED='\033[1;31m'
readonly GREEN='\033[1;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[1;34m'
readonly PURPLE='\033[1;35m'
readonly CYAN='\033[1;36m'
readonly WHITE='\033[1;37m'
readonly RESET='\033[0m'

# ---- Global state used by trap/cleanup ----------------------------------------
SPIN_PID=""
TMP_DIR=""

# =============================================================================
# Logging / UI
# =============================================================================

log_info() { echo -e "${BLUE}[INFO]${RESET} $*"; }
log_ok()   { echo -e "${GREEN}[OK]${RESET} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${RESET} $*"; }
log_err()  { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# Mirrors every message into the logfile too, timestamped, once STATE_DIR exists.
log_to_file() {
    [[ -d "$STATE_DIR" ]] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >>"$LOGFILE"
}

die() {
    local code="$1"; shift
    log_err "$*"
    log_to_file "FATAL: $*"
    exit "$code"
}

print_help() {
    cat <<EOF
Termo-Kali installer

Usage: $(basename "$0") [options]

Options:
  -h, --help    Show this help and exit

Installs Kali Linux under Termux via proot. Kali is installed directly into
\$HOME, so ~/start-kali.sh is created regardless of the directory you run
this script from. Safe to re-run: if Kali is already installed, it skips
straight to the launch prompt.

Logs:   ${LOGFILE}
Help:   ${HELP_FILE} (created after a successful install)
EOF
}

display_banner() {
    clear
    cat <<'BANNER'

              ████████╗███████╗██████╗ ███╗   ███╗ ██████╗       ██╗  ██╗ █████╗ ██╗     ██╗
              ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██╔═══██╗      ██║ ██╔╝██╔══██╗██║     ██║
                 ██║   █████╗  ██████╔╝██╔████╔██║██║   ██║█████╗█████╔╝ ███████║██║     ██║
                 ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║   ██║╚════╝██╔═██╗ ██╔══██║██║     ██║
                 ██║   ███████╗██║  ██║██║ ╚═╝ ██║╚██████╔╝      ██║  ██╗██║  ██║███████╗██║
                 ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝       ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝

BANNER
    echo -e "${YELLOW}               ╔══════════════════════════════════════════════════════════╗"
    echo -e "${YELLOW}               ║  ${WHITE}Advanced Kali Linux Installation for Termux Environment${YELLOW}  ║"
    echo -e "${YELLOW}               ╚══════════════════════════════════════════════════════════╝${RESET}"
    echo
}

# Background spinner. Always paired with stop_spinner, but the EXIT trap
# guarantees it's reaped even if an error path forgets to call it.
progress_spinner() {
    local message="$1"
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    (
        while true; do
            printf '\r%b[%b%s%b] %s' "$PURPLE" "$BLUE" "${frames[$i]}" "$PURPLE" "$message"
            sleep 0.1
            i=$(( (i + 1) % ${#frames[@]} ))
        done
    ) &
    SPIN_PID=$!
    disown
}

stop_spinner() {
    if [[ -n "$SPIN_PID" ]] && kill -0 "$SPIN_PID" 2>/dev/null; then
        kill "$SPIN_PID" 2>/dev/null
        wait "$SPIN_PID" 2>/dev/null || true
    fi
    SPIN_PID=""
    printf '\r\033[K'
}

# Pure-bash/bc-free would be ideal, but `bc` is now a declared dependency
# (needed by several Kali/pentest tools anyway), so use it deliberately here
# rather than reimplementing float math — this doubles as a functional check
# that the bc dependency actually works.
progress_bar() {
    local duration="$1" steps=20
    local delay
    delay=$(echo "scale=2; $duration/$steps" | bc)
    printf '%bProgress: %b|' "$PURPLE" "$RESET"
    for ((i = 0; i < steps; i++)); do
        sleep "$delay"
        printf '%b█%b' "$GREEN" "$RESET"
    done
    printf '| %bComplete!%b\n' "$GREEN" "$RESET"
}

# =============================================================================
# Cleanup / signal handling
# =============================================================================

cleanup_and_exit() {
    local exit_code=$?
    stop_spinner
    [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
    rm -f "$LOCKFILE" 2>/dev/null || true

    if [[ $exit_code -ne 0 ]]; then
        log_err "Installation aborted (exit code $exit_code)."
        [[ -f "$LOGFILE" ]] && log_warn "See $LOGFILE for details."
    fi
    exit "$exit_code"
}
trap cleanup_and_exit EXIT
trap 'exit 130' INT    # convert Ctrl+C into a normal trapped exit (128+SIGINT)
trap 'exit 143' TERM

# =============================================================================
# Preflight checks
# =============================================================================

require_termux() {
    if [[ ! -d "/data/data/com.termux" ]]; then
        die 10 "This script must be run inside a Termux environment."
    fi
    if [[ -z "${PREFIX:-}" ]] || [[ ! -x "${PREFIX}/bin/bash" ]]; then
        log_warn "\$PREFIX doesn't look like a standard Termux install; continuing cautiously."
    fi
}

acquire_lock() {
    mkdir -p "$STATE_DIR"
    if [[ -e "$LOCKFILE" ]]; then
        local pid
        pid=$(cat "$LOCKFILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            die 11 "Another instance is already running (pid $pid)."
        fi
        log_warn "Removing stale lock from a previous crashed run."
        rm -f "$LOCKFILE"
    fi
    echo $$ > "$LOCKFILE"
}

check_disk_space() {
    local free_mb
    free_mb=$(df -Pm "$HOME" 2>/dev/null | awk 'NR==2 {print $4}')
    if [[ -z "$free_mb" ]]; then
        log_warn "Could not determine free disk space; continuing anyway."
        return
    fi
    if (( free_mb < MIN_FREE_MB )); then
        die 12 "Only ${free_mb}MB free in \$HOME; Kali needs at least ${MIN_FREE_MB}MB."
    fi
    log_ok "Disk space check passed (${free_mb}MB free)."
}

# Returns 0 if the package appears installed, 1 otherwise.
pkg_is_installed() {
    local pkg="$1" bin="$2"
    if [[ -n "$bin" ]] && command -v "$bin" &>/dev/null; then
        return 0
    fi
    # coreutils/xz-utils-style packages have no single canonical binary name
    # guaranteed to exist under that exact name; fall back to Termux's own
    # package database (dpkg is the backend `pkg`/apt use on Termux itself —
    # this queries Termux's own state, it does not assume a Debian/Ubuntu host).
    if command -v dpkg &>/dev/null && dpkg -s "$pkg" &>/dev/null 2>&1; then
        return 0
    fi
    return 1
}

check_dependencies() {
    progress_spinner "Checking system dependencies"
    local missing=()
    local entry pkg bin
    for entry in "${REQUIRED_PKGS[@]}"; do
        pkg="${entry%%:*}"
        bin="${entry#*:}"
        pkg_is_installed "$pkg" "$bin" || missing+=("$pkg")
    done
    stop_spinner

    if [[ ${#missing[@]} -eq 0 ]]; then
        log_ok "All dependencies are installed."
        return
    fi

    log_warn "Installing missing dependencies: ${missing[*]}"

    if ! pkg update -y >>"$LOGFILE" 2>&1; then
        die 13 "\`pkg update\` failed. Check your internet connection (see $LOGFILE)."
    fi

    if ! pkg install -y "${missing[@]}" >>"$LOGFILE" 2>&1; then
        die 13 "Failed to install: ${missing[*]} (see $LOGFILE)."
    fi

    # Re-verify — a package can report success while still lacking the
    # expected binary if the repo mirror served a broken build.
    local still_missing=()
    for entry in "${REQUIRED_PKGS[@]}"; do
        pkg="${entry%%:*}"
        bin="${entry#*:}"
        pkg_is_installed "$pkg" "$bin" || still_missing+=("$pkg")
    done
    if [[ ${#still_missing[@]} -gt 0 ]]; then
        die 13 "Still missing after install: ${still_missing[*]} (see $LOGFILE)."
    fi
    log_ok "Dependencies installed successfully."
}

check_network() {
    progress_spinner "Checking network connectivity"
    local reachable=1
    if command -v curl &>/dev/null; then
        curl --silent --head --fail --max-time 10 "$KALI_INSTALLER_URL" >/dev/null 2>&1 || reachable=0
    else
        wget --spider --quiet --timeout=10 "$KALI_INSTALLER_URL" 2>/dev/null || reachable=0
    fi
    stop_spinner

    if [[ $reachable -ne 1 ]]; then
        die 14 "Cannot reach $KALI_INSTALLER_URL. Check your internet connection."
    fi
    log_ok "Network reachable."
}

# =============================================================================
# Download + validation
# =============================================================================

# Retries across both tools where available; HTTPS only.
download_file() {
    local url="$1" dest="$2" attempt
    for attempt in 1 2 3; do
        if command -v curl &>/dev/null; then
            if curl --fail --silent --show-error --location \
                    --connect-timeout 15 --max-time 120 \
                    -o "$dest" "$url" 2>>"$LOGFILE"; then
                return 0
            fi
        elif command -v wget &>/dev/null; then
            if wget --quiet --timeout=15 --tries=1 -O "$dest" "$url" 2>>"$LOGFILE"; then
                return 0
            fi
        else
            log_err "Neither curl nor wget is available."
            return 1
        fi
        log_warn "Download attempt $attempt/3 failed; retrying..."
        sleep 2
    done
    return 1
}

# Rejects empty files, HTML error pages, and anything that isn't valid shell
# syntax, so a GitHub 404/rate-limit page never gets piped into bash.
validate_shell_script() {
    local file="$1"

    if [[ ! -s "$file" ]]; then
        log_err "Downloaded file is empty."
        return 1
    fi

    if head -c 1024 "$file" 2>/dev/null | grep -qi '<html'; then
        log_err "Downloaded file looks like an HTML page, not a script."
        return 1
    fi

    if ! bash -n "$file" 2>>"$LOGFILE"; then
        log_err "Downloaded file failed shell syntax validation."
        return 1
    fi

    return 0
}

# =============================================================================
# Install
# =============================================================================

install_kali() {
    if [[ -x "$START_SCRIPT" ]]; then
        log_ok "Kali Linux is already installed (${START_SCRIPT} found)."
        return
    fi

    log_info "Installing Kali Linux environment into \$HOME..."
    check_network

    TMP_DIR=$(mktemp -d "${TMPDIR:-$STATE_DIR}/kali.XXXXXX")
    local kali_script="$TMP_DIR/kali.sh"

    progress_spinner "Downloading Kali setup script"
    local ok=1
    download_file "$KALI_INSTALLER_URL" "$kali_script" || ok=0
    stop_spinner

    [[ $ok -eq 1 ]] || die 15 "Failed to download the Kali setup script after retries."

    if ! validate_shell_script "$kali_script"; then
        die 15 "Downloaded installer failed validation; refusing to execute it."
    fi
    log_ok "Downloaded and validated Kali setup script."

    if command -v sha256sum &>/dev/null; then
        # Upstream publishes no checksum to verify against; this is an audit
        # trail of exactly what was executed, not a substitute for a real
        # signature check.
        log_to_file "kali.sh sha256: $(sha256sum "$kali_script" | cut -d' ' -f1)"
    fi

    progress_spinner "Setting up Kali Linux environment (this can take a while)"
    local install_ok=1
    ( cd "$KALI_HOME" && bash "$kali_script" ) >>"$LOGFILE" 2>&1 || install_ok=0
    stop_spinner

    if [[ $install_ok -ne 1 ]] || [[ ! -f "$START_SCRIPT" ]]; then
        die 16 "Kali Linux installation failed. See $LOGFILE for details."
    fi

    chmod +x "$START_SCRIPT"
    log_ok "Kali Linux installed successfully at $START_SCRIPT."
}

write_help_file() {
    cat > "$HELP_FILE" << EOF
# ------ TERMO-KALI QUICK REFERENCE ------

## Starting Kali
    ~/start-kali.sh
(or: bash ~/start-kali.sh)

## Exiting Kali
    exit
(or Ctrl+D at the Kali prompt — this returns you to Termux, it does not
uninstall anything.)

## Fixing "permission denied" when starting Kali
    chmod +x ~/start-kali.sh
Then run ./start-kali.sh (or ~/start-kali.sh) again.

## Inside Kali
- Update packages:   apt update && apt upgrade -y
- Install a tool:    apt install <package-name>
- Network tools:     nmap, wireshark, aircrack-ng
- Web tools:         burpsuite, sqlmap, nikto
- Password tools:    hydra, john, hashcat
- Exploitation:      metasploit-framework, searchsploit
- Wordlists:         /usr/share/wordlists/
- Optional GUI desktop (run INSIDE Kali, not Termux): see termo.txt

## Troubleshooting
- Re-running this installer is safe: if ~/start-kali.sh already exists it
  skips straight to the launch prompt instead of reinstalling.
- Full install log: ${LOGFILE}
- "Another instance is already running": a previous run may have crashed
  without cleaning up; wait a moment or remove ${LOCKFILE} if you're sure
  nothing else is running.
- Download/network errors: verify Termux has internet access and that
  Android hasn't restricted its background data.
- Low storage errors: Kali needs roughly 2GB+ free; check with 'df -h \$HOME'.
- To start over completely: rm -rf ~/start-kali.sh ~/kali-* ~/.termo-kali
  (this removes the installed Kali environment — back up anything inside
  it first).

For more information, visit: https://www.kali.org/docs/
EOF
    log_ok "Wrote help file to $HELP_FILE."
}

prompt_launch() {
    local reply="y"
    echo -ne "${PURPLE}[*] ${YELLOW}Launch Kali now? [Y/n] (auto-yes in 10s): ${RESET}"
    read -r -t 10 reply || true
    echo
    case "${reply,,}" in
        n|no) log_info "Skipping launch. Run: $START_SCRIPT" ;;
        *)    exec "$START_SCRIPT" ;;
    esac
}

# =============================================================================
# Main
# =============================================================================

main() {
    for arg in "$@"; do
        case "$arg" in
            -h|--help) print_help; exit 0 ;;
        esac
    done

    display_banner
    sleep 1

    mkdir -p "$STATE_DIR"
    : > "$LOGFILE"

    require_termux
    acquire_lock
    check_disk_space

    log_info "Starting installation process..."

    check_dependencies
    install_kali
    write_help_file

    echo -e "\n${GREEN}╔═════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║ ${WHITE}Installation Complete! Run the following:    ${GREEN}║${RESET}"
    echo -e "${GREEN}║ ${CYAN}~/start-kali.sh                             ${GREEN}║${RESET}"
    echo -e "${GREEN}║ ${WHITE}For help and commands reference, view:      ${GREEN}║${RESET}"
    echo -e "${GREEN}║ ${CYAN}cat ~/kali-help.txt                         ${GREEN}║${RESET}"
    echo -e "${GREEN}╚═════════════════════════════════════════════╝${RESET}"

    progress_bar 3
    prompt_launch
}

main "$@"
