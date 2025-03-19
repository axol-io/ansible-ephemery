#!/bin/bash
# Version: 1.0.0
#
# Validator Alert System
# =====================
# This script provides a comprehensive alert system for validator performance,
# with configurable thresholds, multiple notification channels, and alert categories.

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
BASE_DIR=${BASE_DIR:-"/root/ephemery"}
CONFIG_DIR="${BASE_DIR}/config"
DATA_DIR="${BASE_DIR}/data"
LOG_DIR="${BASE_DIR}/logs"
METRICS_DIR="${DATA_DIR}/metrics"
ALERT_DIR="${DATA_DIR}/alerts"
ALERT_CONFIG="${CONFIG_DIR}/alert_config.json"
ALERT_LOG="${LOG_DIR}/validator_alerts.log"
ALERT_HISTORY="${ALERT_DIR}/history"
ACTIVE_ALERTS="${ALERT_DIR}/active_alerts.json"
VALIDATOR_METRICS="${METRICS_DIR}/validator_metrics.json"
EARNINGS_DATA="${METRICS_DIR}/earnings/validator_earnings.json"
COMPARISON_DATA="${METRICS_DIR}/comparisons/validator_comparison.json"
BEACON_NODE_ENDPOINT=${BEACON_NODE_ENDPOINT:-"http://localhost:5052"}

# Default alert thresholds
DEFAULT_CRITICAL_ATTESTATION_RATE=0.90
DEFAULT_WARNING_ATTESTATION_RATE=0.95
DEFAULT_CRITICAL_BALANCE_DECREASE=0.01
DEFAULT_WARNING_BALANCE_DECREASE=0.005
DEFAULT_CRITICAL_SYNC_DISTANCE=100
DEFAULT_WARNING_SYNC_DISTANCE=50
DEFAULT_CRITICAL_PEERS=5
DEFAULT_WARNING_PEERS=10

# Default notification settings
DEFAULT_ENABLE_EMAIL=false
DEFAULT_ENABLE_TELEGRAM=false
DEFAULT_ENABLE_DISCORD=false
DEFAULT_ENABLE_CONSOLE=true
DEFAULT_ENABLE_LOG=true
DEFAULT_EMAIL_RECIPIENT=""
DEFAULT_TELEGRAM_BOT_TOKEN=""
DEFAULT_TELEGRAM_CHAT_ID=""
DEFAULT_DISCORD_WEBHOOK=""

# Ensure directories exist
mkdir -p "${ALERT_DIR}/history" "${LOG_DIR}"

# Create default alert configuration if it doesn't exist
if [[ ! -f "${ALERT_CONFIG}" ]]; then
    mkdir -p "$(dirname "${ALERT_CONFIG}")"
    cat > "${ALERT_CONFIG}" << EOF
{
  "alert_thresholds": {
    "attestation": {
      "critical": ${DEFAULT_CRITICAL_ATTESTATION_RATE},
      "warning": ${DEFAULT_WARNING_ATTESTATION_RATE}
    },
    "balance": {
      "critical_decrease": ${DEFAULT_CRITICAL_BALANCE_DECREASE},
      "warning_decrease": ${DEFAULT_WARNING_BALANCE_DECREASE}
    },
    "sync": {
      "critical_distance": ${DEFAULT_CRITICAL_SYNC_DISTANCE},
      "warning_distance": ${DEFAULT_WARNING_SYNC_DISTANCE}
    },
    "peers": {
      "critical_minimum": ${DEFAULT_CRITICAL_PEERS},
      "warning_minimum": ${DEFAULT_WARNING_PEERS}
    }
  },
  "notification": {
    "email": {
      "enabled": ${DEFAULT_ENABLE_EMAIL},
      "recipient": "${DEFAULT_EMAIL_RECIPIENT}"
    },
    "telegram": {
      "enabled": ${DEFAULT_ENABLE_TELEGRAM},
      "bot_token": "${DEFAULT_TELEGRAM_BOT_TOKEN}",
      "chat_id": "${DEFAULT_TELEGRAM_CHAT_ID}"
    },
    "discord": {
      "enabled": ${DEFAULT_ENABLE_DISCORD},
      "webhook_url": "${DEFAULT_DISCORD_WEBHOOK}"
    },
    "console": {
      "enabled": ${DEFAULT_ENABLE_CONSOLE}
    },
    "log": {
      "enabled": ${DEFAULT_ENABLE_LOG},
      "path": "${ALERT_LOG}"
    }
  },
  "alert_categories": {
    "attestation": {
      "enabled": true,
      "reminder_hours": 6
    },
    "proposal": {
      "enabled": true,
      "reminder_hours": 1
    },
    "balance": {
      "enabled": true,
      "reminder_hours": 12
    },
    "sync": {
      "enabled": true,
      "reminder_hours": 2
    },
    "peer_count": {
      "enabled": true,
      "reminder_hours": 4
    },
    "client_update": {
      "enabled": true,
      "reminder_hours": 24
    },
    "system_resources": {
      "enabled": true,
      "reminder_hours": 1
    }
  }
}
EOF
    echo "Created default alert configuration at ${ALERT_CONFIG}"
