#!/bin/bash
# Version: 1.0.0
#
# Enhanced Checkpoint Sync - Implements multi-provider fallback and improved monitoring
#
# This script implements the "Enhanced Checkpoint Sync" priority item from the roadmap
# It adds multi-provider fallback, improved monitoring, and better sync performance

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Load configuration if available
CONFIG_FILE="/opt/ephemery/config/ephemery_paths.conf"
if [ -f "${CONFIG_FILE}" ]; then
  echo "Loading configuration from ${CONFIG_FILE}"
  source "${CONFIG_FILE}"
else
  echo "Configuration file not found, using default paths"
  # Default paths if config not available
  EPHEMERY_BASE_DIR="/opt/ephemery"
  EPHEMERY_SCRIPTS_DIR="${EPHEMERY_BASE_DIR}/scripts"
  EPHEMERY_DATA_DIR="${EPHEMERY_BASE_DIR}/data"
  EPHEMERY_CONFIG_DIR="${EPHEMERY_BASE_DIR}/config"
  EPHEMERY_LOGS_DIR="${EPHEMERY_BASE_DIR}/logs"
fi

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Source the common library if it exists, otherwise use local definitions
if [[ -f "${SCRIPT_DIR}/../utilities/lib/common.sh" ]]; then
  source "${SCRIPT_DIR}/../utilities/lib/common.sh"
else
  # Define basic functions if common.sh is not available

  print_banner() {
    local message="$1"
    echo -e "${BLUE}==================================================${NC}"
    echo -e "${BLUE}    ${message}${NC}"
    echo -e "${BLUE}==================================================${NC}"
  }

  log_message() {
    local level="$1"
    local message="$2"

    case "${level}" in
      "INFO")
        echo -e "${GREEN}[INFO] ${message}${NC}"
        ;;
      "WARN")
        echo -e "${YELLOW}[WARN] ${message}${NC}"
        ;;
      "ERROR")
        echo -e "${RED}[ERROR] ${message}${NC}"
        ;;
      *)
        echo -e "[${level}] ${message}"
        ;;
    esac
  }

  check_command() {
    local cmd="$1"
    if ! command -v "${cmd}" &>/dev/null; then
      log_message "ERROR" "Required command '${cmd}' not found"
      return 1
    fi
    return 0
  }

  confirm_action() {
    local message="${1:-Are you sure you want to continue?}"

    echo -e "${YELLOW}${message} (y/n)${NC}"
    read -r response
    if [[ "${response}" =~ ^[Yy]$ ]]; then
      return 0
    else
      return 1
    fi
  }
fi

# Default configuration
DEFAULT_CHECKPOINT_URLS=(
  "https://checkpoint-sync.ephemery.ethpandaops.io"
  "https://checkpoint-sync.ephemery.ethpandaops.io"
  "https://beaconstate-ephemery.chainsafe.io"
)
CHECKPOINT_TIMEOUT=300
MAX_RETRIES=3
CONFIG_FILE="${EPHEMERY_BASE_DIR}/inventory.yaml"
BACKUP_DIR="${EPHEMERY_BASE_DIR}/backups/$(date +%Y%m%d%H%M%S)"
MONITOR_INTERVAL=60
VERBOSE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      echo "Usage: $(basename "$0") [options]"
      echo ""
      echo "Options:"
      echo "  -h, --help                 Display this help message"
      echo "  -v, --verbose              Enable verbose output"
      echo "  -t, --timeout SECONDS      Set timeout for checkpoint sync (default: 300)"
      echo "  -m, --monitor              Set up continuous monitoring after setup"
      echo "  -r, --reset                Reset the database before attempting sync"
      echo "  -f, --force                Skip confirmations"
      echo ""
      echo "Example:"
      echo "  $(basename "$0") --timeout 600 --monitor"
      exit 0
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -t | --timeout)
      CHECKPOINT_TIMEOUT="$2"
      shift 2
      ;;
    -m | --monitor)
      SETUP_MONITORING=true
      shift
      ;;
    -r | --reset)
      RESET_DATABASE=true
      shift
      ;;
    -f | --force)
      FORCE=true
      shift
      ;;
    *)
      log_message "ERROR" "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Print banner
print_banner "Enhanced Checkpoint Sync"

# Check prerequisites
log_message "INFO" "Checking prerequisites..."

# Check if running in an Ephemery environment
if [[ ! -f "${CONFIG_FILE}" ]]; then
  log_message "ERROR" "Not in an Ephemery environment. Cannot find ${CONFIG_FILE}"
  exit 1
fi

