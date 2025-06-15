#!/bin/bash

# Port Cleanup Utility for Not a cPanel
# Emergency port release tool for when services don't shut down properly

# Configuration
APP_PORT=5000
DB_PORT=5432
LOGFILE="./logs/port_cleanup.log"

# Colors
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
white='\033[1;37m'
reset='\033[0m'

# Create logs directory if it doesn't exist
mkdir -p logs

function log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

function show_banner() {
    clear
    echo -e "${red}╔══════════════════════════════════════════════════════════════╗${reset}"
    echo -e "${red}║${white}                    PORT CLEANUP UTILITY                     ${red}║${reset}"
    echo -e "${red}║${white}                   Emergency Port Release                   ${red}║${reset}"
    echo -e "${red}╚══════════════════════════════════════════════════════════════╝${reset}"
    echo ""
}

function check_port_status() {
    local port=$1
    local service_name=$2
    
    if command -v lsof >/dev/null 2>&1; then
        local pids=$(lsof -ti:$port 2>/dev/null)
        if [ -n "$pids" ]; then
            echo -e "${red}●${reset} Port $port ($service_name): ${red}OCCUPIED${reset} - PIDs: $pids"
            return 1
        else
            echo -e "${green}○${reset} Port $port ($service_name): ${green}FREE${reset}"
            return 0
        fi
    elif command -v netstat >/dev/null 2>&1; then
        if netstat -ln | grep ":$port " >/dev/null 2>&1; then
            echo -e "${red}●${reset} Port $port ($service_name): ${red}OCCUPIED${reset}"
            return 1
        else
            echo -e "${green}○${reset} Port $port ($service_name): ${green}FREE${reset}"
            return 0
        fi
    else
        echo -e "${yellow}?${reset} Port $port ($service_name): ${yellow}UNKNOWN${reset} (no tools available)"
        return 2
    fi
}

function kill_port_processes() {
    local port=$1
    local service_name=$2
    local killed_count=0
    
    echo -e "\n${yellow}Cleaning up port $port ($service_name)...${reset}"
    log_message "INFO: Starting cleanup for port $port ($service_name)"
    
    if command -v lsof >/dev/null 2>&1; then
        local pids=$(lsof -ti:$port 2>/dev/null)
        if [ -n "$pids" ]; then
            echo -e "Found processes: $pids"
            
            # First try graceful termination
            for pid in $pids; do
                if kill -TERM "$pid" 2>/dev/null; then
                    echo -e "  ${yellow}Sent SIGTERM to PID $pid${reset}"
                    log_message "INFO: Sent SIGTERM to PID $pid on port $port"
                    ((killed_count++))
                fi
            done
            
            # Wait for graceful shutdown
            echo -e "  Waiting 3 seconds for graceful shutdown..."
            sleep 3
            
            # Check if any processes are still running
            pids=$(lsof -ti:$port 2>/dev/null)
            if [ -n "$pids" ]; then
                echo -e "  ${red}Some processes still running, force killing...${reset}"
                for pid in $pids; do
                    if kill -KILL "$pid" 2>/dev/null; then
                        echo -e "  ${red}Force killed PID $pid${reset}"
                        log_message "WARNING: Force killed PID $pid on port $port"
                        ((killed_count++))
                    fi
                done
            fi
        fi
    fi
    
    # Alternative cleanup methods
    if command -v fuser >/dev/null 2>&1; then
        echo -e "  Using fuser as backup cleanup method..."
        if fuser -k $port/tcp 2>/dev/null; then
            echo -e "  ${green}fuser cleanup completed${reset}"
            log_message "INFO: fuser cleanup completed for port $port"
        fi
    fi
    
    # Final verification
    sleep 1
    if check_port_status $port "$service_name" >/dev/null; then
        echo -e "  ${green}✓ Port $port is now FREE${reset}"
        log_message "INFO: Port $port cleanup successful"
    else
        echo -e "  ${red}✗ Port $port may still be occupied${reset}"
        log_message "WARNING: Port $port cleanup may have failed"
    fi
    
    return $killed_count
}

