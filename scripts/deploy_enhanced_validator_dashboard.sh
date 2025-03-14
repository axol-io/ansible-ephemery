#!/bin/bash
#
# Enhanced Validator Status Dashboard Deployment Script
# This script deploys the enhanced validator status dashboard for Ephemery
#
# Usage: ./deploy_enhanced_validator_dashboard.sh [options]
# Options:
#   --host HOSTNAME     Target hostname (default: localhost)
#   --port PORT         API port (default: 5000)
#   --base-dir DIR      Base directory (default: /opt/ephemery)
#   --beacon-api URL    Beacon node API URL (default: http://localhost:5052)
#   --validator-api URL Validator API URL (default: http://localhost:5064)
#   --help              Show this help message

set -e

# Default values
TARGET_HOST="localhost"
API_PORT=5000
BASE_DIR="/opt/ephemery"
BEACON_API="http://localhost:5052"
VALIDATOR_API="http://localhost:5064"
DASHBOARD_DIR="${BASE_DIR}/dashboard"
API_DIR="${DASHBOARD_DIR}/api"
LOG_DIR="/var/log/ephemery"
METRICS_DIR="${BASE_DIR}/data/metrics"

# ANSI color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display usage information
show_usage() {
    echo -e "${BLUE}Enhanced Validator Status Dashboard Deployment Script${NC}"
    echo ""
    echo "This script deploys the enhanced validator status dashboard for Ephemery."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --host HOSTNAME     Target hostname (default: ${TARGET_HOST})"
    echo "  --port PORT         API port (default: ${API_PORT})"
    echo "  --base-dir DIR      Base directory (default: ${BASE_DIR})"
    echo "  --beacon-api URL    Beacon node API URL (default: ${BEACON_API})"
    echo "  --validator-api URL Validator API URL (default: ${VALIDATOR_API})"
    echo "  --help              Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --host my-server.example.com --port 5001"
}

# Function to parse command-line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --host)
                TARGET_HOST="$2"
                shift 2
                ;;
            --port)
                API_PORT="$2"
                shift 2
                ;;
            --base-dir)
                BASE_DIR="$2"
                DASHBOARD_DIR="${BASE_DIR}/dashboard"
                API_DIR="${DASHBOARD_DIR}/api"
                METRICS_DIR="${BASE_DIR}/data/metrics"
                shift 2
                ;;
            --beacon-api)
                BEACON_API="$2"
                shift 2
                ;;
            --validator-api)
                VALIDATOR_API="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to verify prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    # Check if required commands exist
    for cmd in "ssh" "scp" "rsync"; do
        if ! command -v "${cmd}" &> /dev/null; then
            echo -e "${RED}Error: Required command '${cmd}' not found${NC}"
            exit 1
        fi
    done
    
    # Check if we can connect to the target host
    if [[ "${TARGET_HOST}" != "localhost" ]]; then
        if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${TARGET_HOST}" "exit"; then
            echo -e "${RED}Error: Cannot connect to ${TARGET_HOST}${NC}"
            echo "Make sure SSH is properly configured for this host."
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Prerequisites check passed${NC}"
}

