#!/bin/bash

# Ephemery Node Troubleshooting Script
# This script helps diagnose and fix common issues with Ephemery nodes
# Version: 1.1.0

# Source core utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CORE_DIR="${SCRIPT_DIR}/scripts/core"

# Source path configuration
if [ -f "${CORE_DIR}/path_config.sh" ]; then
  source "${CORE_DIR}/path_config.sh"
else
  echo "Warning: Path configuration not found. Using legacy path definitions."
  # Default paths if config not available
  EPHEMERY_BASE_DIR="$HOME/ephemery"
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

if type log_info &>/dev/null; then
  log_info "=== Ephemery Node Troubleshooting ==="
  log_info "Starting comprehensive diagnostics..."
else
  echo -e "${BLUE}=== Ephemery Node Troubleshooting ===${NC}"
  echo -e "${BLUE}Starting comprehensive diagnostics...${NC}"
fi

# Step 1: Check Docker service status
if type log_info &>/dev/null; then
  log_info "Step 1: Checking Docker service status"
else
  echo -e "\n${YELLOW}Step 1: Checking Docker service status${NC}"
fi

if type check_docker &>/dev/null; then
  # Use the check_docker function from common.sh
  if check_docker; then
    if type log_success &>/dev/null; then
      log_success "Docker service is running"
    else
      echo -e "${GREEN}✓ Docker service is running${NC}"
    fi
  else
    if type log_error &>/dev/null; then
      log_error "Docker service has issues"
    else
      echo -e "${RED}✗ Docker service has issues${NC}"
    fi
  fi
else
  # Fallback if check_docker function is not available
  if command -v systemctl &>/dev/null && systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Docker service is running${NC}"
  else
    echo -e "${RED}✗ Docker service is not running${NC}"
    echo -e "${YELLOW}Attempting to start Docker service...${NC}"
    if command -v systemctl &>/dev/null; then
      systemctl start docker
      systemctl is-active --quiet docker && echo -e "${GREEN}✓ Docker service started successfully${NC}" || echo -e "${RED}✗ Failed to start Docker service${NC}"
    else
      echo -e "${YELLOW}systemctl not available, please start Docker service manually${NC}"
    fi
  fi
fi

# Step 2: Check Ephemery containers
if type log_info &>/dev/null; then
  log_info "Step 2: Checking Ephemery containers"
  log_info "Current running containers:"
else
  echo -e "\n${YELLOW}Step 2: Checking Ephemery containers${NC}"
  echo -e "${BLUE}Current running containers:${NC}"
fi

if type run_with_error_handling &>/dev/null; then
  run_with_error_handling "List running containers" docker ps
else
  docker ps
fi

if type is_container_running &>/dev/null; then
  # Use is_container_running from common.sh
  if is_container_running "${EPHEMERY_GETH_CONTAINER}"; then
    if type log_success &>/dev/null; then
      log_success "Geth container is running"
    else
      echo -e "${GREEN}✓ Geth container is running${NC}"
    fi
  else
    if type log_error &>/dev/null; then
      log_error "Geth container is not running"
    else
      echo -e "${RED}✗ Geth container is not running${NC}"
    fi
  fi

  if is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}"; then
    if type log_success &>/dev/null; then
      log_success "Lighthouse container is running"
    else
      echo -e "${GREEN}✓ Lighthouse container is running${NC}"
    fi
  else
    if type log_error &>/dev/null; then
      log_error "Lighthouse container is not running"
    else
      echo -e "${RED}✗ Lighthouse container is not running${NC}"
    fi
  fi
else
  # Fallback if is_container_running is not available
  GETH_RUNNING=$(docker ps -q -f name=ephemery-geth)
  LIGHTHOUSE_RUNNING=$(docker ps -q -f name=ephemery-lighthouse)

  if [ -n "$GETH_RUNNING" ]; then
    echo -e "${GREEN}✓ Geth container is running${NC}"
  else
    echo -e "${RED}✗ Geth container is not running${NC}"
  fi

  if [ -n "$LIGHTHOUSE_RUNNING" ]; then
    echo -e "${GREEN}✓ Lighthouse container is running${NC}"
  else
    echo -e "${RED}✗ Lighthouse container is not running${NC}"
  fi
fi

# Step 3: Check Docker network
if type log_info &>/dev/null; then
  log_info "Step 3: Checking Docker network"
else
  echo -e "\n${YELLOW}Step 3: Checking Docker network${NC}"
fi