# Check for required tools
for cmd in ansible ansible-playbook curl jq systemctl; do
  if ! check_command "${cmd}"; then
    log_message "ERROR" "Required command '${cmd}' not found. Please install it and try again."
    exit 1
  fi
done

# Create backup directory
mkdir -p "${BACKUP_DIR}"
log_message "INFO" "Backup directory created: ${BACKUP_DIR}"

# Backup inventory file
cp "${CONFIG_FILE}" "${BACKUP_DIR}/inventory.yaml.backup"
log_message "INFO" "Backed up inventory.yaml to ${BACKUP_DIR}/inventory.yaml.backup"

# Function to check if URL is accessible
check_url() {
  local url="$1"
  local timeout="${2:-10}"

  if ${VERBOSE}; then
    log_message "INFO" "Checking URL: ${url} (timeout: ${timeout}s)"
  fi

  if curl --silent --fail --max-time "${timeout}" --output /dev/null "${url}"; then
    return 0
  else
    return 1
  fi
}

# Function to find a working checkpoint sync URL
find_working_checkpoint_url() {
  log_message "INFO" "Testing checkpoint sync URLs..."

  for url in "${DEFAULT_CHECKPOINT_URLS[@]}"; do
    log_message "INFO" "Testing URL: ${url}"
    if check_url "${url}" 20; then
      log_message "INFO" "URL is accessible: ${url}"
      WORKING_URL="${url}"
      return 0
    else
      log_message "WARN" "URL is not accessible: ${url}"
    fi
  done

  log_message "ERROR" "No working checkpoint sync URL found"
  return 1
}

# Function to update the inventory file with checkpoint sync configuration
update_inventory() {
  local backup_file="${BACKUP_DIR}/inventory.yaml.pre_update"
  cp "${CONFIG_FILE}" "${backup_file}"
  log_message "INFO" "Backed up inventory file to ${backup_file}"

  # Use sed to update the inventory file with the working URL and other optimizations
  sed -i.bak \
    -e 's/use_checkpoint_sync: false/use_checkpoint_sync: true/' \
    -e "s|checkpoint_sync_url: .*|checkpoint_sync_url: \"${WORKING_URL}\"|" \
    -e 's/cl_extra_opts: .*/cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"/' \
    -e 's/el_extra_opts: .*/el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"/' \
    "${CONFIG_FILE}"

  # Check if sed command succeeded
  if [[ $? -eq 0 ]]; then
    log_message "INFO" "Updated inventory.yaml with checkpoint sync configuration"
  else
    log_message "ERROR" "Failed to update inventory.yaml"
    cp "${backup_file}" "${CONFIG_FILE}"
    exit 1
  fi
}

# Function to create the fallback script
create_fallback_script() {
  local script_file="${EPHEMERY_BASE_DIR}/scripts/utilities/checkpoint_sync_fallback.sh"

  log_message "INFO" "Creating checkpoint sync fallback script at ${script_file}"

  mkdir -p "$(dirname "${script_file}")"

  # Create the fallback script
  cat >"${script_file}" <<EOL
#!/bin/bash
#
# Checkpoint Sync Fallback - Automatic fallback to alternative checkpoint URLs
#
# This script periodically checks the configured checkpoint sync URL and
# falls back to alternative URLs if the configured one is not accessible.

set -e

# Configuration
INVENTORY_FILE="\${INVENTORY_FILE:-${EPHEMERY_BASE_DIR}/inventory.yaml}"
CHECKPOINT_URLS=(
$(for url in "${DEFAULT_CHECKPOINT_URLS[@]}"; do echo "    \"${url}\""; done)
)
CHECK_INTERVAL=\${CHECK_INTERVAL:-300}
LOG_FILE="\${LOG_FILE:-/var/log/ephemery/checkpoint_fallback.log}"

# Create log directory if it doesn't exist
mkdir -p "\$(dirname "\$LOG_FILE")"

log() {
    local timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
    echo "[\$timestamp] \$1" | tee -a "\$LOG_FILE"
}

# Function to check if URL is accessible
check_url() {
    local url="\$1"
    local timeout="\${2:-10}"

    if curl --silent --fail --max-time "\$timeout" --output /dev/null "\$url"; then
        return 0
    else
        return 1
    fi
}

# Function to get current checkpoint URL from inventory
get_current_url() {
    grep -E "^[[:space:]]*checkpoint_sync_url:" "\$INVENTORY_FILE" | sed -E "s/^[[:space:]]*checkpoint_sync_url:[[:space:]]*[\"']?(.*)[\"']?/\\1/"
}

# Function to update the inventory file with a new checkpoint URL
update_url() {
    local new_url="\$1"
    local current_url=\$(get_current_url)

    if [[ "\$current_url" == "\$new_url" ]]; then
        log "URL already set to \$new_url, no update needed"
        return 0
    fi

    log "Updating checkpoint URL from \$current_url to \$new_url"

    # Create backup
    cp "\$INVENTORY_FILE" "\$INVENTORY_FILE.bak-\$(date +%Y%m%d%H%M%S)"

    # Update the URL
    sed -i.tmp -E "s|(checkpoint_sync_url:)[[:space:]]*[\"']?.*[\"']?|\\1 \"\$new_url\"|" "\$INVENTORY_FILE"

    # Check if update was successful
    if grep -q "\$new_url" "\$INVENTORY_FILE"; then
        log "Successfully updated checkpoint URL to \$new_url"

        # Restart lighthouse service if it exists
        if systemctl is-active --quiet lighthouse.service; then
            log "Restarting lighthouse service..."
            systemctl restart lighthouse.service
        fi

        return 0
    else
        log "Failed to update checkpoint URL"
        return 1
    fi
}

# Function to find a working checkpoint URL
find_working_url() {
    for url in "\${CHECKPOINT_URLS[@]}"; do
        log "Testing URL: \$url"
        if check_url "\$url" 20; then
            log "URL is accessible: \$url"
            return 0
        else
            log "URL is not accessible: \$url"
        fi
    done

    log "No working checkpoint URL found"
    return 1
}

# Main loop
log "Starting checkpoint sync fallback script"
log "Monitoring inventory file: \$INVENTORY_FILE"
log "Check interval: \$CHECK_INTERVAL seconds"

while true; do
    current_url=\$(get_current_url)
    log "Current checkpoint URL: \$current_url"

    if ! check_url "\$current_url" 30; then
        log "Current checkpoint URL is not accessible, finding alternative..."

        for url in "\${CHECKPOINT_URLS[@]}"; do
            if [[ "\$url" != "\$current_url" ]] && check_url "\$url" 20; then
                log "Found working alternative URL: \$url"
                update_url "\$url"
                break
            fi
        done
    else
        log "Current checkpoint URL is accessible, no action needed"
    fi

    log "Sleeping for \$CHECK_INTERVAL seconds"
    sleep "\$CHECK_INTERVAL"
done
EOL

  # Make the script executable
  chmod +x "${script_file}"

  log_message "INFO" "Fallback script created successfully"

  # Create systemd service for the fallback script
  local service_file="/etc/systemd/system/checkpoint-fallback.service"

  log_message "INFO" "Creating systemd service at ${service_file}"

  # Create the service file
  cat >"${service_file}" <<EOL
[Unit]
Description=Ephemery Checkpoint Sync Fallback Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=root
ExecStart=${script_file}
Restart=always
RestartSec=30
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=checkpoint-fallback

[Install]
WantedBy=multi-user.target
EOL

  # Enable and start the service
  systemctl daemon-reload
  systemctl enable checkpoint-fallback.service
  systemctl start checkpoint-fallback.service

  log_message "INFO" "Fallback service created, enabled, and started"
}

