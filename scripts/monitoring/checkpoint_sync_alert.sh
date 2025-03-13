#!/bin/bash
# checkpoint_sync_alert.sh - Monitors checkpoint sync and sends alerts when issues are detected
# Part of the Ephemery checkpoint sync fix implementation

# Colors for terminal output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration - Edit these variables as needed
ALERT_EMAIL="" # Set email address to receive alerts
SLACK_WEBHOOK="" # Set Slack webhook URL to receive alerts
DISCORD_WEBHOOK="" # Set Discord webhook URL to receive alerts
CHECK_INTERVAL=900 # 15 minutes between checks
PROGRESS_THRESHOLD=10 # Minimum expected slots progress in check interval
MAX_SYNC_DISTANCE=1000 # Alert if sync distance exceeds this value
MAX_RETRIES=3 # Number of restart attempts before giving up

# Lighthouse API endpoint
LIGHTHOUSE_API="http://localhost:5052"

# Log file
LOG_FILE="/var/log/ephemery/checkpoint_sync_alert.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Function to log messages
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

# Function to send email alert
send_email_alert() {
    local subject="$1"
    local message="$2"

    if [ -n "$ALERT_EMAIL" ]; then
        log_message "INFO" "Sending email alert to $ALERT_EMAIL"
        echo "$message" | mail -s "$subject" "$ALERT_EMAIL"
    fi
}

# Function to send Slack alert
send_slack_alert() {
    local message="$1"

    if [ -n "$SLACK_WEBHOOK" ]; then
        log_message "INFO" "Sending Slack alert"
        curl -s -X POST -H 'Content-type: application/json' \
             --data "{\"text\":\"$message\"}" \
             "$SLACK_WEBHOOK"
    fi
}

# Function to send Discord alert
send_discord_alert() {
    local message="$1"

    if [ -n "$DISCORD_WEBHOOK" ]; then
        log_message "INFO" "Sending Discord alert"
        curl -s -X POST -H "Content-Type: application/json" \
             --data "{\"content\":\"$message\"}" \
             "$DISCORD_WEBHOOK"
    fi
}

# Function to send alert through all configured channels
send_alert() {
    local subject="$1"
    local message="$2"

    log_message "ALERT" "$subject: $message"

    send_email_alert "$subject" "$message"
    send_slack_alert "$message"
    send_discord_alert "$message"
}

# Function to restart Lighthouse
restart_lighthouse() {
    log_message "WARNING" "Attempting to restart Lighthouse"
    docker restart ephemery-lighthouse
    return $?
}

# Function to check if Lighthouse API is responsive
check_lighthouse_api() {
    curl -s -f "${LIGHTHOUSE_API}/eth/v1/node/health" > /dev/null
    return $?
}

# Function to get sync status
get_sync_status() {
    if ! check_lighthouse_api; then
        log_message "ERROR" "Lighthouse API is not responsive"
        return 1
    fi

    local sync_status=$(curl -s "${LIGHTHOUSE_API}/eth/v1/node/syncing")
    if [ $? -ne 0 ] || [ -z "$sync_status" ]; then
        log_message "ERROR" "Failed to get sync status"
        return 1
    fi

    echo "$sync_status"
    return 0
}

# Function to extract head slot from sync status
get_head_slot() {
    local sync_status="$1"
    echo "$sync_status" | grep -o '"head_slot":"[^"]*"' | cut -d':' -f2 | tr -d '"'
}

# Function to extract sync distance from sync status
get_sync_distance() {
    local sync_status="$1"
    echo "$sync_status" | grep -o '"sync_distance":"[^"]*"' | cut -d':' -f2 | tr -d '"'
}

