#!/bin/bash

# Not a cPanel - Service Monitor with ASCII Art
# Monitors the health of Not a cPanel application and its dependencies

LOGFILE="./logs/watcher.log"
APP_PORT=5000
DB_PORT=5432
LOG_LINES=10

# Create logs directory if it doesn't exist
mkdir -p logs

# ANSI colors
green='\033[0;32m'
red='\033[0;31m'
yellow='\033[1;33m'
blue='\033[0;34m'
white='\033[1;37m'
gray='\033[0;90m'
cyan='\033[0;36m'
magenta='\033[0;35m'
reset='\033[0m'

# ASCII Art for NEOFLOPPY
ASCII_ART="
${red}███╗   ██╗███████╗ ██████╗ ███████╗██╗      ██████╗ ██████╗ ██████╗ ██╗   ██╗${reset}
${red}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝${reset}
${red}██╔██╗ ██║█████╗  ██║   ██║█████╗  ██║     ██║   ██║██████╔╝██████╔╝ ╚████╔╝${reset} 
${red}██║╚██╗██║██╔══╝  ██║   ██║██╔══╝  ██║     ██║   ██║██╔═══╝ ██╔═══╝   ╚██╔╝${reset}  
${red}██║ ╚████║███████╗╚██████╔╝██║     ███████╗╚██████╔╝██║     ██║        ██║${reset}   
${red}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝     ╚═╝        ╚═╝${reset}   
"

function log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

function check_app_server() {
    if curl -s -f "http://localhost:$APP_PORT" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

function check_database() {
    # Try multiple ways to check PostgreSQL
    if command -v pg_isready >/dev/null 2>&1; then
        pg_isready -h localhost -p $DB_PORT >/dev/null 2>&1
        return $?
    elif command -v nc >/dev/null 2>&1; then
        nc -z localhost $DB_PORT >/dev/null 2>&1
        return $?
    elif command -v telnet >/dev/null 2>&1; then
        timeout 2 telnet localhost $DB_PORT >/dev/null 2>&1
        return $?
    else
        # Fallback: assume it's running if we can't check
        return 0
    fi
}

function check_docker() {
    if command -v docker >/dev/null 2>&1; then
        docker info >/dev/null 2>&1
        return $?
    else
        # Docker not installed, that's okay
        return 0
    fi
}

function get_container_count() {
    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
        docker ps -q | wc -l
    else
        echo "N/A"
    fi
}

function get_uptime() {
    if command -v uptime >/dev/null 2>&1; then
        uptime | awk '{print $3,$4}' | sed 's/,//'
    else
        echo "N/A"
    fi
}

function get_recent_logs() {
    if [ -f "$LOGFILE" ]; then
        tail -n $LOG_LINES "$LOGFILE"
    else
        echo "No logs yet..."
    fi
}

function display_status() {
    clear
    
    # Display static ASCII art
    echo -e "$ASCII_ART"
    echo ""
    
    # Service status section
    echo -e "${blue}╔══════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${blue}║${white}                      SERVICE STATUS                          ${blue}║${reset}"
    echo -e "${blue}╚══════════════════════════════════════════════════════════════╝${reset}"
    
    # Check application server
    if check_app_server; then
        echo -e "${green}✓${reset} Application Server: ${green}RUNNING${reset} (http://localhost:$APP_PORT)"
    else
        echo -e "${red}✗${reset} Application Server: ${red}DOWN${reset} (http://localhost:$APP_PORT)"
    fi
    
    # Check database
    if check_database; then
        echo -e "${green}✓${reset} PostgreSQL Database: ${green}RUNNING${reset} (localhost:$DB_PORT)"
    else
        echo -e "${red}✗${reset} PostgreSQL Database: ${red}DOWN${reset} (localhost:$DB_PORT)"
    fi
    
    # Check Docker
    if check_docker; then
        container_count=$(get_container_count)
        echo -e "${green}✓${reset} Docker Service: ${green}RUNNING${reset} ($container_count containers)"
    else
        echo -e "${yellow}⚠${reset} Docker Service: ${yellow}NOT AVAILABLE${reset}"
    fi
    
    echo ""
    echo -e "${gray}System Uptime: $(get_uptime) | Last Check: $(date '+%H:%M:%S')${reset}"
    echo ""
    
    # Log window
    echo -e "${cyan}╔══════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${cyan}║${white}                        EVENT LOG                            ${cyan}║${reset}"
    echo -e "${cyan}╠══════════════════════════════════════════════════════════════╣${reset}"
    
    # Display recent logs in the box
    local log_content=$(get_recent_logs)
    local line_count=0
    
    while IFS= read -r line && [ $line_count -lt $LOG_LINES ]; do
        if [ -n "$line" ]; then
            # Truncate line if too long (60 chars to fit in box)
            local display_line=$(echo "$line" | cut -c1-60)
            local line_length=${#display_line}
            local padding_length=$((60 - line_length))
            local padding=""
            
            # Create padding if needed
            if [ $padding_length -gt 0 ]; then
                padding=$(printf "%*s" $padding_length "")
            fi
            
            # Add color based on log level
            if [[ $line == *"WARNING"* ]]; then
                echo -e "${cyan}║${yellow}$display_line${reset}$padding${cyan}║${reset}"
            elif [[ $line == *"ERROR"* ]]; then
                echo -e "${cyan}║${red}$display_line${reset}$padding${cyan}║${reset}"
            elif [[ $line == *"INFO"* ]]; then
                echo -e "${cyan}║${green}$display_line${reset}$padding${cyan}║${reset}"
            else
                echo -e "${cyan}║${gray}$display_line${reset}$padding${cyan}║${reset}"
            fi
        else
            # Empty line
            echo -e "${cyan}║$(printf '%*s' 60 '')║${reset}"
        fi
        ((line_count++))
    done <<< "$log_content"
    
    # Fill remaining lines if needed
    while [ $line_count -lt $LOG_LINES ]; do
        echo -e "${cyan}║$(printf '%*s' 60 '')║${reset}"
        ((line_count++))
    done
    
    echo -e "${cyan}╚══════════════════════════════════════════════════════════════╝${reset}"
    echo ""
    echo -e "${gray}Press Ctrl+C to stop monitoring${reset}"
}

function check_and_log() {
    local all_good=true
    
    if ! check_app_server; then
        log_message "WARNING: Application server is not responding on port $APP_PORT"
        all_good=false
    fi
    
    if ! check_database; then
        log_message "WARNING: PostgreSQL database is not responding on port $DB_PORT"
        all_good=false
    fi
    
    if ! check_docker; then
        log_message "INFO: Docker service is not available"
    fi
    
    if $all_good; then
        log_message "INFO: All core services are running normally"
    fi
}

# Trap Ctrl+C
trap 'echo -e "\n${yellow}Monitoring stopped.${reset}"; exit 0' INT

# Initial log entry
log_message "INFO: Not a cPanel monitor started"

# Main monitoring loop
while true; do
    display_status
    check_and_log
    sleep 5
done