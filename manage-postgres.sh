#!/bin/bash

# PostgreSQL Management Script for Not a cPanel
# This script provides easy management of the PostgreSQL installation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Database configuration
DB_NAME="notacpanel"
DB_USER="notacpanel"
DB_HOST="localhost"
DB_PORT="5432"

# Load database password from config file
if [ -f "config.py" ]; then
    DB_PASS=$(grep "DB_PASSWORD" config.py | cut -d'"' -f2)
else
    echo "Error: config.py not found. Please run from the installation directory."
    exit 1
fi

if [ -z "$DB_PASS" ]; then
    echo "Error: Could not load database password from config.py"
    exit 1
fi

show_help() {
    echo "PostgreSQL Management for Not a cPanel"
    echo "======================================"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  status      - Show PostgreSQL service status"
    echo "  connect     - Connect to the database"
    echo "  backup      - Create database backup"
    echo "  restore     - Restore database from backup"
    echo "  reset       - Reset database (WARNING: deletes all data)"
    echo "  logs        - Show PostgreSQL logs"
    echo "  info        - Show database information"
    echo "  test        - Test database connection"
    echo "  help        - Show this help message"
    echo ""
}

check_postgres() {
    if ! command -v psql &> /dev/null; then
        print_error "PostgreSQL is not installed"
        exit 1
    fi
    
    if ! sudo systemctl is-active --quiet postgresql; then
        print_error "PostgreSQL service is not running"
        print_status "Start it with: sudo systemctl start postgresql"
        exit 1
    fi
}

show_status() {
    print_status "PostgreSQL Service Status:"
    sudo systemctl status postgresql --no-pager -l
    
    echo ""
    print_status "Database Connection Test:"
    if PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT version();" > /dev/null 2>&1; then
        print_success "Database connection successful"
    else
        print_error "Database connection failed"
    fi
}

connect_db() {
    print_status "Connecting to PostgreSQL database..."
    print_status "Database: $DB_NAME"
    print_status "User: $DB_USER"
    print_status "Host: $DB_HOST:$DB_PORT"
    echo ""
    PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME
}

backup_db() {
    BACKUP_FILE="notacpanel_backup_$(date +%Y%m%d_%H%M%S).sql"
    print_status "Creating database backup: $BACKUP_FILE"
    
    PGPASSWORD=$DB_PASS pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > $BACKUP_FILE
    
    if [ $? -eq 0 ]; then
        print_success "Backup created successfully: $BACKUP_FILE"
    else
        print_error "Backup failed"
        exit 1
    fi
}

restore_db() {
    if [ -z "$1" ]; then
        print_error "Please specify backup file"
        echo "Usage: $0 restore <backup_file.sql>"
        exit 1
    fi
    
    if [ ! -f "$1" ]; then
        print_error "Backup file not found: $1"
        exit 1
    fi
    
    print_warning "This will restore the database from: $1"
    print_warning "All current data will be lost!"
    read -p "Are you sure? (type 'yes' to confirm): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_status "Restore cancelled"
        exit 0
    fi
    
    print_status "Restoring database from: $1"
    PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME < "$1"
    
    if [ $? -eq 0 ]; then
        print_success "Database restored successfully"
    else
        print_error "Restore failed"
        exit 1
    fi
}

reset_db() {
    print_warning "This will completely reset the database!"
    print_warning "All data will be lost!"
    read -p "Are you sure? (type 'yes' to confirm): " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_status "Reset cancelled"
        exit 0
    fi
    
    print_status "Resetting database..."
    
    # Drop and recreate database
    sudo -u postgres psql << EOF
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\c $DB_NAME;
GRANT ALL ON SCHEMA public TO $DB_USER;
EOF
    
    print_success "Database reset complete"
}

show_logs() {
    print_status "PostgreSQL logs:"
    sudo journalctl -u postgresql -f --no-pager -n 50
}

show_info() {
    print_status "PostgreSQL Database Information:"
    echo "================================"
    echo "Database Name: $DB_NAME"
    echo "Username: $DB_USER"
    echo "Host: $DB_HOST"
    echo "Port: $DB_PORT"
    echo ""
    
    print_status "Service Status:"
    sudo systemctl is-active postgresql
    
    print_status "Database Size:"
    PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "
        SELECT 
            pg_database.datname as database_name,
            pg_size_pretty(pg_database_size(pg_database.datname)) as size
        FROM pg_database 
        WHERE datname = '$DB_NAME';"
    
    print_status "Tables:"
    PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "\dt"
}

test_connection() {
    print_status "Testing PostgreSQL connection..."
    
    if PGPASSWORD=$DB_PASS psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT 'Connection successful!' as status, version();" 2>/dev/null; then
        print_success "Database connection test passed"
    else
        print_error "Database connection test failed"
        exit 1
    fi
}

# Main script logic
case "$1" in
    status)
        check_postgres
        show_status
        ;;
    connect)
        check_postgres
        connect_db
        ;;
    backup)
        check_postgres
        backup_db
        ;;
    restore)
        check_postgres
        restore_db "$2"
        ;;
    reset)
        check_postgres
        reset_db
        ;;
    logs)
        show_logs
        ;;
    info)
        check_postgres
        show_info
        ;;
    test)
        check_postgres
        test_connection
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac