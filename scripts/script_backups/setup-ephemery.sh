#!/bin/bash
# Ephemery Testnet Node Setup Script
# This script automates the setup of an Ephemery testnet node with Electra/Pectra support

# Color codes for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=======================================${NC}"
echo -e "${GREEN}Ephemery Testnet Node Setup Script${NC}"
echo -e "${GREEN}=======================================${NC}"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

# Check Docker
echo -e "\n${YELLOW}Checking Docker...${NC}"
if command -v docker &> /dev/null; then
    echo -e "${GREEN}✓ Docker is installed${NC}"
else
    echo -e "${RED}✗ Docker is not installed${NC}"
    echo -e "${YELLOW}Installing Docker...${NC}"

    # Update package lists
    apt-get update

    # Install prerequisites
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common

    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

    # Add Docker repository
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"

    # Update package lists again
    apt-get update

    # Install Docker
    apt-get install -y docker-ce

    # Verify Docker is installed
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✓ Docker installed successfully${NC}"
    else
        echo -e "${RED}✗ Docker installation failed. Please install Docker manually.${NC}"
        exit 1
    fi
fi

# Create directory structure
echo -e "\n${YELLOW}Creating directory structure...${NC}"
mkdir -p /opt/ephemery/data/geth
mkdir -p /opt/ephemery/data/lighthouse
mkdir -p /opt/ephemery/data/validator
mkdir -p /opt/ephemery/config/ephemery_network
echo -e "${GREEN}✓ Directory structure created${NC}"

# Generate JWT token
echo -e "\n${YELLOW}Generating JWT token...${NC}"
openssl rand -hex 32 > /opt/ephemery/jwt.hex
echo -e "${GREEN}✓ JWT token generated${NC}"

# Download the Ephemery network configuration
echo -e "\n${YELLOW}Downloading Ephemery network configuration...${NC}"
curl -s -L https://github.com/ephemery-testnet/ephemery-genesis/releases/download/ephemery-143/testnet-all.tar.gz -o /tmp/testnet-all.tar.gz
if [ $? -eq 0 ]; then
    tar -xzf /tmp/testnet-all.tar.gz -C /opt/ephemery/config/ephemery_network
    rm /tmp/testnet-all.tar.gz
    echo -e "${GREEN}✓ Network configuration downloaded${NC}"
else
    echo -e "${RED}✗ Failed to download network configuration${NC}"
    echo -e "${YELLOW}Please download the Ephemery network configuration manually${NC}"
fi

# Pull Docker images
echo -e "\n${YELLOW}Pulling Docker images...${NC}"
docker pull pk910/ephemery-geth:latest
docker pull sigp/lighthouse:v5.3.0
echo -e "${GREEN}✓ Docker images pulled${NC}"

# Stop and remove existing containers
echo -e "\n${YELLOW}Stopping and removing existing containers...${NC}"
docker stop ephemery-geth ephemery-lighthouse ephemery-validator-lighthouse 2>/dev/null
docker rm ephemery-geth ephemery-lighthouse ephemery-validator-lighthouse 2>/dev/null
echo -e "${GREEN}✓ Containers stopped and removed${NC}"

# Start Geth
echo -e "\n${YELLOW}Starting Geth...${NC}"
docker run -d --name ephemery-geth \
  --restart=unless-stopped \
  --network=host \
  -v /opt/ephemery/data/geth:/data \
  -v /opt/ephemery/jwt.hex:/jwt.hex \
  -v /opt/ephemery/config/ephemery_network:/ephemery_config \
  pk910/ephemery-geth:latest \
  --http \
  --http.addr=0.0.0.0 \
  --http.port=8545 \
  --http.api=eth,web3,net,admin,debug \
  --authrpc.jwtsecret=/jwt.hex \
  --authrpc.addr=0.0.0.0

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Geth started successfully${NC}"
else
    echo -e "${RED}✗ Failed to start Geth${NC}"
    exit 1
fi

# Wait for Geth to initialize
echo -e "\n${YELLOW}Waiting for Geth to initialize (30 seconds)...${NC}"
sleep 30

