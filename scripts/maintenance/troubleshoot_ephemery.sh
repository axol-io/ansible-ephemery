#!/bin/bash

# Ephemery Node Troubleshooting Script
# This script helps diagnose and fix common issues with Ephemery nodes
# Version: 1.1.0

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
CORE_DIR="${SCRIPT_DIR}/../core"

# Source path configuration
if [ -f "${CORE_DIR}/path_config.sh" ]; then
  source "${CORE_DIR}/path_config.sh"
else
  log_warn "Path configuration not found. Using legacy path definitions."
  # Default paths if config not available
  EPHEMERY_BASE_DIR="${HOME}/ephemery"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_JWT_SECRET="${EPHEMERY_BASE_DIR}/jwt.hex"
  EPHEMERY_GETH_CONTAINER="ephemery-geth"
  EPHEMERY_LIGHTHOUSE_CONTAINER="ephemery-lighthouse"
  EPHEMERY_VALIDATOR_CONTAINER="ephemery-validator"
fi

# Source error handling
if [ -f "${CORE_DIR}/error_handling.sh" ]; then
  source "${CORE_DIR}/error_handling.sh"
  # Set up error handling
  setup_error_handling
  # Allow the script to continue on errors for troubleshooting
  ERROR_CONTINUE_ON_ERROR=true
fi

# Source common utilities
if [ -f "${CORE_DIR}/common.sh" ]; then
  source "${CORE_DIR}/common.sh"
fi

# Colors for better readability (fallback if common.sh not available)
GREEN=${GREEN:-'\033[0;32m'}
YELLOW=${YELLOW:-'\033[1;33m'}
BLUE=${BLUE:-'\033[0;34m'}
RED=${RED:-'\033[0;31m'}
NC=${NC:-'\033[0m'} # No Color

# Default settings
VERBOSE=false
FIX_ISSUES=true
RESTART_CONTAINERS=false
FORCE_RESET=false
CUSTOM_BASE_DIR=""

