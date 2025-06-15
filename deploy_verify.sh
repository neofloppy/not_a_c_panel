#!/bin/bash

# Deployment Verification Script for Fresh Ubuntu Server
# Ensures all tools and configurations are properly set up

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                 DEPLOYMENT VERIFICATION                      ║"
echo "║                   Fresh Ubuntu Server                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
green='\033[0;32m'
red='\033[0;31m'
yellow='\033[1;33m'
blue='\033[0;34m'
cyan='\033[0;36m'
white='\033[1;37m'
reset='\033[0m'

VERIFICATION_LOG="./logs/deployment_verification.log"
mkdir -p logs

function log_check() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$VERIFICATION_LOG"
}

function check_tool() {
    local tool=$1
    local description=$2
    local critical=${3:-false}
    
    if command -v "$tool" >/dev/null 2>&1; then
        echo -e "${green}✓${reset} $tool: Available ($description)"
        log_check "SUCCESS: $tool is available"
        return 0
    else
        if [ "$critical" = true ]; then
            echo -e "${red}✗${reset} $tool: MISSING - $description (CRITICAL)"
            log_check "CRITICAL: $tool is missing"
        else
            echo -e "${yellow}⚠${reset} $tool: Missing - $description (Optional)"
            log_check "WARNING: $tool is missing"
        fi
        return 1
    fi
}

function check_port() {
    local port=$1
    local service=$2
    
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i:$port >/dev/null 2>&1; then
            local pids=$(lsof -ti:$port 2>/dev/null | tr '\n' ' ')
            echo -e "${yellow}⚠${reset} Port $port: OCCUPIED by PIDs: $pids ($service)"
            log_check "WARNING: Port $port is occupied at deployment check"
            return 1
        else
            echo -e "${green}✓${reset} Port $port: FREE ($service)"
            log_check "SUCCESS: Port $port is free"
            return 0
        fi
    else
        echo -e "${blue}?${reset} Port $port: Cannot check - lsof not available ($service)"
        log_check "INFO: Cannot check port $port - lsof unavailable"
        return 2
    fi
}

