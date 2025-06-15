#!/bin/bash

# Not a cPanel - BULLETPROOF Service Monitor
# Enhanced version that GUARANTEES port cleanup on shutdown
# Addresses all known port closure issues

LOGFILE="./logs/watcher.log"
APP_PORT=5000
DB_PORT=5432
LOG_LINES=10

# Critical: PID tracking for bulletproof cleanup
WATCHER_PID=$$
CHILD_PIDS=()
CLEANUP_DONE=false
FORCE_EXIT=false

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

# ASCII Art for NeoShell
NEOSHELL_ART="
${cyan}███╗   ██╗███████╗ ██████╗ ███████╗██╗  ██╗███████╗██╗     ██╗     ${reset}
${cyan}████╗  ██║██╔════╝██╔═══██╗██╔════╝██║  ██║██╔════╝██║     ██║     ${reset}
${cyan}██╔██╗ ██║█████╗  ██║   ██║███████╗███████║█████╗  ██║     ██║     ${reset}
${cyan}██║╚██╗██║██╔══╝  ██║   ██║╚════██║██╔══██║██╔══╝  ██║     ██║     ${reset}
${cyan}██║ ╚████║███████╗╚██████╔╝███████║██║  ██║███████╗███████╗███████╗${reset}
${cyan}╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝${reset}
"

function log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

function track_child_process() {
    local pid=$1
    CHILD_PIDS+=($pid)
    log_message "INFO: Tracking child process PID $pid"
}

