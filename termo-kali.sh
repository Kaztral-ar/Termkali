#!/bin/bash

# =======================================
# Enhanced Termo-Kali Installation Script
# =======================================

CYAN='\033[1;36m'
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
WHITE='\033[1;37m'
RESET='\033[0m'

TERMO_KALI_UPDATE_URL="https://raw.githubusercontent.com/Kaztral-ar/Termokali/main/termo-kali.sh"

get_terminal_width() {
    local width
    width=$(stty size 2>/dev/null | awk '{print $2}')
    width=${width:-${COLUMNS:-80}}
    [[ "$width" =~ ^[0-9]+$ ]] || width=80
    echo "$width"
}

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
    local i=0
    while true; do
        printf "\r\033[2K${PURPLE}[${BLUE}${spinner[$i]}${PURPLE}] ${message}"
        i=$(( (i+1) % ${#spinner[@]} ))
        sleep 0.1
    done &
    SPIN_PID=$!
    disown
}

stop_spinner() {
    kill "$SPIN_PID" 2>/dev/null
    printf "\r\033[2K"
}

progress_bar() {
    local duration=$1
    local steps=20
    local delay=$(echo "scale=2; $duration/$steps" | bc)
    echo -ne "${PURPLE}Progress: ${RESET}|"
    for ((i=0; i<steps; i++)); do
        sleep "$delay"
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
        printf "\r\033[2K${CYAN}[${spinner[$i]}]${RESET} ${WHITE}Downloading...${RESET}"
        i=$(( (i + 1) % ${#spinner[@]} ))
        sleep 0.12
    done
    wait "$download_pid"
    local status=$?
    printf "\r\033[2K"
    return "$status"
}

render_progress_bar() {
    local value="$1"
    local label="$2"
    local width=18
    local filled=0
    local empty=$width
    local filled_bar=""
    local empty_bar=""

    if [[ "$value" =~ ^[0-9]+$ ]]; then
        [ "$value" -gt 100 ] && value=100
        filled=$(( value * width / 100 ))
        empty=$(( width - filled ))
    fi

    [ "$filled" -gt 0 ] && filled_bar=$(printf '█%.0s' $(seq 1 "$filled"))
    [ "$empty" -gt 0 ] && empty_bar=$(printf '░%.0s' $(seq 1 "$empty"))

    printf "\033[2K\r${CYAN}[${GREEN}%s${WHITE}%s${CYAN}]${RESET} ${WHITE}%3s%%${RESET} ${PURPLE}%s${RESET}" \
        "$filled_bar" "$empty_bar" "$value" "$label"
}

run_kali_installer_with_progress() {
    local installer="$1"
    local log_file
    local installer_pid
    local status
    local last_percent=""
    local stage="Preparing"

    log_file="$(mktemp "${TMPDIR:-/tmp}/termo-kali-install.XXXXXX")"
    if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
        echo -e "${RED}[✗] Could not create installation log${RESET}"
        return 1
    fi

    printf "\n${WHITE}  Installing Kali Linux CLI${RESET}\n"
    render_progress_bar "--" "$stage"

    if command -v script >/dev/null 2>&1; then
        script -q -c "bash \"$installer\"" "$log_file" >/dev/null 2>&1 &
    else
        bash "$installer" >"$log_file" 2>&1 &
    fi
    installer_pid=$!

    while kill -0 "$installer_pid" 2>/dev/null; do
        local recent_output
        recent_output=$(tail -c 16384 "$log_file" 2>/dev/null | tr '\r' '\n')

        if printf '%s' "$recent_output" | grep -qiE 'Download Rootfs|Download.*Rootfs'; then
            stage="Downloading"
        elif printf '%s' "$recent_output" | grep -qiE 'Decompressing Rootfs'; then
            stage="Extracting"
        elif printf '%s' "$recent_output" | grep -qiE 'writing launch script|fixing shebang|making .* executable'; then
            stage="Configuring"
        elif printf '%s' "$recent_output" | grep -qiE 'Patching mirrorlist|sources.list'; then
            stage="Repositories"
        elif printf '%s' "$recent_output" | grep -qiE 'removing image|You can now launch Kali'; then
            stage="Finalizing"
        fi

        local percent
        percent=$(printf '%s' "$recent_output" | grep -oE '[0-9]{1,3}%' | tail -1 | tr -d '%')
        if [[ "$percent" =~ ^[0-9]{1,3}$ ]] && [ "$percent" -le 100 ]; then
            last_percent="$percent"
        fi

        if [ "$stage" = "Downloading" ] && [ -n "$last_percent" ]; then
            render_progress_bar "$last_percent" "Downloading"
        else
            render_progress_bar "--" "$stage"
        fi
        sleep 0.2
    done

    wait "$installer_pid"
    status=$?

    if [ "$status" -eq 0 ] && [ -f "start-kali.sh" ]; then
        render_progress_bar "100" "Complete"
        printf "\n\n${GREEN}[✓] Kali Linux CLI installed successfully${RESET}\n"
    else
        printf "\033[2K\r"
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
    fi
    echo -e "${GREEN}[✓] Dependencies ready${RESET}"
}

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
        run_kali_installer_with_progress "kali.sh" || exit 1
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

# Marching Blocks desktop loading effect. Raw upstream apt/wget output is hidden.
run_desktop_installer_with_progress() {
    local installer="$1"
    local log_file
    local installer_pid
    local status
    local width=12
    local position=0
    local direction=1
    local block_width=2
    local frame
    local label="Preparing XFCE"
    local first_frame=1
    local last_log_size=0
    local last_fs_size=0
    local stall_ticks=0
    local stall_limit=10000
    local installer_stalled=0

    log_file="$(mktemp "${TMPDIR:-/tmp}/termo-kali-desktop.XXXXXX")"
    if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
        echo -e "${RED}[✗] Could not create desktop installation log${RESET}"
        return 1
    fi

    if command -v script >/dev/null 2>&1; then
        script -q -c "bash \"$installer\"" "$log_file" >/dev/null 2>&1 &
    else
        bash "$installer" >"$log_file" 2>&1 &
    fi
    installer_pid=$!

    printf "\n${WHITE}  Loading desktop environment${RESET}\n"

    while kill -0 "$installer_pid" 2>/dev/null; do
        local recent_output
        recent_output=$(tail -c 16384 "$log_file" 2>/dev/null | tr '\r' '\n')

        local log_size
        local fs_size
        log_size=$(wc -c < "$log_file" 2>/dev/null | tr -d ' ')
        fs_size=0
        if [ -d "kali-fs" ]; then
            fs_size=$(du -sk "kali-fs" 2>/dev/null | awk '{print $1}')
            fs_size=${fs_size:-0}
        fi
        if [ "$log_size" -gt "$last_log_size" ] || [ "$fs_size" -gt "$last_fs_size" ]; then
            stall_ticks=0
            last_log_size="$log_size"
            last_fs_size="$fs_size"
        else
            stall_ticks=$((stall_ticks + 1))
        fi

        if [ "$stall_ticks" -ge "$stall_limit" ]; then
            installer_stalled=1
            label="Installer stalled"
            printf "\033[2K\r${RED}[✗] No installer activity detected for 20 minutes.${RESET}\n"
            printf "${YELLOW}The XFCE installation appears to be stuck. Check your internet connection and storage, then run Desktop Environment again.${RESET}\n"
            kill "$installer_pid" 2>/dev/null
            sleep 1
            pkill -TERM -P "$installer_pid" 2>/dev/null || true
            break
        fi

        if printf '%s' "$recent_output" | grep -qiE 'apt|install.*xfce|xfce4|xfce'; then
            label="Installing XFCE"
        fi
        if printf '%s' "$recent_output" | grep -qiE 'configur|setting up|desktop'; then
            label="Configuring desktop"
        fi
        if printf '%s' "$recent_output" | grep -qiE 'vnc|tightvnc|tigervnc'; then
            label="Setting up VNC"
        fi

        frame=""
        for ((i=0; i<width; i++)); do
            if [ "$i" -eq "$position" ] || [ "$i" -eq $((position + 1)) ]; then
                frame+="▰"
            else
                frame+="▱"
            fi
        done

        if [ "$first_frame" -eq 1 ]; then
            printf "\033[2K\r${CYAN}[${GREEN}%s${CYAN}]${RESET}\n" "$frame"
            printf "\033[2K\r  ${WHITE}%s${RESET}" "$label"
            first_frame=0
        else
            printf "\033[1A\033[2K\r${CYAN}[${GREEN}%s${CYAN}]${RESET}\n" "$frame"
            printf "\033[2K\r  ${WHITE}%s${RESET}" "$label"
        fi

        position=$((position + direction))
        if [ "$position" -ge $((width - block_width)) ]; then
            position=$((width - block_width))
            direction=-1
        elif [ "$position" -le 0 ]; then
            position=0
            direction=1
        fi
        sleep 0.12
    done

    wait "$installer_pid" 2>/dev/null
    status=$?
    if [ "$installer_stalled" -eq 1 ]; then
        status=124
    fi

    # Remove the two live animation lines before printing the final result once.
    printf "\033[2K\r"
    printf "\033[1A\033[2K\r"
    if [ "$status" -eq 0 ]; then
        printf "${CYAN}[${GREEN}▱▱▰▰▱▱▱▱▱▱▱▱${CYAN}]${RESET}\n"
        echo -e "  ${GREEN}Complete${RESET}"
        echo -e "${GREEN}[✓] Kali XFCE desktop environment setup completed${RESET}"
    else
        echo -e "${RED}[✗] Kali XFCE desktop environment setup failed${RESET}"
        echo -e "${YELLOW}Last installer output:${RESET}"
        tail -n 20 "$log_file"
    fi

    rm -f "$log_file"
    return "$status"
}

launch_desktop_environment() {
    local desktop_script="kali-xfce.sh"
    local desktop_url="https://raw.githubusercontent.com/AndronixApp/AndronixOrigin/master/Installer/Kali/kali-xfce.sh"

    clear
    display_banner
    echo -e "${CYAN}[*] Preparing Kali XFCE desktop environment...${RESET}\n"

    if [ -f "$desktop_script" ]; then
        chmod +x "$desktop_script"
    else
        echo -e "${CYAN}[•] Downloading Kali XFCE installer...${RESET}"
        if ! download_with_animation "$desktop_url" "$desktop_script"; then
            echo -e "${RED}[✗] Kali XFCE installer download failed${RESET}"
            return 1
        fi
        chmod +x "$desktop_script"
    fi

    run_desktop_installer_with_progress "$desktop_script"
    local status=$?
    rm -f "$desktop_script" 2>/dev/null
    return "$status"
}

update_termokali() {
    local current_script="${BASH_SOURCE[0]}"
    local temp_script

    if [ ! -f "$current_script" ]; then
        echo -e "${RED}[✗] Current Termo-Kali script could not be located.${RESET}"
        return 1
    fi

    temp_script="$(mktemp "${TMPDIR:-/tmp}/termo-kali-update.XXXXXX")"
    if ! wget -q "$TERMO_KALI_UPDATE_URL" -O "$temp_script"; then
        rm -f "$temp_script"
        echo -e "${RED}[✗] Failed to check for Termo-Kali updates.${RESET}"
        return 1
    fi

    if [ ! -s "$temp_script" ]; then
        rm -f "$temp_script"
        echo -e "${RED}[✗] Update file is empty.${RESET}"
        return 1
    fi

    if cmp -s "$current_script" "$temp_script"; then
        rm -f "$temp_script"
        echo -e "${GREEN}[✓] Termo-Kali is already up to date.${RESET}"
        return 0
    fi

    chmod +x "$temp_script"
    if ! mv "$temp_script" "$current_script"; then
        rm -f "$temp_script"
        echo -e "${RED}[✗] Failed to install the Termo-Kali update.${RESET}"
        return 1
    fi

    echo -e "${GREEN}[✓] Termo-Kali updated successfully.${RESET}"
    exec bash "$current_script"
}

show_help() {
    while true; do
        clear
        display_banner
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║${CYAN}                         HELP MENU                         ${GREEN}║${RESET}"
        echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${GREEN}║${CYAN}  1)${WHITE} Reinstall Kali Linux                              ${GREEN}║${RESET}"
        echo -e "${GREEN}║${CYAN}  2)${WHITE} Update Termo-Kali                                ${GREEN}║${RESET}"
        echo -e "${GREEN}║${CYAN}  3)${WHITE} Help Documentation                               ${GREEN}║${RESET}"
        echo -e "${GREEN}║${CYAN}  4)${WHITE} Back                                             ${GREEN}║${RESET}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
        read -rp "Choose an option: " choice
        case "$choice" in
            1)
                clear
                display_banner
                echo -e "${YELLOW}[*] Reinstalling Kali Linux CLI...${RESET}"
                rm -rf kali-fs start-kali.sh 2>/dev/null
                install_kali
                cleanup
                read -rp "Press Enter to continue..."
                ;;
            2)
                update_termokali
                ;;
            3)
                clear
                display_banner
                if [ -f kali-help.txt ]; then
                    cat kali-help.txt
                else
                    echo -e "${YELLOW}Kali help documentation is not available yet.${RESET}"
                fi
                read -rp "Press Enter to continue..."
                ;;
            4)
                return
                ;;
            *)
                echo -e "${RED}[✗] Invalid option.${RESET}"
                sleep 1
                ;;
        esac
    done
}

