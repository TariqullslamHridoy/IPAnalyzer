#!/bin/bash

# =========================
# IPAnalyzer - Tor-based IP Info Tool
# =========================

# Colors
RED='\e[1;91m'
GREEN='\e[1;92m'
YELLOW='\e[1;93m'
BLUE='\e[1;94m'
CYAN='\e[1;96m'
WHITE='\e[1;97m'
RESET='\e[0m'

# --- helpers ---
is_root() { [ "$EUID" -eq 0 ]; }
as_root() {
  if is_root; then "$@"; else sudo "$@"; fi
}

start_tor() {
  if command -v systemctl >/dev/null 2>&1; then
    as_root systemctl start tor 2>/dev/null || as_root systemctl start tor@default 2>/dev/null || true
  elif command -v service >/dev/null 2>&1; then
    as_root service tor start || true
  fi
  # last resort: spawn tor directly if no SOCKS port
  if ! nc -z 127.0.0.1 9050 2>/dev/null; then
    (as_root tor >/dev/null 2>&1 &)
  fi
  # wait until Tor is ready
  for _ in {1..20}; do
    nc -z 127.0.0.1 9050 2>/dev/null && return 0
    sleep 0.5
  done
  echo -e "${RED}[!] Tor SOCKS port (9050) not reachable.${RESET}"
}