# Function to run diagnostics
run_diagnostics() {
  log_info "=== Ephemery Node Troubleshooting ==="
  log_info "Starting comprehensive diagnostics..."

  # Check if Docker is running
  log_info "Step 1: Checking Docker service status"
  if command -v systemctl &>/dev/null; then
    if systemctl is-active --quiet docker; then
      log_success "✓ Docker service is running"
    else
      log_error "✗ Docker service has issues"
      return 1
    fi
  else
    if docker info &>/dev/null; then
      log_success "✓ Docker service is running"
    else
      log_error "✗ Docker service is not running"
      log_warn "Attempting to start Docker service..."
      if command -v systemctl &>/dev/null; then
        systemctl start docker
        systemctl is-active --quiet docker && log_success "✓ Docker service started successfully" || log_error "✗ Failed to start Docker service"
      else
        log_warn "systemctl not available, please start Docker service manually"
      fi
    fi
  fi

  # Step 2: Check Ephemery containers
  log_info "Step 2: Checking Ephemery containers"
  log_info "Current running containers:"

  if type run_with_error_handling &>/dev/null; then
    run_with_error_handling "List running containers" docker ps
  else
    docker ps
  fi

  if type is_container_running &>/dev/null; then
    # Use is_container_running from common.sh
    if is_container_running "${EPHEMERY_GETH_CONTAINER}"; then
      log_success "✓ Geth container is running"
    else
      log_error "✗ Geth container is not running"
    fi

    if is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}"; then
      log_success "✓ Lighthouse container is running"
    else
      log_error "✗ Lighthouse container is not running"
    fi
  else
    # Fallback if is_container_running is not available
    GETH_RUNNING=$(docker ps -q -f name=ephemery-geth)
    LIGHTHOUSE_RUNNING=$(docker ps -q -f name=ephemery-lighthouse)

    if [ -n "${GETH_RUNNING}" ]; then
      log_success "✓ Geth container is running"
    else
      log_error "✗ Geth container is not running"
    fi

    if [ -n "${LIGHTHOUSE_RUNNING}" ]; then
      log_success "✓ Lighthouse container is running"
    else
      log_error "✗ Lighthouse container is not running"
    fi
  fi

  # Step 3: Check Docker network
  log_info "Step 3: Checking Docker network"

  if type run_with_error_handling &>/dev/null; then
    if run_with_error_handling "Inspect Docker network" docker network inspect ephemery-net &>/dev/null; then
      log_success "✓ Ephemery network exists"
      log_info "Network details:"
      run_with_error_handling "Show network details" docker network inspect ephemery-net
    else
      log_error "✗ Ephemery network does not exist"
      log_info "Creating ephemery network..."
      run_with_error_handling "Create Docker network" docker network create ephemery-net
      log_success "✓ Ephemery network created"
    fi
  else
    if docker network inspect ephemery-net &>/dev/null; then
      log_success "✓ Ephemery network exists"
      log_info "Network details:"
      docker network inspect ephemery-net
    else
      log_error "✗ Ephemery network does not exist"
      log_info "Creating ephemery network..."
      docker network create ephemery-net
      log_success "✓ Ephemery network created"
    fi
  fi

  # Step 4: Check JWT token
  log_info "Step 4: Checking JWT token"

  if type check_file_exists &>/dev/null; then
    if check_file_exists "${EPHEMERY_JWT_SECRET}"; then
      log_success "✓ JWT token file exists"

      # Check file permissions
      FILE_PERMS=$(stat -c "%a" "${EPHEMERY_JWT_SECRET}")
      if [ "${FILE_PERMS}" == "600" ]; then
        log_success "✓ JWT token has correct permissions (600)"
      else
        log_error "✗ JWT token has incorrect permissions: ${FILE_PERMS}"
        log_info "Setting correct permissions..."
        run_with_error_handling "Set JWT permissions" chmod 600 "${EPHEMERY_JWT_SECRET}"
        log_success "Permissions corrected"
      fi

      # Check token format
      TOKEN=$(cat "${EPHEMERY_JWT_SECRET}")
      TOKEN_LENGTH=${#TOKEN}

      log_info "Token value (first 10 chars): ${TOKEN:0:10}..."
      log_info "Token length: ${TOKEN_LENGTH} characters"

      if [[ ${TOKEN} == 0x* ]] && [ "${TOKEN_LENGTH}" -eq 66 ]; then
        log_success "✓ Token format appears correct (0x + 64 hex chars)"
      else
        log_error "✗ Token format may be incorrect"
        log_info "Regenerating JWT token..."
        run_with_error_handling "Regenerate JWT token" bash -c "echo \"0x\$(openssl rand -hex 32)\" > \"${EPHEMERY_JWT_SECRET}\""
        run_with_error_handling "Set JWT permissions" chmod 600 "${EPHEMERY_JWT_SECRET}"
        log_success "New JWT token generated"
        TOKEN=$(cat "${EPHEMERY_JWT_SECRET}")
        log_info "New token value (first 10 chars): ${TOKEN:0:10}..."
      fi
    else
      log_error "✗ JWT token file does not exist"
      log_info "Creating JWT token..."
      run_with_error_handling "Create config directory" mkdir -p "${EPHEMERY_CONFIG_DIR}"
      run_with_error_handling "Generate JWT token" bash -c "echo \"0x\$(openssl rand -hex 32)\" > \"${EPHEMERY_JWT_SECRET}\""
      run_with_error_handling "Set JWT permissions" chmod 600 "${EPHEMERY_JWT_SECRET}"
      log_success "JWT token created"
    fi
  else
    # Fallback if check_file_exists function is not available
    if [ -f "${EPHEMERY_JWT_SECRET}" ]; then
      log_success "✓ JWT token file exists"

      # Check file permissions
      FILE_PERMS=$(stat -c "%a" "${EPHEMERY_JWT_SECRET}")
      if [ "${FILE_PERMS}" == "600" ]; then
        log_success "✓ JWT token has correct permissions (600)"
      else
        log_error "✗ JWT token has incorrect permissions: ${FILE_PERMS}"
        log_info "Setting correct permissions..."
        chmod 600 "${EPHEMERY_JWT_SECRET}"
        log_success "Permissions corrected"
      fi

      # Check token format
      TOKEN=$(cat "${EPHEMERY_JWT_SECRET}")
      TOKEN_LENGTH=${#TOKEN}

      log_info "Token value (first 10 chars): ${TOKEN:0:10}..."
      log_info "Token length: ${TOKEN_LENGTH} characters"

      if [[ ${TOKEN} == 0x* ]] && [ "${TOKEN_LENGTH}" -eq 66 ]; then
        log_success "✓ Token format appears correct (0x + 64 hex chars)"
      else
        log_error "✗ Token format may be incorrect"
        log_info "Regenerating JWT token..."
        echo "0x$(openssl rand -hex 32)" >"${EPHEMERY_JWT_SECRET}"
        chmod 600 "${EPHEMERY_JWT_SECRET}"
        log_success "New JWT token generated"
        TOKEN=$(cat "${EPHEMERY_JWT_SECRET}")
        log_info "New token value (first 10 chars): ${TOKEN:0:10}..."
      fi
    else
      log_error "✗ JWT token file does not exist"
      log_info "Creating JWT token..."
      mkdir -p "${EPHEMERY_CONFIG_DIR}"
      echo "0x$(openssl rand -hex 32)" >"${EPHEMERY_JWT_SECRET}"
      chmod 600 "${EPHEMERY_JWT_SECRET}"
      log_success "JWT token created"
    fi
  fi

  # Step 5: Verify container networking
  log_info "Step 5: Verifying container networking"

  # Get container running status
  if ! type is_container_running &>/dev/null; then
    GETH_RUNNING=$(docker ps -q -f name=ephemery-geth)
    LIGHTHOUSE_RUNNING=$(docker ps -q -f name=ephemery-lighthouse)
  fi

  if { type is_container_running &>/dev/null && is_container_running "${EPHEMERY_GETH_CONTAINER}" && is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}"; } || { [ -n "${GETH_RUNNING}" ] && [ -n "${LIGHTHOUSE_RUNNING}" ]; }; then
    GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-geth)
    LIGHTHOUSE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-lighthouse)

    log_info "Geth container IP: ${GETH_IP}"
    log_info "Lighthouse container IP: ${LIGHTHOUSE_IP}"
    log_info "Testing network connectivity from Lighthouse to Geth..."

    if type run_with_error_handling &>/dev/null; then
      if run_with_error_handling "Test container connectivity" docker exec ephemery-lighthouse ping -c 2 ephemery-geth &>/dev/null; then
        log_success "✓ Lighthouse can ping Geth by container name"
      else
        log_error "✗ Lighthouse cannot ping Geth by container name"

        if run_with_error_handling "Test IP connectivity" docker exec ephemery-lighthouse ping -c 2 "${GETH_IP}" &>/dev/null; then
          log_success "✓ Lighthouse can ping Geth by IP address"
        else
          log_error "✗ Lighthouse cannot ping Geth by IP address"
          log_warning "This indicates a network configuration issue"
        fi
      fi
    else
      if docker exec ephemery-lighthouse ping -c 2 ephemery-geth &>/dev/null; then
        log_success "✓ Lighthouse can ping Geth by container name"
      else
        log_error "✗ Lighthouse cannot ping Geth by container name"

        if docker exec ephemery-lighthouse ping -c 2 "${GETH_IP}" &>/dev/null; then
          log_success "✓ Lighthouse can ping Geth by IP address"
        else
          log_error "✗ Lighthouse cannot ping Geth by IP address"
          log_warning "This indicates a network configuration issue"
        fi
      fi
    fi
  else
    if type log_warning &>/dev/null; then
      log_warning "Skipping network tests as not all containers are running"
    else
      log_warn "Skipping network tests as not all containers are running"
    fi
  fi

  # Step 6: Check container configuration
  log_info "Step 6: Checking container configurations"

  if (type is_container_running &>/dev/null && is_container_running "${EPHEMERY_GETH_CONTAINER}") || [ -n "${GETH_RUNNING}" ]; then
    log_info "Geth container configuration:"
    run_with_error_handling "Inspect Geth container" docker inspect ephemery-geth
    log_info "Geth JWT path in container:"
    run_with_error_handling "Check JWT in container" docker exec ephemery-geth ls -la /config/jwt-secret

    if type run_with_error_handling &>/dev/null; then
      if run_with_error_handling "Check JWT access" docker exec ephemery-geth cat /config/jwt-secret &>/dev/null; then
        log_success "✓ Geth can access JWT token in container"
        GETH_TOKEN=$(docker exec ephemery-geth cat /config/jwt-secret)
        log_info "Geth JWT token (first 10 chars): ${GETH_TOKEN:0:10}..."
      else
        log_error "✗ Geth cannot access JWT token in container"
      fi
    else
      if docker exec ephemery-geth cat /config/jwt-secret &>/dev/null; then
        log_success "✓ Geth can access JWT token in container"
        GETH_TOKEN=$(docker exec ephemery-geth cat /config/jwt-secret)
        log_info "Geth JWT token (first 10 chars): ${GETH_TOKEN:0:10}..."
      else
        log_error "✗ Geth cannot access JWT token in container"
      fi
    fi
  fi

  if (type is_container_running &>/dev/null && is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}") || [ -n "${LIGHTHOUSE_RUNNING}" ]; then
    log_info "Lighthouse container configuration:"
    run_with_error_handling "Inspect Lighthouse container" docker inspect ephemery-lighthouse
    log_info "Lighthouse JWT path in container:"
    run_with_error_handling "Check JWT in container" docker exec ephemery-lighthouse ls -la /config/jwt-secret

    if type run_with_error_handling &>/dev/null; then
      if run_with_error_handling "Check JWT access" docker exec ephemery-lighthouse cat /config/jwt-secret &>/dev/null; then
        log_success "✓ Lighthouse can access JWT token in container"
        LIGHTHOUSE_TOKEN=$(docker exec ephemery-lighthouse cat /config/jwt-secret)
        log_info "Lighthouse JWT token (first 10 chars): ${LIGHTHOUSE_TOKEN:0:10}..."
      else
        log_error "✗ Lighthouse cannot access JWT token in container"
      fi
    else
      if docker exec ephemery-lighthouse cat /config/jwt-secret &>/dev/null; then
        log_success "✓ Lighthouse can access JWT token in container"
        LIGHTHOUSE_TOKEN=$(docker exec ephemery-lighthouse cat /config/jwt-secret)
        log_info "Lighthouse JWT token (first 10 chars): ${LIGHTHOUSE_TOKEN:0:10}..."
      else
        log_error "✗ Lighthouse cannot access JWT token in container"
      fi
    fi
  fi

  # Compare tokens
  if { (type is_container_running &>/dev/null && is_container_running "${EPHEMERY_GETH_CONTAINER}" && is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}"); } || { [ -n "${GETH_RUNNING}" ] && [ -n "${LIGHTHOUSE_RUNNING}" ]; }; then
    GETH_TOKEN=$(docker exec ephemery-geth cat /config/jwt-secret)
    LIGHTHOUSE_TOKEN=$(docker exec ephemery-lighthouse cat /config/jwt-secret)

    if [ "${GETH_TOKEN}" == "${LIGHTHOUSE_TOKEN}" ]; then
      log_success "✓ JWT tokens match between containers"
    else
      log_error "✗ JWT tokens DO NOT match between containers"
      log_warning "This is likely causing the authentication failure"
    fi
  fi

  # Step 7: Check logs for specific errors
  log_info "Step 7: Checking container logs for errors"

  if (type is_container_running &>/dev/null && is_container_running "${EPHEMERY_GETH_CONTAINER}") || [ -n "${GETH_RUNNING}" ]; then
    log_info "Recent Geth logs:"
    run_with_error_handling "Show Geth logs" docker logs --tail 20 ephemery-geth
  fi

  if (type is_container_running &>/dev/null && is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}") || [ -n "${LIGHTHOUSE_RUNNING}" ]; then
    log_info "Recent Lighthouse logs:"
    run_with_error_handling "Show Lighthouse logs" docker logs --tail 20 ephemery-lighthouse
  fi

  # Step 8: Fix JWT token and restart containers
  log_info "Step 8: Would you like to fix JWT token and restart containers? (y/n)"

  read -p "Proceed? " PROCEED

  if [ "${PROCEED}" == "y" ] || [ "${PROCEED}" == "Y" ]; then
    log_info "Stopping containers..."
    run_with_error_handling "Stop containers" docker stop ephemery-geth ephemery-lighthouse
    log_info "Regenerating JWT token..."
    run_with_error_handling "Generate JWT" bash -c "echo \"0x\$(openssl rand -hex 32)\" > \"${EPHEMERY_JWT_SECRET}\""
    run_with_error_handling "Set permissions" chmod 600 "${EPHEMERY_JWT_SECRET}"
    log_info "Starting containers with new JWT token..."
    run_with_error_handling "Start Geth" docker start ephemery-geth
    sleep 10
    run_with_error_handling "Start Lighthouse" docker start ephemery-lighthouse
    log_success "Containers restarted with new JWT token"
    log_warning "Check logs after 30 seconds to verify the issue is resolved"
  else
    log_info "Skipping container restart"
  fi

  if type log_success &>/dev/null; then
    log_success "=== Troubleshooting Complete ==="
    log_info "If issues persist, consider the following:"
    log_info "1. Check if the execution endpoint URL is correct (http://ephemery-geth:8551)"
    log_info "2. Try using IP address instead of container name in connection string"
    log_info "3. Review container configurations for compatibility"
    log_info "4. Consider recreating the Docker network"
  else
    log_success "=== Troubleshooting Complete ==="
    log_info "If issues persist, consider the following:"
    log_info "1. Check if the execution endpoint URL is correct (http://ephemery-geth:8551)"
    log_info "2. Try using IP address instead of container name in connection string"
    log_info "3. Review container configurations for compatibility"
    log_info "4. Consider recreating the Docker network"
  fi
}

# Run diagnostics
run_diagnostics

# Script end
