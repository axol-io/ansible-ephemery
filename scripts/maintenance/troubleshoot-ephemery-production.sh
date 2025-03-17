#!/bin/bash
# Version: 1.0.0

# Ephemery Production Node Troubleshooting Script
# This script helps diagnose and fix common issues with Ephemery production nodes

# Colors for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Ephemery Production Node Troubleshooting ===${NC}"
echo -e "${BLUE}Starting comprehensive diagnostics...${NC}"

# Load configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "${CONFIG_FILE}" ]; then
  echo -e "${BLUE}Loading configuration from ${CONFIG_FILE}${NC}"
  source "${CONFIG_FILE}"
else
  echo -e "${YELLOW}Configuration file not found, using default paths${NC}"
  # Default paths if config not available
  EPHEMERY_BASE_DIR="/root/ephemery"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_JWT_SECRET="${EPHEMERY_CONFIG_DIR}/jwt.hex"
fi

# Step 1: Check Docker service status
echo -e "\n${YELLOW}Step 1: Checking Docker service status${NC}"
if systemctl is-active --quiet docker; then
  echo -e "${GREEN}✓ Docker service is running${NC}"
else
  echo -e "${RED}✗ Docker service is not running${NC}"
  echo -e "${YELLOW}Attempting to start Docker service...${NC}"
  systemctl start docker
  systemctl is-active --quiet docker && echo -e "${GREEN}✓ Docker service started successfully${NC}" || echo -e "${RED}✗ Failed to start Docker service${NC}"
fi

# Step 2: Check Ephemery containers
echo -e "\n${YELLOW}Step 2: Checking Ephemery containers${NC}"
echo -e "${BLUE}Current running containers:${NC}"
docker ps

GETH_RUNNING=$(docker ps -q -f name=ephemery-geth)
LIGHTHOUSE_RUNNING=$(docker ps -q -f name=ephemery-lighthouse)

if [ -n "${GETH_RUNNING}" ]; then
  echo -e "${GREEN}✓ Geth container is running${NC}"
else
  echo -e "${RED}✗ Geth container is not running${NC}"
fi

if [ -n "${LIGHTHOUSE_RUNNING}" ]; then
  echo -e "${GREEN}✓ Lighthouse container is running${NC}"
else
  echo -e "${RED}✗ Lighthouse container is not running${NC}"
fi

# Step 3: Check Docker network
echo -e "\n${YELLOW}Step 3: Checking Docker network${NC}"
if docker network inspect ephemery &>/dev/null; then
  echo -e "${GREEN}✓ Ephemery network exists${NC}"
  echo -e "${BLUE}Network details:${NC}"
  docker network inspect ephemery
else
  echo -e "${RED}✗ Ephemery network does not exist${NC}"
  echo -e "${YELLOW}Creating ephemery network...${NC}"
  docker network create ephemery
  echo -e "${GREEN}✓ Ephemery network created${NC}"
fi

# Check for dedicated network
if docker network inspect ephemery-net &>/dev/null; then
  echo -e "${GREEN}✓ Dedicated ephemery-net network exists${NC}"
  echo -e "${BLUE}Network details:${NC}"
  docker network inspect ephemery-net
else
  echo -e "${YELLOW}Creating dedicated ephemery-net network...${NC}"
  docker network create ephemery-net
  echo -e "${GREEN}✓ Dedicated ephemery-net network created${NC}"

  # Connect containers to the new network if they exist
  if [ -n "${GETH_RUNNING}" ]; then
    docker network connect ephemery-net ephemery-geth
    echo -e "${GREEN}✓ Connected Geth to ephemery-net${NC}"
  fi

  if [ -n "${LIGHTHOUSE_RUNNING}" ]; then
    docker network connect ephemery-net ephemery-lighthouse
    echo -e "${GREEN}✓ Connected Lighthouse to ephemery-net${NC}"
  fi
fi

