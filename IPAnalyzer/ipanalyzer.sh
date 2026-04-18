#!/bin/bash

# ===================================================
# IPAnalyzer - Optimized Tor-based IP Info Tool
# Developer : Tariqullslamhridoy (MrVillain)
# ===================================================

# Colors
RED='\e[1;91m'
GREEN='\e[1;92m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
CYAN='\e[1;96m'
WHITE='\e[1;97m'
RESET='\e[0m'

# --- Helpers ---
is_root() { [ "$EUID" -eq 0 ]; }
as_root() { if is_root; then "$@"; else sudo "$@"; fi }

start_tor() {
  echo -e "${YELLOW}[*] Starting Tor service...${RESET}"
  if command -v systemctl >/dev/null 2>&1; then
    as_root systemctl start tor 2>/dev/null || as_root systemctl start tor@default 2>/dev/null
  else
    as_root service tor start 2>/dev/null || (as_root tor >/dev/null 2>&1 &)
  fi
  
  # Wait for Tor SOCKS port
  for _ in {1..15}; do
    nc -z 127.0.0.1 9050 2>/dev/null && return 0
    sleep 1
  done
  echo -e "${RED}[!] Tor SOCKS port (9050) unreachable. Please check Tor config.${RESET}"
}

check_dependencies() {
  dependencies=(tor torsocks curl jq nc)
  missing=()
  for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then missing+=("$dep"); fi
  done

  if ((${#missing[@]})); then
    echo -e "${YELLOW}[*] Installing missing tools: ${missing[*]}${RESET}"
    as_root apt update && as_root apt install -y "${missing[@]}"
  fi
  start_tor
}

change_tor_ip() {
  echo -e "${CYAN}[*] Refreshing Tor Circuit...${RESET}"
  # Try via Control Port (9051) first
  if nc -z 127.0.0.1 9051 2>/dev/null; then
    printf 'AUTHENTICATE ""\nSIGNAL NEWNYM\nQUIT\n' | nc 127.0.0.1 9051 >/dev/null 2>&1
  else
    # Fallback to reload
    as_root systemctl reload tor 2>/dev/null || pkill -HUP tor 2>/dev/null
  fi
  sleep 2
}

# Request Wrappers
tor_request() {
  curl -sS -4 --max-time 15 --socks5-hostname 127.0.0.1:9050 -H 'User-Agent: curl' "$1"
}
direct_request() {
  curl -sS -4 --max-time 10 -H 'User-Agent: curl' "$1"
}

parse_ip_data() {
  local ip_data=$1 title=$2
  if ! echo "$ip_data" | jq -e . >/dev/null 2>&1; then
    echo -e "${RED}[!] Error: Invalid Data Received.${RESET}"
    return
  fi

  # Extracting with fallback to 'N/A'
  get_val() { echo "$ip_data" | jq -r "$1 // \"N/A\""; }

  local ip=$(get_val '.ip')
  local city=$(get_val '.city')
  local region=$(get_val '.region // .region_name')
  local country=$(get_val '.country_name // .country')
  local isp=$(get_val '.org // .connection.isp // .connection.org')
  local lat=$(get_val '.latitude // .lat')
  local lon=$(get_val '.longitude // .lon')
  local tz=$(get_val '.timezone // .timezone.id')

  printf "\n${CYAN}--- %s ---${RESET}\n" "$title"
  printf "  ${WHITE}IP Address   : ${GREEN}%s${RESET}\n" "$ip"
  printf "  ${WHITE}City/Region  : ${GREEN}%s, %s${RESET}\n" "$city" "$region"
  printf "  ${WHITE}Country      : ${GREEN}%s${RESET}\n" "$country"
  printf "  ${WHITE}ISP/ASN      : ${GREEN}%s${RESET}\n" "$isp"
  printf "  ${WHITE}Timezone     : ${GREEN}%s${RESET}\n" "$tz"
  
  if [[ "$lat" != "N/A" ]]; then
    printf "  ${WHITE}Location     : ${YELLOW}%s, %s${RESET}\n" "$lat" "$lon"
    printf "  ${BLUE}Google Maps  : https://www.google.com/maps?q=%s,%s${RESET}\n" "$lat" "$lon"
  fi
  
  echo -e "\n${YELLOW}Press Enter to return...${RESET}"
  read -r
  menu
}

my_original_ip() {
  echo -e "${YELLOW}[*] Fetching your real IP info...${RESET}"
  data=$(direct_request "https://ipapi.co/json/")
  [[ -z "$data" ]] && data=$(direct_request "https://ipwho.is/")
  parse_ip_data "$data" "ORIGINAL CONNECTION"
}

my_tor_ip() {
  change_tor_ip
  echo -e "${YELLOW}[*] Fetching Tor IP info...${RESET}"
  data=$(tor_request "https://ipapi.co/json/")
  [[ -z "$data" ]] && data=$(tor_request "https://ipwho.is/")
  parse_ip_data "$data" "ANONYMOUS TOR CONNECTION"
}

track_ip() {
  echo -ne "\n${YELLOW}Enter Target IP/Domain: ${RESET}"
  read -r target
  [[ -z "$target" ]] && menu
  
  echo -e "${YELLOW}[*] Tracking $target via Tor...${RESET}"
  data=$(tor_request "https://ipapi.co/$target/json/")
  [[ -z "$data" ]] && data=$(tor_request "https://ipwho.is/$target")
  parse_ip_data "$data" "TARGET INFO: $target"
}

exits() {
  echo -ne "${CYAN}Stop Tor service before exiting? (y/N): ${RESET}"
  read -r ans
  [[ "$ans" =~ ^[Yy]$ ]] && as_root systemctl stop tor 2>/dev/null
  echo -e "${GREEN}Goodbye!${RESET}"
  exit 0
}

banner() {
  clear
  echo -e "${GREEN}"
  cat << "EOF"
  _____ _____                    _                    
 |_   _|  __ \ /\               | |                   
   | | | |__) /  \   _ __   __ _| |_   _ _______ _ __ 
   | | |  ___/ /\ \ | '_ \ / _` | | | | |_  / _ \ '__|
  _| |_| |  / ____ \| | | | (_| | | |_| |/ /  __/ |   
 |_____|_| /_/    \_\_| |_|\__,_|_|\__, /___\___|_|   
                                    __/ |             
                                   |___/              
EOF
  echo -e "${WHITE}       Developer : Tariqullslamhridoy (MrVillain)${RESET}"
  echo -e "${CYAN}   --------------------------------------------------${RESET}"
}

menu() {
  banner
  echo -e "${RED}[01]${WHITE} My Original IP"
  echo -e "${RED}[02]${WHITE} My Tor IP (Identity Change)"
  echo -e "${RED}[03]${WHITE} Track Specific IP/Domain"
  echo -e "${RED}[00]${WHITE} Exit"
  echo -ne "\n${YELLOW}Select Option: ${RESET}"
  read -r opt

  case $opt in
    1|01) my_original_ip ;;
    2|02) my_tor_ip ;;
    3|03) track_ip ;;
    0|00) exits ;;
    *) echo -e "${RED}Invalid!${RESET}"; sleep 1; menu ;;
  esac
}

# Execution
check_dependencies
menu
