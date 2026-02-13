#!/usr/bin/env bash
# DuckDNS Setup and IP Update Script for Goblin Assistant
# This script configures and updates your DuckDNS domain to point to your public IP
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration file location
CONFIG_FILE="${SCRIPT_DIR}/.duckdns.conf"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck disable=SC1090
        source "$CONFIG_FILE"
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
# DuckDNS Configuration
DUCKDNS_DOMAIN="$DUCKDNS_DOMAIN"
DUCKDNS_TOKEN="$DUCKDNS_TOKEN"
EOF
    chmod 600 "$CONFIG_FILE"
    log_success "Configuration saved to $CONFIG_FILE"
}

# Setup wizard
setup_wizard() {
    log_info "DuckDNS Setup Wizard"
    echo ""
    echo "This wizard will help you configure DuckDNS for your Goblin Assistant."
    echo ""
    echo "To use DuckDNS, you need to:"
    echo "1. Go to https://www.duckdns.org"
    echo "2. Sign in with one of the supported accounts (GitHub, Google, etc.)"
    echo "3. Create a subdomain (e.g., 'goblinos-assistant' or 'goblinOS-assistant')"
    echo "4. Copy your token from the top of the page"
    echo ""
    
    # Get domain name
    read -r -p "Enter your DuckDNS subdomain (without .duckdns.org): " DUCKDNS_DOMAIN
    if [[ -z "$DUCKDNS_DOMAIN" ]]; then
        log_error "Domain name cannot be empty"
        exit 1
    fi
    
    # Get token
    read -r -p "Enter your DuckDNS token: " DUCKDNS_TOKEN
    if [[ -z "$DUCKDNS_TOKEN" ]]; then
        log_error "Token cannot be empty"
        exit 1
    fi
    
    save_config
    
    log_info "Configuration complete!"
    echo ""
    echo "Your Goblin Assistant will be accessible at: http://${DUCKDNS_DOMAIN}.duckdns.org:8000"
    echo "(Note: You'll need to set up port forwarding first. For HTTPS, see SSL/TLS setup in DUCKDNS_SETUP.md)"
}

# Update DuckDNS IP
update_ip() {
    if [[ -z "${DUCKDNS_DOMAIN:-}" ]] || [[ -z "${DUCKDNS_TOKEN:-}" ]]; then
        log_error "DuckDNS not configured. Run: $0 setup"
        exit 1
    fi
    
    log_info "Updating DuckDNS IP for ${DUCKDNS_DOMAIN}.duckdns.org"
    
    # Update DuckDNS with current public IP
    RESPONSE=$(curl -s "https://www.duckdns.org/update?domains=${DUCKDNS_DOMAIN}&token=${DUCKDNS_TOKEN}&ip=" 2>/dev/null)
    
    if [[ -z "$RESPONSE" ]]; then
        log_error "Failed to connect to DuckDNS. Check your internet connection."
        echo "$(date): ERROR - Network failure" >> "${SCRIPT_DIR}/.duckdns.log"
        exit 1
    fi
    
    if [[ "$RESPONSE" == "OK" ]]; then
        # Get current public IP for logging
        PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "unknown")
        log_success "DuckDNS updated successfully!"
        log_info "Domain: ${DUCKDNS_DOMAIN}.duckdns.org"
        log_info "Public IP: ${PUBLIC_IP}"
        echo "$(date): OK - IP updated to ${PUBLIC_IP}" >> "${SCRIPT_DIR}/.duckdns.log"
    elif [[ "$RESPONSE" == "KO" ]]; then
        log_error "DuckDNS update failed. Check your domain and token."
        echo "$(date): KO - Update failed" >> "${SCRIPT_DIR}/.duckdns.log"
        exit 1
    else
        log_error "Unexpected response: $RESPONSE"
        echo "$(date): ERROR - Unexpected response: $RESPONSE" >> "${SCRIPT_DIR}/.duckdns.log"
        exit 1
    fi
}