# Function to extract is_syncing flag from sync status
is_syncing() {
    local sync_status="$1"
    local syncing=$(echo "$sync_status" | grep -o '"is_syncing":[^,}]*' | cut -d':' -f2)
    if [[ "$syncing" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Main monitoring loop
log_message "INFO" "Starting checkpoint sync monitoring"
log_message "INFO" "Check interval: ${CHECK_INTERVAL}s, Progress threshold: ${PROGRESS_THRESHOLD} slots"

retry_count=0

while true; do
    # Get initial sync status
    initial_status=$(get_sync_status)
    if [ $? -ne 0 ]; then
        send_alert "Lighthouse API Error" "Unable to connect to Lighthouse API. Check if lighthouse is running."
        sleep 60
        continue
    fi

    initial_head_slot=$(get_head_slot "$initial_status")
    initial_sync_distance=$(get_sync_distance "$initial_status")

    log_message "INFO" "Current state - Head slot: $initial_head_slot, Sync distance: $initial_sync_distance"

    # Check if sync distance is too large
    if [ -n "$initial_sync_distance" ] && [ "$initial_sync_distance" -gt "$MAX_SYNC_DISTANCE" ]; then
        send_alert "High Sync Distance" "Sync distance is too high: $initial_sync_distance slots. This may indicate checkpoint sync issues."
    fi

    # Wait for the check interval
    log_message "INFO" "Waiting ${CHECK_INTERVAL}s for next check..."
    sleep "$CHECK_INTERVAL"

    # Get current sync status
    current_status=$(get_sync_status)
    if [ $? -ne 0 ]; then
        send_alert "Lighthouse API Error" "Unable to connect to Lighthouse API after interval. Check if lighthouse is running."
        continue
    fi

    current_head_slot=$(get_head_slot "$current_status")
    current_sync_distance=$(get_sync_distance "$current_status")

    log_message "INFO" "Updated state - Head slot: $current_head_slot, Sync distance: $current_sync_distance"

    # Calculate progress
    slots_progressed=$((current_head_slot - initial_head_slot))
    distance_reduced=$((initial_sync_distance - current_sync_distance))

    log_message "INFO" "Sync progress - Slots progressed: $slots_progressed, Distance reduced: $distance_reduced"

    # Check if sync is stuck
    if is_syncing "$current_status" && [ "$slots_progressed" -lt "$PROGRESS_THRESHOLD" ] && [ "$distance_reduced" -lt "$PROGRESS_THRESHOLD" ]; then
        log_message "WARNING" "Sync progress is too slow. Slots progressed: $slots_progressed, Distance reduced: $distance_reduced"

        # Check Lighthouse logs for errors
        checkpoint_errors=$(docker logs ephemery-lighthouse --tail 100 2>&1 | grep -i checkpoint | grep -i error)

        # Send alert
        alert_message="Checkpoint sync appears to be stuck or progressing too slowly.\n"
        alert_message+="Head slot: $current_head_slot\n"
        alert_message+="Sync distance: $current_sync_distance\n"
        alert_message+="Progress in last ${CHECK_INTERVAL}s: $slots_progressed slots\n"

        if [ -n "$checkpoint_errors" ]; then
            alert_message+="\nFound checkpoint errors in logs:\n$checkpoint_errors"
        fi

        send_alert "Checkpoint Sync Issue" "$alert_message"

        # Try to restart if retry count is below max
        if [ "$retry_count" -lt "$MAX_RETRIES" ]; then
            retry_count=$((retry_count + 1))
            log_message "WARNING" "Attempting restart (attempt $retry_count/$MAX_RETRIES)"

            if restart_lighthouse; then
                send_alert "Lighthouse Restarted" "Lighthouse has been restarted to attempt to fix sync issues. This is restart attempt $retry_count of $MAX_RETRIES."
            else
                send_alert "Restart Failed" "Failed to restart Lighthouse. Manual intervention may be required."
            fi

            # Wait for restart to take effect
            log_message "INFO" "Waiting 60s for restart to take effect..."
            sleep 60
        else
            send_alert "Checkpoint Sync Failed" "Checkpoint sync is still stuck after $MAX_RETRIES restart attempts. Manual intervention required."
            log_message "ERROR" "Maximum retry count reached. Manual intervention required."
            retry_count=0
            sleep 3600  # Wait longer before checking again
        fi
    else
        # Reset retry count if making progress
        retry_count=0

        # If fully synced, log and wait longer
        if ! is_syncing "$current_status"; then
            log_message "INFO" "Lighthouse is fully synced"
            sleep 1800  # Check less frequently when synced
        fi
    fi
done
