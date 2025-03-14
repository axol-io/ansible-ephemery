#!/bin/bash
#
# Validator Alerts System Setup Script
# This script installs and configures the Advanced Validator Performance Monitoring alerts system
#
# Usage: ./setup_validator_alerts.sh [options]
# Options:
#   --base-dir DIR         Base directory (default: /opt/ephemery)
#   --config-file FILE     Configuration file path
#   --with-email           Configure email notifications
#   --with-webhook URL     Configure webhook notifications to URL
#   --with-telegram        Configure Telegram notifications
#   --with-discord URL     Configure Discord webhook notifications
#   --help                 Show this help message

set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common functions if available
COMMON_SCRIPT="${REPO_ROOT}/scripts/utilities/common_functions.sh"
if [[ -f "$COMMON_SCRIPT" ]]; then
    source "$COMMON_SCRIPT"
else
    # Define minimal required functions if common_functions.sh is not available
    function log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
    function log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
    function log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" >&2; }
    function log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
    function log_debug() { if $VERBOSE; then echo -e "${CYAN}[DEBUG]${NC} $*"; fi; }
fi

# Default values
BASE_DIR="/opt/ephemery"
ALERTS_DIR="${BASE_DIR}/validator_metrics/alerts"
CONFIG_DIR="${BASE_DIR}/config"
PROMETHEUS_CONFIG="${CONFIG_DIR}/prometheus.yml"
GRAFANA_DIR="${BASE_DIR}/grafana"
DASHBOARDS_DIR="${GRAFANA_DIR}/dashboards"
SCRIPTS_DIR="${BASE_DIR}/scripts"
WITH_EMAIL=false
WITH_WEBHOOK=false
WITH_TELEGRAM=false
WITH_DISCORD=false
WEBHOOK_URL=""
DISCORD_URL=""
VERBOSE=false
CONFIG_FILE=""
AUTO_RESTART_SERVICES=true

# Script version
VERSION="1.0.0"

# Show banner
function show_banner() {
    echo -e "${BLUE}=============================================================${NC}"
    echo -e "${BLUE}       Validator Alerts System Setup Script v${VERSION}      ${NC}"
    echo -e "${BLUE}=============================================================${NC}"
    echo -e "This script installs and configures the Advanced Validator"
    echo -e "Performance Monitoring alerts system for Ephemery nodes."
    echo -e "${BLUE}=============================================================${NC}"
    echo ""
}

# Show usage information
function show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --base-dir DIR         Base directory (default: ${BASE_DIR})"
    echo "  --config-file FILE     Configuration file path"
    echo "  --with-email           Configure email notifications"
    echo "  --with-webhook URL     Configure webhook notifications to URL"
    echo "  --with-telegram        Configure Telegram notifications"
    echo "  --with-discord URL     Configure Discord webhook notifications"
    echo "  --no-restart           Don't restart services after configuration"
    echo "  --verbose              Enable verbose output"
    echo "  --help                 Show this help message"
    echo ""
}

# Parse command line arguments
function parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base-dir)
                BASE_DIR="$2"
                ALERTS_DIR="${BASE_DIR}/validator_metrics/alerts"
                CONFIG_DIR="${BASE_DIR}/config"
                PROMETHEUS_CONFIG="${CONFIG_DIR}/prometheus.yml"
                GRAFANA_DIR="${BASE_DIR}/grafana"
                DASHBOARDS_DIR="${GRAFANA_DIR}/dashboards"
                SCRIPTS_DIR="${BASE_DIR}/scripts"
                shift 2
                ;;
            --config-file)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --with-email)
                WITH_EMAIL=true
                shift
                ;;
            --with-webhook)
                WITH_WEBHOOK=true
                WEBHOOK_URL="$2"
                shift 2
                ;;
            --with-telegram)
                WITH_TELEGRAM=true
                shift
                ;;
            --with-discord)
                WITH_DISCORD=true
                DISCORD_URL="$2"
                shift 2
                ;;
            --no-restart)
                AUTO_RESTART_SERVICES=false
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_banner
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check dependencies
function check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq and try again."
        log_info "On Ubuntu/Debian: sudo apt-get install jq"
        log_info "On CentOS/RHEL: sudo yum install jq"
        exit 1
    fi
    
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        log_error "curl is not installed. Please install curl and try again."
        log_info "On Ubuntu/Debian: sudo apt-get install curl"
        log_info "On CentOS/RHEL: sudo yum install curl"
        exit 1
    fi
    
    # Check if systemctl is available
    if ! command -v systemctl &> /dev/null; then
        log_warning "systemctl is not available. Service management will be skipped."
        AUTO_RESTART_SERVICES=false
    fi
    
    log_success "All required dependencies are installed."
}