# Function to create the monitoring script
create_monitoring_script() {
  local script_file="${EPHEMERY_BASE_DIR}/scripts/monitoring/checkpoint_sync_monitor.sh"

  log_message "INFO" "Creating checkpoint sync monitoring script at ${script_file}"

  mkdir -p "$(dirname "${script_file}")"

  # Create the monitoring script
  cat >"${script_file}" <<EOL
#!/bin/bash
#
# Checkpoint Sync Monitoring - Monitors sync progress and provides alerts
#
# This script periodically checks the sync status and provides alerts if sync is stalled

set -e

# Configuration
LOG_FILE="\${LOG_FILE:-/var/log/ephemery/checkpoint_monitor.log}"
CHECK_INTERVAL=\${CHECK_INTERVAL:-${MONITOR_INTERVAL}}
ALERT_THRESHOLD=\${ALERT_THRESHOLD:-3}
PROGRESS_HISTORY_FILE="/var/log/ephemery/sync_progress_history.log"
LIGHTHOUSE_METRICS_PORT=5054

# Create log directories if they don't exist
mkdir -p "\$(dirname "\$LOG_FILE")" "\$(dirname "\$PROGRESS_HISTORY_FILE")"

log() {
    local timestamp=\$(date '+%Y-%m-%d %H:%M:%S')
    echo "[\$timestamp] \$1" | tee -a "\$LOG_FILE"
}

# Function to get current sync status from Lighthouse metrics
get_sync_status() {
    if ! curl -s "http://localhost:\$LIGHTHOUSE_METRICS_PORT/metrics" > /tmp/lighthouse_metrics; then
        log "Error: Could not fetch Lighthouse metrics"
        return 1
    fi

    # Extract sync information
    SYNC_DISTANCE=\$(grep 'sync_eth2_fallback_distance{sync_type="Optimistic"}' /tmp/lighthouse_metrics | awk '{print \$2}')
    SYNC_SPEED=\$(grep 'sync_eth2_slots_per_second{sync_type="Optimistic"}' /tmp/lighthouse_metrics | awk '{print \$2}')

    if [[ -z "\$SYNC_DISTANCE" || -z "\$SYNC_SPEED" ]]; then
        log "Error: Could not parse sync metrics"
        return 1
    fi

    echo "\$SYNC_DISTANCE \$SYNC_SPEED"
}

# Function to send alert
send_alert() {
    local message="\$1"
    local level="\${2:-warning}"

    log "[ALERT-\$level] \$message"

    # Add your preferred alert mechanism here (email, SMS, etc.)
    # For example, you could use the 'mail' command:
    # echo "\$message" | mail -s "Ephemery Sync Alert: \$level" your-email@example.com
}

# Function to record sync progress
record_progress() {
    local distance="\$1"
    local speed="\$2"
    local timestamp=\$(date +%s)

    echo "\$timestamp \$distance \$speed" >> "\$PROGRESS_HISTORY_FILE"
}

# Function to check if sync is making progress
check_progress() {
    local current_distance="\$1"
    local samples=\${2:-\$ALERT_THRESHOLD}

    # We need at least N+1 samples to compare
    local lines=\$(tail -n \$((\$samples + 1)) "\$PROGRESS_HISTORY_FILE" 2>/dev/null || echo "")

    if [[ -z "\$lines" || \$(echo "\$lines" | wc -l) -lt \$((\$samples + 1)) ]]; then
        log "Not enough history to check progress"
        return 0
    fi

    # Get the first sample from our window
    local first_sample=\$(echo "\$lines" | head -n 1)
    local first_distance=\$(echo "\$first_sample" | awk '{print \$2}')

    # Calculate progress
    local progress=\$(echo "\$first_distance - \$current_distance" | bc)

    log "Progress over last monitoring period: \$progress slots"

    if (( \$(echo "\$progress < 10" | bc -l) )); then
        log "WARNING: Sync progress is very slow or stalled"
        return 1
    fi

    return 0
}

# Function to estimate completion time
estimate_completion() {
    local distance="\$1"
    local speed="\$2"

    if (( \$(echo "\$speed <= 0" | bc -l) )); then
        echo "Unknown"
        return
    fi

    local seconds=\$(echo "\$distance / \$speed" | bc)
    local hours=\$(echo "\$seconds / 3600" | bc)
    local minutes=\$(echo "(\$seconds % 3600) / 60" | bc)

    echo "\${hours}h \${minutes}m"
}

# Main loop
log "Starting checkpoint sync monitoring script"
log "Check interval: \$CHECK_INTERVAL seconds"
log "Alert threshold: \$ALERT_THRESHOLD consecutive slow checks"

slow_count=0

while true; do
    # Get current sync status
    status=\$(get_sync_status)
    if [[ \$? -ne 0 ]]; then
        log "Failed to get sync status, will retry next cycle"
        sleep "\$CHECK_INTERVAL"
        continue
    fi

    distance=\$(echo "\$status" | awk '{print \$1}')
    speed=\$(echo "\$status" | awk '{print \$2}')

    # Record progress
    record_progress "\$distance" "\$speed"

    # Estimate completion time
    estimate=\$(estimate_completion "\$distance" "\$speed")

    log "Sync status: \$distance slots behind, syncing at \$speed slots/sec, estimated completion: \$estimate"

    # Check if sync is making progress
    if ! check_progress "\$distance"; then
        slow_count=\$((\$slow_count + 1))

        if [[ \$slow_count -ge \$ALERT_THRESHOLD ]]; then
            send_alert "Sync has been stalled or very slow for \$slow_count checks. Current distance: \$distance slots"
            slow_count=0
        else
            log "Slow sync detected (\$slow_count/\$ALERT_THRESHOLD before alerting)"
        fi
    else
        # Reset counter if progress is good
        if [[ \$slow_count -gt 0 ]]; then
            log "Sync speed has recovered"
            slow_count=0
        fi
    fi

    # If sync is complete, send a success alert
    if (( \$(echo "\$distance < 10" | bc -l) )); then
        send_alert "Sync is nearly complete! Current distance: \$distance slots" "info"
    fi

    sleep "\$CHECK_INTERVAL"
done
EOL

  # Make the script executable
  chmod +x "${script_file}"

  log_message "INFO" "Monitoring script created successfully"

  # Create systemd service for the monitoring script
  local service_file="/etc/systemd/system/checkpoint-monitor.service"

  log_message "INFO" "Creating systemd service at ${service_file}"

  # Create the service file
  cat >"${service_file}" <<EOL
[Unit]
Description=Ephemery Checkpoint Sync Monitoring Service
After=network.target lighthouse.service
Wants=network.target lighthouse.service

[Service]
Type=simple
User=root
ExecStart=${script_file}
Restart=always
RestartSec=30
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=checkpoint-monitor

[Install]
WantedBy=multi-user.target
EOL

  # Enable and start the service
  systemctl daemon-reload
  systemctl enable checkpoint-monitor.service
  systemctl start checkpoint-monitor.service

  log_message "INFO" "Monitoring service created, enabled, and started"
}