function cleanup_zombie_processes() {
    echo -e "\n${cyan}Cleaning up zombie processes...${reset}"
    
    if command -v pkill >/dev/null 2>&1; then
        pkill -f "not_a_c_panel" 2>/dev/null && echo -e "  Killed not_a_c_panel processes"
        pkill -f "python.*5000" 2>/dev/null && echo -e "  Killed Python processes on port 5000"
        pkill -f "node.*5000" 2>/dev/null && echo -e "  Killed Node.js processes on port 5000"
        pkill -f "flask.*5000" 2>/dev/null && echo -e "  Killed Flask processes on port 5000"
    fi
    
    log_message "INFO: Zombie process cleanup completed"
}

function interactive_mode() {
    show_banner
    
    echo -e "${blue}Current port status:${reset}"
    check_port_status $APP_PORT "Application"
    check_port_status $DB_PORT "Database"
    
    echo ""
    echo -e "${white}Available actions:${reset}"
    echo -e "  ${green}1${reset}) Clean up application port ($APP_PORT)"
    echo -e "  ${green}2${reset}) Clean up database port ($DB_PORT)"
    echo -e "  ${green}3${reset}) Clean up both ports"
    echo -e "  ${green}4${reset}) Clean up zombie processes"
    echo -e "  ${green}5${reset}) Full cleanup (all of the above)"
    echo -e "  ${green}6${reset}) Check status only"
    echo -e "  ${red}q${reset}) Quit"
    echo ""
    
    read -p "Choose an action [1-6,q]: " -n 1 -r choice
    echo ""
    
    case $choice in
        1)
            kill_port_processes $APP_PORT "Application"
            ;;
        2)
            kill_port_processes $DB_PORT "Database"
            ;;
        3)
            kill_port_processes $APP_PORT "Application"
            kill_port_processes $DB_PORT "Database"
            ;;
        4)
            cleanup_zombie_processes
            ;;
        5)
            kill_port_processes $APP_PORT "Application"
            kill_port_processes $DB_PORT "Database"
            cleanup_zombie_processes
            echo -e "\n${green}Full cleanup completed!${reset}"
            ;;
        6)
            echo -e "\n${blue}Current status:${reset}"
            check_port_status $APP_PORT "Application"
            check_port_status $DB_PORT "Database"
            ;;
        q|Q)
            echo -e "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${red}Invalid choice!${reset}"
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..." -r
    interactive_mode
}

function emergency_cleanup() {
    show_banner
    echo -e "${red}EMERGENCY CLEANUP MODE${reset}"
    echo -e "${yellow}This will forcefully kill ALL processes on monitored ports!${reset}"
    echo ""
    
    read -p "Are you sure you want to proceed? (type 'YES' to confirm): " -r confirm
    if [ "$confirm" = "YES" ]; then
        log_message "CRITICAL: Emergency cleanup initiated"
        
        kill_port_processes $APP_PORT "Application"
        kill_port_processes $DB_PORT "Database"
        cleanup_zombie_processes
        
        echo -e "\n${red}Emergency cleanup completed!${reset}"
        log_message "CRITICAL: Emergency cleanup completed"
    else
        echo -e "Emergency cleanup cancelled."
    fi
}

# Main execution
case "${1:-interactive}" in
    "emergency"|"-e"|"--emergency")
        emergency_cleanup
        ;;
    "auto"|"-a"|"--auto")
        show_banner
        echo -e "${cyan}Running automatic cleanup...${reset}"
        kill_port_processes $APP_PORT "Application"
        kill_port_processes $DB_PORT "Database"
        cleanup_zombie_processes
        echo -e "\n${green}Automatic cleanup completed!${reset}"
        ;;
    "status"|"-s"|"--status")
        show_banner
        echo -e "${blue}Port Status Check:${reset}"
        check_port_status $APP_PORT "Application"
        check_port_status $DB_PORT "Database"
        ;;
    *)
        interactive_mode
        ;;
esac