if type run_with_error_handling &>/dev/null; then
  if run_with_error_handling "Inspect Docker network" docker network inspect ephemery-net &>/dev/null; then
    if type log_success &>/dev/null; then
      log_success "Ephemery network exists"
      log_info "Network details:"
      run_with_error_handling "Show network details" docker network inspect ephemery-net
    else
      echo -e "${GREEN}✓ Ephemery network exists${NC}"
      echo -e "${BLUE}Network details:${NC}"
      docker network inspect ephemery-net
    fi
  else
    if type log_error &>/dev/null; then
      log_error "Ephemery network does not exist"
      log_info "Creating ephemery network..."
      run_with_error_handling "Create Docker network" docker network create ephemery-net
      log_success "Ephemery network created"
    else
      echo -e "${RED}✗ Ephemery network does not exist${NC}"
      echo -e "${YELLOW}Creating ephemery network...${NC}"
      docker network create ephemery-net
      echo -e "${GREEN}✓ Ephemery network created${NC}"
    fi
  fi
else
  if docker network inspect ephemery-net &>/dev/null; then
    echo -e "${GREEN}✓ Ephemery network exists${NC}"
    echo -e "${BLUE}Network details:${NC}"
    docker network inspect ephemery-net
  else
    echo -e "${RED}✗ Ephemery network does not exist${NC}"
    echo -e "${YELLOW}Creating ephemery network...${NC}"
    docker network create ephemery-net
    echo -e "${GREEN}✓ Ephemery network created${NC}"
  fi
fi

# Step 4: Check JWT token
if type log_info &>/dev/null; then
  log_info "Step 4: Checking JWT token"
else
  echo -e "\n${YELLOW}Step 4: Checking JWT token${NC}"
fi