# Main function
main() {
  # Find a working checkpoint sync URL
  if ! find_working_checkpoint_url; then
    log_message "ERROR" "Could not find a working checkpoint sync URL. Please check your network connection."
    exit 1
  fi

  # Confirm changes
  if [[ "${FORCE:-false}" != "true" ]]; then
    if ! confirm_action "Ready to update checkpoint sync configuration with URL: ${WORKING_URL}. Continue?"; then
      log_message "INFO" "Operation cancelled by user"
      exit 0
    fi
  fi

  # Update inventory file
  update_inventory

  # Create fallback script
  if [[ "${FORCE:-false}" != "true" ]]; then
    if confirm_action "Would you like to set up automatic fallback between checkpoint providers?"; then
      create_fallback_script
    else
      log_message "INFO" "Skipping fallback script creation"
    fi
  else
    create_fallback_script
  fi

  # Set up monitoring if requested
  if [[ "${SETUP_MONITORING:-false}" == "true" ]]; then
    if [[ "${FORCE:-false}" != "true" ]]; then
      if confirm_action "Would you like to set up checkpoint sync monitoring?"; then
        create_monitoring_script
      else
        log_message "INFO" "Skipping monitoring script creation"
      fi
    else
      create_monitoring_script
    fi
  fi

  # Optionally reset the database and restart services
  if [[ "${RESET_DATABASE:-false}" == "true" ]]; then
    if [[ "${FORCE:-false}" != "true" ]]; then
      if confirm_action "Would you like to reset the database and restart services?"; then
        log_message "INFO" "Resetting database and restarting services..."

        # Stop services
        systemctl stop lighthouse.service
        systemctl stop execution-client.service

        # Reset database
        rm -rf /var/lib/lighthouse/data
        rm -rf /var/lib/execution-client/data

        # Start services
        systemctl start execution-client.service
        systemctl start lighthouse.service

        log_message "INFO" "Services restarted with fresh database"
      else
        log_message "INFO" "Skipping database reset"
      fi
    else
      log_message "INFO" "Resetting database and restarting services..."

      # Stop services
      systemctl stop lighthouse.service
      systemctl stop execution-client.service

      # Reset database
      rm -rf /var/lib/lighthouse/data
      rm -rf /var/lib/execution-client/data

      # Start services
      systemctl start execution-client.service
      systemctl start lighthouse.service

      log_message "INFO" "Services restarted with fresh database"
    fi
  fi

  log_message "INFO" "Enhanced checkpoint sync setup complete!"
  log_message "INFO" "Please monitor your node's sync status to ensure it's working correctly."

  # Provide instructions to the user
  echo ""
  echo "========================================================"
  echo "                   NEXT STEPS                           "
  echo "========================================================"
  echo ""
  echo "1. Monitor your node's sync status:"
  echo "   - Check progress: journalctl -fu lighthouse.service"
  echo "   - View metrics: curl http://localhost:5054/metrics | grep sync"
  echo ""
  echo "2. If you set up monitoring, view the logs:"
  echo "   - journalctl -fu checkpoint-monitor.service"
  echo ""
  echo "3. If you set up fallback, view the logs:"
  echo "   - journalctl -fu checkpoint-fallback.service"
  echo ""
  echo "4. Visit the dashboard (if set up) to view sync progress visually."
  echo ""
  echo "For more information, consult the Ephemery documentation."
  echo "========================================================"
}

# Run the main function
main