function install_missing_tools() {
    echo -e "\n${cyan}Checking if we can install missing tools...${reset}"
    
    if [ "$EUID" -eq 0 ] || command -v sudo >/dev/null 2>&1; then
        echo -e "${green}Root access or sudo available - can install packages${reset}"
        
        # Update package list
        echo -e "${yellow}Updating package list...${reset}"
        if command -v apt >/dev/null 2>&1; then
            sudo apt update >/dev/null 2>&1
            
            # Install critical tools
            local tools_to_install=()
            
            if ! command -v lsof >/dev/null 2>&1; then
                tools_to_install+=("lsof")
            fi
            if ! command -v curl >/dev/null 2>&1; then
                tools_to_install+=("curl")
            fi
            if ! command -v netstat >/dev/null 2>&1; then
                tools_to_install+=("net-tools")
            fi
            
            if [ ${#tools_to_install[@]} -gt 0 ]; then
                echo -e "${yellow}Installing: ${tools_to_install[*]}${reset}"
                sudo apt install -y "${tools_to_install[@]}" >/dev/null 2>&1
                echo -e "${green}Installation completed${reset}"
            fi
        fi
    else
        echo -e "${red}No root access - cannot install missing tools${reset}"
        echo -e "${yellow}Please install manually: lsof curl net-tools${reset}"
    fi
}

function test_cleanup_capabilities() {
    echo -e "\n${cyan}Testing port cleanup capabilities...${reset}"
    
    # Test with a dummy process on a high port
    local test_port=9999
    
    # Start a dummy server
    echo -e "${yellow}Starting test server on port $test_port...${reset}"
    python3 -c "
import socket
import time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('localhost', $test_port))
s.listen(1)
print('Test server started')
time.sleep(30)
" &
    local test_pid=$!
    
    sleep 2
    
    # Check if port is occupied
    if command -v lsof >/dev/null 2>&1; then
        if lsof -i:$test_port >/dev/null 2>&1; then
            echo -e "${green}✓${reset} Test server is running on port $test_port"
            
            # Test cleanup
            echo -e "${yellow}Testing cleanup on port $test_port...${reset}"
            local pids=$(lsof -ti:$test_port 2>/dev/null)
            if [ -n "$pids" ]; then
                for pid in $pids; do
                    if kill -TERM "$pid" 2>/dev/null; then
                        echo -e "${green}✓${reset} Successfully sent SIGTERM to PID $pid"
                        sleep 1
                        if ! kill -0 "$pid" 2>/dev/null; then
                            echo -e "${green}✓${reset} Process terminated gracefully"
                        else
                            kill -KILL "$pid" 2>/dev/null
                            echo -e "${yellow}⚠${reset} Had to force kill process"
                        fi
                    fi
                done
            fi
            
            # Verify cleanup
            sleep 1
            if ! lsof -i:$test_port >/dev/null 2>&1; then
                echo -e "${green}✓${reset} Port cleanup test PASSED"
                log_check "SUCCESS: Port cleanup test passed"
            else
                echo -e "${red}✗${reset} Port cleanup test FAILED"
                log_check "ERROR: Port cleanup test failed"
            fi
        else
            echo -e "${red}✗${reset} Test server failed to start"
        fi
    else
        echo -e "${yellow}⚠${reset} Cannot test cleanup - lsof not available"
    fi
    
    # Clean up test process
    kill -KILL $test_pid 2>/dev/null
}

# Start verification
echo -e "${blue}Starting deployment verification...${reset}"
log_check "INFO: Deployment verification started"

echo -e "\n${white}1. SYSTEM INFORMATION${reset}"
echo -e "OS: $(uname -s) $(uname -r)"
echo -e "Architecture: $(uname -m)"
echo -e "User: $(whoami)"
echo -e "Working Directory: $(pwd)"

echo -e "\n${white}2. CRITICAL TOOLS CHECK${reset}"
check_tool "lsof" "Process and port monitoring" true
check_tool "curl" "HTTP health checks" true
check_tool "kill" "Process termination" true
check_tool "ps" "Process information" true

echo -e "\n${white}3. OPTIONAL TOOLS CHECK${reset}"
check_tool "netstat" "Network statistics (fallback)" false
check_tool "fuser" "File/port usage (nuclear option)" false
check_tool "ss" "Socket statistics (modern)" false
check_tool "pkill" "Pattern-based process killing" false
check_tool "nc" "Network connectivity testing" false
check_tool "telnet" "Port connectivity testing" false

echo -e "\n${white}4. PORT AVAILABILITY CHECK${reset}"
check_port 5000 "Application Server"
check_port 5432 "PostgreSQL Database"

echo -e "\n${white}5. FILE PERMISSIONS CHECK${reset}"
for script in "watcher.sh" "watcher_bulletproof.sh" "port_cleanup.sh"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            echo -e "${green}✓${reset} $script: Executable"
        else
            echo -e "${yellow}⚠${reset} $script: Not executable - fixing..."
            chmod +x "$script"
            echo -e "${green}✓${reset} $script: Made executable"
        fi
    else
        echo -e "${red}✗${reset} $script: File not found"
    fi
done

echo -e "\n${white}6. DIRECTORY STRUCTURE CHECK${reset}"
if [ -d "logs" ]; then
    echo -e "${green}✓${reset} logs directory exists"
else
    echo -e "${yellow}⚠${reset} logs directory missing - creating..."
    mkdir -p logs
    echo -e "${green}✓${reset} logs directory created"
fi

# Install missing tools if possible
install_missing_tools

# Test cleanup capabilities
test_cleanup_capabilities

echo -e "\n${white}7. FINAL RECOMMENDATIONS${reset}"

# Check if critical tools are missing
missing_critical=false
if ! command -v lsof >/dev/null 2>&1; then
    echo -e "${red}⚠${reset} CRITICAL: Install lsof: sudo apt install lsof"
    missing_critical=true
fi
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${red}⚠${reset} CRITICAL: Install curl: sudo apt install curl"
    missing_critical=true
fi

if [ "$missing_critical" = false ]; then
    echo -e "${green}✓${reset} All critical tools are available"
    echo -e "${green}✓${reset} System is ready for bulletproof monitoring"
    echo -e "\n${cyan}DEPLOYMENT STATUS: ${green}READY${reset}"
    echo -e "${cyan}Recommended script: ${white}./watcher_bulletproof.sh${reset}"
else
    echo -e "${red}✗${reset} Missing critical tools - install them first"
    echo -e "\n${cyan}DEPLOYMENT STATUS: ${red}NOT READY${reset}"
fi

echo -e "\n${white}8. USAGE INSTRUCTIONS${reset}"
echo -e "1. Make scripts executable: ${yellow}chmod +x *.sh${reset}"
echo -e "2. Start monitoring: ${yellow}./watcher_bulletproof.sh${reset}"
echo -e "3. Graceful shutdown: ${yellow}Ctrl+C${reset}"
echo -e "4. Emergency shutdown: ${yellow}Ctrl+\\${reset}"
echo -e "5. Manual cleanup: ${yellow}./port_cleanup.sh${reset}"

log_check "INFO: Deployment verification completed"
echo -e "\n${blue}Verification log saved to: $VERIFICATION_LOG${reset}"