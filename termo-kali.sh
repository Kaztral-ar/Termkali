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
# The layout automatically switches to a compact version on narrow terminals.
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
    local line

    echo -e ""
    for line in "${dragon[@]}"; do
        printf "%b%s%b\n" "${CYAN}" "$line" "${RESET}"
    done
    echo -e ""

    if [ "$width" -ge 32 ]; then
        printf "${WHITE}TERMO-KALI${RESET}\n"
        printf "${CYAN}KALI LINUX • TERMUX • PROOT${RESET}\n"
        printf "${BLUE}NO ROOT REQUIRED${RESET}\n"
    else
        printf "${WHITE}TERMO-KALI${RESET}\n"
        printf "${CYAN}KALI • TERMUX • PROOT${RESET}\n"
        printf "${BLUE}NO ROOT${RESET}\n"
    fi
    echo -e ""
}

# Function to display spinning progress indicator
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
    
    # Store the PID so we can kill it later
    disown
}

# Function to stop the spinner
stop_spinner() {
    kill $SPIN_PID 2>/dev/null
    echo -ne "\r\033[K"
}

# Function to display progress bar
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

# Animated download indicator without a percentage.
# The animation runs while wget performs the real download in the background.
download_with_animation() {
    local url="$1"
    local output="$2"
    local frames=('▰▱▱▱▱▱▱▱' '▰▰▱▱▱▱▱▱' '▰▰▰▱▱▱▱▱' '▰▰▰▰▱▱▱▱' '▰▰▰▰▰▱▱▱' '▰▰▰▰▰▰▱▱' '▰▰▰▰▰▰▰▱' '▰▰▰▰▰▰▰▰' '▱▰▰▰▰▰▰▰' '▱▱▰▰▰▰▰▰' '▱▱▱▰▰▰▰▰' '▱▱▱▱▰▰▰▰')
    local i=0

    wget "$url" -O "$output" -q &
    local download_pid=$!

    while kill -0 "$download_pid" 2>/dev/null; do
        printf "\r${CYAN}[${frames[$i]}]${RESET} ${WHITE}Downloading Kali setup...${RESET}"
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.12
    done

    wait "$download_pid"
    local status=$?
    printf "\r\033[K"
    return "$status"
}

# Function to check dependencies
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

# Function to install Kali Linux
install_kali() {
    echo -e "\n${YELLOW}[*] Installing Kali Linux environment...${RESET}\n"
    
    if [ -f "kali.sh" ]; then
        echo -e "${GREEN}[✓] Kali setup script already available${RESET}"
    else
        echo -e "${CYAN}[•] Downloading Kali Linux...${RESET}"
        if ! download_with_animation "https://raw.githubusercontent.com/EXALAB/AnLinux-Resources/master/Scripts/Installer/Kali/kali.sh" "kali.sh"; then
            echo -e "${RED}[✗] Kali Linux download failed${RESET}"
            exit 1
        fi
        
        if [ ! -f "kali.sh" ]; then
            echo -e "${RED}[✗] Kali Linux download failed${RESET}"
            exit 1
        fi
        
        echo -e "${GREEN}[✓] Kali Linux files downloaded${RESET}"
    fi
    
    if [ -f "start-kali.sh" ]; then
        echo -e "${GREEN}[✓] Existing Kali installation detected${RESET}"
    else
        progress_spinner "Preparing Kali Linux environment"
        bash kali.sh &> /dev/null
        local install_status=$?
        stop_spinner
        
        if [ "$install_status" -ne 0 ] || [ ! -f "start-kali.sh" ]; then
            echo -e "${RED}[✗] Kali Linux installation failed.${RESET}"
            exit 1
        fi
        
        echo -e "${GREEN}[✓] Kali Linux installed successfully${RESET}"
    fi
    
    # Create a help file with useful commands
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

# Function to clean up
cleanup() {
    progress_spinner "Cleaning up installation files"
    rm -f kali.sh &> /dev/null
    stop_spinner
    echo -e "${GREEN}[✓] Cleanup completed${RESET}"
}

# Main function
main() {
    display_banner
    sleep 2
    
    # Check for Termux environment
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
    
    # Check dependencies
    check_dependencies
    
    # Install Kali
    install_kali
    
    # Clean up
    cleanup
    
    # Final message
    echo -e "\n${GREEN}╔═════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║ ${WHITE}Installation Complete! Run the following:    ${GREEN}║${RESET}"
    echo -e "${GREEN}║ ${CYAN}./start-kali.sh                             ${GREEN}║${RESET}"
    echo -e "${GREEN}║ ${WHITE}For help and commands reference, view:      ${GREEN}║${RESET}"
    echo -e "${GREEN}║ ${CYAN}cat kali-help.txt                           ${GREEN}║${RESET}"
    echo -e "${GREEN}╚═════════════════════════════════════════════╝${RESET}"
    
    echo -e "${GREEN}[✓] Kali Linux installation completed${RESET}"
    echo -e "\n${PURPLE}[*] ${YELLOW}Starting Kali Linux in 5 seconds...${RESET}"
    sleep 5
    ./start-kali.sh
}

# Execute main function
main