# Function to create required directories
create_directories() {
    echo -e "${BLUE}Creating required directories...${NC}"
    
    if [[ "${TARGET_HOST}" == "localhost" ]]; then
        # Local deployment
        mkdir -p "${DASHBOARD_DIR}"
        mkdir -p "${API_DIR}"
        mkdir -p "${LOG_DIR}"
        mkdir -p "${METRICS_DIR}"
        mkdir -p "${METRICS_DIR}/history"
        mkdir -p "${METRICS_DIR}/alerts"
        mkdir -p "${METRICS_DIR}/validator_details"
    else
        # Remote deployment
        ssh "${TARGET_HOST}" "mkdir -p ${DASHBOARD_DIR} ${API_DIR} ${LOG_DIR} ${METRICS_DIR} ${METRICS_DIR}/history ${METRICS_DIR}/alerts ${METRICS_DIR}/validator_details"
    fi
    
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Function to install required packages
install_packages() {
    echo -e "${BLUE}Installing required packages...${NC}"
    
    if [[ "${TARGET_HOST}" == "localhost" ]]; then
        # Local deployment
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y python3 python3-pip nginx curl jq
        elif command -v yum &> /dev/null; then
            yum install -y python3 python3-pip nginx curl jq
        else
            echo -e "${RED}Error: Unsupported package manager${NC}"
            exit 1
        fi
        
        pip3 install flask flask-cors requests
    else
        # Remote deployment
        ssh "${TARGET_HOST}" "if command -v apt-get &> /dev/null; then apt-get update && apt-get install -y python3 python3-pip nginx curl jq; elif command -v yum &> /dev/null; then yum install -y python3 python3-pip nginx curl jq; else echo 'Error: Unsupported package manager' && exit 1; fi"
        
        ssh "${TARGET_HOST}" "pip3 install flask flask-cors requests"
    fi
    
    echo -e "${GREEN}✓ Packages installed${NC}"
}

# Function to copy dashboard files
copy_dashboard_files() {
    echo -e "${BLUE}Copying dashboard files...${NC}"
    
    # Get the script's directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
    
    if [[ "${TARGET_HOST}" == "localhost" ]]; then
        # Local deployment
        cp "${REPO_ROOT}/dashboard/validator_dashboard.html" "${DASHBOARD_DIR}/"
        cp "${REPO_ROOT}/dashboard/api/validator_metrics_api.py" "${API_DIR}/"
    else
        # Remote deployment
        scp "${REPO_ROOT}/dashboard/validator_dashboard.html" "${TARGET_HOST}:${DASHBOARD_DIR}/"
        scp "${REPO_ROOT}/dashboard/api/validator_metrics_api.py" "${TARGET_HOST}:${API_DIR}/"
    fi
    
    echo -e "${GREEN}✓ Dashboard files copied${NC}"
}

# Function to configure the dashboard service
configure_service() {
    echo -e "${BLUE}Configuring dashboard service...${NC}"
    
    # Create service file
    SERVICE_CONTENT="[Unit]
Description=Ephemery Validator Dashboard API
After=network.target

[Service]
User=root
WorkingDirectory=${API_DIR}
ExecStart=/usr/bin/python3 ${API_DIR}/validator_metrics_api.py
Restart=always
Environment=BEACON_NODE_ENDPOINT=${BEACON_API}
Environment=VALIDATOR_ENDPOINT=${VALIDATOR_API}
Environment=EPHEMERY_BASE_DIR=${BASE_DIR}
Environment=VALIDATOR_API_PORT=${API_PORT}

[Install]
WantedBy=multi-user.target
"
    
    if [[ "${TARGET_HOST}" == "localhost" ]]; then
        # Local deployment
        echo "${SERVICE_CONTENT}" > "/etc/systemd/system/validator-dashboard.service"
        systemctl daemon-reload
        systemctl enable validator-dashboard
        systemctl restart validator-dashboard
    else
        # Remote deployment
        echo "${SERVICE_CONTENT}" | ssh "${TARGET_HOST}" "cat > /etc/systemd/system/validator-dashboard.service && systemctl daemon-reload && systemctl enable validator-dashboard && systemctl restart validator-dashboard"
    fi
    
    echo -e "${GREEN}✓ Service configured${NC}"
}

# Function to configure Nginx
configure_nginx() {
    echo -e "${BLUE}Configuring Nginx...${NC}"
    
    # Create Nginx configuration file
    NGINX_CONTENT="server {
    listen 80;
    server_name ${TARGET_HOST};

    access_log /var/log/nginx/validator-dashboard-access.log;
    error_log /var/log/nginx/validator-dashboard-error.log;

    # Dashboard UI location
    location /validator-dashboard/ {
        alias ${DASHBOARD_DIR}/;
        index validator_dashboard.html;
        try_files \$uri \$uri/ /validator_dashboard.html;
    }

    # API endpoints
    location /validator-api/ {
        proxy_pass http://127.0.0.1:${API_PORT}/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Direct API access
    location /api/ {
        proxy_pass http://127.0.0.1:${API_PORT}/api/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:${API_PORT}/health;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Root redirect to dashboard
    location = / {
        return 301 /validator-dashboard/;
    }
}
"
    
    if [[ "${TARGET_HOST}" == "localhost" ]]; then
        # Local deployment
        echo "${NGINX_CONTENT}" > "/etc/nginx/sites-available/validator-dashboard.conf"
        ln -sf "/etc/nginx/sites-available/validator-dashboard.conf" "/etc/nginx/sites-enabled/"
        rm -f "/etc/nginx/sites-enabled/default" || true
        systemctl restart nginx
    else
        # Remote deployment
        echo "${NGINX_CONTENT}" | ssh "${TARGET_HOST}" "cat > /etc/nginx/sites-available/validator-dashboard.conf && ln -sf /etc/nginx/sites-available/validator-dashboard.conf /etc/nginx/sites-enabled/ && rm -f /etc/nginx/sites-enabled/default || true && systemctl restart nginx"
    fi
    
    echo -e "${GREEN}✓ Nginx configured${NC}"
}

# Function to verify deployment
verify_deployment() {
    echo -e "${BLUE}Verifying deployment...${NC}"
    
    # Wait for services to start
    sleep 3
    
    # Check if services are running
    if [[ "${TARGET_HOST}" == "localhost" ]]; then
        # Local deployment
        if ! systemctl is-active --quiet validator-dashboard; then
            echo -e "${RED}Error: validator-dashboard service is not running${NC}"
            echo "Check logs with: journalctl -u validator-dashboard"
            exit 1
        fi
        
        if ! systemctl is-active --quiet nginx; then
            echo -e "${RED}Error: nginx service is not running${NC}"
            echo "Check logs with: journalctl -u nginx"
            exit 1
        }
        
        # Check if API is responding
        if ! curl -s "http://localhost:${API_PORT}/health" | grep -q "healthy"; then
            echo -e "${RED}Error: API health check failed${NC}"
            exit 1
        }
    else
        # Remote deployment
        if ! ssh "${TARGET_HOST}" "systemctl is-active --quiet validator-dashboard"; then
            echo -e "${RED}Error: validator-dashboard service is not running${NC}"
            echo "Check logs with: ssh ${TARGET_HOST} 'journalctl -u validator-dashboard'"
            exit 1
        fi
        
        if ! ssh "${TARGET_HOST}" "systemctl is-active --quiet nginx"; then
            echo -e "${RED}Error: nginx service is not running${NC}"
            echo "Check logs with: ssh ${TARGET_HOST} 'journalctl -u nginx'"
            exit 1
        fi
        
        # Check if API is responding
        if ! ssh "${TARGET_HOST}" "curl -s 'http://localhost:${API_PORT}/health'" | grep -q "healthy"; then
            echo -e "${RED}Error: API health check failed${NC}"
            exit 1
        fi
    fi
    
    echo -e "${GREEN}✓ Deployment verified${NC}"
}

# Main function
main() {
    echo -e "${BLUE}===== Enhanced Validator Status Dashboard Deployment =====${NC}"
    
    # Parse command-line arguments
    parse_args "$@"
    
    # Verify prerequisites
    check_prerequisites
    
    # Create required directories
    create_directories
    
    # Install required packages
    install_packages
    
    # Copy dashboard files
    copy_dashboard_files
    
    # Configure service
    configure_service
    
    # Configure Nginx
    configure_nginx
    
    # Verify deployment
    verify_deployment
    
    echo -e "${GREEN}===== Deployment Completed Successfully =====${NC}"
    echo ""
    echo -e "You can now access the Enhanced Validator Status Dashboard at:"
    echo -e "${GREEN}http://${TARGET_HOST}/validator-dashboard/${NC}"
    echo ""
}

# Execute main function
main "$@" 