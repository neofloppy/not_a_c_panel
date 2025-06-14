#!/bin/bash

# Required commands
REQUIRED_COMMANDS=(pg_isready docker systemctl)

# Check for required tools
for cmd in "${REQUIRED_COMMANDS[@]}"; do
  if ! command -v $cmd &> /dev/null; then
    echo "Missing required command: $cmd"
    exit 1
  fi
done

LOGFILE="/tmp/neofloppy_watcher.log"
touch "$LOGFILE"

# ANSI
red='\033[0;31m'
white='\033[0;37m'
gray='\033[0;90m'
reset='\033[0m'

# Face art
face=(
"⠀⠀⠀⠀⢀⡴⠶⣶⣶⣤⣄⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⠀⣰⠋⠀⢸⣿⣿⠿⠛⠻⢿⣷⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⠀⣸⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⢻⣿⣷⣄⠀⠀⠀⠀⠀⠀⠀⠀"
"⠀⢀⡏⠀⠀⢀⣠⣶⣶⣶⣦⣤⣀⠀⠈⢻⣿⣿⣆⠀⠀⠀⠀⠀⠀⠀"
"⠀⢸⠁⠀⣴⣿⣿⣿⣿⣿⣿⣿⣿⡷⠀⠈⣿⣿⣿⣆⠀⠀⠀⠀⠀⠀"
"⠀⣿⠀⠀⠉⠻⣿⣿⣿⣿⡿⠋⠁⠀⠀⠀⠘⣿⣿⣿⣧⠀⠀⠀⠀⠀"
"⢠⣿⠀⠀⠀⠀⠀⠈⠉⠁⠀⠀⠀⠀⠀⠀⠀⠙⠛⢿⣿⠀⠀⠀⠀⠀"
"⢸⡇⠀⠀⣠⣴⣶⣶⣶⣶⣦⣄⠀⠀⠀⠀⠀⠀⠀⠀⣿⠀⠀⠀⠀⠀"
"⠈⢿⣄⠀⠹⣿⣿⣿⣿⣿⠿⠋⠀⠀⠀⠀⠀⠀⠀⠀⡿⠀⠀⠀⠀⠀"
"⠀⠈⠻⣷⣤⣈⠙⠛⠋⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⢀⣧⠀⠀⠀⠀⠀"
"⠀⠀⠀⠈⠙⠻⠿⢿⣷⣶⣶⣶⣶⣦⣤⣤⣤⣤⣴⣾⣿⠀⠀⠀⠀⠀"
"⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠉⠛⠛⠛⠛⠛⠛⠋⠁⠀⠀⠀⠀⠀"
)

function glitch_line() {
  local line="$1"
  for (( i=0; i<${#line}; i++ )); do
    char="${line:i:1}"
    if (( RANDOM % 10 == 0 )); then
      printf "${red}$(echo "\\x$(printf %x $((RANDOM % 26 + 97)))")${reset}"
    else
      printf "$char"
    fi
  done
  echo
}

function is_postgres_up() {
  pg_isready &> /dev/null
  return $?
}

function is_docker_running() {
  systemctl is-active --quiet docker
  return $?
}

function is_ftp_up() {
  if systemctl is-active --quiet vsftpd; then return 0; fi
  if systemctl is-active --quiet proftpd; then return 0; fi
  if docker ps | grep -qi ftp; then return 0; fi
  return 1
}

function log_failure() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

function all_services_up() {
  if ! is_postgres_up; then
    log_failure "PostgreSQL is DOWN"
    return 1
  fi
  if ! is_docker_running; then
    log_failure "Docker is DOWN"
    return 1
  fi
  if ! is_ftp_up; then
    log_failure "FTP is DOWN"
    return 1
  fi
  return 0
}

# Whisper scroll
function whisper_scroll() {
  local whisper="i live in the kernel"
  for ((i=0; i<${#whisper}+10; i++)); do
    echo -ne "${white}$(printf '%*s\r' $((i)) "${whisper:0:i}")${reset}"
    sleep 0.03
  done
}

# Main loop
while true; do
  clear
  if all_services_up; then
    tput cup 0 0
    echo -e "${red}███╗   ██╗███████╗ ██████╗ ███████╗██╗      ██████╗ ██████╗ ██████╗ ██╗   ██╗${reset}"
    echo -e "${red}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝${reset}"
    echo -e "${red}██╔██╗ ██║█████╗  ██║   ██║█████╗  ██║     ██║   ██║██████╔╝██████╔╝ ╚████╔╝ ${reset}"
    echo -e "${red}██║╚██╗██║██╔══╝  ██║   ██║██╔══╝  ██║     ██║   ██║██╔═══╝ ██╔═══╝   ╚██╔╝  ${reset}"
    echo -e "${red}██║ ╚████║███████╗╚██████╔╝███████╗███████╗╚██████╔╝██║     ██║        ██║   ${reset}"
    echo -e "${red}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝        ╚═╝   ${reset}"
    echo

    for line in "${face[@]}"; do
      glitch_line "$line"
    done

    whisper_scroll
  else
    echo -e "${gray}Service check failed. Watching in silence...${reset}"
    echo -e "${red}█${white}█${gray}█${red}.${gray}.${white}.${gray}.${red}█${reset}"
  fi

  sleep 3
done