# Step 4: Check JWT token
echo -e "\n${YELLOW}Step 4: Checking JWT token${NC}"
if [ -f "${EPHEMERY_JWT_SECRET}" ]; then
  echo -e "${GREEN}✓ JWT token file exists${NC}"

  # Check file permissions
  FILE_PERMS=$(stat -c "%a" "${EPHEMERY_JWT_SECRET}")
  if [ "${FILE_PERMS}" == "600" ]; then
    echo -e "${GREEN}✓ JWT token has correct permissions (600)${NC}"
  else
    echo -e "${RED}✗ JWT token has incorrect permissions: ${FILE_PERMS}${NC}"
    echo -e "${YELLOW}Setting correct permissions...${NC}"
    chmod 600 "${EPHEMERY_JWT_SECRET}"
    echo -e "${GREEN}✓ Permissions corrected${NC}"
  fi

  # Check token format
  TOKEN=$(cat "${EPHEMERY_JWT_SECRET}")
  TOKEN_LENGTH=${#TOKEN}

  echo -e "${BLUE}Token value (first 10 chars): ${TOKEN:0:10}...${NC}"
  echo -e "${BLUE}Token length: ${TOKEN_LENGTH} characters${NC}"

  if [[ ${TOKEN} == 0x* ]] && [ "${TOKEN_LENGTH}" -eq 66 ]; then
    echo -e "${GREEN}✓ Token format appears correct (0x + 64 hex chars)${NC}"
  else
    echo -e "${RED}✗ Token format may be incorrect${NC}"
    echo -e "${YELLOW}Regenerating JWT token...${NC}"
    echo "0x$(openssl rand -hex 32)" >"${EPHEMERY_JWT_SECRET}"
    chmod 600 "${EPHEMERY_JWT_SECRET}"
    echo -e "${GREEN}✓ New JWT token generated${NC}"
    TOKEN=$(cat "${EPHEMERY_JWT_SECRET}")
    echo -e "${BLUE}New token value (first 10 chars): ${TOKEN:0:10}...${NC}"
  fi
else
  echo -e "${RED}✗ JWT token file does not exist${NC}"
  echo -e "${YELLOW}Creating JWT token...${NC}"
  mkdir -p "${EPHEMERY_CONFIG_DIR}"
  echo "0x$(openssl rand -hex 32)" >"${EPHEMERY_JWT_SECRET}"
  chmod 600 "${EPHEMERY_JWT_SECRET}"
  echo -e "${GREEN}✓ JWT token created${NC}"
fi

# Step 5: Verify container networking
echo -e "\n${YELLOW}Step 5: Verifying container networking${NC}"
if [ -n "${GETH_RUNNING}" ] && [ -n "${LIGHTHOUSE_RUNNING}" ]; then
  GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-geth)
  LIGHTHOUSE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-lighthouse)

  # Get IPs from dedicated network if available
  GETH_DEDICATED_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{if eq .NetworkID "ephemery-net"}}{{.IPAddress}}{{end}}{{end}}' ephemery-geth)
  LIGHTHOUSE_DEDICATED_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{if eq .NetworkID "ephemery-net"}}{{.IPAddress}}{{end}}{{end}}' ephemery-lighthouse)

  echo -e "${BLUE}Geth container IP (default network): ${GETH_IP}${NC}"
  echo -e "${BLUE}Lighthouse container IP (default network): ${LIGHTHOUSE_IP}${NC}"

  if [ -n "${GETH_DEDICATED_IP}" ]; then
    echo -e "${BLUE}Geth container IP (dedicated network): ${GETH_DEDICATED_IP}${NC}"
  fi

  if [ -n "${LIGHTHOUSE_DEDICATED_IP}" ]; then
    echo -e "${BLUE}Lighthouse container IP (dedicated network): ${LIGHTHOUSE_DEDICATED_IP}${NC}"
  fi

  echo -e "${YELLOW}Testing network connectivity from Lighthouse to Geth...${NC}"
  if docker exec ephemery-lighthouse ping -c 2 ephemery-geth &>/dev/null; then
    echo -e "${GREEN}✓ Lighthouse can ping Geth by container name${NC}"
  else
    echo -e "${RED}✗ Lighthouse cannot ping Geth by container name${NC}"

    if docker exec ephemery-lighthouse ping -c 2 "${GETH_IP}" &>/dev/null; then
      echo -e "${GREEN}✓ Lighthouse can ping Geth by IP address${NC}"
    else
      echo -e "${RED}✗ Lighthouse cannot ping Geth by IP address${NC}"
      echo -e "${YELLOW}This indicates a network configuration issue${NC}"
    fi
  fi

  # Test API endpoint connectivity
  echo -e "${YELLOW}Testing API endpoint connectivity...${NC}"
  if docker exec ephemery-lighthouse curl -s http://ephemery-geth:8551 &>/dev/null; then
    echo -e "${GREEN}✓ Lighthouse can connect to Geth API endpoint by name${NC}"
  else
    echo -e "${RED}✗ Lighthouse cannot connect to Geth API endpoint by name${NC}"
    echo -e "${YELLOW}This may be due to JWT authentication or network issues${NC}"
  fi