# Start Lighthouse
echo -e "\n${YELLOW}Starting Lighthouse...${NC}"
docker run -d --name ephemery-lighthouse \
  --restart=unless-stopped \
  --network=host \
  -v /opt/ephemery/data/lighthouse:/data \
  -v /opt/ephemery/jwt.hex:/jwt.hex \
  -v /opt/ephemery/config/ephemery_network:/ephemery_config \
  sigp/lighthouse:v5.3.0 \
  lighthouse bn \
  --datadir=/data \
  --execution-jwt=/jwt.hex \
  --execution-endpoint=http://127.0.0.1:8551 \
  --http \
  --http-address=0.0.0.0 \
  --http-port=5052 \
  --metrics \
  --metrics-address=0.0.0.0 \
  --metrics-port=5054 \
  --testnet-dir=/ephemery_config \
  --boot-nodes=enr:-Iq4QNMYHuJGbnXyBj6FPS2UkOQ-hnxT-mIdNMMr7evR9UYtLemaluorL6J10RoUG1V4iTPTEbl3huijSNs5_ssBWFiGAYhBNHOzgmlkgnY0gmlwhIlKy_CJc2VjcDI1NmsxoQNULnJBzD8Sakd9EufSXhM4rQTIkhKBBTmWVJUtLCp8KoN1ZHCCIyk,enr:-Jq4QG8kommqwFYVbEqCUqJ6npHXdBw744AXgLtD2Fu6ZEvGLbF4HfgXghexazfh1rrGx8majjFNVP6PBOyEJKzHDxQBhGV0aDKQthie0mAAEBsKAAAAAAAAAIJpZIJ2NIJpcIRBbZouiXNlY3AyNTZrMaEDWBWEKcVGoF9-RyZUuqBsZBQgabSHqHbW4lYVNhduKHeDdWRwgiMp \
  --disable-upnp \
  --discovery-port=9000 \
  --target-peers=10 \
  --subscribe-all-subnets \
  --import-all-attestations \
  --allow-insecure-genesis-sync

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Lighthouse started successfully${NC}"
else
    echo -e "${RED}✗ Failed to start Lighthouse${NC}"
    exit 1
fi

# Wait for Lighthouse to initialize
echo -e "\n${YELLOW}Waiting for Lighthouse to initialize (30 seconds)...${NC}"
sleep 30

# Start Validator
echo -e "\n${YELLOW}Starting Validator...${NC}"
docker run -d --name ephemery-validator-lighthouse \
  --restart=unless-stopped \
  --network=host \
  -v /opt/ephemery/data/validator:/data \
  -v /opt/ephemery/jwt.hex:/jwt.hex \
  -v /opt/ephemery/config/ephemery_network:/ephemery_config \
  sigp/lighthouse:v5.3.0 \
  lighthouse vc \
  --datadir=/data \
  --beacon-nodes=http://127.0.0.1:5052 \
  --testnet-dir=/ephemery_config

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Validator started successfully${NC}"
else
    echo -e "${RED}✗ Failed to start Validator${NC}"
    # Don't exit on validator failure, as it's not critical
    echo -e "${YELLOW}You can start the validator later once you have imported validator keys${NC}"
fi

# Display status
echo -e "\n${YELLOW}Checking status...${NC}"
echo -e "\n${YELLOW}Geth peers:${NC}"
curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545 | grep -o '"result":"[^"]*"'

echo -e "\n${YELLOW}Lighthouse sync status:${NC}"
curl -s http://localhost:5052/eth/v1/node/syncing

echo -e "\n${GREEN}=======================================${NC}"
echo -e "${GREEN}Ephemery Node Setup Complete!${NC}"
echo -e "${GREEN}=======================================${NC}"
echo -e "\n${YELLOW}Note:${NC}"
echo -e "- Geth and Lighthouse will take time to sync. This could take several hours to days."
echo -e "- You can check the sync status using the commands in the documentation."
echo -e "- If you want to add validator keys, use the Lighthouse validator key import process."
echo -e "- For troubleshooting, run the troubleshoot-ephemery.sh script."
echo -e "\n${YELLOW}Useful commands:${NC}"
echo -e "- View Geth logs: ${GREEN}docker logs ephemery-geth${NC}"
echo -e "- View Lighthouse logs: ${GREEN}docker logs ephemery-lighthouse${NC}"
echo -e "- View Validator logs: ${GREEN}docker logs ephemery-validator-lighthouse${NC}"
echo -e "- Check Geth peers: ${GREEN}curl -s -X POST -H \"Content-Type: application/json\" --data '{\"jsonrpc\":\"2.0\",\"method\":\"net_peerCount\",\"params\":[],\"id\":1}' http://localhost:8545${NC}"
echo -e "- Check Lighthouse sync: ${GREEN}curl -s http://localhost:5052/eth/v1/node/syncing${NC}"