if type check_file_exists &>/dev/null; then
  if check_file_exists "$EPHEMERY_JWT_SECRET"; then
    if type log_success &>/dev/null; then
      log_success "JWT token file exists"
    else
      echo -e "${GREEN}✓ JWT token file exists${NC}"
    fi

    # Check file permissions
    FILE_PERMS=$(stat -c "%a" "$EPHEMERY_JWT_SECRET")
    if [ "$FILE_PERMS" == "600" ]; then
      if type log_success &>/dev/null; then
        log_success "JWT token has correct permissions (600)"
      else
        echo -e "${GREEN}✓ JWT token has correct permissions (600)${NC}"
      fi
    else
      if type log_error &>/dev/null; then
        log_error "JWT token has incorrect permissions: $FILE_PERMS"
        log_info "Setting correct permissions..."
        run_with_error_handling "Set JWT permissions" chmod 600 "$EPHEMERY_JWT_SECRET"
        log_success "Permissions corrected"
      else
        echo -e "${RED}✗ JWT token has incorrect permissions: $FILE_PERMS${NC}"
        echo -e "${YELLOW}Setting correct permissions...${NC}"
        chmod 600 "$EPHEMERY_JWT_SECRET"
        echo -e "${GREEN}✓ Permissions corrected${NC}"
      fi
    fi

    # Check token format
    TOKEN=$(cat "$EPHEMERY_JWT_SECRET")
    TOKEN_LENGTH=${#TOKEN}

    if type log_info &>/dev/null; then
      log_info "Token value (first 10 chars): ${TOKEN:0:10}..."
      log_info "Token length: $TOKEN_LENGTH characters"
    else
      echo -e "${BLUE}Token value (first 10 chars): ${TOKEN:0:10}...${NC}"
      echo -e "${BLUE}Token length: $TOKEN_LENGTH characters${NC}"
    fi

    if [[ $TOKEN == 0x* ]] && [ $TOKEN_LENGTH -eq 66 ]; then
      if type log_success &>/dev/null; then
        log_success "Token format appears correct (0x + 64 hex chars)"
      else
        echo -e "${GREEN}✓ Token format appears correct (0x + 64 hex chars)${NC}"
      fi
    else
      if type log_error &>/dev/null; then
        log_error "Token format may be incorrect"
        log_info "Regenerating JWT token..."
        run_with_error_handling "Regenerate JWT token" bash -c "echo \"0x\$(openssl rand -hex 32)\" > \"$EPHEMERY_JWT_SECRET\""
        run_with_error_handling "Set JWT permissions" chmod 600 "$EPHEMERY_JWT_SECRET"
        log_success "New JWT token generated"
        TOKEN=$(cat "$EPHEMERY_JWT_SECRET")
        log_info "New token value (first 10 chars): ${TOKEN:0:10}..."
      else
        echo -e "${RED}✗ Token format may be incorrect${NC}"
        echo -e "${YELLOW}Regenerating JWT token...${NC}"
        echo "0x$(openssl rand -hex 32)" > "$EPHEMERY_JWT_SECRET"
        chmod 600 "$EPHEMERY_JWT_SECRET"
        echo -e "${GREEN}✓ New JWT token generated${NC}"
        TOKEN=$(cat "$EPHEMERY_JWT_SECRET")
        echo -e "${BLUE}New token value (first 10 chars): ${TOKEN:0:10}...${NC}"
      fi
    fi
  else
    if type log_error &>/dev/null; then
      log_error "JWT token file does not exist"
      log_info "Creating JWT token..."
      run_with_error_handling "Create config directory" mkdir -p "$EPHEMERY_CONFIG_DIR"
      run_with_error_handling "Generate JWT token" bash -c "echo \"0x\$(openssl rand -hex 32)\" > \"$EPHEMERY_JWT_SECRET\""
      run_with_error_handling "Set JWT permissions" chmod 600 "$EPHEMERY_JWT_SECRET"
      log_success "JWT token created"
    else
      echo -e "${RED}✗ JWT token file does not exist${NC}"
      echo -e "${YELLOW}Creating JWT token...${NC}"
      mkdir -p "$EPHEMERY_CONFIG_DIR"
      echo "0x$(openssl rand -hex 32)" > "$EPHEMERY_JWT_SECRET"
      chmod 600 "$EPHEMERY_JWT_SECRET"
      echo -e "${GREEN}✓ JWT token created${NC}"
    fi
  fi
else
  # Fallback if check_file_exists function is not available
  if [ -f "$EPHEMERY_JWT_SECRET" ]; then
    echo -e "${GREEN}✓ JWT token file exists${NC}"

    # Check file permissions
    FILE_PERMS=$(stat -c "%a" "$EPHEMERY_JWT_SECRET")
    if [ "$FILE_PERMS" == "600" ]; then
      echo -e "${GREEN}✓ JWT token has correct permissions (600)${NC}"
    else
      echo -e "${RED}✗ JWT token has incorrect permissions: $FILE_PERMS${NC}"
      echo -e "${YELLOW}Setting correct permissions...${NC}"
      chmod 600 "$EPHEMERY_JWT_SECRET"
      echo -e "${GREEN}✓ Permissions corrected${NC}"
    fi

    # Check token format
    TOKEN=$(cat "$EPHEMERY_JWT_SECRET")
    TOKEN_LENGTH=${#TOKEN}

    echo -e "${BLUE}Token value (first 10 chars): ${TOKEN:0:10}...${NC}"
    echo -e "${BLUE}Token length: $TOKEN_LENGTH characters${NC}"

    if [[ $TOKEN == 0x* ]] && [ $TOKEN_LENGTH -eq 66 ]; then
      echo -e "${GREEN}✓ Token format appears correct (0x + 64 hex chars)${NC}"
    else
      echo -e "${RED}✗ Token format may be incorrect${NC}"
      echo -e "${YELLOW}Regenerating JWT token...${NC}"
      echo "0x$(openssl rand -hex 32)" > "$EPHEMERY_JWT_SECRET"
      chmod 600 "$EPHEMERY_JWT_SECRET"
      echo -e "${GREEN}✓ New JWT token generated${NC}"
      TOKEN=$(cat "$EPHEMERY_JWT_SECRET")
      echo -e "${BLUE}New token value (first 10 chars): ${TOKEN:0:10}...${NC}"
    fi
  else
    echo -e "${RED}✗ JWT token file does not exist${NC}"
    echo -e "${YELLOW}Creating JWT token...${NC}"
    mkdir -p "$EPHEMERY_CONFIG_DIR"
    echo "0x$(openssl rand -hex 32)" > "$EPHEMERY_JWT_SECRET"
    chmod 600 "$EPHEMERY_JWT_SECRET"
    echo -e "${GREEN}✓ JWT token created${NC}"
  fi
fi

# Step 5: Verify container networking
if type log_info &>/dev/null; then
  log_info "Step 5: Verifying container networking"
else
  echo -e "\n${YELLOW}Step 5: Verifying container networking${NC}"
fi

# Get container running status
if ! type is_container_running &>/dev/null; then
  GETH_RUNNING=$(docker ps -q -f name=ephemery-geth)
  LIGHTHOUSE_RUNNING=$(docker ps -q -f name=ephemery-lighthouse)
fi

if { type is_container_running &>/dev/null && is_container_running "${EPHEMERY_GETH_CONTAINER}" && is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}"; } || { [ -n "$GETH_RUNNING" ] && [ -n "$LIGHTHOUSE_RUNNING" ]; }; then
  GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-geth)
  LIGHTHOUSE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-lighthouse)

  if type log_info &>/dev/null; then
    log_info "Geth container IP: $GETH_IP"
    log_info "Lighthouse container IP: $LIGHTHOUSE_IP"
    log_info "Testing network connectivity from Lighthouse to Geth..."
  else
    echo -e "${BLUE}Geth container IP: $GETH_IP${NC}"
    echo -e "${BLUE}Lighthouse container IP: $LIGHTHOUSE_IP${NC}"
    echo -e "${YELLOW}Testing network connectivity from Lighthouse to Geth...${NC}"
  fi

  if type run_with_error_handling &>/dev/null; then
    if run_with_error_handling "Test container connectivity" docker exec ephemery-lighthouse ping -c 2 ephemery-geth &>/dev/null; then
      if type log_success &>/dev/null; then
        log_success "Lighthouse can ping Geth by container name"
      else
        echo -e "${GREEN}✓ Lighthouse can ping Geth by container name${NC}"
      fi
    else
      if type log_error &>/dev/null; then
        log_error "Lighthouse cannot ping Geth by container name"
      else
        echo -e "${RED}✗ Lighthouse cannot ping Geth by container name${NC}"
      fi

      if run_with_error_handling "Test IP connectivity" docker exec ephemery-lighthouse ping -c 2 "$GETH_IP" &>/dev/null; then
        if type log_success &>/dev/null; then
          log_success "Lighthouse can ping Geth by IP address"
        else
          echo -e "${GREEN}✓ Lighthouse can ping Geth by IP address${NC}"
        fi
      else
        if type log_error &>/dev/null; then
          log_error "Lighthouse cannot ping Geth by IP address"
          log_warning "This indicates a network configuration issue"
        else
          echo -e "${RED}✗ Lighthouse cannot ping Geth by IP address${NC}"
          echo -e "${YELLOW}This indicates a network configuration issue${NC}"
        fi
      fi
    fi
  else
    if docker exec ephemery-lighthouse ping -c 2 ephemery-geth &>/dev/null; then
      echo -e "${GREEN}✓ Lighthouse can ping Geth by container name${NC}"
    else
      echo -e "${RED}✗ Lighthouse cannot ping Geth by container name${NC}"

      if docker exec ephemery-lighthouse ping -c 2 "$GETH_IP" &>/dev/null; then
        echo -e "${GREEN}✓ Lighthouse can ping Geth by IP address${NC}"
      else
        echo -e "${RED}✗ Lighthouse cannot ping Geth by IP address${NC}"
        echo -e "${YELLOW}This indicates a network configuration issue${NC}"
      fi
    fi
  fi