else
  echo -e "${YELLOW}Skipping network tests as not all containers are running${NC}"
fi

# Step 6: Check container configuration
echo -e "\n${YELLOW}Step 6: Checking container configurations${NC}"
if [ -n "${GETH_RUNNING}" ]; then
  echo -e "${BLUE}Geth container configuration:${NC}"
  docker inspect ephemery-geth | grep -A 10 -B 2 "Cmd"

  echo -e "${BLUE}Geth JWT path in container:${NC}"
  docker exec ephemery-geth ls -la /config/jwt-secret

  if docker exec ephemery-geth cat /config/jwt-secret &>/dev/null; then
    echo -e "${GREEN}✓ Geth can access JWT token in container${NC}"
    GETH_TOKEN=$(docker exec ephemery-geth cat /config/jwt-secret)
    echo -e "${BLUE}Geth JWT token (first 10 chars): ${GETH_TOKEN:0:10}...${NC}"
  else
    echo -e "${RED}✗ Geth cannot access JWT token in container${NC}"
  fi
fi

if [ -n "${LIGHTHOUSE_RUNNING}" ]; then
  echo -e "${BLUE}Lighthouse container configuration:${NC}"
  docker inspect ephemery-lighthouse | grep -A 20 -B 2 "Cmd"

  echo -e "${BLUE}Lighthouse JWT path in container:${NC}"
  docker exec ephemery-lighthouse ls -la /config/jwt-secret

  if docker exec ephemery-lighthouse cat /config/jwt-secret &>/dev/null; then
    echo -e "${GREEN}✓ Lighthouse can access JWT token in container${NC}"
    LIGHTHOUSE_TOKEN=$(docker exec ephemery-lighthouse cat /config/jwt-secret)
    echo -e "${BLUE}Lighthouse JWT token (first 10 chars): ${LIGHTHOUSE_TOKEN:0:10}...${NC}"
  else
    echo -e "${RED}✗ Lighthouse cannot access JWT token in container${NC}"
  fi

  # Check execution endpoint configuration
  EXECUTION_ENDPOINT=$(docker inspect ephemery-lighthouse | grep -A 1 "execution-endpoint" | grep -v "execution-endpoint" | tr -d '", ' | head -1)
  echo -e "${BLUE}Lighthouse execution endpoint: ${EXECUTION_ENDPOINT}${NC}"

  if [[ "${EXECUTION_ENDPOINT}" == *"ephemery-geth"* ]]; then
    echo -e "${YELLOW}⚠ Lighthouse is using container name for execution endpoint${NC}"
    echo -e "${YELLOW}Consider using IP address instead if experiencing JWT authentication issues${NC}"
  elif [[ "${EXECUTION_ENDPOINT}" == *"${GETH_IP}"* || "${EXECUTION_ENDPOINT}" == *"${GETH_DEDICATED_IP}"* ]]; then
    echo -e "${GREEN}✓ Lighthouse is using IP address for execution endpoint${NC}"
  fi
