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

# ASCII Art for NEOFLOPPY (original)
NEOFLOPPY_ART="
${red}███╗   ██╗███████╗ ██████╗ ███████╗██╗      ██████╗ ██████╗ ██████╗ ██╗   ██╗${reset}
${red}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝${reset}
${red}██╔██╗ ██║█████╗  ██║   ██║█████╗  ██║     ██║   ██║██████╔╝██████╔╝ ╚████╔╝${reset} 
${red}██║╚██╗██║██╔══╝  ██║   ██║██╔══╝  ██║     ██║   ██║██╔═══╝ ██╔═══╝   ╚██╔╝${reset}  
${red}██║ ╚████║███████╗╚██████╔╝██║     ███████╗╚██████╔╝██║     ██║        ██║${reset}   
${red}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝     ╚═╝        ╚═╝${reset}   
"

# ASCII Art for NeoShell (final)
NEOSHELL_ART="
${cyan}███╗   ██╗███████╗ ██████╗ ███████╗██╗  ██╗███████╗██╗     ██╗     ${reset}
${cyan}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║  ██║██╔════╝██║     ██║     ${reset}
${cyan}██╔██╗ ██║█████╗  ██║   ██║███████╗███████║█████╗  ██║     ██║     ${reset}
${cyan}██║╚██╗██║██╔══╝  ██║   ██║╚════██║██╔══██║██╔══╝  ██║     ██║     ${reset}
${cyan}██║ ╚████║███████╗╚██████╔╝███████║██║  ██║███████╗███████╗███████╗${reset}
${cyan}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝${reset}
"

# Melting animation frames
MELT_FRAME_1="
${red}███╗   ██╗███████╗ ██████╗ ███████╗██╗      ██████╗ ██████╗ ██████╗ ██╗   ██╗${reset}
${red}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝${reset}
${red}██╔██╗ ██║█████╗  ██║   ██║█████╗  ██║     ██║   ██║██████╔╝██████╔╝ ╚████╔╝${reset} 
${red}██║╚██╗██║██╔══╝  ██║   ██║██╔══╝  ██║     ██║   ██║██╔═══╝ ██╔═══╝   ╚██╔╝${reset}  
${red}██║ ╚████║███████╗╚██████╔╝██║     ███████╗╚██████╔╝██║     ██║        ██║${reset}   
${red}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝     ╚═╝        ╚═╝${reset}   
${red}  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
"

MELT_FRAME_2="
${red}███╗   ██╗███████╗ ██████╗ ███████╗██╗      ██████╗ ██████╗ ██████╗ ██╗   ██╗${reset}
${red}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝${reset}
${red}██╔██╗ ██║█████╗  ██║   ██║█████╗  ██║     ██║   ██║██████╔╝██████╔╝ ╚████╔╝${reset} 
${red}██║╚██╗██║██╔══╝  ██║   ██║██╔══╝  ██║     ██║   ██║██╔═══╝ ██╔═══╝   ╚██╔╝${reset}  
${red}██║ ╚████║███████╗╚██████╔╝██║     ███████╗╚██████╔╝██║     ██║        ██║${reset}   
${red}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝     ╚═╝        ╚═╝${reset}   
${red}  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
${red}    ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
"

MELT_FRAME_3="
${red}███╗   ██╗███████╗ ██████╗ ███████╗██╗      ██████╗ ██████╗ ██████╗ ██╗   ██╗${reset}
${red}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝${reset}
${red}██╔██╗ ██║█████╗  ██║   ██║█████╗  ██║     ██║   ██║██████╔╝██████╔╝ ╚████╔╝${reset} 
${red}██║╚██╗██║██╔══╝  ██║   ██║██╔══╝  ██║     ██║   ██║██╔═══╝ ██╔═══╝   ╚██╔╝${reset}  
${red}██║ ╚████║███████╗╚██████╔╝██║     ███████╗╚██████╔╝██║     ██║        ██║${reset}   
${red}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝     ╚═╝        ╚═╝${reset}   
${red}  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
${red}    ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
${red}      ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
"

MELT_FRAME_4="
${yellow}███╗   ██╗███████╗ ██████╗ ███████╗██╗      ██████╗ ██████╗ ██████╗ ██╗   ██╗${reset}
${yellow}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗╚██╗ ██╔╝${reset}
${yellow}██╔██╗ ██║█████╗  ██║   ██║█████╗  ██║     ██║   ██║██████╔╝██████╔╝ ╚████╔╝${reset} 
${red}██║╚██╗██║██╔══╝  ██║   ██║██╔══╝  ██║     ██║   ██║██╔═══╝ ██╔═══╝   ╚██╔╝${reset}  
${red}██║ ╚████║███████╗╚██████╔╝██║     ███████╗╚██████╔╝██║     ██║        ██║${reset}   
${red}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚═╝     ╚══════╝ ╚═════╝ ╚═╝     ╚═╝        ╚═╝${reset}   
${red}  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
${red}    ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
${red}      ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
"