# Create directories
function create_directories() {
    log_info "Creating required directories..."
    
    mkdir -p "${ALERTS_DIR}"
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${DASHBOARDS_DIR}"
    mkdir -p "${SCRIPTS_DIR}"
    
    log_success "Directories created successfully."
}

# Copy alert script
function install_alert_script() {
    log_info "Installing validator alerts script..."
    
    # Copy the validator alerts script to the scripts directory
    cp "${SCRIPT_DIR}/validator_alerts_system.sh" "${SCRIPTS_DIR}/"
    chmod +x "${SCRIPTS_DIR}/validator_alerts_system.sh"
    
    log_success "Validator alerts script installed successfully."
}

# Create alert configuration
function create_alert_config() {
    log_info "Creating alert configuration..."
    
    if [[ -n "${CONFIG_FILE}" && -f "${CONFIG_FILE}" ]]; then
        log_info "Using provided configuration file: ${CONFIG_FILE}"
        cp "${CONFIG_FILE}" "${ALERTS_DIR}/alerts_config.json"
    else
        # Create default configuration
        cat > "${ALERTS_DIR}/alerts_config.json" << EOF
{
    "alert_thresholds": {
        "attestation_performance": 90,
        "proposal_performance": 100,
        "balance_decrease": 0.02,
        "sync_status": 50,
        "peer_count": 10,
        "cpu_usage": 80,
        "memory_usage": 80,
        "disk_usage": 80
    },
    "notification_settings": {
        "email": {
            "enabled": $([ "$WITH_EMAIL" = true ] && echo "true" || echo "false"),
            "smtp_server": "smtp.example.com",
            "smtp_port": 587,
            "username": "user@example.com",
            "password": "",
            "recipients": ["admin@example.com"]
        },
        "webhook": {
            "enabled": $([ "$WITH_WEBHOOK" = true ] && echo "true" || echo "false"),
            "url": "${WEBHOOK_URL}"
        },
        "telegram": {
            "enabled": $([ "$WITH_TELEGRAM" = true ] && echo "true" || echo "false"),
            "bot_token": "",
            "chat_id": ""
        },
        "discord": {
            "enabled": $([ "$WITH_DISCORD" = true ] && echo "true" || echo "false"),
            "webhook_url": "${DISCORD_URL}"
        }
    },
    "alert_settings": {
        "notification_levels": {
            "info": false,
            "warning": true,
            "error": true,
            "critical": true
        },
        "cooldown_periods": {
            "info": 3600,
            "warning": 1800,
            "error": 900,
            "critical": 300
        }
    },
    "system_settings": {
        "check_interval": 300,
        "history_retention_days": 30,
        "log_level": "info"
    }
}
EOF
    fi
    
    log_success "Alert configuration created successfully."
}

# Configure Prometheus for alerts
function configure_prometheus() {
    log_info "Configuring Prometheus for validator alerts..."
    
    if [[ ! -f "${PROMETHEUS_CONFIG}" ]]; then
        log_warning "Prometheus configuration file not found at ${PROMETHEUS_CONFIG}. Creating a new one."
        mkdir -p "$(dirname "${PROMETHEUS_CONFIG}")"
        cat > "${PROMETHEUS_CONFIG}" << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'validator'
    static_configs:
      - targets: ['localhost:8081']

  - job_name: 'beacon'
    static_configs:
      - targets: ['localhost:8080']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF
    fi
    
    # Add validator_alerts job if it doesn't exist
    if ! grep -q "job_name: 'validator_alerts'" "${PROMETHEUS_CONFIG}"; then
        log_info "Adding validator_alerts job to Prometheus configuration..."
        # Create a temporary file
        TEMP_FILE=$(mktemp)
        
        # Extract the scrape_configs section up to the last closing bracket
        sed -n '/scrape_configs:/,/^$/p' "${PROMETHEUS_CONFIG}" > "${TEMP_FILE}"
        
        # Add our new job
        cat >> "${TEMP_FILE}" << EOF
  - job_name: 'validator_alerts'
    static_configs:
      - targets: ['localhost:9877']
    scrape_interval: 30s
EOF
        
        # Create a new config with the updated scrape_configs
        # First, get everything before scrape_configs
        grep -B 1000 "scrape_configs:" "${PROMETHEUS_CONFIG}" | head -n -1 > "${PROMETHEUS_CONFIG}.new"
        
        # Add the updated scrape_configs section
        cat "${TEMP_FILE}" >> "${PROMETHEUS_CONFIG}.new"
        
        # Get everything after the scrape_configs section
        grep -A 1000 -m 1 "^$" "${PROMETHEUS_CONFIG}" | tail -n +2 >> "${PROMETHEUS_CONFIG}.new"
        
        # Replace the old config with the new one
        mv "${PROMETHEUS_CONFIG}.new" "${PROMETHEUS_CONFIG}"
        
        # Clean up
        rm "${TEMP_FILE}"
    else
        log_info "validator_alerts job already exists in Prometheus configuration."
    fi
    
    log_success "Prometheus configured successfully for validator alerts."
}

