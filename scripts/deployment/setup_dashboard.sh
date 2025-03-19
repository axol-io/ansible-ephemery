#!/bin/bash
# Version: 1.0.0
# setup_dashboard.sh - Script to set up the Ephemery checkpoint sync monitoring dashboard
# This implements Phase 4 of the Fix Checkpoint Sync Roadmap

# Colors for terminal output

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
DASHBOARD_DIR="${PROJECT_ROOT}/dashboard"

# Check dependencies
check_dependencies() {
  echo -e "${BLUE}Checking dependencies...${NC}"

  # Check for Docker
  if ! command -v docker &>/dev/null; then
    echo -e "${RED}Error: Docker is not installed.${NC}"
    echo -e "Please install Docker before running this script."
    exit 1
  fi

  # Check for Docker Compose
  if ! command -v docker-compose &>/dev/null; then
    echo -e "${YELLOW}Warning: Docker Compose is not installed.${NC}"
    echo -e "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.24.6/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  fi

  echo -e "${GREEN}All dependencies satisfied.${NC}"
}

# Function to display banner
show_banner() {
  echo -e "${BLUE}======================================================${NC}"
  echo -e "${BLUE}    Ephemery Checkpoint Sync Dashboard Setup    ${NC}"
  echo -e "${BLUE}======================================================${NC}"
  echo ""
  echo -e "This script sets up the Ephemery Checkpoint Sync Dashboard."
  echo -e "The dashboard provides real-time monitoring of sync status,"
  echo -e "historical sync data, and tools to manage checkpoint sync."
  echo ""
}

# Start the dashboard
start_dashboard() {
  echo -e "${BLUE}Starting the dashboard services...${NC}"

  cd "${DASHBOARD_DIR}" || {
    echo -e "${RED}Error: Failed to change directory to ${DASHBOARD_DIR}${NC}"
    exit 1
  }

  if [ -f "docker-compose.yml" ]; then
    docker-compose up -d

    if [ "$?" -eq 0 ]; then
      echo -e "${GREEN}Dashboard started successfully!${NC}"
      echo -e "You can access the dashboard at http://localhost:8080"
      echo -e "Grafana is available at http://localhost:3000 (admin/ephemery)"
      echo -e "Prometheus is available at http://localhost:9090"
    else
      echo -e "${RED}Failed to start the dashboard services.${NC}"
      echo -e "Please check the Docker Compose logs for more information."
      exit 1
    fi
  else
    echo -e "${RED}Error: docker-compose.yml not found in ${DASHBOARD_DIR}${NC}"
    echo -e "Please make sure the dashboard files are properly set up."
    exit 1
  fi
}

# Stop the dashboard
stop_dashboard() {
  echo -e "${BLUE}Stopping the dashboard services...${NC}"

  cd "${DASHBOARD_DIR}" || {
    echo -e "${RED}Error: Failed to change directory to ${DASHBOARD_DIR}${NC}"
    exit 1
  }

  if [ -f "docker-compose.yml" ]; then
    docker-compose down

    if [ "$?" -eq 0 ]; then
      echo -e "${GREEN}Dashboard stopped successfully!${NC}"
    else
      echo -e "${RED}Failed to stop the dashboard services.${NC}"
      echo -e "Please check the Docker Compose logs for more information."
      exit 1
    fi
  else
    echo -e "${RED}Error: docker-compose.yml not found in ${DASHBOARD_DIR}${NC}"
    echo -e "Please make sure the dashboard files are properly set up."
    exit 1
  fi
}

# Restart the dashboard
restart_dashboard() {
  echo -e "${BLUE}Restarting the dashboard services...${NC}"

  cd "${DASHBOARD_DIR}" || {
    echo -e "${RED}Error: Failed to change directory to ${DASHBOARD_DIR}${NC}"
    exit 1
  }

  if [ -f "docker-compose.yml" ]; then
    docker-compose restart

    if [ "$?" -eq 0 ]; then
      echo -e "${GREEN}Dashboard restarted successfully!${NC}"
    else
      echo -e "${RED}Failed to restart the dashboard services.${NC}"
      echo -e "Please check the Docker Compose logs for more information."
      exit 1
    fi
  else
    echo -e "${RED}Error: docker-compose.yml not found in ${DASHBOARD_DIR}${NC}"
    echo -e "Please make sure the dashboard files are properly set up."
    exit 1
  fi
}