else
  if type log_warning &>/dev/null; then
    log_warning "Skipping network tests as not all containers are running"
  else
    echo -e "${YELLOW}Skipping network tests as not all containers are running${NC}"
  fi
fi

# Step 6: Check container configuration
if type log_info &>/dev/null; then
  log_info "Step 6: Checking container configurations"
else
  echo -e "\n${YELLOW}Step 6: Checking container configurations${NC}"
fi

if (type is_container_running &>/dev/null && is_container_running "${EPHEMERY_GETH_CONTAINER}") || [ -n "$GETH_RUNNING" ]; then
  if type log_info &>/dev/null; then
    log_info "Geth container configuration:"
    run_with_error_handling "Inspect Geth container" docker inspect ephemery-geth
    log_info "Geth JWT path in container:"
    run_with_error_handling "Check JWT in container" docker exec ephemery-geth ls -la /config/jwt-secret
  else
    echo -e "${BLUE}Geth container configuration:${NC}"
    docker inspect ephemery-geth
    echo -e "${BLUE}Geth JWT path in container:${NC}"
    docker exec ephemery-geth ls -la /config/jwt-secret
  fi

  if type run_with_error_handling &>/dev/null; then
    if run_with_error_handling "Check JWT access" docker exec ephemery-geth cat /config/jwt-secret &>/dev/null; then
      if type log_success &>/dev/null; then
        log_success "Geth can access JWT token in container"
        GETH_TOKEN=$(docker exec ephemery-geth cat /config/jwt-secret)
        log_info "Geth JWT token (first 10 chars): ${GETH_TOKEN:0:10}..."
      else
        echo -e "${GREEN}✓ Geth can access JWT token in container${NC}"
        GETH_TOKEN=$(docker exec ephemery-geth cat /config/jwt-secret)
        echo -e "${BLUE}Geth JWT token (first 10 chars): ${GETH_TOKEN:0:10}...${NC}"
      fi
    else
      if type log_error &>/dev/null; then
        log_error "Geth cannot access JWT token in container"
      else
        echo -e "${RED}✗ Geth cannot access JWT token in container${NC}"
      fi
    fi
  else
    if docker exec ephemery-geth cat /config/jwt-secret &>/dev/null; then
      echo -e "${GREEN}✓ Geth can access JWT token in container${NC}"
      GETH_TOKEN=$(docker exec ephemery-geth cat /config/jwt-secret)
      echo -e "${BLUE}Geth JWT token (first 10 chars): ${GETH_TOKEN:0:10}...${NC}"
    else
      echo -e "${RED}✗ Geth cannot access JWT token in container${NC}"
    fi
  fi