show_main_menu() {
    while true; do
        clear
        display_banner
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
        echo -e "${GREEN}║${CYAN}                       TERMO-KALI                         ${GREEN}║${RESET}"
        echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${RESET}"
        echo -e "${GREEN}║${CYAN}  1)${WHITE} Run Kali Linux                         ${GREEN}║${RESET}"
        echo -e "${GREEN}║${CYAN}  2)${WHITE} Desktop Environment                     ${GREEN}║${RESET}"
        echo -e "${GREEN}║${CYAN}  3)${WHITE} Help                                  ${GREEN}║${RESET}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
        read -rp "Choose an option: " choice
        case "$choice" in
            1)
                if [ -f "start-kali.sh" ]; then
                    bash ./start-kali.sh
                else
                    echo -e "${RED}[✗] Kali Linux is not installed.${RESET}"
                    sleep 2
                fi
                ;;
            2)
                launch_desktop_environment
                read -rp "Press Enter to continue..."
                ;;
            3)
                show_help
                ;;
            *)
                echo -e "${RED}[✗] Invalid option.${RESET}"
                sleep 1
                ;;
        esac
    done
}

main() {
    clear
    display_banner

    if [ -z "$PREFIX" ] || [ ! -d "$PREFIX" ]; then
        echo -e "${RED}[✗] This script must be run inside Termux.${RESET}"
        exit 1
    fi

    check_dependencies
    install_kali
    cleanup
    show_main_menu
}

main "$@"