# Show dashboard status
show_status() {
  echo -e "${BLUE}Checking dashboard status...${NC}"

  cd "${DASHBOARD_DIR}" || {
    echo -e "${RED}Error: Failed to change directory to ${DASHBOARD_DIR}${NC}"
    exit 1
  }

  if [ -f "docker-compose.yml" ]; then
    docker-compose ps
  else
    echo -e "${RED}Error: docker-compose.yml not found in ${DASHBOARD_DIR}${NC}"
    echo -e "Please make sure the dashboard files are properly set up."
    exit 1
  fi
}

# Show usage
usage() {
  echo -e "Usage: $0 [command]"
  echo -e ""
  echo -e "Commands:"
  echo -e "  start      Start the dashboard services"
  echo -e "  stop       Stop the dashboard services"
  echo -e "  restart    Restart the dashboard services"
  echo -e "  status     Show the status of the dashboard services"
  echo -e "  help       Show this help message"
  echo -e ""
}

# Main function
main() {
  show_banner

  # Check if dashboard directory exists
  if [ ! -d "${DASHBOARD_DIR}" ]; then
    echo -e "${RED}Error: Dashboard directory does not exist at ${DASHBOARD_DIR}${NC}"
    echo -e "Please run the setup first or check the repository structure."
    exit 1
  fi

  # Process command
  case "$1" in
    start)
      check_dependencies
      start_dashboard
      ;;
    stop)
      check_dependencies
      stop_dashboard
      ;;
    restart)
      check_dependencies
      restart_dashboard
      ;;
    status)
      check_dependencies
      show_status
      ;;
    help)
      usage
      ;;
    *)
      echo -e "${YELLOW}No command specified. Using default command: start${NC}"
      check_dependencies
      start_dashboard
      ;;
  esac
}

# Execute main function with all args
main "$@"

# Install Docker API
if [ "${install_api}" = true ]; then
  echo -e "${GREEN}Installing Dashboard API...${NC}"
  # Ensure we have Python 3 and pip
  apt-get update
  apt-get install -y python3 python3-pip

  # Navigate to dashboard directory
  cd "${DASHBOARD_DIR}" || {
    echo "Error: Failed to change directory to ${DASHBOARD_DIR}"
    exit 1
  }

  # Install dependencies
  pip3 install -r api/requirements.txt

  # Setup API service
  cp api/dashboard_api.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable dashboard_api
  systemctl start dashboard_api

  # Setup websocket service for sync status
  cp api/sync_websocket.service /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable sync_websocket
  systemctl start sync_websocket

  echo -e "${GREEN}Dashboard API installed.${NC}"
fi

# Install Docker Compose
if [ "${install_compose}" = true ]; then
  echo -e "${GREEN}Installing Docker Compose...${NC}"
  apt-get update
  apt-get install -y docker-compose

  # Navigate to dashboard directory
  cd "${DASHBOARD_DIR}" || {
    echo "Error: Failed to change directory to ${DASHBOARD_DIR}"
    exit 1
  }

  # Start services
  docker-compose up -d

  echo -e "${GREEN}Dashboard services started.${NC}"
fi

# Install the frontend
if [ "${install_frontend}" = true ]; then
  echo -e "${GREEN}Installing Dashboard Frontend...${NC}"
  apt-get update
  apt-get install -y nginx

  # Navigate to dashboard directory
  cd "${DASHBOARD_DIR}" || {
    echo "Error: Failed to change directory to ${DASHBOARD_DIR}"
    exit 1
  }

  # Deploy frontend
  cp -r app/* /var/www/html/

  # Setup Nginx configuration
  cp nginx/dashboard.conf /etc/nginx/sites-available/
  ln -sf /etc/nginx/sites-available/dashboard.conf /etc/nginx/sites-enabled/
  rm -f /etc/nginx/sites-enabled/default
  systemctl restart nginx

  echo -e "${GREEN}Dashboard Frontend installed.${NC}"
fi

# Set up Prometheus metrics
if [ "${install_prometheus}" = true ]; then
  echo -e "${GREEN}Setting up Prometheus for metrics collection...${NC}"
  apt-get update
  apt-get install -y prometheus

  # Navigate to dashboard directory
  cd "${DASHBOARD_DIR}" || {
    echo "Error: Failed to change directory to ${DASHBOARD_DIR}"
    exit 1
  }

  # Fix by adding the missing fi here
fi