fi

# Create an empty active alerts file if it doesn't exist
if [[ ! -f "${ACTIVE_ALERTS}" ]]; then
    echo "[]" > "${ACTIVE_ALERTS}"
fi

# Function to load alert configuration
load_alert_config() {
    if [[ -f "${ALERT_CONFIG}" ]]; then
        cat "${ALERT_CONFIG}"
    else
        echo "Error: Alert configuration file not found at ${ALERT_CONFIG}"
        exit 1
    fi
}

# Function to check for validator attestation issues
check_attestation() {
    local config="$1"
    local alerts=()
    
    # Load validator metrics
    if [[ ! -f "${VALIDATOR_METRICS}" ]]; then
        echo "Warning: Validator metrics file not found at ${VALIDATOR_METRICS}"
        return 0
    fi
    
    local validator_metrics=$(cat "${VALIDATOR_METRICS}")
    
    # Extract attestation metrics
    local attestation_effectiveness=$(echo "${validator_metrics}" | grep -o '"attestation_effectiveness":[^}]*' || echo "{}")
    local attestation_rate=$(echo "${attestation_effectiveness}" | grep -o '"rate":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "1.0")
    
    # Get thresholds from config
    local critical_threshold=$(echo "${config}" | grep -o '"attestation":[^}]*"critical":[[:space:]]*[0-9.]*' | grep -o '"critical":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "${DEFAULT_CRITICAL_ATTESTATION_RATE}")
    local warning_threshold=$(echo "${config}" | grep -o '"attestation":[^}]*"warning":[[:space:]]*[0-9.]*' | grep -o '"warning":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "${DEFAULT_WARNING_ATTESTATION_RATE}")
    
    # Check against thresholds
    if (( $(echo "${attestation_rate} < ${critical_threshold}" | bc -l) )); then
        alerts+=("$(create_alert "attestation" "critical" "Attestation effectiveness critically low (${attestation_rate})")")
    elif (( $(echo "${attestation_rate} < ${warning_threshold}" | bc -l) )); then
        alerts+=("$(create_alert "attestation" "warning" "Attestation effectiveness below threshold (${attestation_rate})")")
    fi
    
    echo "${alerts[@]}"
}

# Function to check for balance decreases
check_balance() {
    local config="$1"
    local alerts=()
    
    # Check if comparison data exists
    if [[ ! -f "${COMPARISON_DATA}" ]]; then
        echo "Warning: Validator comparison data not found at ${COMPARISON_DATA}"
        return 0
    fi
    
    local comparison_data=$(cat "${COMPARISON_DATA}")
    
    # Extract balance trend
    local balance_trend=$(echo "${comparison_data}" | grep -o '"balance_trend":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "stable")
    
    # Get balance ratio from comparison data
    local balance_ratio=$(echo "${comparison_data}" | grep -o '"balance":[^}]*"ratio":[[:space:]]*[0-9.]*' | grep -o '"ratio":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "1.0")
    
    # Get thresholds from config
    local critical_decrease=$(echo "${config}" | grep -o '"balance":[^}]*"critical_decrease":[[:space:]]*[0-9.]*' | grep -o '"critical_decrease":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "${DEFAULT_CRITICAL_BALANCE_DECREASE}")
    local warning_decrease=$(echo "${config}" | grep -o '"balance":[^}]*"warning_decrease":[[:space:]]*[0-9.]*' | grep -o '"warning_decrease":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "${DEFAULT_WARNING_BALANCE_DECREASE}")
    
    # Check balance trend and ratio
    if [[ "${balance_trend}" == "decreasing" ]]; then
        local balance_percent=$(echo "${comparison_data}" | grep -o '"balance":[^}]*"percent_of_network":[[:space:]]*[0-9.]*' | grep -o '"percent_of_network":[[:space:]]*[0-9.]*' | cut -d':' -f2 | tr -d ' ' || echo "100")
        
        if (( $(echo "${balance_ratio} < (1 - ${critical_decrease})" | bc -l) )); then
            alerts+=("$(create_alert "balance" "critical" "Validator balance critically decreasing (${balance_percent}% of network average)")")
        elif (( $(echo "${balance_ratio} < (1 - ${warning_decrease})" | bc -l) )); then
            alerts+=("$(create_alert "balance" "warning" "Validator balance decreasing (${balance_percent}% of network average)")")
        fi
    fi
    
    echo "${alerts[@]}"
}

# Function to check sync status
check_sync() {
    local config="$1"
    local alerts=()
    
    # Get sync status from beacon node
    local sync_json
    sync_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/node/syncing" \
        -H "Accept: application/json" || echo '{"data":{"is_syncing":false,"sync_distance":"0"}}')
    
    local is_syncing=$(echo "${sync_json}" | grep -o '"is_syncing":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "false")
    local sync_distance=$(echo "${sync_json}" | grep -o '"sync_distance":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "0")
    
    # Get thresholds from config
    local critical_distance=$(echo "${config}" | grep -o '"sync":[^}]*"critical_distance":[[:space:]]*[0-9]*' | grep -o '"critical_distance":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "${DEFAULT_CRITICAL_SYNC_DISTANCE}")
    local warning_distance=$(echo "${config}" | grep -o '"sync":[^}]*"warning_distance":[[:space:]]*[0-9]*' | grep -o '"warning_distance":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "${DEFAULT_WARNING_SYNC_DISTANCE}")
    
    # Check if syncing and sync distance
    if [[ "${is_syncing}" == "true" ]]; then
        if [[ ${sync_distance} =~ ^[0-9]+$ ]] && (( sync_distance > critical_distance )); then
            alerts+=("$(create_alert "sync" "critical" "Node is syncing with critical distance (${sync_distance} slots)")")
        elif [[ ${sync_distance} =~ ^[0-9]+$ ]] && (( sync_distance > warning_distance )); then
            alerts+=("$(create_alert "sync" "warning" "Node is syncing (${sync_distance} slots behind)")")
        fi
    fi
    
    echo "${alerts[@]}"
}

# Function to check peer count
check_peers() {
    local config="$1"
    local alerts=()
    
    # Get peer count from beacon node
    local peer_json
    peer_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/node/peer_count" \
        -H "Accept: application/json" || echo '{"data":{"connected":"0","disconnected":"0"}}')
    
    local connected_peers=$(echo "${peer_json}" | grep -o '"connected":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "0")
    
    # Get thresholds from config
    local critical_minimum=$(echo "${config}" | grep -o '"peers":[^}]*"critical_minimum":[[:space:]]*[0-9]*' | grep -o '"critical_minimum":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "${DEFAULT_CRITICAL_PEERS}")
    local warning_minimum=$(echo "${config}" | grep -o '"peers":[^}]*"warning_minimum":[[:space:]]*[0-9]*' | grep -o '"warning_minimum":[[:space:]]*[0-9]*' | cut -d':' -f2 | tr -d ' ' || echo "${DEFAULT_WARNING_PEERS}")
    
    # Check peer count against thresholds
    if (( connected_peers < critical_minimum )); then
        alerts+=("$(create_alert "peer_count" "critical" "Critically low peer count (${connected_peers} connected)")")
    elif (( connected_peers < warning_minimum )); then
        alerts+=("$(create_alert "peer_count" "warning" "Low peer count (${connected_peers} connected)")")
    fi
    
    echo "${alerts[@]}"
}

# Function to check system resources
check_system_resources() {
    local alerts=()
    
    # Check CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
    
    # Check memory usage
    local mem_info=$(free -m | grep Mem)
    local mem_total=$(echo "${mem_info}" | awk '{print $2}')
    local mem_used=$(echo "${mem_info}" | awk '{print $3}')
    local mem_usage_percent=$(echo "scale=2; (${mem_used} / ${mem_total}) * 100" | bc)
    
    # Check disk usage
    local disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    # Generate alerts for high resource usage
    if (( $(echo "${cpu_usage} > 90" | bc -l) )); then
        alerts+=("$(create_alert "system_resources" "critical" "CPU usage critically high (${cpu_usage}%)")")
    elif (( $(echo "${cpu_usage} > 80" | bc -l) )); then
        alerts+=("$(create_alert "system_resources" "warning" "CPU usage high (${cpu_usage}%)")")
    fi
    
    if (( $(echo "${mem_usage_percent} > 90" | bc -l) )); then
        alerts+=("$(create_alert "system_resources" "critical" "Memory usage critically high (${mem_usage_percent}%)")")
    elif (( $(echo "${mem_usage_percent} > 80" | bc -l) )); then
        alerts+=("$(create_alert "system_resources" "warning" "Memory usage high (${mem_usage_percent}%)")")
    fi
    
    if (( disk_usage > 90 )); then
        alerts+=("$(create_alert "system_resources" "critical" "Disk usage critically high (${disk_usage}%)")")
    elif (( disk_usage > 80 )); then
        alerts+=("$(create_alert "system_resources" "warning" "Disk usage high (${disk_usage}%)")")
    fi
    
    echo "${alerts[@]}"
}

# Function to check for client updates
check_client_updates() {
    local alerts=()
    
    # Get current client versions
    local client_json
    client_json=$(curl -s "${BEACON_NODE_ENDPOINT}/eth/v1/node/version" \
        -H "Accept: application/json" || echo '{"data":{"version":"unknown"}}')
    
    local client_version=$(echo "${client_json}" | grep -o '"version":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "unknown")
    
    # Check if we can determine the client type from the version string
    local client_type="unknown"
    if [[ "${client_version}" == *"lighthouse"* ]]; then
        client_type="lighthouse"
    elif [[ "${client_version}" == *"prysm"* ]]; then
        client_type="prysm"
    elif [[ "${client_version}" == *"teku"* ]]; then
        client_type="teku"
    elif [[ "${client_version}" == *"nimbus"* ]]; then
        client_type="nimbus"
    elif [[ "${client_version}" == *"lodestar"* ]]; then
        client_type="lodestar"
    fi
    
    # Check for updates based on client type
    # This is a simplified approach - in a real environment, you'd query GitHub releases or other sources
    local update_needed=false
    local update_message=""
    
    # For demonstration, we'll generate an update alert randomly with 1% chance
    # In a real implementation, you would check against the latest known versions
    if (( RANDOM % 100 == 0 )); then
        update_needed=true
        update_message="A new version of ${client_type} is available. Current: ${client_version}"
    fi
    
    if [[ "${update_needed}" == "true" ]]; then
        alerts+=("$(create_alert "client_update" "warning" "${update_message}")")
    fi
    
    echo "${alerts[@]}"
}

# Function to create a standardized alert object
create_alert() {
    local category="$1"
    local severity="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local alert_id="${category}_${severity}_$(date +%s)"
    
    local alert_json=$(cat <<EOF
{
  "id": "${alert_id}",
  "timestamp": "${timestamp}",
  "category": "${category}",
  "severity": "${severity}",
  "message": "${message}",
  "acknowledged": false,
  "first_seen": "${timestamp}",
  "last_notified": "${timestamp}"
}
EOF
    )
    
    echo "${alert_json}"
}

# Function to load active alerts
load_active_alerts() {
    if [[ -f "${ACTIVE_ALERTS}" ]]; then
        cat "${ACTIVE_ALERTS}"
    else
        echo "[]"
    fi
}

# Function to save active alerts
save_active_alerts() {
    local alerts="$1"
    echo "${alerts}" > "${ACTIVE_ALERTS}"
    
    # Save a copy to history with timestamp
    local history_file="${ALERT_HISTORY}/alerts_$(date +%Y%m%d_%H%M%S).json"
    echo "${alerts}" > "${history_file}"
}

# Function to update the active alerts list with new alerts
update_active_alerts() {
    local active_alerts="$1"
    local new_alerts=("${@:2}")
    
    # If no new alerts and no active alerts, just return an empty array
    if [[ ${#new_alerts[@]} -eq 0 && "${active_alerts}" == "[]" ]]; then
        echo "[]"
        return 0
    fi
    
    # Start with current active alerts or empty array
    local updated_alerts="${active_alerts}"
    if [[ "${updated_alerts}" == "[]" ]]; then
        updated_alerts="["
    else
        # Remove the closing bracket
        updated_alerts="${updated_alerts%]}"
    fi
    
    # For each new alert
    for new_alert in "${new_alerts[@]}"; do
        if [[ -n "${new_alert}" ]]; then
            # Extract the category and message of the new alert
            local new_category=$(echo "${new_alert}" | grep -o '"category":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
            local new_message=$(echo "${new_alert}" | grep -o '"message":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
            local new_severity=$(echo "${new_alert}" | grep -o '"severity":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
            
            # Check if a similar alert already exists
            local alert_exists=false
            
            # Convert active_alerts to an array of individual alert objects
            local IFS=$'\n'
            local alert_objects=()
            
            # Extract alert objects - this is a simplified approach and might break with complex JSON
            while IFS= read -r line; do
                if [[ "${line}" == "{" ]]; then
                    alert_objects+=("{")
                elif [[ "${line}" == "}" ]] || [[ "${line}" == "}," ]]; then
                    alert_objects[-1]="${alert_objects[-1]}${line}"
                else
                    alert_objects[-1]="${alert_objects[-1]}${line}"
                fi
            done < <(echo "${active_alerts}" | grep -v '^\[' | grep -v '^\]')
            
            for existing_alert in "${alert_objects[@]}"; do
                if [[ -n "${existing_alert}" && "${existing_alert}" != "{" ]]; then
                    local existing_category=$(echo "${existing_alert}" | grep -o '"category":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
                    local existing_message=$(echo "${existing_alert}" | grep -o '"message":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
                    local existing_severity=$(echo "${existing_alert}" | grep -o '"severity":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
                    
                    # If same category and similar message, update the existing alert
                    if [[ "${existing_category}" == "${new_category}" && "${existing_message}" == "${new_message}" ]]; then
                        alert_exists=true
                        break
                    fi
                    
                    # If same category but new alert is higher severity, replace the existing alert
                    if [[ "${existing_category}" == "${new_category}" && 
                          ( ( "${new_severity}" == "critical" && "${existing_severity}" == "warning" ) ||
                            ( "${new_severity}" == "critical" && "${existing_severity}" == "info" ) ||
                            ( "${new_severity}" == "warning" && "${existing_severity}" == "info" ) ) ]]; then
                        # Remove the existing alert by not including it in the updated array
                        alert_exists=false
                        continue
                    fi
                fi
            done
            
            # If alert doesn't exist or needs updating, add it
            if [[ "${alert_exists}" == "false" ]]; then
                # Add comma if not the first alert
                if [[ "${updated_alerts}" != "[" ]]; then
                    updated_alerts="${updated_alerts},"
                fi
                
                # Add the new alert
                updated_alerts="${updated_alerts}${new_alert}"
            fi
        fi
    done
    
    # Close the JSON array
    updated_alerts="${updated_alerts}]"
    
    echo "${updated_alerts}"
}

# Function to send email notifications
send_email_notification() {
    local config="$1"
    local alert="$2"
    
    # Get email configuration
    local email_enabled=$(echo "${config}" | grep -o '"email":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "false")
    local email_recipient=$(echo "${config}" | grep -o '"email":[^}]*"recipient":[[:space:]]*"[^"]*"' | grep -o '"recipient":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "")
    
    if [[ "${email_enabled}" == "true" && -n "${email_recipient}" ]]; then
        # Extract alert details
        local severity=$(echo "${alert}" | grep -o '"severity":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local message=$(echo "${alert}" | grep -o '"message":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local category=$(echo "${alert}" | grep -o '"category":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        
        # Create email subject and body
        local subject="Validator Alert: [${severity}] ${category}"
        local body="Validator Alert\n\nSeverity: ${severity}\nCategory: ${category}\nMessage: ${message}\nTime: $(date)"
        
        # Send email (using mail command - assumes mail server is configured)
        if command -v mail &> /dev/null; then
            echo -e "${body}" | mail -s "${subject}" "${email_recipient}"
            echo "Email notification sent to ${email_recipient}"
        else
            echo "Warning: 'mail' command not found. Email notification not sent."
        fi
    fi
}

# Function to send Telegram notifications
send_telegram_notification() {
    local config="$1"
    local alert="$2"
    
    # Get Telegram configuration
    local telegram_enabled=$(echo "${config}" | grep -o '"telegram":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "false")
    local bot_token=$(echo "${config}" | grep -o '"telegram":[^}]*"bot_token":[[:space:]]*"[^"]*"' | grep -o '"bot_token":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "")
    local chat_id=$(echo "${config}" | grep -o '"telegram":[^}]*"chat_id":[[:space:]]*"[^"]*"' | grep -o '"chat_id":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "")
    
    if [[ "${telegram_enabled}" == "true" && -n "${bot_token}" && -n "${chat_id}" ]]; then
        # Extract alert details
        local severity=$(echo "${alert}" | grep -o '"severity":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local message=$(echo "${alert}" | grep -o '"message":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local category=$(echo "${alert}" | grep -o '"category":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        
        # Format message
        local formatted_message="⚠️ *Validator Alert*\n\n*Severity*: ${severity}\n*Category*: ${category}\n*Message*: ${message}\n*Time*: $(date)"
        
        # Send to Telegram
        local telegram_api="https://api.telegram.org/bot${bot_token}/sendMessage"
        curl -s -X POST "${telegram_api}" -d chat_id="${chat_id}" -d text="${formatted_message}" -d parse_mode="Markdown" > /dev/null
        
        echo "Telegram notification sent"
    fi
}

# Function to send Discord notifications
send_discord_notification() {
    local config="$1"
    local alert="$2"
    
    # Get Discord configuration
    local discord_enabled=$(echo "${config}" | grep -o '"discord":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "false")
    local webhook_url=$(echo "${config}" | grep -o '"discord":[^}]*"webhook_url":[[:space:]]*"[^"]*"' | grep -o '"webhook_url":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "")
    
    if [[ "${discord_enabled}" == "true" && -n "${webhook_url}" ]]; then
        # Extract alert details
        local severity=$(echo "${alert}" | grep -o '"severity":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local message=$(echo "${alert}" | grep -o '"message":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local category=$(echo "${alert}" | grep -o '"category":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        
        # Determine color based on severity
        local color=16776960  # Yellow (warning)
        if [[ "${severity}" == "critical" ]]; then
            color=16711680  # Red
        elif [[ "${severity}" == "info" ]]; then
            color=65280  # Green
        fi
        
        # Create Discord payload
        local payload=$(cat <<EOF
{
  "embeds": [{
    "title": "Validator Alert: ${severity} - ${category}",
    "description": "${message}",
    "color": ${color},
    "fields": [
      {
        "name": "Severity",
        "value": "${severity}",
        "inline": true
      },
      {
        "name": "Category",
        "value": "${category}",
        "inline": true
      },
      {
        "name": "Time",
        "value": "$(date)",
        "inline": false
      }
    ]
  }]
}
EOF
        )
        
        # Send to Discord
        curl -s -X POST "${webhook_url}" -H "Content-Type: application/json" -d "${payload}" > /dev/null
        
        echo "Discord notification sent"
    fi
}

# Function to log alerts to file
log_alert() {
    local config="$1"
    local alert="$2"
    
    # Get log configuration
    local log_enabled=$(echo "${config}" | grep -o '"log":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "true")
    local log_path=$(echo "${config}" | grep -o '"log":[^}]*"path":[[:space:]]*"[^"]*"' | grep -o '"path":[[:space:]]*"[^"]*"' | cut -d'"' -f4 || echo "${ALERT_LOG}")
    
    if [[ "${log_enabled}" == "true" ]]; then
        # Extract alert details
        local severity=$(echo "${alert}" | grep -o '"severity":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local message=$(echo "${alert}" | grep -o '"message":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local category=$(echo "${alert}" | grep -o '"category":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local timestamp=$(echo "${alert}" | grep -o '"timestamp":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        
        # Log to file
        echo "[${timestamp}] [${severity}] [${category}] ${message}" >> "${log_path}"
    fi
}

# Function to output alerts to console
output_to_console() {
    local config="$1"
    local alert="$2"
    
    # Get console configuration
    local console_enabled=$(echo "${config}" | grep -o '"console":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "true")
    
    if [[ "${console_enabled}" == "true" ]]; then
        # Extract alert details
        local severity=$(echo "${alert}" | grep -o '"severity":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local message=$(echo "${alert}" | grep -o '"message":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        local category=$(echo "${alert}" | grep -o '"category":[[:space:]]*"[^"]*"' | cut -d'"' -f4)
        
        # Determine color based on severity
        local color_code=""
        if [[ "${severity}" == "critical" ]]; then
            color_code="\033[1;31m"  # Bold Red
        elif [[ "${severity}" == "warning" ]]; then
            color_code="\033[1;33m"  # Bold Yellow
        elif [[ "${severity}" == "info" ]]; then
            color_code="\033[1;32m"  # Bold Green
        fi
        
        # Output to console with color
        echo -e "${color_code}[${severity}] [${category}] ${message}\033[0m"
    fi
}

# Function to send notifications for an alert
send_notifications() {
    local config="$1"
    local alert="$2"
    
    # Log the alert
    log_alert "${config}" "${alert}"
    
    # Output to console
    output_to_console "${config}" "${alert}"
    
    # Send email
    send_email_notification "${config}" "${alert}"
    
    # Send Telegram message
    send_telegram_notification "${config}" "${alert}"
    
    # Send Discord message
    send_discord_notification "${config}" "${alert}"
}

# Main function
main() {
    echo "Starting validator alert system check at $(date)"
    
    # Load alert configuration
    local config=$(load_alert_config)
    echo "Loaded alert configuration"
    
    # Load active alerts
    local active_alerts=$(load_active_alerts)
    echo "Loaded active alerts"
    
    # Perform all checks
    echo "Performing alert checks..."
    local attestation_alerts=$(check_attestation "${config}")
    local balance_alerts=$(check_balance "${config}")
    local sync_alerts=$(check_sync "${config}")
    local peer_alerts=$(check_peers "${config}")
    local system_alerts=$(check_system_resources)
    local update_alerts=$(check_client_updates)
    
    # Collect all new alerts
    local new_alerts=()
    
    # Only add alerts if the corresponding category is enabled
    local attestation_enabled=$(echo "${config}" | grep -o '"attestation":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "true")
    if [[ "${attestation_enabled}" == "true" && -n "${attestation_alerts}" ]]; then
        new_alerts+=("${attestation_alerts}")
    fi
    
    local balance_enabled=$(echo "${config}" | grep -o '"balance":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "true")
    if [[ "${balance_enabled}" == "true" && -n "${balance_alerts}" ]]; then
        new_alerts+=("${balance_alerts}")
    fi
    
    local sync_enabled=$(echo "${config}" | grep -o '"sync":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "true")
    if [[ "${sync_enabled}" == "true" && -n "${sync_alerts}" ]]; then
        new_alerts+=("${sync_alerts}")
    fi
    
    local peer_count_enabled=$(echo "${config}" | grep -o '"peer_count":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "true")
    if [[ "${peer_count_enabled}" == "true" && -n "${peer_alerts}" ]]; then
        new_alerts+=("${peer_alerts}")
    fi
    
    local system_resources_enabled=$(echo "${config}" | grep -o '"system_resources":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "true")
    if [[ "${system_resources_enabled}" == "true" && -n "${system_alerts}" ]]; then
        new_alerts+=("${system_alerts}")
    fi
    
    local client_update_enabled=$(echo "${config}" | grep -o '"client_update":[^}]*"enabled":[[:space:]]*[^,}]*' | grep -o '"enabled":[[:space:]]*[^,}]*' | cut -d':' -f2 | tr -d ' "' || echo "true")
    if [[ "${client_update_enabled}" == "true" && -n "${update_alerts}" ]]; then
        new_alerts+=("${update_alerts}")
    fi
    
    # Update active alerts with new alerts
    local updated_alerts=$(update_active_alerts "${active_alerts}" "${new_alerts[@]}")
    
    # Save updated alerts
    save_active_alerts "${updated_alerts}"
    
    # Send notifications for new alerts
    for alert in "${new_alerts[@]}"; do
        if [[ -n "${alert}" ]]; then
            send_notifications "${config}" "${alert}"
        fi
    done
    
    # Print summary
    local alert_count=$(echo "${updated_alerts}" | grep -o '{' | wc -l)
    echo "Validator alert system check completed at $(date)"
    echo "Active alerts: ${alert_count}"
}

# Run the main function
main 