fi

# Compare tokens
if [ -n "${GETH_RUNNING}" ] && [ -n "${LIGHTHOUSE_RUNNING}" ]; then
  GETH_TOKEN=$(docker exec ephemery-geth cat /config/jwt-secret)
  LIGHTHOUSE_TOKEN=$(docker exec ephemery-lighthouse cat /config/jwt-secret)

  if [ "${GETH_TOKEN}" == "${LIGHTHOUSE_TOKEN}" ]; then
    echo -e "${GREEN}✓ JWT tokens match between containers${NC}"
  else
    echo -e "${RED}✗ JWT tokens DO NOT match between containers${NC}"
    echo -e "${YELLOW}This is likely causing the authentication failure${NC}"
  fi
fi

# Step 7: Check logs for specific errors
echo -e "\n${YELLOW}Step 7: Checking container logs for errors${NC}"
if [ -n "${GETH_RUNNING}" ]; then
  echo -e "${BLUE}Recent Geth logs:${NC}"
  docker logs --tail 20 ephemery-geth
fi

if [ -n "${LIGHTHOUSE_RUNNING}" ]; then
  echo -e "${BLUE}Recent Lighthouse logs:${NC}"
  docker logs --tail 20 ephemery-lighthouse

  # Check for specific JWT errors
  JWT_ERRORS=$(docker logs ephemery-lighthouse 2>&1 | grep -c "Failed jwt authorization")
  if [ "${JWT_ERRORS}" -gt 0 ]; then
    echo -e "${RED}✗ Found ${JWT_ERRORS} JWT authorization errors in Lighthouse logs${NC}"
  else
    echo -e "${GREEN}✓ No JWT authorization errors found in recent logs${NC}"
  fi
fi

# Step 8: Check monitoring stack
echo -e "\n${YELLOW}Step 8: Checking monitoring stack${NC}"
PROMETHEUS_RUNNING=$(docker ps -q -f name=prometheus)
GRAFANA_RUNNING=$(docker ps -q -f name=grafana)

if [ -n "${PROMETHEUS_RUNNING}" ]; then
  echo -e "${GREEN}✓ Prometheus container is running${NC}"
else
  echo -e "${RED}✗ Prometheus container is not running${NC}"

  # Check Prometheus configuration
  if [ -f "${EPHEMERY_CONFIG_DIR}/prometheus/prometheus.yml" ]; then
    echo -e "${GREEN}✓ Prometheus configuration file exists${NC}"
  else
    echo -e "${RED}✗ Prometheus configuration file does not exist${NC}"
    echo -e "${YELLOW}Creating Prometheus configuration...${NC}"

    mkdir -p "${EPHEMERY_CONFIG_DIR}/prometheus"
    cat >"${EPHEMERY_CONFIG_DIR}/prometheus/prometheus.yml" <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'geth'
    metrics_path: /debug/metrics/prometheus
    static_configs:
      - targets: ['ephemery-geth:6060']

  - job_name: 'lighthouse'
    static_configs:
      - targets: ['ephemery-lighthouse:5054']
EOF
    echo -e "${GREEN}✓ Prometheus configuration created${NC}"
  fi
fi

if [ -n "${GRAFANA_RUNNING}" ]; then
  echo -e "${GREEN}✓ Grafana container is running${NC}"
else
  echo -e "${RED}✗ Grafana container is not running${NC}"
fi

# Step 9: Fix JWT token and restart containers
echo -e "\n${YELLOW}Step 9: Would you like to fix JWT token and restart containers? (y/n)${NC}"
read -p "Proceed? " PROCEED