# Install Grafana dashboard
function install_grafana_dashboard() {
    log_info "Installing Grafana dashboard for validator alerts..."
    
    # Copy the dashboard JSON file to the Grafana dashboards directory
    cp "${REPO_ROOT}/dashboard/grafana/advanced_validator_monitoring.json" "${DASHBOARDS_DIR}/"
    
    # Check if Grafana provisioning is set up
    if [[ -d "${GRAFANA_DIR}/provisioning/dashboards" ]]; then
        log_info "Setting up Grafana dashboard provisioning..."
        
        # Create a provisioning configuration if it doesn't exist
        if [[ ! -f "${GRAFANA_DIR}/provisioning/dashboards/validator_alerts.yaml" ]]; then
            cat > "${GRAFANA_DIR}/provisioning/dashboards/validator_alerts.yaml" << EOF
apiVersion: 1

providers:
  - name: 'validator_alerts'
    orgId: 1
    folder: 'Ephemery'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    options:
      path: ${DASHBOARDS_DIR}
      foldersFromFilesStructure: true
EOF
        fi
    else
        log_warning "Grafana provisioning directory not found. You'll need to import the dashboard manually."
        log_info "Dashboard JSON file has been copied to: ${DASHBOARDS_DIR}/advanced_validator_monitoring.json"
    fi
    
    log_success "Grafana dashboard installed successfully."
}

# Create systemd service
function create_systemd_service() {
    log_info "Creating systemd service for validator alerts..."
    
    # Create the systemd service file
    cat > "/etc/systemd/system/validator-alerts.service" << EOF
[Unit]
Description=Validator Alerts System
After=network.target
Wants=prometheus.service

[Service]
Type=simple
User=root
ExecStart=${SCRIPTS_DIR}/validator_alerts_system.sh --interval 300
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start the service
    if [[ "${AUTO_RESTART_SERVICES}" == "true" ]]; then
        log_info "Enabling and starting validator alerts service..."
        systemctl daemon-reload
        systemctl enable validator-alerts.service
        systemctl start validator-alerts.service
        
        # Restart Prometheus and Grafana if they exist
        if systemctl list-units --type=service | grep -q prometheus; then
            log_info "Restarting Prometheus service..."
            systemctl restart prometheus
        fi
        
        if systemctl list-units --type=service | grep -q grafana-server; then
            log_info "Restarting Grafana service..."
            systemctl restart grafana-server
        fi
    else
        log_info "Skipping service restart as requested."
        log_info "To manually start the service, run: systemctl start validator-alerts.service"
    fi
    
    log_success "Systemd service created successfully."
}

