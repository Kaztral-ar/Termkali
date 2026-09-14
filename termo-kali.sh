#!/bin/bash

# =======================================
# Enhanced Termo-Kali Installation Script
# =======================================

# Color definitions
CYAN='\033[1;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
WHITE='\033[1;37m'
RESET='\033[0m'

# Termo-Kali repository used for self-updates.
TERMO_KALI_UPDATE_URL="https://raw.githubusercontent.com/Kaztral-ar/Termokali/main/termo-kali.sh"

# Get current terminal width without adding a dependency.
get_terminal_width() {
    local width
    width=$(stty size 2>/dev/null | awk '{print $2}')
    width=${width:-${COLUMNS:-80}}
    [[ "$width" =~ ^[0-9]+$ ]] || width=80
    echo "$width"
}

# Function to display a modern responsive banner
display_banner() {
    clear
    local width
    width=$(get_terminal_width)
    local dragon=(
        '           / \\  //\\'
        '    |\\___/|      \\//'
        '    /0  0  \\__  //'
        '   /     /  \\/_/'
        '   \\_^_/\\   /'
        '      \\__/'
    )
    local branding=(
    '████████╗███████╗██████╗ ███╗   ███╗ ██████╗       ██╗  ██╗ █████╗ ██╗     ██╗'
    '╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██╔═══██╗      ██║ ██╔╝██╔══██╗██║     ██║'
    '   ██║   █████╗  ██████╔╝██╔████╔██║██║   ██║█████╗█████╔╝ ███████║██║     ██║'
    '   ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║   ██║╚════╝██╔═██╗ ██╔══██║██║     ██║'
    '   ██║   ███████╗██║  ██║██║ ╚═╝ ██║╚██████╔╝      ██║  ██╗██║  ██║███████╗██║'
    '   ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝       ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝'
)
    local line

    echo -e ""
    for line in "${dragon[@]}"; do
        printf "%b%s%b\n" "${CYAN}" "$line" "${RESET}"
    done
    echo -e ""

    if [ "$width" -ge 58 ]; then
        for line in "${branding[@]}"; do
            printf "%b%s%b\n" "${WHITE}" "$line" "${RESET}"
        done
        echo -e ""
        printf "${CYAN}KALI LINUX • TERMUX • PROOT${RESET}\n"
        printf "${BLUE}NO ROOT REQUIRED${RESET}\n"
    else
        printf "${WHITE}TERMO-KALI${RESET}\n"
        printf "${CYAN}KALI • TERMUX • PROOT${RESET}\n"
        printf "${BLUE}NO ROOT${RESET}\n"
    fi
    echo -e ""
}

