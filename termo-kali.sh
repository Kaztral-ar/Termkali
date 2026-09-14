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

download_with_animation() {
    local url="$1"
    local output="$2"
    local spinner=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0

    wget "$url" -O "$output" -q &
    local download_pid=$!

    while kill -0 "$download_pid" 2>/dev/null; do
        printf "\r${CYAN}[${spinner[$i]}]${RESET} ${WHITE}Downloading Kali Linux...${RESET}"
        i=$(( (i + 1) % ${#spinner[@]} ))
        sleep 0.12
    done

    wait "$download_pid"
    local status=$?
    printf "\r\033[K"
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
        progress_spinner "Preparing Kali Linux CLI environment"
        bash kali.sh &> /dev/null
        local install_status=$?
        stop_spinner

        if [ "$install_status" -ne 0 ] || [ ! -f "start-kali.sh" ]; then
            echo -e "${RED}[✗] Kali Linux CLI installation failed.${RESET}"
            exit 1
        fi

        echo -e "${GREEN}[✓] Kali Linux CLI installed successfully${RESET}"
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
                echo -e "\n${YELLOW}[*] Updating Termo-Kali dependencies...${RESET}"
                pkg update -y &> /dev/null
                pkg upgrade -y &> /dev/null
                echo -e "${GREEN}[✓] Termo-Kali environment updated${RESET}"
                read -r -p "Press Enter to continue..."
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