# Create Prometheus alert exporter
function create_prometheus_exporter() {
    log_info "Creating Prometheus alert exporter script..."
    
    # Create the exporter script that exposes alerts to Prometheus
    cat > "${SCRIPTS_DIR}/validator_alerts_exporter.py" << EOF
#!/usr/bin/env python3
"""
Validator Alerts Prometheus Exporter
This script reads alerts from the JSON file and exposes them as Prometheus metrics
"""

import json
import time
import os
import http.server
import socketserver
from http import HTTPStatus
from datetime import datetime

# Configuration
ALERTS_FILE = "${ALERTS_DIR}/alerts.json"
METRICS_PORT = 9877
UPDATE_INTERVAL = 10  # seconds

class MetricsHandler(http.server.SimpleHTTPRequestHandler):
    """Handler for metrics endpoint"""
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/metrics':
            self.send_response(HTTPStatus.OK)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            
            metrics = generate_metrics()
            self.wfile.write(metrics.encode('utf-8'))
        else:
            self.send_response(HTTPStatus.NOT_FOUND)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress logging"""
        return

def read_alerts():
    """Read alerts from JSON file"""
    if not os.path.exists(ALERTS_FILE):
        return []
    
    try:
        with open(ALERTS_FILE, 'r') as f:
            data = json.load(f)
            return data.get('alerts', [])
    except (json.JSONDecodeError, IOError) as e:
        print(f"Error reading alerts file: {e}")
        return []

def generate_metrics():
    """Generate Prometheus metrics from alerts"""
    alerts = read_alerts()
    
    # Generate metrics
    output = []
    
    # Add metric metadata
    output.append('# HELP validator_alerts Validator alerts with severity and type')
    output.append('# TYPE validator_alerts gauge')
    
    # Add metrics for each alert
    for alert in alerts:
        alert_id = alert.get('id', '')
        alert_type = alert.get('type', '')
        severity = alert.get('severity', '')
        message = alert.get('message', '').replace('"', '\\"')
        timestamp = alert.get('timestamp', '')
        acknowledged = str(alert.get('acknowledged', False)).lower()
        
        labels = f'{{id="{alert_id}", type="{alert_type}", severity="{severity}", message="{message}", timestamp="{timestamp}", acknowledged="{acknowledged}"}}'
        output.append(f'validator_alerts{labels} 1')
    
    # Add counter metrics by severity
    severity_counts = {}
    for alert in alerts:
        sev = alert.get('severity', '')
        if not alert.get('acknowledged', False):
            severity_counts[sev] = severity_counts.get(sev, 0) + 1
    
    output.append('# HELP validator_alerts_count Count of active alerts by severity')
    output.append('# TYPE validator_alerts_count gauge')
    
    for severity, count in severity_counts.items():
        output.append(f'validator_alerts_count{{severity="{severity}"}} {count}')
    
    # Add timestamp of last update
    output.append('# HELP validator_alerts_last_updated_timestamp Timestamp of last update')
    output.append('# TYPE validator_alerts_last_updated_timestamp gauge')
    output.append(f'validator_alerts_last_updated_timestamp {int(time.time())}')
    
    return '\\n'.join(output)

def main():
    """Main function"""
    print(f"Starting Validator Alerts Prometheus Exporter on port {METRICS_PORT}")
    
    # Create a server
    handler = MetricsHandler
    httpd = socketserver.TCPServer(("", METRICS_PORT), handler)
    
    # Start the server in a separate thread
    import threading
    server_thread = threading.Thread(target=httpd.serve_forever)
    server_thread.daemon = True
    server_thread.start()
    
    try:
        while True:
            time.sleep(UPDATE_INTERVAL)
    except KeyboardInterrupt:
        print("Stopping exporter...")
        httpd.shutdown()

if __name__ == "__main__":
    main()
EOF
    
    # Make the script executable
    chmod +x "${SCRIPTS_DIR}/validator_alerts_exporter.py"
    
    # Create systemd service for the exporter
    cat > "/etc/systemd/system/validator-alerts-exporter.service" << EOF
[Unit]
Description=Validator Alerts Prometheus Exporter
After=network.target
Wants=validator-alerts.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 ${SCRIPTS_DIR}/validator_alerts_exporter.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start the service
    if [[ "${AUTO_RESTART_SERVICES}" == "true" ]]; then
        log_info "Enabling and starting validator alerts exporter service..."
        systemctl daemon-reload
        systemctl enable validator-alerts-exporter.service
        systemctl start validator-alerts-exporter.service
    else
        log_info "Skipping service restart as requested."
        log_info "To manually start the exporter, run: systemctl start validator-alerts-exporter.service"
    fi
    
    log_success "Prometheus alert exporter created and configured successfully."
}

# Main function
function main() {
    show_banner
    parse_args "$@"
    
    if [[ "${VERBOSE}" == "true" ]]; then
        log_info "Verbose mode enabled"
    fi
    
    check_dependencies
    create_directories
    install_alert_script
    create_alert_config
    configure_prometheus
    install_grafana_dashboard
    create_systemd_service
    create_prometheus_exporter
    
    log_success "Validator Alerts System setup completed successfully!"
    log_info "You can now access the advanced validator monitoring dashboard in Grafana."
    log_info "The validator alerts service is running and will check for issues every 5 minutes."
    
    if [[ "${AUTO_RESTART_SERVICES}" == "true" ]]; then
        log_info "All services have been started automatically."
    else
        log_info "Please start the services manually:"
        log_info "  systemctl start validator-alerts.service"
        log_info "  systemctl start validator-alerts-exporter.service"
        log_info "  systemctl restart prometheus grafana-server"
    fi
}

# Run the script
main "$@" 