MELT_FRAME_5="
${yellow}███╗   ██╗███████╗ ██████╗ ███████╗██╗  ██╗███████╗██╗     ██╗     ${reset}
${yellow}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║  ██║██╔════╝██║     ██║     ${reset}
${yellow}██╔██╗ ██║█████╗  ██║   ██║███████╗███████║█████╗  ██║     ██║     ${reset}
${red}██║╚██╗██║██╔══╝  ██║   ██║╚════██║██╔══██║██╔══╝  ██║     ██║     ${reset}
${red}██║ ╚████║███████╗╚██████╔╝███████║██║  ██║███████╗███████╗███████╗${reset}
${red}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝${reset}
${red}  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
${red}    ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
"

MELT_FRAME_6="
${cyan}███╗   ██╗███████╗ ██████╗ ███████╗██╗  ██╗███████╗██╗     ██╗     ${reset}
${cyan}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║  ██║██╔════╝██║     ██║     ${reset}
${cyan}██╔██╗ ██║█████╗  ██║   ██║███████╗███████║█████╗  ██║     ██║     ${reset}
${yellow}██║╚██╗██║██╔══╝  ██║   ██║╚════██║██╔══██║██╔══╝  ██║     ██║     ${reset}
${red}██║ ╚████║███████╗╚██████╔╝███████║██║  ██║███████╗███████╗███████╗${reset}
${red}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝${reset}
${red}  ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄${reset}
"

MELT_FRAME_7="
${cyan}███╗   ██╗███████╗ ██████╗ ███████╗██╗  ██╗███████╗██╗     ██╗     ${reset}
${cyan}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║  ██║██╔════╝██║     ██║     ${reset}
${cyan}██╔██╗ ██║█████╗  ██║   ██║███████╗███████║█████╗  ██║     ██║     ${reset}
${cyan}██║╚██╗██║██╔══╝  ██║   ██║╚════██║██╔══██║██╔══╝  ██║     ██║     ${reset}
${cyan}██║ ╚████║███████╗╚██████╔╝███████║██║  ██║███████╗███████╗███████╗${reset}
${cyan}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝${reset}
"

# Global variables
ANIMATION_SHOWN=false
WATCHER_PID=$
CLEANUP_DONE=false

function log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

function cleanup_ports() {
    if [ "$CLEANUP_DONE" = true ]; then
        return
    fi
    
    log_message "INFO: Starting graceful shutdown and port cleanup"
    
    # Kill processes using our monitored ports
    local pids_killed=0
    
    # Find and terminate processes on APP_PORT
    if command -v lsof >/dev/null 2>&1; then
        local app_pids=$(lsof -ti:$APP_PORT 2>/dev/null)
        if [ -n "$app_pids" ]; then
            echo -e "\n${yellow}Terminating processes on port $APP_PORT...${reset}"
            for pid in $app_pids; do
                if kill -TERM "$pid" 2>/dev/null; then
                    log_message "INFO: Sent SIGTERM to process $pid on port $APP_PORT"
                    ((pids_killed++))
                fi
            done
            
            # Wait a moment for graceful shutdown
            sleep 2
            
            # Force kill if still running
            app_pids=$(lsof -ti:$APP_PORT 2>/dev/null)
            if [ -n "$app_pids" ]; then
                for pid in $app_pids; do
                    if kill -KILL "$pid" 2>/dev/null; then
                        log_message "WARNING: Force killed process $pid on port $APP_PORT"
                        ((pids_killed++))
                    fi
                done
            fi
        fi
    elif command -v netstat >/dev/null 2>&1; then
        # Fallback using netstat
        local app_pids=$(netstat -tlnp 2>/dev/null | grep ":$APP_PORT " | awk '{print $7}' | cut -d'/' -f1 | grep -v -)
        if [ -n "$app_pids" ]; then
            echo -e "\n${yellow}Terminating processes on port $APP_PORT...${reset}"
            for pid in $app_pids; do
                if kill -TERM "$pid" 2>/dev/null; then
                    log_message "INFO: Sent SIGTERM to process $pid on port $APP_PORT"
                    ((pids_killed++))
                fi
            done
            sleep 2
            # Force kill check
            app_pids=$(netstat -tlnp 2>/dev/null | grep ":$APP_PORT " | awk '{print $7}' | cut -d'/' -f1 | grep -v -)
            if [ -n "$app_pids" ]; then
                for pid in $app_pids; do
                    if kill -KILL "$pid" 2>/dev/null; then
                        log_message "WARNING: Force killed process $pid on port $APP_PORT"
                        ((pids_killed++))
                    fi
                done
            fi
        fi
    fi
    
    # Clean up any zombie processes
    if command -v pkill >/dev/null 2>&1; then
        pkill -f "not_a_c_panel" 2>/dev/null || true
        pkill -f "python.*5000" 2>/dev/null || true
        pkill -f "node.*5000" 2>/dev/null || true
    fi
    
    # Verify ports are free
    sleep 1
    local port_status=""
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i:$APP_PORT >/dev/null 2>&1; then
            port_status="STILL OCCUPIED"
        else
            port_status="FREE"
        fi
    else
        port_status="UNKNOWN"
    fi
    
    log_message "INFO: Port $APP_PORT status after cleanup: $port_status"
    log_message "INFO: Terminated $pids_killed processes during cleanup"
    
    CLEANUP_DONE=true
}

