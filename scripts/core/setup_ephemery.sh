#!/usr/bin/env bash
#
# Script Name: setup_ephemery.sh
# Description: Automates the setup of an Ephemery testnet node with Electra/Pectra support
# Author: Ephemery Team
# Created: 2023-05-15
# Last Modified: 2023-05-15
#
# Usage: ./setup_ephemery.sh [options]
#
# Dependencies:
#   - Docker
#   - Docker Compose
#   - curl
#   - jq
#
# Exit Codes:
#   0 - Success
#   1 - General error
#   2 - Docker not installed
#   3 - Docker Compose not installed
#   4 - Permission error

# Enable strict mode
set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Load common utilities
source "${SCRIPT_DIR}/../utilities/common.sh"
source "${SCRIPT_DIR}/../utilities/logging.sh"
source "${SCRIPT_DIR}/../utilities/config.sh"
source "${SCRIPT_DIR}/../utilities/validation.sh"

# Load configuration file if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "$CONFIG_FILE" ]; then
    log_info "Loading configuration from $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    log_info "Configuration file not found, using default paths"
    # Define default paths
    EPHEMERY_BASE_DIR="/opt/ephemery"
    EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"
    EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
    EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
    EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
    EPHEMERY_JWT_SECRET="${EPHEMERY_CONFIG_DIR}/jwt.hex"
fi

log_info "======================================="
log_info "Ephemery Testnet Node Setup Script"
log_info "======================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root"
   exit 4
fi

# Check Docker
log_info "Checking Docker..."
if is_command_available "docker"; then
    log_success "Docker is installed"
else
    log_error "Docker is not installed"
    log_info "Installing Docker..."

    # Update package lists
    apt-get update
    
    # Install dependencies
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up the stable repository
    echo \
      "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
    
    if is_command_available "docker"; then
        log_success "Docker installed successfully"
    else
        log_critical "Failed to install Docker. Please install manually and try again."
        exit 2
    fi
fi

# Check Docker Compose
log_info "Checking Docker Compose..."
if is_command_available "docker-compose"; then
    log_success "Docker Compose is installed"
else
    log_error "Docker Compose is not installed"
    log_info "Installing Docker Compose..."
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/download/v2.5.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    if is_command_available "docker-compose"; then
        log_success "Docker Compose installed successfully"
    else
        log_critical "Failed to install Docker Compose. Please install manually and try again."
        exit 3
    fi
fi

# Create Ephemery directory
log_info "Creating Ephemery directory..."
mkdir -p "$EPHEMERY_BASE_DIR"
chmod 755 "$EPHEMERY_BASE_DIR"

# Create configuration directory and copy the paths configuration
mkdir -p "$EPHEMERY_CONFIG_DIR"
chmod 755 "$EPHEMERY_CONFIG_DIR"

# Copy or create the configuration file if it doesn't exist in the target location
if [ ! -f "${EPHEMERY_CONFIG_DIR}/ephemery_paths.conf" ]; then
    log_info "Creating standard configuration file..."
    cat > "${EPHEMERY_CONFIG_DIR}/ephemery_paths.conf" << EOF
# Ephemery Paths Configuration
# This file defines standard paths used across all Ephemery scripts and services

# Base directory for Ephemery installation
EPHEMERY_BASE_DIR="${EPHEMERY_BASE_DIR}"

# Directory for Ephemery scripts
EPHEMERY_SCRIPTS_DIR="\${EPHEMERY_BASE_DIR}/scripts"

# Directory for Ephemery data
EPHEMERY_DATA_DIR="\${EPHEMERY_BASE_DIR}/data"

# Directory for Ephemery logs
EPHEMERY_LOGS_DIR="\${EPHEMERY_BASE_DIR}/logs"

# Directory for Ephemery configuration
EPHEMERY_CONFIG_DIR="\${EPHEMERY_BASE_DIR}/config"

# JWT secret path
EPHEMERY_JWT_SECRET="\${EPHEMERY_CONFIG_DIR}/jwt.hex"

# Validator keys directory
EPHEMERY_VALIDATOR_KEYS="\${EPHEMERY_DATA_DIR}/validator_keys"

# Metrics directory
EPHEMERY_METRICS_DIR="\${EPHEMERY_DATA_DIR}/metrics"

# Default endpoints
LIGHTHOUSE_API_ENDPOINT="http://localhost:5052"
GETH_API_ENDPOINT="http://localhost:8545"
VALIDATOR_API_ENDPOINT="http://localhost:5062"
EOF
    chmod 644 "${EPHEMERY_CONFIG_DIR}/ephemery_paths.conf"
    log_success "Configuration file created"
fi

# Download configuration files
log_info "Downloading configuration files..."
curl -s https://raw.githubusercontent.com/ephemery-labs/ephemery-deploy/main/docker-compose.yml -o "$EPHEMERY_BASE_DIR/docker-compose.yml"
curl -s https://raw.githubusercontent.com/ephemery-labs/ephemery-deploy/main/.env -o "$EPHEMERY_BASE_DIR/.env"

# Customize configuration
log_info "Customizing configuration..."
# (Implementation of configuration customization would go here)

# Start Ephemery node
log_info "Starting Ephemery node..."
cd "$EPHEMERY_BASE_DIR"
docker-compose up -d

# Verify containers are running
log_info "Verifying containers are running..."
if docker ps | grep -q "ephemery"; then
    log_success "Ephemery node is running!"
else
    log_error "Something went wrong. Containers are not running."
    exit 1
fi

log_info "Setup complete!"
log_info "You can check the status of your node with: docker ps"
log_info "For logs, use: docker logs [container_name]" 