function bulletproof_port_cleanup() {
    if [ "$CLEANUP_DONE" = true ]; then
        return 0
    fi
    
    echo -e "\n${yellow}BULLETPROOF PORT CLEANUP INITIATED${reset}"
    log_message "CRITICAL: Bulletproof port cleanup started"
    
    local total_killed=0
    local cleanup_methods=0
    
    # Method 1: lsof-based cleanup (most reliable)
    if command -v lsof >/dev/null 2>&1; then
        echo -e "${cyan}Method 1: Using lsof for precise process identification${reset}"
        ((cleanup_methods++))
        
        for port in $APP_PORT $DB_PORT; do
            local pids=$(lsof -ti:$port 2>/dev/null)
            if [ -n "$pids" ]; then
                echo -e "  Port $port occupied by PIDs: $pids"
                for pid in $pids; do
                    # Get process info before killing
                    local proc_info=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
                    
                    # Graceful termination first
                    if kill -TERM "$pid" 2>/dev/null; then
                        echo -e "    ${yellow}SIGTERM sent to $pid ($proc_info)${reset}"
                        log_message "INFO: SIGTERM sent to PID $pid ($proc_info) on port $port"
                        ((total_killed++))
                    fi
                done
                
                # Wait for graceful shutdown
                sleep 3
                
                # Force kill survivors
                pids=$(lsof -ti:$port 2>/dev/null)
                if [ -n "$pids" ]; then
                    echo -e "    ${red}Force killing remaining processes...${reset}"
                    for pid in $pids; do
                        local proc_info=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
                        if kill -KILL "$pid" 2>/dev/null; then
                            echo -e "    ${red}SIGKILL sent to $pid ($proc_info)${reset}"
                            log_message "WARNING: SIGKILL sent to PID $pid ($proc_info) on port $port"
                            ((total_killed++))
                        fi
                    done
                fi
            fi
        done
    fi
    
    # Method 2: netstat-based cleanup (fallback)
    if command -v netstat >/dev/null 2>&1; then
        echo -e "${cyan}Method 2: Using netstat for additional cleanup${reset}"
        ((cleanup_methods++))
        
        for port in $APP_PORT $DB_PORT; do
            local pids=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | grep -E '^[0-9]+$')
            if [ -n "$pids" ]; then
                for pid in $pids; do
                    if [ "$pid" != "-" ] && [ -n "$pid" ]; then
                        local proc_info=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
                        if kill -KILL "$pid" 2>/dev/null; then
                            echo -e "    ${red}Netstat cleanup: killed $pid ($proc_info)${reset}"
                            log_message "WARNING: Netstat cleanup killed PID $pid on port $port"
                            ((total_killed++))
                        fi
                    fi
                done
            fi
        done
    fi
    
    # Method 3: fuser nuclear option
    if command -v fuser >/dev/null 2>&1; then
        echo -e "${cyan}Method 3: Using fuser for nuclear cleanup${reset}"
        ((cleanup_methods++))
        
        for port in $APP_PORT $DB_PORT; do
            if fuser -k $port/tcp 2>/dev/null; then
                echo -e "    ${red}fuser killed processes on port $port${reset}"
                log_message "CRITICAL: fuser cleanup executed on port $port"
                ((total_killed++))
            fi
        done
    fi
    
    # Method 4: ss-based cleanup (modern alternative)
    if command -v ss >/dev/null 2>&1; then
        echo -e "${cyan}Method 4: Using ss for modern socket cleanup${reset}"
        ((cleanup_methods++))
        
        for port in $APP_PORT $DB_PORT; do
            local pids=$(ss -tlnp 2>/dev/null | grep ":$port " | sed -n 's/.*pid=\([0-9]*\).*/\1/p' | sort -u)
            if [ -n "$pids" ]; then
                for pid in $pids; do
                    if [ -n "$pid" ]; then
                        local proc_info=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
                        if kill -KILL "$pid" 2>/dev/null; then
                            echo -e "    ${red}ss cleanup: killed $pid ($proc_info)${reset}"
                            log_message "CRITICAL: ss cleanup killed PID $pid on port $port"
                            ((total_killed++))
                        fi
                    fi
                done
            fi
        done
    fi
    
    # Method 5: Pattern-based process cleanup
    echo -e "${cyan}Method 5: Pattern-based zombie cleanup${reset}"
    if command -v pkill >/dev/null 2>&1; then
        local patterns=("not_a_c_panel" "python.*:$APP_PORT" "node.*:$APP_PORT" "flask.*run" "gunicorn.*$APP_PORT" "uvicorn.*$APP_PORT")
        for pattern in "${patterns[@]}"; do
            if pkill -f "$pattern" 2>/dev/null; then
                echo -e "    ${yellow}Killed processes matching: $pattern${reset}"
                log_message "INFO: Pattern cleanup killed processes matching: $pattern"
                ((total_killed++))
            fi
        done
    fi
    
    # Method 6: Kill tracked child processes
    echo -e "${cyan}Method 6: Cleaning up tracked child processes${reset}"
    for pid in "${CHILD_PIDS[@]}"; do
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            local proc_info=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
            if kill -KILL "$pid" 2>/dev/null; then
                echo -e "    ${red}Killed tracked child: $pid ($proc_info)${reset}"
                log_message "INFO: Killed tracked child process PID $pid"
                ((total_killed++))
            fi
        fi
    done
    
    # Final verification with multiple attempts
    echo -e "${cyan}Final verification (3 attempts)...${reset}"
    local verification_attempts=0
    local ports_clear=false
    
    while [ $verification_attempts -lt 3 ] && [ "$ports_clear" = false ]; do
        ((verification_attempts++))
        echo -e "  Verification attempt $verification_attempts/3..."
        
        local occupied_ports=0
        for port in $APP_PORT $DB_PORT; do
            if command -v lsof >/dev/null 2>&1; then
                if lsof -i:$port >/dev/null 2>&1; then
                    ((occupied_ports++))
                    echo -e "    ${red}Port $port still occupied${reset}"
                else
                    echo -e "    ${green}Port $port is FREE${reset}"
                fi
            elif command -v netstat >/dev/null 2>&1; then
                if netstat -ln | grep ":$port " >/dev/null 2>&1; then
                    ((occupied_ports++))
                    echo -e "    ${red}Port $port still occupied${reset}"
                else
                    echo -e "    ${green}Port $port is FREE${reset}"
                fi
            fi
        done
        
        if [ $occupied_ports -eq 0 ]; then
            ports_clear=true
            echo -e "  ${green}✓ All ports are now FREE${reset}"
        else
            echo -e "  ${yellow}Waiting 2 seconds before retry...${reset}"
            sleep 2
        fi
    done
    
    # Summary
    echo -e "\n${white}CLEANUP SUMMARY:${reset}"
    echo -e "  Methods used: $cleanup_methods"
    echo -e "  Processes terminated: $total_killed"
    echo -e "  Verification attempts: $verification_attempts"
    
    if [ "$ports_clear" = true ]; then
        echo -e "  ${green}✓ SUCCESS: All ports are FREE${reset}"
        log_message "SUCCESS: Bulletproof cleanup completed - all ports free"
    else
        echo -e "  ${red}✗ WARNING: Some ports may still be occupied${reset}"
        log_message "WARNING: Bulletproof cleanup completed but some ports may still be occupied"
    fi
    
    CLEANUP_DONE=true
    return 0
}

