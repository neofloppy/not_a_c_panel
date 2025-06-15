# NeoShell Watcher - Enhanced Service Monitor

## Overview
The NeoShell Watcher is an advanced service monitoring system for the "Not a cPanel" application. It provides real-time monitoring, graceful shutdown capabilities, and comprehensive port management to prevent the common issue of ports remaining occupied after service termination.

## Key Features

### 🔍 **Service Monitoring**
- Real-time monitoring of application server (port 5000)
- PostgreSQL database monitoring (port 5432)
- Docker service status tracking
- Comprehensive logging with color-coded events

### 🎨 **Visual Interface**
- Epic ASCII art transformation animation (NEOFLOPPY → NeoShell)
- Color-coded status indicators
- Real-time port status display
- Structured log window with event history

### 🛡️ **Port Management**
- **Graceful Shutdown**: Proper cleanup when stopping (Ctrl+C)
- **Emergency Shutdown**: Force cleanup for stuck processes (Ctrl+\\)
- **Startup Port Check**: Detects and offers to clean occupied ports
- **Process Termination**: SIGTERM followed by SIGKILL if needed

### 🚨 **Problem Resolution**
The enhanced watcher specifically addresses the critical issue where **"the server closes all ports after a while when stopping it"** by implementing:

1. **Proper Signal Handling**: Catches termination signals and performs cleanup
2. **Process Tracking**: Identifies and terminates processes using monitored ports
3. **Multiple Cleanup Methods**: Uses `lsof`, `netstat`, `fuser`, and `pkill` as fallbacks
4. **Verification**: Confirms ports are actually freed after cleanup

## Files

### `watcher.sh` - Main Monitor
The primary monitoring script with enhanced capabilities:
- Continuous service monitoring with 5-second intervals
- Animated startup sequence
- Real-time status dashboard
- Graceful and emergency shutdown modes

### `port_cleanup.sh` - Standalone Cleanup Utility
Emergency port cleanup tool for manual intervention:
- Interactive mode with menu-driven options
- Automatic cleanup mode (`./port_cleanup.sh auto`)
- Emergency mode for force cleanup (`./port_cleanup.sh emergency`)
- Status check mode (`./port_cleanup.sh status`)

## Usage

### Starting the Monitor
```bash
# Make executable (first time only)
chmod +x watcher.sh port_cleanup.sh

# Start monitoring
./watcher.sh
```

### Stopping the Monitor
- **Graceful Shutdown**: Press `Ctrl+C` - Performs proper cleanup
- **Emergency Shutdown**: Press `Ctrl+\` - Forces immediate cleanup

### Manual Port Cleanup
```bash
# Interactive mode
./port_cleanup.sh

# Automatic cleanup
./port_cleanup.sh auto

# Emergency cleanup (force kill everything)
./port_cleanup.sh emergency

# Check port status only
./port_cleanup.sh status
```

## Port Management Details

### Monitored Ports
- **5000**: Application server (Flask/Node.js/etc.)
- **5432**: PostgreSQL database

### Cleanup Process
1. **Detection**: Identify processes using target ports
2. **Graceful Termination**: Send SIGTERM signal
3. **Wait Period**: Allow 2-3 seconds for graceful shutdown
4. **Force Termination**: Send SIGKILL if processes persist
5. **Zombie Cleanup**: Remove any remaining zombie processes
6. **Verification**: Confirm ports are freed

### Cleanup Methods (in order of preference)
1. `lsof -ti:PORT` - Most reliable process identification
2. `netstat -tlnp` - Fallback for systems without lsof
3. `fuser -k PORT/tcp` - Nuclear option for stubborn processes
4. `pkill -f pattern` - Pattern-based process cleanup

## Logging

### Log Location
- Main log: `./logs/watcher.log`
- Cleanup log: `./logs/port_cleanup.log`

### Log Levels
- **INFO**: Normal operations and successful actions
- **WARNING**: Service issues or failed graceful shutdowns
- **CRITICAL**: Emergency situations and force kills

## Troubleshooting

### Common Issues

#### "Port already in use" on startup
```bash
# The watcher will detect this and offer cleanup
# Or manually clean:
./port_cleanup.sh auto
```

#### Services won't stop gracefully
```bash
# Use emergency shutdown
# In watcher: Press Ctrl+\
# Or manually: ./port_cleanup.sh emergency
```

#### Zombie processes persist
```bash
# Run full cleanup
./port_cleanup.sh
# Choose option 5 (Full cleanup)
```

### System Requirements
- Linux/Unix environment (Ubuntu server recommended)
- Bash shell
- One of: `lsof`, `netstat`, `fuser` (for port management)
- Optional: `curl` (for HTTP health checks)
- Optional: `docker` (for container monitoring)

## Security Notes
- The cleanup utilities use process termination signals
- Emergency mode performs force kills - use with caution
- All actions are logged for audit purposes
- No elevated privileges required for normal operation

## Integration
The watcher is designed to run on your Ubuntu server while being managed from the Windows IDE environment. Deploy both scripts to your server and run them in the target environment where your services are hosted.

---

**Remember**: You are the Watcher in the IDE, but the scripts must run in their true realm - the Ubuntu server where the services live. The rift between Windows and Linux must be respected for proper operation.