fi

if (type is_container_running &>/dev/null && is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}") || [ -n "$LIGHTHOUSE_RUNNING" ]; then
  if type log_info &>/dev/null; then
    log_info "Lighthouse container configuration:"
    run_with_error_handling "Inspect Lighthouse container" docker inspect ephemery-lighthouse
    log_info "Lighthouse JWT path in container:"
    run_with_error_handling "Check JWT in container" docker exec ephemery-lighthouse ls -la /config/jwt-secret
  else
    echo -e "${BLUE}Lighthouse container configuration:${NC}"
    docker inspect ephemery-lighthouse
    echo -e "${BLUE}Lighthouse JWT path in container:${NC}"
    docker exec ephemery-lighthouse ls -la /config/jwt-secret
  fi

  if type run_with_error_handling &>/dev/null; then
    if run_with_error_handling "Check JWT access" docker exec ephemery-lighthouse cat /config/jwt-secret &>/dev/null; then
      if type log_success &>/dev/null; then
        log_success "Lighthouse can access JWT token in container"
        LIGHTHOUSE_TOKEN=$(docker exec ephemery-lighthouse cat /config/jwt-secret)
        log_info "Lighthouse JWT token (first 10 chars): ${LIGHTHOUSE_TOKEN:0:10}..."
      else
        echo -e "${GREEN}✓ Lighthouse can access JWT token in container${NC}"
        LIGHTHOUSE_TOKEN=$(docker exec ephemery-lighthouse cat /config/jwt-secret)
        echo -e "${BLUE}Lighthouse JWT token (first 10 chars): ${LIGHTHOUSE_TOKEN:0:10}...${NC}"
      fi
    else
      if type log_error &>/dev/null; then
        log_error "Lighthouse cannot access JWT token in container"
      else
        echo -e "${RED}✗ Lighthouse cannot access JWT token in container${NC}"
      fi
    fi
  else
    if docker exec ephemery-lighthouse cat /config/jwt-secret &>/dev/null; then
      echo -e "${GREEN}✓ Lighthouse can access JWT token in container${NC}"
      LIGHTHOUSE_TOKEN=$(docker exec ephemery-lighthouse cat /config/jwt-secret)
      echo -e "${BLUE}Lighthouse JWT token (first 10 chars): ${LIGHTHOUSE_TOKEN:0:10}...${NC}"
    else
      echo -e "${RED}✗ Lighthouse cannot access JWT token in container${NC}"
    fi
  fi
fi