check_dependencies() {
  echo -e "${YELLOW}Checking required dependencies...${RESET}"
  dependencies=(tor torsocks curl jq nc)
  missing=()
  for dep in "${dependencies[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      missing+=("$dep")
    else
      echo -e "${GREEN}[*] $dep is installed.${RESET}"
    fi
  done
  if ((${#missing[@]})); then
    echo -e "${RED}[*] Installing: ${missing[*]}${RESET}"
    as_root apt update && as_root apt install -y "${missing[@]}"
  fi
  start_tor
}

# Request a NEW identity if control port enabled
change_tor_ip() {
  echo -e "${CYAN}Requesting new Tor circuit...${RESET}"
  if nc -z 127.0.0.1 9051 2>/dev/null; then
    printf 'AUTHENTICATE ""\nSIGNAL NEWNYM\nQUIT\n' | nc 127.0.0.1 9051 >/dev/null 2>&1 || true
  else
    pkill -HUP tor 2>/dev/null || as_root systemctl reload tor 2>/dev/null || true
  fi
  sleep 3
}

# curl helpers
tor_request() {
  curl -sS -4 --max-time 15 --socks5-hostname 127.0.0.1:9050 -H 'User-Agent: curl' "$1"
}
direct_request() {
  curl -sS -4 --max-time 10 -H 'User-Agent: curl' "$1"
}

# fallback-aware fetch
fetch_ip_json() {
  local target="$1"
  local url1="https://ipapi.co/${target}json"
  local url2="https://ipwho.is/${target}"
  local body

  body=$(direct_request "$url1")
  echo "$body" | jq -e . >/dev/null 2>&1 || body=$(direct_request "$url2")
  echo "$body" | jq -e . >/dev/null 2>&1 || return 1
  printf '%s' "$body"
}

parse_ip_data() {
  local ip_data=$1 title=$2

  echo "$ip_data" | jq -e . >/dev/null 2>&1 || { echo -e "${RED}[!] Provider returned non-JSON.${RESET}"; return; }

  local local_ip city region country country_code region_code languages calling_code timezone postal asn isp lat lon currency

  local_ip=$(echo "$ip_data" | jq -r '.ip // empty')
  city=$(echo "$ip_data" | jq -r '.city // empty')
  region=$(echo "$ip_data" | jq -r '.region // .region_name // empty')
  country=$(echo "$ip_data" | jq -r '.country_name // .country // empty')
  country_code=$(echo "$ip_data" | jq -r '.country // .country_code // empty')
  region_code=$(echo "$ip_data" | jq -r '.region_code // empty')
  languages=$(echo "$ip_data" | jq -r '.languages // empty')
  calling_code=$(echo "$ip_data" | jq -r '.country_calling_code // .calling_code // empty')
  timezone=$(echo "$ip_data" | jq -r '.timezone // .timezone.id // empty')
  postal=$(echo "$ip_data" | jq -r '.postal // .zip // empty')
  asn=$(echo "$ip_data" | jq -r '.asn // .connection.asn // empty')
  isp=$(echo "$ip_data" | jq -r '.org // .connection.isp // .connection.org // empty')
  lat=$(echo "$ip_data" | jq -r '.latitude // .lat // empty')
  lon=$(echo "$ip_data" | jq -r '.longitude // .lon // empty')
  currency=$(echo "$ip_data" | jq -r '.currency // .currency.code // empty')

  if [ -z "$local_ip" ]; then
    echo -e "${RED}[!] Failed to fetch IP details.${RESET}"
    return
  fi

  printf "\n${CYAN}%s:${RESET}\n" "$title"
  printf "  ${GREEN}IP Address   : %s${RESET}\n" "$local_ip"
  printf "  ${GREEN}City         : %s${RESET}\n" "$city"
  printf "  ${GREEN}Region       : %s${RESET}\n" "$region"
  printf "  ${GREEN}Country      : %s${RESET}\n" "$country"
  printf "  ${GREEN}Country Code : %s${RESET}\n" "$country_code"
  printf "  ${GREEN}Region Code  : %s${RESET}\n" "$region_code"
  printf "  ${GREEN}Languages    : %s${RESET}\n" "$languages"
  printf "  ${GREEN}Calling Code : %s${RESET}\n" "$calling_code"
  printf "  ${GREEN}Timezone     : %s${RESET}\n" "$timezone"
  printf "  ${GREEN}Postal Code  : %s${RESET}\n" "$postal"
  printf "  ${GREEN}ASN          : %s${RESET}\n" "$asn"
  printf "  ${GREEN}ISP          : %s${RESET}\n" "$isp"
  printf "  ${GREEN}Latitude     : %s${RESET}\n" "$lat"
  printf "  ${GREEN}Longitude    : %s${RESET}\n" "$lon"
  printf "  ${GREEN}Currency     : %s${RESET}\n" "$currency"
  if [ -n "$lat" ] && [ -n "$lon" ]; then
    printf "  ${BLUE}Google Maps  : https://maps.google.com/?q=%s,%s${RESET}\n" "$lat" "$lon"
  fi
  printf "\n${YELLOW}Press Enter to return to the main menu...${RESET}\n"
  read -r
  menu
}

my_original_ip() {
  ip_data=$(fetch_ip_json "")
  parse_ip_data "$ip_data" "Your Original IP"
}

my_tor_ip() {
  change_tor_ip
  ip_data=$(tor_request "https://ipapi.co/json")
  echo "$ip_data" | jq -e . >/dev/null 2>&1 || ip_data=$(tor_request "https://ipwho.is/")
  parse_ip_data "$ip_data" "Your Tor IP"
}

track_ip() {
  read -p $'\n\e[1;33mEnter an IP or domain: \e[0m' user_ip
  if ! [[ "$user_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$|: ]]; then
    resolved=$(getent ahostsv4 "$user_ip" 2>/dev/null | awk 'NR==1{print $1}')
    user_ip=${resolved:-$user_ip}
  fi
  change_tor_ip
  ip_data=$(tor_request "https://ipapi.co/$user_ip/json")
  echo "$ip_data" | jq -e . >/dev/null 2>&1 || ip_data=$(tor_request "https://ipwho.is/$user_ip")
  parse_ip_data "$ip_data" "Details for IP $user_ip"
}

# Exit function
exits() {
  read -p "Do you want to stop Tor service as well? (y/N): " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    as_root systemctl stop tor 2>/dev/null || as_root service tor stop 2>/dev/null || pkill tor
  fi
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

                        Developer : Tariqullslamhridoy (MrVillain)

EOF
  printf "${RESET}${YELLOW}* GitHub: https://github.com/Tariqullslamhridoy${RESET}\n"
}

menu() {
  printf "\n"
  printf "${RED}  [${WHITE}01${RED}]${YELLOW} My Original IP${RESET}\n"
  printf "${RED}  [${WHITE}02${RED}]${YELLOW} My Tor IP ${RESET}\n"
  printf "${RED}  [${WHITE}03${RED}]${YELLOW} Track an IP/Domain${RESET}\n"
  printf "${RED}  [${WHITE}00${RED}]${YELLOW} Exit${RESET}\n"
  printf "\n"
  read -p $'  \e[1;91m[\e[0m\e[1;97m~\e[0m\e[1;91m]\e[0m\e[1;92m Select An Option: \e[0m' option

  case $option in
    1 | 01) my_original_ip ;;
    2 | 02) my_tor_ip ;;
    3 | 03) track_ip ;;
    0 | 00) exits ;;
    *) 
      printf "${RED}[!] Invalid option${RESET}\n"
      sleep 1
      menu
      ;;
  esac
}

# Main
check_dependencies
banner
menu