# Check current IP and domain status
check_status() {
    if [[ -z "${DUCKDNS_DOMAIN:-}" ]] || [[ -z "${DUCKDNS_TOKEN:-}" ]]; then
        log_error "DuckDNS not configured. Run: $0 setup"
        exit 1
    fi
    
    log_info "Checking DuckDNS status..."
    
    PUBLIC_IP=$(curl -s https://api.ipify.org 2>/dev/null || echo "unknown")
    DOMAIN_IP=$(dig +short "${DUCKDNS_DOMAIN}.duckdns.org" @8.8.8.8 2>/dev/null | tail -n1)
    
    if [[ -z "$DOMAIN_IP" ]]; then
        DOMAIN_IP="not found"
    fi
    
    echo ""
    echo "Domain: ${DUCKDNS_DOMAIN}.duckdns.org"
    echo "Current Public IP: ${PUBLIC_IP}"
    echo "Domain Points To: ${DOMAIN_IP}"
    echo ""
    
    if [[ "$PUBLIC_IP" == "$DOMAIN_IP" ]]; then
        log_success "Domain is correctly pointing to your current IP!"
    else
        log_warning "Domain IP does not match your current public IP"
        log_info "Run '$0 update' to sync"
    fi
    
    # Show recent log entries
    if [[ -f "${SCRIPT_DIR}/.duckdns.log" ]]; then
        echo ""
        log_info "Recent updates:"
        tail -5 "${SCRIPT_DIR}/.duckdns.log"
    fi
}

# Install as cron job
install_cron() {
    if [[ -z "${DUCKDNS_DOMAIN:-}" ]] || [[ -z "${DUCKDNS_TOKEN:-}" ]]; then
        log_error "DuckDNS not configured. Run: $0 setup"
        exit 1
    fi
    
    log_info "Installing DuckDNS auto-update as cron job..."
    
    CRON_CMD="*/5 * * * * ${SCRIPT_DIR}/duckdns_setup.sh update >/dev/null 2>&1"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "duckdns_setup.sh"; then
        log_warning "Cron job already exists"
        log_info "Current cron entries:"
        crontab -l | grep "duckdns_setup.sh"
    else
        # Add cron job
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        log_success "Cron job installed! DuckDNS will update every 5 minutes"
        log_info "To view cron jobs: crontab -l"
        log_info "To remove: crontab -e (then delete the line)"
    fi
}

# Install as launchd service (macOS)
install_launchd() {
    if [[ -z "${DUCKDNS_DOMAIN:-}" ]] || [[ -z "${DUCKDNS_TOKEN:-}" ]]; then
        log_error "DuckDNS not configured. Run: $0 setup"
        exit 1
    fi
    
    log_info "Installing DuckDNS auto-update as launchd service..."
    
    PLIST_FILE="$HOME/Library/LaunchAgents/com.goblinos.duckdns.plist"
    
    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.goblinos.duckdns</string>
  <key>ProgramArguments</key>
  <array>
    <string>${SCRIPT_DIR}/duckdns_setup.sh</string>
    <string>update</string>
  </array>
  <key>StartInterval</key>
  <integer>300</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/tmp/duckdns.out.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/duckdns.err.log</string>
</dict>
</plist>
EOF
    
    launchctl load "$PLIST_FILE" 2>/dev/null || true
    
    log_success "Launchd service installed! DuckDNS will update every 5 minutes"
    log_info "Service file: $PLIST_FILE"
    log_info "To unload: launchctl unload $PLIST_FILE"
}

# Show usage
show_usage() {
    cat << EOF
DuckDNS Setup and Update Script for Goblin Assistant

Usage: $0 <command>

Commands:
  setup       Run the setup wizard to configure DuckDNS
  update      Update DuckDNS with your current public IP
  status      Check current IP and domain status
  cron        Install as a cron job (updates every 5 minutes)
  launchd     Install as a launchd service (macOS, updates every 5 minutes)
  help        Show this help message

Examples:
  $0 setup          # First time setup
  $0 update         # Manually update IP
  $0 status         # Check if domain is pointing to correct IP
  $0 cron           # Install auto-update via cron
  $0 launchd        # Install auto-update via launchd (macOS)

For more information, see: https://www.duckdns.org
EOF
}

# Main execution
main() {
    load_config
    
    case "${1:-}" in
        setup)
            setup_wizard
            ;;
        update)
            update_ip
            ;;
        status)
            check_status
            ;;
        cron)
            install_cron
            ;;
        launchd)
            install_launchd
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            if [[ -z "${1:-}" ]]; then
                log_error "No command specified"
            else
                log_error "Unknown command: $1"
            fi
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