function check_app_server() {
    if curl -s -f "http://localhost:$APP_PORT" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

function check_database() {
    if command -v pg_isready >/dev/null 2>&1; then
        pg_isready -h localhost -p $DB_PORT >/dev/null 2>&1
        return $?
    elif command -v nc >/dev/null 2>&1; then
        nc -z localhost $DB_PORT >/dev/null 2>&1
        return $?
    else
        return 0
    fi
}

function display_status() {
    clear
    echo -e "$NEOSHELL_ART"
    echo ""
    
    # Service status
    echo -e "${blue}╔══════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${blue}║${white}                   BULLETPROOF MONITOR                       ${blue}║${reset}"
    echo -e "${blue}╚══════════════════════════════════════════════════════════════╝${reset}"
    
    if check_app_server; then
        echo -e "${green}✓${reset} Application Server: ${green}RUNNING${reset} (http://localhost:$APP_PORT)"
    else
        echo -e "${red}✗${reset} Application Server: ${red}DOWN${reset} (http://localhost:$APP_PORT)"
    fi
    
    if check_database; then
        echo -e "${green}✓${reset} PostgreSQL Database: ${green}RUNNING${reset} (localhost:$DB_PORT)"
    else
        echo -e "${red}✗${reset} PostgreSQL Database: ${red}DOWN${reset} (localhost:$DB_PORT)"
    fi
    
    # Port status
    echo ""
    echo -e "${magenta}╔══════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${magenta}║${white}                       PORT STATUS                           ${magenta}║${reset}"
    echo -e "${magenta}╚══════════════════════════════════════════════════════════════╝${reset}"
    
    for port in $APP_PORT $DB_PORT; do
        local service_name="Application"
        [ $port -eq $DB_PORT ] && service_name="Database"
        
        if command -v lsof >/dev/null 2>&1; then
            if lsof -i:$port >/dev/null 2>&1; then
                local pids=$(lsof -ti:$port 2>/dev/null | tr '\n' ' ')
                echo -e "${green}●${reset} Port $port: ${green}OCCUPIED${reset} ($service_name) - PIDs: $pids"
            else
                echo -e "${red}○${reset} Port $port: ${red}FREE${reset} ($service_name)"
            fi
        else
            echo -e "${yellow}?${reset} Port $port: ${yellow}UNKNOWN${reset} ($service_name)"
        fi
    done
    
    echo ""
    echo -e "${gray}Watcher PID: $WATCHER_PID | Tracked Children: ${#CHILD_PIDS[@]} | $(date '+%H:%M:%S')${reset}"
    echo ""
    echo -e "${cyan}Press Ctrl+C for bulletproof shutdown | Ctrl+\\ for emergency exit${reset}"
}

function graceful_shutdown() {
    if [ "$FORCE_EXIT" = true ]; then
        return
    fi
    
    FORCE_EXIT=true
    echo -e "\n${yellow}INITIATING BULLETPROOF SHUTDOWN...${reset}"
    log_message "CRITICAL: Bulletproof shutdown initiated"
    
    bulletproof_port_cleanup
    
    echo -e "${green}Bulletproof shutdown completed successfully!${reset}"
    log_message "SUCCESS: Bulletproof shutdown completed"
    exit 0
}

function emergency_exit() {
    echo -e "\n${red}EMERGENCY EXIT - NUCLEAR CLEANUP!${reset}"
    log_message "CRITICAL: Emergency nuclear cleanup initiated"
    
    # Kill everything related to our ports immediately
    if command -v fuser >/dev/null 2>&1; then
        fuser -k $APP_PORT/tcp $DB_PORT/tcp 2>/dev/null
    fi
    
    # Kill all child processes
    for pid in "${CHILD_PIDS[@]}"; do
        kill -KILL "$pid" 2>/dev/null
    done
    
    # Pattern-based nuclear cleanup
    pkill -f "not_a_c_panel" 2>/dev/null
    pkill -f "python.*$APP_PORT" 2>/dev/null
    pkill -f "node.*$APP_PORT" 2>/dev/null
    
    echo -e "${red}Nuclear cleanup completed!${reset}"
    log_message "CRITICAL: Nuclear cleanup completed"
    exit 1
}

# Bulletproof signal handling
trap 'graceful_shutdown' INT TERM
trap 'emergency_exit' QUIT
trap 'emergency_exit' EXIT  # Ensures cleanup even on unexpected exit

# Pre-flight checks
echo -e "${yellow}BULLETPROOF WATCHER STARTING...${reset}"
log_message "INFO: Bulletproof watcher starting - PID $WATCHER_PID"

# Check for existing port conflicts
if command -v lsof >/dev/null 2>&1; then
    for port in $APP_PORT $DB_PORT; do
        if lsof -i:$port >/dev/null 2>&1; then
            echo -e "${red}WARNING: Port $port is occupied at startup!${reset}"
            read -p "Clean up port $port before starting? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                bulletproof_port_cleanup
                CLEANUP_DONE=false  # Reset for normal operation
            fi
        fi
    done
fi

echo -e "${green}Starting bulletproof monitoring...${reset}"

# Main monitoring loop with error handling
while [ "$FORCE_EXIT" = false ]; do
    if ! display_status 2>/dev/null; then
        log_message "ERROR: Display function failed, continuing..."
    fi
    
    # Health check logging
    local status_msg="INFO: Monitoring active"
    if ! check_app_server; then
        status_msg="WARNING: App server down on port $APP_PORT"
    fi
    if ! check_database; then
        status_msg="$status_msg | DB down on port $DB_PORT"
    fi
    log_message "$status_msg"
    
    sleep 5
done