progress_spinner() {
    local message="$1"
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local delay=0.1
    local i=0
    while true; do
        echo -ne "\r${PURPLE}[${BLUE}${spinner[$i]}${PURPLE}] ${message}"
        sleep $delay
        i=$(( (i+1) % ${#spinner[@]} ))
    done &
    SPIN_PID=$!
    disown
}

stop_spinner() {
    kill $SPIN_PID 2>/dev/null
    echo -ne "\r\033[K"
}

progress_bar() {
    local duration=$1
    local steps=20
    local delay=$(echo "scale=2; $duration/$steps" | bc)
    echo -ne "${PURPLE}Progress: ${RESET}|"
    for ((i=0; i<steps; i++)); do
        sleep $delay
        echo -ne "${GREEN}█${RESET}"
    done
    echo -ne "| ${GREEN}Complete!${RESET}\n"
}

# Download a small installer script with a spinner while keeping raw output hidden.
download_with_animation() {
    local url="$1"
    local output="$2"
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    wget "$url" -O "$output" -q &
    local download_pid=$!

    while kill -0 "$download_pid" 2>/dev/null; do
        printf "\r${CYAN}[${spinner[$i]}]${RESET} ${WHITE}Downloading...${RESET}"
        i=$(( (i + 1) % ${#spinner[@]} ))
        sleep 0.12
    done

    wait "$download_pid"
    local status=$?
    printf "\r\033[K"
    return "$status"
}

# Print one compact real percentage without exposing the installer log.
render_progress_bar() {
    local value="$1"
    local label="$2"
    local width=28
    local filled=0
    local empty=28

    if [[ "$value" =~ ^[0-9]+$ ]]; then
        [ "$value" -gt 100 ] && value=100
        filled=$(( value * width / 100 ))
        empty=$(( width - filled ))
    fi

    local filled_bar=""
    local empty_bar=""
    if [ "$filled" -gt 0 ]; then
        filled_bar=$(printf '█%.0s' $(seq 1 "$filled"))
    fi
    if [ "$empty" -gt 0 ]; then
        empty_bar=$(printf '░%.0s' $(seq 1 "$empty"))
    fi

    printf "\r\033[K  ${CYAN}[${GREEN}%s${WHITE}%s${CYAN}]${RESET} ${WHITE}%3s%%${RESET}  ${PURPLE}%s${RESET}" \
        "$filled_bar" "$empty_bar" "$value" "$label"
}

# Run the Andronix Kali CLI installer silently and expose only clean stage/progress UI.
# The percentage is taken from the real wget output when available; no fake percentage is used.
run_kali_installer_with_progress() {
    local installer="$1"
    local log_file
    local installer_pid
    local status
    local last_percent=""
    local stage="Preparing Kali Linux"
    local last_stage=""

    log_file="$(mktemp "${TMPDIR:-/tmp}/termo-kali-install.XXXXXX")"
    if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
        echo -e "${RED}[✗] Could not create installation log${RESET}"
        return 1
    fi

    printf "\n${WHITE}  Installing Kali Linux CLI${RESET}\n\n"
    render_progress_bar "--" "$stage"

    # Run through a pseudo-terminal when available so wget keeps its real
    # percentage output even though the installer log is hidden from the user.
    if command -v script >/dev/null 2>&1; then
        script -q -c "bash \"$installer\"" "$log_file" >/dev/null 2>&1 &
    else
        bash "$installer" >"$log_file" 2>&1 &
    fi
    installer_pid=$!

    while kill -0 "$installer_pid" 2>/dev/null; do
        local recent_output
        recent_output=$(tail -c 16384 "$log_file" 2>/dev/null)

        if printf '%s' "$recent_output" | grep -qiE 'Download Rootfs|Download.*Rootfs'; then
            stage="Downloading Kali Linux"
        fi
        if printf '%s' "$recent_output" | grep -qiE 'Decompressing Rootfs'; then
            stage="Extracting Kali Linux"
            last_percent=""
        elif printf '%s' "$recent_output" | grep -qiE 'writing launch script|fixing shebang|making .* executable'; then
            stage="Configuring Kali Linux"
            last_percent=""
        elif printf '%s' "$recent_output" | grep -qiE 'Patching mirrorlist|sources.list'; then
            stage="Configuring Kali repositories"
            last_percent=""
        elif printf '%s' "$recent_output" | grep -qiE 'removing image|You can now launch Kali'; then
            stage="Finalizing Kali Linux"
            last_percent=""
        fi

        if [ "$stage" != "$last_stage" ]; then
            last_stage="$stage"
            if [ "$stage" != "Downloading Kali Linux" ]; then
                render_progress_bar "--" "$stage"
            fi
        fi

        if [ "$stage" = "Downloading Kali Linux" ]; then
            local percent
            percent=$(printf '%s' "$recent_output" | grep -oE '[0-9]{1,3}%' | tail -1 | tr -d '%')
            if [[ "$percent" =~ ^[0-9]{1,3}$ ]] && [ "$percent" -le 100 ]; then
                last_percent="$percent"
            fi
            if [ -n "$last_percent" ]; then
                render_progress_bar "$last_percent" "$stage"
            else
                render_progress_bar "--" "$stage"
            fi
        fi

        sleep 0.25
    done

    wait "$installer_pid"
    status=$?

    if [ "$status" -eq 0 ] && [ -f "start-kali.sh" ]; then
        render_progress_bar "100" "Kali Linux ready"
        printf "\n\n${GREEN}[✓] Kali Linux CLI installed successfully${RESET}\n"
    else
        printf "\r\033[K"
        echo -e "${RED}[✗] Kali Linux CLI installation failed.${RESET}"
        echo -e "${YELLOW}Last installer output:${RESET}"
        tail -n 20 "$log_file"
    fi

    rm -f "$log_file"
    return "$status"
}

check_dependencies() {
    progress_spinner "Checking dependencies"
    local dependencies=("wget" "python" "openssl-tool" "proot")
    local missing_deps=()

    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    stop_spinner

    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo -e "${YELLOW}[•] Installing required dependencies...${RESET}"
        pkg update -y &> /dev/null
        for dep in "${missing_deps[@]}"; do
            pkg install -y "$dep" &> /dev/null
        done
        echo -e "${GREEN}[✓] Dependencies ready${RESET}"
    else
        echo -e "${GREEN}[✓] Dependencies ready${RESET}"
    fi
}

# Kali CLI installer: Andronix Kali rootfs without a desktop environment.
install_kali() {
    echo -e "\n${YELLOW}[*] Installing Kali Linux CLI environment...${RESET}\n"

    if [ -f "kali.sh" ]; then
        echo -e "${GREEN}[✓] Kali setup script already available${RESET}"
    else
        echo -e "${CYAN}[•] Downloading Kali Linux CLI installer...${RESET}"
        if ! download_with_animation "https://raw.githubusercontent.com/AndronixApp/AndronixOrigin/master/Installer/Kali/kali.sh" "kali.sh"; then
            echo -e "${RED}[✗] Kali Linux CLI download failed${RESET}"
            exit 1
        fi

        if [ ! -f "kali.sh" ]; then
            echo -e "${RED}[✗] Kali Linux CLI download failed${RESET}"
            exit 1
        fi

        echo -e "${GREEN}[✓] Kali Linux CLI installer downloaded${RESET}"
    fi

    if [ -f "start-kali.sh" ]; then
        echo -e "${GREEN}[✓] Existing Kali installation detected${RESET}"
    else
        if ! run_kali_installer_with_progress "kali.sh"; then
            exit 1
        fi
    fi

    cat > kali-help.txt << 'EOL'
# ------ KALI LINUX QUICK REFERENCE ------

## Basic Commands:
- Start Kali:        ./start-kali.sh
- Update packages:   apt update && apt upgrade -y
- Install tool:      apt install [package-name]
- Network tools:     nmap, wireshark, aircrack-ng
- Web tools:         burpsuite, sqlmap, nikto
- Password tools:    hydra, john, hashcat
- Exploitation:      metasploit-framework, searchsploit
- Quit Kali:         exit

## Useful Kali Directories:
- Tools directory:   /usr/share/
- Wordlists:         /usr/share/wordlists/

## Tips:
- Run 'apt update' after installation
- Install tools only as needed to save space
- Use 'man [command]' for help on specific tools

For more information, visit: https://www.kali.org/docs/
EOL
}

cleanup() {
    progress_spinner "Cleaning up installation files"
    rm -f kali.sh &> /dev/null
    stop_spinner
    echo -e "${GREEN}[✓] Cleanup completed${RESET}"
}

# Desktop environment installer: Andronix Kali XFCE image/installer.
launch_desktop_environment() {
    local desktop_script="kali-xfce.sh"
    local desktop_url="https://raw.githubusercontent.com/AndronixApp/AndronixOrigin/master/Installer/Kali/kali-xfce.sh"

    echo -e "${CYAN}[*] Preparing Kali XFCE desktop environment...${RESET}"

    if [ -f "$desktop_script" ]; then
        echo -e "${GREEN}[✓] Kali XFCE installer already available${RESET}"
    else
        echo -e "${CYAN}[•] Downloading Kali XFCE installer...${RESET}"
        if ! download_with_animation "$desktop_url" "$desktop_script"; then
            echo -e "${RED}[✗] Kali XFCE installer download failed${RESET}"
            read -r -p "Press Enter to return..."
            return
        fi
        chmod +x "$desktop_script"
        echo -e "${GREEN}[✓] Kali XFCE installer downloaded${RESET}"
    fi

    echo -e "${YELLOW}[*] Starting Kali XFCE desktop setup...${RESET}"
    bash "$desktop_script"
    local desktop_status=$?

    if [ "$desktop_status" -eq 0 ]; then
        echo -e "${GREEN}[✓] Kali XFCE desktop environment setup completed${RESET}"
    else
        echo -e "${RED}[✗] Kali XFCE desktop environment setup failed${RESET}"
    fi

    rm -f "$desktop_script" &> /dev/null
    read -r -p "Press Enter to return..."
}

# Check GitHub and replace the running installer only when a newer script is available.
update_termokali() {
    local script_path="${BASH_SOURCE[0]}"
    local script_dir
    local current_script
    local temp_file

    script_dir="$(cd "$(dirname "$script_path")" 2>/dev/null && pwd)"
    current_script="${script_dir}/$(basename "$script_path")"
    temp_file="$(mktemp "${TMPDIR:-/tmp}/termo-kali-update.XXXXXX")"

    if [ -z "$temp_file" ] || [ ! -f "$temp_file" ]; then
        echo -e "${RED}[✗] Could not create update file${RESET}"
        read -r -p "Press Enter to return..."
        return
    fi

    echo -e "${CYAN}[*] Checking Termo-Kali repository for updates...${RESET}"

    if ! wget -q "$TERMO_KALI_UPDATE_URL" -O "$temp_file"; then
        rm -f "$temp_file"
        echo -e "${RED}[✗] Could not check for updates. Check your internet connection.${RESET}"
        read -r -p "Press Enter to return..."
        return
    fi

    if [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        echo -e "${RED}[✗] Update file is empty or invalid${RESET}"
        read -r -p "Press Enter to return..."
        return
    fi

    if cmp -s "$current_script" "$temp_file"; then
        rm -f "$temp_file"
        echo -e "${GREEN}[✓] Termo-Kali is already up to date${RESET}"
        read -r -p "Press Enter to return..."
        return
    fi

    chmod +x "$temp_file"
    if mv "$temp_file" "$current_script"; then
        echo -e "${GREEN}[✓] New Termo-Kali version found and installed${RESET}"
        echo -e "${CYAN}[*] Restarting Termo-Kali...${RESET}"
        sleep 1
        exec bash "$current_script"
    else
        rm -f "$temp_file"
        echo -e "${RED}[✗] Could not install the update${RESET}"
        read -r -p "Press Enter to return..."
    fi
}

show_help_menu() {
    while true; do
        clear
        display_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║${WHITE}                 HELP MENU                   ${GREEN}║${RESET}"
        echo -e "${GREEN}╠══════════════════════════════════════════════╣${RESET}"
        echo -e "${GREEN}║${CYAN}  1)${WHITE} Reinstall Kali Linux                    ${GREEN}║${RESET}"
        echo -e "${GREEN}║${CYAN}  2)${WHITE} Update Termo-Kali                       ${GREEN}║${RESET}"
        echo -e "${GREEN}║${CYAN}  3)${WHITE} Help Documentation                     ${GREEN}║${RESET}"
        echo -e "${GREEN}║${CYAN}  4)${WHITE} Back                                  ${GREEN}║${RESET}"
        echo -e "${GREEN}╚══════════════════════════════════════════════╝${RESET}\n"

        read -r -p "Select an option [1-4]: " help_choice
        case "$help_choice" in
            1)
                echo -e "\n${YELLOW}[*] Reinstalling Kali Linux CLI...${RESET}"
                rm -f start-kali.sh
                install_kali
                cleanup
                echo -e "${GREEN}[✓] Reinstallation completed${RESET}"
                read -r -p "Press Enter to continue..."
                ;;
            2)
                update_termokali
                ;;
            3)
                clear
                display_banner
                if [ -f "kali-help.txt" ]; then
                    cat kali-help.txt
                else
                    echo -e "${YELLOW}[•] Help documentation is not available yet.${RESET}"
                fi
                echo
                read -r -p "Press Enter to return..."
                ;;
            4)
                return
                ;;
            *)
                echo -e "${RED}[✗] Invalid option. Please select 1-4.${RESET}"
                sleep 1
                ;;
        esac
    done
}

show_main_menu() {
    while true; do
        clear
        display_banner
        echo -e "${GREEN}╔══════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║${WHITE}               TERMO-KALI MENU               ${GREEN}║${RESET}"
        echo -e "${GREEN}╠══════════════════════════════════════════════╣${RESET}"
        echo -e "${GREEN}║${CYAN}  1)${WHITE} Run Kali Linux                         ${GREEN}║${RESET}"
        echo -e "${GREEN}║${CYAN}  2)${WHITE} Desktop Environment                     ${GREEN}║${RESET}"
        echo -e "${GREEN}║${CYAN}  3)${WHITE} Help                                  ${GREEN}║${RESET}"
        echo -e "${GREEN}╚══════════════════════════════════════════════╝${RESET}\n"

        read -r -p "Select an option [1-3]: " choice
        case "$choice" in
            1)
                clear
                display_banner
                echo -e "${GREEN}[*] Starting Kali Linux...${RESET}\n"
                ./start-kali.sh
                ;;
            2)
                launch_desktop_environment
                ;;
            3)
                show_help_menu
                ;;
            *)
                echo -e "${RED}[✗] Invalid option. Please select 1-3.${RESET}"
                sleep 1
                ;;
        esac
    done
}

main() {
    display_banner
    sleep 2

    if [ ! -d "/data/data/com.termux" ]; then
        echo -e "${RED}[✗] This script must be run in Termux environment.${RESET}"
        exit 1
    fi

    echo -e "${GREEN}[✓] Checking required files${RESET}"
    if [ -f "start-kali.sh" ]; then
        echo -e "${GREEN}[✓] Existing Kali launcher found${RESET}"
    else
        echo -e "${YELLOW}[•] Kali launcher not found; setup will continue${RESET}"
    fi

    echo -e "${GREEN}[✓] Checking environment${RESET}"
    echo -e "${YELLOW}[*] Starting installation process...${RESET}"
    sleep 1

    check_dependencies
    install_kali
    cleanup

    show_main_menu
}

main
