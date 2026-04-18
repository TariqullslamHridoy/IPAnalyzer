#!/bin/bash

# ===================================================
# IPAnalyzer v3.0 - Elite OSINT Intelligence Tool
# Developed by: Md. Tariqul Islam Hridoy (MrVillain)
# Purpose: Professional IP Tracking & Geolocation
# ===================================================

# Colors (Cyberpunk Theme)
RED='\e[1;91m'
GREEN='\e[1;92m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
PURPLE='\e[1;95m'
CYAN='\e[1;96m'
WHITE='\e[1;97m'
RESET='\e[0m'

# --- Internal Helpers ---
is_root() { [ "$EUID" -eq 0 ]; }
as_root() { if is_root; then "$@"; else sudo "$@"; fi }

start_tor() {
    echo -e "${YELLOW}[*] Initializing Tor Stealth Network...${RESET}"
    if command -v systemctl >/dev/null 2>&1; then
        as_root systemctl start tor 2>/dev/null
    else
        as_root service tor start 2>/dev/null || (as_root tor >/dev/null 2>&1 &)
    fi
    
    for _ in {1..15}; do
        nc -z 127.0.0.1 9050 2>/dev/null && return 0
        sleep 1
    done
    echo -e "${RED}[!] Tor Network Unreachable! Use Option 00 to check config.${RESET}"
}

check_dependencies() {
    deps=(tor jq curl nc)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo -e "${YELLOW}[!] Installing $dep...${RESET}"
            as_root apt update && as_root apt install -y "$dep"
        fi
    done
    start_tor
}

change_identity() {
    echo -e "${PURPLE}[*] Rotating Tor Circuit (New Identity)...${RESET}"
    if nc -z 127.0.0.1 9051 2>/dev/null; then
        printf 'AUTHENTICATE ""\nSIGNAL NEWNYM\nQUIT\n' | nc 127.0.0.1 9051 >/dev/null 2>&1
    else
        as_root systemctl reload tor 2>/dev/null || pkill -HUP tor 2>/dev/null
    fi
    sleep 3
}

# --- Pro Request Engine ---
fetch_data() {
    local target=$1
    local use_tor=$2
    local agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    
    # logic: Try ipwho.is first (More stable), then ipapi.co
    if [ "$use_tor" == "true" ]; then
        curl -sS -4 --socks5-hostname 127.0.0.1:9050 -A "$agent" "https://ipwho.is/$target"
    else
        curl -sS -4 -A "$agent" "https://ipwho.is/$target"
    fi
}

parse_intel() {
    local data=$1 title=$2
    if [[ -z "$data" || "$data" == *"false"* ]]; then
        echo -e "${RED}[!] Error: Intelligence Data Blocked or Rate-limited.${RESET}"
        return
    fi

    # Parsing with JQ
    get() { echo "$data" | jq -r "$1 // \"N/A\""; }

    local ip=$(get '.ip')
    local type=$(get '.type')
    local continent=$(get '.continent')
    local country=$(get '.country')
    local region=$(get '.region')
    local city=$(get '.city')
    local isp=$(get '.connection.isp')
    local asn=$(get '.connection.asn')
    local lat=$(get '.latitude')
    local lon=$(get '.longitude')
    local tz=$(get '.timezone.id')
    local curr=$(get '.currency.name')

    clear
    banner
    echo -e "${CYAN}━━━━━━━━━━━━━━━ ${WHITE}INTEL REPORT: $title ${CYAN}━━━━━━━━━━━━━━━${RESET}"
    printf "  ${BLUE}● ${WHITE}IP Address   : ${GREEN}%s (${YELLOW}%s${GREEN})${RESET}\n" "$ip" "$type"
    printf "  ${BLUE}● ${WHITE}Location     : ${GREEN}%s, %s, %s${RESET}\n" "$city" "$region" "$country"
    printf "  ${BLUE}● ${WHITE}Continent    : ${GREEN}%s${RESET}\n" "$continent"
    printf "  ${BLUE}● ${WHITE}ISP/Provider : ${GREEN}%s${RESET}\n" "$isp"
    printf "  ${BLUE}● ${WHITE}ASN/Org      : ${GREEN}%s${RESET}\n" "$asn"
    printf "  ${BLUE}● ${WHITE}Timezone     : ${GREEN}%s${RESET}\n" "$tz"
    printf "  ${BLUE}● ${WHITE}Currency     : ${GREEN}%s${RESET}\n" "$curr"
    
    if [[ "$lat" != "N/A" ]]; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        printf "  ${RED}➤ ${WHITE}Coordinates  : ${YELLOW}%s, %s${RESET}\n" "$lat" "$lon"
        printf "  ${RED}➤ ${WHITE}Google Maps  : ${CYAN}https://www.google.com/maps?q=%s,%s${RESET}\n" "$lat" "$lon"
    fi
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -ne "${YELLOW}Press Enter to return to Command Center...${RESET}"
    read -r
}

# --- Actions ---
my_ip() {
    echo -e "${YELLOW}[*] Bypassing Local Filters...${RESET}"
    data=$(fetch_data "" "false")
    parse_intel "$data" "REAL CONNECTION"
}

tor_ip() {
    change_identity
    echo -e "${YELLOW}[*] Routing through Tor Nodes...${RESET}"
    data=$(fetch_data "" "true")
    parse_intel "$data" "ANONYMOUS CIRCUIT"
}

track_target() {
    echo -ne "\n${YELLOW}Enter Target IP or Domain: ${RESET}"
    read -r target
    [[ -z "$target" ]] && return
    echo -e "${YELLOW}[*] Tracking Intelligence for: $target...${RESET}"
    data=$(fetch_data "$target" "true")
    parse_intel "$data" "TARGET: $target"
}

banner() {
    clear
    echo -e "${CYAN}"
    cat << "EOF"
    █▀▀█ ░▀░ █▀▀█ █▀▀▄ █▀▀█ █   █ █▀▀▀ █▀▀█ █▀▀█ 
    █▄▄█ ▀█▀ █▄▄█ █  █ █▄▄█ █▄▄▄█ █▀▀▀ █▄▄▀ █▄▄█ 
    █    ▀▀▀ ▀  ▀ ▀  ▀ ▀  ▀ ▄▄▄█  █▄▄▄ ▀ ▀▀ ▀  ▀
EOF
    echo -e "         ${WHITE}Elite Intelligence Tracking Toolkit v3.0${RESET}"
    echo -e "      ${BLUE}Developed by: Md. Tariqul Islam Hridoy (PI)${RESET}\n"
}

menu() {
    banner
    echo -e "${CYAN}[01]${WHITE} Trace Real Connection (Clear-Net)"
    echo -e "${CYAN}[02]${WHITE} Trace Tor Connection (Identity Refresh)"
    echo -e "${CYAN}[03]${WHITE} Investigate Target IP/Domain"
    echo -e "${CYAN}[00]${WHITE} Secure Exit & Cleanup"
    echo -e "${CYAN}--------------------------------------------------${RESET}"
    echo -ne "${YELLOW}Command Shell > ${RESET}"
    read -r opt

    case $opt in
        1|01) my_ip ; menu ;;
        2|02) tor_ip ; menu ;;
        3|03) track_target ; menu ;;
        0|00) echo -e "${GREEN}Terminating Session...${RESET}" ; exit 0 ;;
        *) echo -e "${RED}Invalid Command!${RESET}" ; sleep 1 ; menu ;;
    esac
}

# Execution
check_dependencies
menu