if [ "${PROCEED}" == "y" ] || [ "${PROCEED}" == "Y" ]; then
  echo -e "${BLUE}Stopping containers...${NC}"
  docker stop ephemery-geth ephemery-lighthouse

  echo -e "${BLUE}Regenerating JWT token...${NC}"
  echo "0x$(openssl rand -hex 32)" >"${EPHEMERY_JWT_SECRET}"
  chmod 600 "${EPHEMERY_JWT_SECRET}"

  echo -e "${BLUE}Starting Geth container...${NC}"
  docker start ephemery-geth
  sleep 10

  # Get Geth IP from dedicated network
  GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{if eq .NetworkID "ephemery-net"}}{{.IPAddress}}{{end}}{{end}}' ephemery-geth)
  if [ -z "${GETH_IP}" ]; then
    GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-geth)
  fi

  echo -e "${BLUE}Recreating Lighthouse container with Geth IP (${GETH_IP})...${NC}"
  docker rm ephemery-lighthouse

  docker run -d --name ephemery-lighthouse \
    --network ephemery-net \
    --restart unless-stopped \
    -v "${EPHEMERY_BASE_DIR}/data/lighthouse:/ethdata" \
    -v "${EPHEMERY_JWT_SECRET}:/config/jwt-secret" \
    -p 5052:5052 -p 9000:9000 -p 9000:9000/udp -p 8008:8008 \
    pk910/ephemery-lighthouse:latest \
    lighthouse beacon \
    --datadir /ethdata \
    --testnet-dir /ephemery_config \
    --execution-jwt /config/jwt-secret \
    --execution-endpoint "http://${GETH_IP}:8551" \
    --http --http-address 0.0.0.0 --http-port 5052 \
    --target-peers=100 \
    --execution-timeout-multiplier=5 \
    --allow-insecure-genesis-sync \
    --genesis-backfill \
    --disable-backfill-rate-limiting \
    --disable-deposit-contract-sync

  echo -e "${GREEN}✓ Containers restarted with new JWT token and IP-based configuration${NC}"
  echo -e "${YELLOW}Check logs after 30 seconds to verify the issue is resolved${NC}"

  # Fix monitoring if needed
  if [ -z "${PROMETHEUS_RUNNING}" ] || [ -z "${GRAFANA_RUNNING}" ]; then
    echo -e "${BLUE}Fixing monitoring stack...${NC}"

    if [ -z "${PROMETHEUS_RUNNING}" ]; then
      docker rm prometheus 2>/dev/null || true
      docker run -d --name prometheus --network host \
        -v "${EPHEMERY_CONFIG_DIR}/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml" \
        prom/prometheus:v2.47.2
      echo -e "${GREEN}✓ Prometheus container recreated${NC}"
    fi

    if [ -z "${GRAFANA_RUNNING}" ]; then
      docker rm grafana 2>/dev/null || true
      docker run -d --name grafana --network host \
        -e GF_SECURITY_ADMIN_USER=admin \
        -e GF_SECURITY_ADMIN_PASSWORD=ephemery \
        -e GF_AUTH_ANONYMOUS_ENABLED=true \
        -e GF_USERS_ALLOW_SIGN_UP=false \
        -e GF_SERVER_HTTP_PORT=3000 \
        grafana/grafana:latest
      echo -e "${GREEN}✓ Grafana container recreated${NC}"
    fi
  fi
else
  echo -e "${BLUE}Skipping container restart${NC}"
fi

echo -e "\n${GREEN}=== Troubleshooting Complete ===${NC}"
echo -e "${BLUE}If issues persist, consider the following:${NC}"
echo -e "1. Check if the execution endpoint URL is correct (http://<GETH_IP>:8551)"
echo -e "2. Try using IP address instead of container name in connection string"
echo -e "3. Review container configurations for compatibility"
echo -e "4. Consider recreating the Docker network"
echo -e "5. Check for firewall rules blocking container communication"

# Script end