function emergency_port_release() {
    echo -e "\n${red}EMERGENCY: Forcing port release...${reset}"
    log_message "CRITICAL: Emergency port release initiated"
    
    # Nuclear option - kill everything on our ports
    if command -v fuser >/dev/null 2>&1; then
        fuser -k $APP_PORT/tcp 2>/dev/null || true
        fuser -k $DB_PORT/tcp 2>/dev/null || true
    fi
    
    # Alternative method
    if command -v ss >/dev/null 2>&1; then
        local pids=$(ss -tlnp | grep ":$APP_PORT " | sed 's/.*pid=\([0-9]*\).*/\1/' | sort -u)
        for pid in $pids; do
            kill -KILL "$pid" 2>/dev/null || true
        done
    fi
    
    log_message "CRITICAL: Emergency port release completed"
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

function play_melting_animation() {
    if [ "$ANIMATION_SHOWN" = true ]; then
        return
    fi
    
    clear
    echo -e "$NEOFLOPPY_ART"
    echo -e "${white}                           Loading NeoShell...${reset}"
    sleep 1
    
    clear
    echo -e "$MELT_FRAME_1"
    echo -e "${white}                           Loading NeoShell...${reset}"
    sleep 0.3
    
    clear
    echo -e "$MELT_FRAME_2"
    echo -e "${white}                           Loading NeoShell...${reset}"
    sleep 0.3
    
    clear
    echo -e "$MELT_FRAME_3"
    echo -e "${white}                           Loading NeoShell...${reset}"
    sleep 0.3
    
    clear
    echo -e "$MELT_FRAME_4"
    echo -e "${white}                           Loading NeoShell...${reset}"
    sleep 0.4
    
    clear
    echo -e "$MELT_FRAME_5"
    echo -e "${white}                           Loading NeoShell...${reset}"
    sleep 0.4
    
    clear
    echo -e "$MELT_FRAME_6"
    echo -e "${white}                           Loading NeoShell...${reset}"
    sleep 0.4
    
    clear
    echo -e "$MELT_FRAME_7"
    echo -e "${white}                           Loading NeoShell...${reset}"
    sleep 0.5
    
    clear
    echo -e "$NEOSHELL_ART"
    echo -e "${cyan}                           Welcome to NeoShell!${reset}"
    sleep 1.5
    
    ANIMATION_SHOWN=true
}

function display_status() {
    clear
    
    # Show NeoShell after animation
    if [ "$ANIMATION_SHOWN" = true ]; then
        echo -e "$NEOSHELL_ART"
    else
        echo -e "$NEOFLOPPY_ART"
    fi
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
    
    # Log window - The box is exactly 64 characters wide
    # ╔══════════════════════════════════════════════════════════════╗ = 64 chars
    # ║ + content (62 chars) + ║ = 64 chars total
    echo -e "${cyan}╔══════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${cyan}║${white}                        EVENT LOG                            ${cyan}║${reset}"
    echo -e "${cyan}╠══════════════════════════════════════════════════════════════╣${reset}"
    
    # Display recent logs in the box
    local log_content=$(get_recent_logs)
    local line_count=0
    
    # Process each log line
    while IFS= read -r line && [ $line_count -lt $LOG_LINES ]; do
        if [ -n "$line" ]; then
            # Ensure line is exactly 62 characters (to fit perfectly in the box)
            local display_line
            if [ ${#line} -gt 62 ]; then
                display_line="${line:0:62}"
            else
                display_line="$line"
                # Add padding to make it exactly 62 characters
                local padding_needed=$((62 - ${#line}))
                if [ $padding_needed -gt 0 ]; then
                    display_line="$line$(printf "%*s" $padding_needed "")"
                fi
            fi
            
            # Add color based on log level
            if [[ $line == *"WARNING"* ]]; then
                echo -e "${cyan}║${yellow}$display_line${reset}${cyan}║${reset}"
            elif [[ $line == *"ERROR"* ]]; then
                echo -e "${cyan}║${red}$display_line${reset}${cyan}║${reset}"
            elif [[ $line == *"INFO"* ]]; then
                echo -e "${cyan}║${green}$display_line${reset}${cyan}║${reset}"
            else
                echo -e "${cyan}║${gray}$display_line${reset}${cyan}║${reset}"
            fi
        else
            # Empty line with exactly 62 spaces
            echo -e "${cyan}║$(printf "%*s" 62 "")║${reset}"
        fi
        ((line_count++))
    done <<< "$log_content"
    
    # Fill remaining lines if needed
    while [ $line_count -lt $LOG_LINES ]; do
        echo -e "${cyan}║$(printf "%*s" 62 "")║${reset}"
        ((line_count++))
    done
    
    echo -e "${cyan}╚══════════════════════════════════════════════════════════════╝${reset}"
    echo ""
    
    # Port status section
    echo -e "${magenta}╔══════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${magenta}║${white}                       PORT STATUS                           ${magenta}║${reset}"
    echo -e "${magenta}╚══════════════════════════════════════════════════════════════╝${reset}"
    
    # Check port availability
    local app_port_status="FREE"
    local db_port_status="FREE"
    
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i:$APP_PORT >/dev/null 2>&1; then
            app_port_status="OCCUPIED"
        fi
        if lsof -i:$DB_PORT >/dev/null 2>&1; then
            db_port_status="OCCUPIED"
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -ln | grep ":$APP_PORT " >/dev/null 2>&1; then
            app_port_status="OCCUPIED"
        fi
        if netstat -ln | grep ":$DB_PORT " >/dev/null 2>&1; then
            db_port_status="OCCUPIED"
        fi
    fi
    
    if [ "$app_port_status" = "OCCUPIED" ]; then
        echo -e "${green}●${reset} Port $APP_PORT: ${green}$app_port_status${reset} (Application)"
    else
        echo -e "${red}○${reset} Port $APP_PORT: ${red}$app_port_status${reset} (Application)"
    fi
    
    if [ "$db_port_status" = "OCCUPIED" ]; then
        echo -e "${green}●${reset} Port $DB_PORT: ${green}$db_port_status${reset} (Database)"
    else
        echo -e "${red}○${reset} Port $DB_PORT: ${red}$db_port_status${reset} (Database)"
    fi
    
    echo ""
    if [ "$ANIMATION_SHOWN" = true ]; then
        echo -e "${cyan}Press Ctrl+C for graceful shutdown | Ctrl+\\ for emergency shutdown${reset}"
    else
        echo -e "${gray}Press Ctrl+C for graceful shutdown | Ctrl+\\ for emergency shutdown${reset}"
    fi
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

function graceful_shutdown() {
    echo -e "\n${yellow}Initiating graceful shutdown...${reset}"
    log_message "INFO: Graceful shutdown initiated by user"
    
    # Stop the monitoring loop
    cleanup_ports
    
    # Final status check
    echo -e "${cyan}Port cleanup completed.${reset}"
    echo -e "${cyan}NeoShell monitoring stopped. Goodbye!${reset}"
    
    log_message "INFO: NeoShell watcher shutdown completed"
    exit 0
}

function emergency_shutdown() {
    echo -e "\n${red}EMERGENCY SHUTDOWN TRIGGERED!${reset}"
    log_message "CRITICAL: Emergency shutdown triggered"
    
    emergency_port_release
    
    echo -e "${red}Emergency shutdown completed.${reset}"
    log_message "CRITICAL: Emergency shutdown completed"
    exit 1
}

# Enhanced trap handlers
trap 'graceful_shutdown' INT TERM
trap 'emergency_shutdown' QUIT

# Initial log entry
log_message "INFO: Not a cPanel monitor started"

# Check for port conflicts before starting
echo -e "${yellow}Checking for port conflicts...${reset}"
if command -v lsof >/dev/null 2>&1; then
    if lsof -i:$APP_PORT >/dev/null 2>&1; then
        echo -e "${red}WARNING: Port $APP_PORT is already in use!${reset}"
        log_message "WARNING: Port $APP_PORT occupied at startup"
        
        read -p "Do you want to clean up ports before starting? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cleanup_ports
            echo -e "${green}Port cleanup completed.${reset}"
        fi
    fi
fi

# Play the epic melting animation first
play_melting_animation

# Main monitoring loop
while true; do
    display_status
    check_and_log
    sleep 5
done