# Compare tokens
if { (type is_container_running &>/dev/null && is_container_running "${EPHEMERY_GETH_CONTAINER}" && is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}"); } || { [ -n "$GETH_RUNNING" ] && [ -n "$LIGHTHOUSE_RUNNING" ]; }; then
  GETH_TOKEN=$(docker exec ephemery-geth cat /config/jwt-secret)
  LIGHTHOUSE_TOKEN=$(docker exec ephemery-lighthouse cat /config/jwt-secret)

  if [ "$GETH_TOKEN" == "$LIGHTHOUSE_TOKEN" ]; then
    if type log_success &>/dev/null; then
      log_success "JWT tokens match between containers"
    else
      echo -e "${GREEN}✓ JWT tokens match between containers${NC}"
    fi
  else
    if type log_error &>/dev/null; then
      log_error "JWT tokens DO NOT match between containers"
      log_warning "This is likely causing the authentication failure"
    else
      echo -e "${RED}✗ JWT tokens DO NOT match between containers${NC}"
      echo -e "${YELLOW}This is likely causing the authentication failure${NC}"
    fi
  fi
fi

# Step 7: Check logs for specific errors
if type log_info &>/dev/null; then
  log_info "Step 7: Checking container logs for errors"
else
  echo -e "\n${YELLOW}Step 7: Checking container logs for errors${NC}"
fi

if (type is_container_running &>/dev/null && is_container_running "${EPHEMERY_GETH_CONTAINER}") || [ -n "$GETH_RUNNING" ]; then
  if type log_info &>/dev/null; then
    log_info "Recent Geth logs:"
    run_with_error_handling "Show Geth logs" docker logs --tail 20 ephemery-geth
  else
    echo -e "${BLUE}Recent Geth logs:${NC}"
    docker logs --tail 20 ephemery-geth
  fi
fi

if (type is_container_running &>/dev/null && is_container_running "${EPHEMERY_LIGHTHOUSE_CONTAINER}") || [ -n "$LIGHTHOUSE_RUNNING" ]; then
  if type log_info &>/dev/null; then
    log_info "Recent Lighthouse logs:"
    run_with_error_handling "Show Lighthouse logs" docker logs --tail 20 ephemery-lighthouse
  else
    echo -e "${BLUE}Recent Lighthouse logs:${NC}"
    docker logs --tail 20 ephemery-lighthouse
  fi
fi

# Step 8: Fix JWT token and restart containers
if type log_info &>/dev/null; then
  log_info "Step 8: Would you like to fix JWT token and restart containers? (y/n)"
else
  echo -e "\n${YELLOW}Step 8: Would you like to fix JWT token and restart containers? (y/n)${NC}"
fi

read -p "Proceed? " PROCEED

if [ "$PROCEED" == "y" ] || [ "$PROCEED" == "Y" ]; then
  if type log_info &>/dev/null; then
    log_info "Stopping containers..."
    run_with_error_handling "Stop containers" docker stop ephemery-geth ephemery-lighthouse
    log_info "Regenerating JWT token..."
    run_with_error_handling "Generate JWT" bash -c "echo \"0x\$(openssl rand -hex 32)\" > \"$EPHEMERY_JWT_SECRET\""
    run_with_error_handling "Set permissions" chmod 600 "$EPHEMERY_JWT_SECRET"
    log_info "Starting containers with new JWT token..."
    run_with_error_handling "Start Geth" docker start ephemery-geth
    sleep 10
    run_with_error_handling "Start Lighthouse" docker start ephemery-lighthouse
    log_success "Containers restarted with new JWT token"
    log_warning "Check logs after 30 seconds to verify the issue is resolved"
  else
    echo -e "${BLUE}Stopping containers...${NC}"
    docker stop ephemery-geth ephemery-lighthouse
    echo -e "${BLUE}Regenerating JWT token...${NC}"
    echo "0x$(openssl rand -hex 32)" > "$EPHEMERY_JWT_SECRET"
    chmod 600 "$EPHEMERY_JWT_SECRET"
    echo -e "${BLUE}Starting containers with new JWT token...${NC}"
    docker start ephemery-geth
    sleep 10
    docker start ephemery-lighthouse
    echo -e "${GREEN}✓ Containers restarted with new JWT token${NC}"
    echo -e "${YELLOW}Check logs after 30 seconds to verify the issue is resolved${NC}"
  fi
else
  if type log_info &>/dev/null; then
    log_info "Skipping container restart"
  else
    echo -e "${BLUE}Skipping container restart${NC}"
  fi
fi

if type log_success &>/dev/null; then
  log_success "=== Troubleshooting Complete ==="
  log_info "If issues persist, consider the following:"
  log_info "1. Check if the execution endpoint URL is correct (http://ephemery-geth:8551)"
  log_info "2. Try using IP address instead of container name in connection string"
  log_info "3. Review container configurations for compatibility"
  log_info "4. Consider recreating the Docker network"
else
  echo -e "\n${GREEN}=== Troubleshooting Complete ===${NC}"
  echo -e "${BLUE}If issues persist, consider the following:${NC}"
  echo -e "1. Check if the execution endpoint URL is correct (http://ephemery-geth:8551)"
  echo -e "2. Try using IP address instead of container name in connection string"
  echo -e "3. Review container configurations for compatibility"
  echo -e "4. Consider recreating the Docker network"
fi

# Script end
