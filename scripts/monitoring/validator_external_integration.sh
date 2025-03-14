#!/bin/bash
#
# Validator External Integration Script
# This script implements integration with external monitoring systems and exposes
# APIs for programmatic access to validator performance data.
#
# Usage: ./validator_external_integration.sh [options]
# Options:
#   --base-dir DIR         Base directory (default: /opt/ephemery)
#   --mode MODE            Operation mode: api, push, sync, prometheus, grafana (default: api)
#   --api-port PORT        Port for API server (default: 8545)
#   --endpoint URL         External system endpoint URL (for push mode)
#   --api-key KEY          API key for external system (for push/sync modes)
#   --webhook-url URL      Webhook URL for external notifications
#   --prometheus-port PORT Port for Prometheus metrics endpoint (default: 9100)
#   --grafana-key KEY      API key for Grafana integration
#   --verbose              Enable verbose output
#   --help                 Show this help message

set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common functions if available
COMMON_SCRIPT="${REPO_ROOT}/scripts/utilities/common_functions.sh"
if [[ -f "$COMMON_SCRIPT" ]]; then
    source "$COMMON_SCRIPT"
else
    # Define minimal required functions if common_functions.sh is not available
    function log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
    function log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
    function log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" >&2; }
    function log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
    function log_debug() { if [[ "$VERBOSE" == "true" ]]; then echo -e "${CYAN}[DEBUG]${NC} $*"; fi; }
fi

# Check for required tools
for cmd in jq curl netstat; do
    if ! command -v $cmd &> /dev/null; then
        log_error "$cmd is required but not installed. Please install it and try again."
        exit 1
    fi
done

# Default values
BASE_DIR="/opt/ephemery"
METRICS_DIR="${BASE_DIR}/validator_metrics/metrics"
ANALYSIS_DIR="${BASE_DIR}/validator_metrics/analysis"
CONFIG_DIR="${BASE_DIR}/config"
API_DIR="${BASE_DIR}/api"
MODE="api"
API_PORT=8545
PROMETHEUS_PORT=9100
ENDPOINT=""
API_KEY=""
WEBHOOK_URL=""
GRAFANA_KEY=""
VERBOSE=false
API_PID_FILE="${API_DIR}/api_server.pid"
PROMETHEUS_PID_FILE="${API_DIR}/prometheus_exporter.pid"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-dir)
            BASE_DIR="$2"
            shift 2
            ;;
        --mode)
            MODE="$2"
            shift 2
            ;;
        --api-port)
            API_PORT="$2"
            shift 2
            ;;
        --prometheus-port)
            PROMETHEUS_PORT="$2"
            shift 2
            ;;
        --endpoint)
            ENDPOINT="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --webhook-url)
            WEBHOOK_URL="$2"
            shift 2
            ;;
        --grafana-key)
            GRAFANA_KEY="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Function to display help
function show_help {
    echo -e "${BLUE}Validator External Integration Script${NC}"
    echo ""
    echo "This script implements integration with external monitoring systems and exposes APIs."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --base-dir DIR         Base directory (default: ${BASE_DIR})"
    echo "  --mode MODE            Operation mode: api, push, sync, prometheus, grafana (default: ${MODE})"
    echo "  --api-port PORT        Port for API server (default: ${API_PORT})"
    echo "  --prometheus-port PORT Port for Prometheus metrics endpoint (default: ${PROMETHEUS_PORT})"
    echo "  --endpoint URL         External system endpoint URL (for push mode)"
    echo "  --api-key KEY          API key for external system (for push/sync modes)"
    echo "  --webhook-url URL      Webhook URL for external notifications"
    echo "  --grafana-key KEY      API key for Grafana integration"
    echo "  --verbose              Enable verbose output"
    echo "  --help                 Show this help message"
    echo ""
    echo "Modes:"
    echo "  api  - Start a local API server to expose validator data"
    echo "  push - Push validator data to an external system"
    echo "  sync - Two-way sync with an external monitoring system"
    echo "  prometheus - Start Prometheus metrics exporter"
    echo "  grafana - Configure Grafana dashboards"
    echo "  webhook - Set up webhook endpoint handler"
}

# Ensure necessary directories exist
function ensure_directories {
    mkdir -p "${METRICS_DIR}"
    mkdir -p "${ANALYSIS_DIR}"
    mkdir -p "${API_DIR}"
    mkdir -p "${API_DIR}/logs"
    
    if [[ ! -d "${METRICS_DIR}" || ! -d "${ANALYSIS_DIR}" ]]; then
        log_error "Required directories do not exist or cannot be created"
        exit 1
    fi
}

# Get validator data for API responses or external system integration
function get_validator_data {
    local validator_index="$1"
    local data_type="$2"  # metrics, analysis, alerts, all
    
    case "${data_type}" in
        metrics)
            local metrics_file="${METRICS_DIR}/validator_${validator_index}_metrics.json"
            if [[ -f "${metrics_file}" ]]; then
                cat "${metrics_file}"
            else
                echo "{}"
            fi
            ;;
        analysis)
            local analysis_file="${ANALYSIS_DIR}/validator_${validator_index}_analysis.json"
            if [[ -f "${analysis_file}" ]]; then
                cat "${analysis_file}"
            else
                echo "{}"
            fi
            ;;
        alerts)
            local alerts_file="${BASE_DIR}/validator_metrics/alerts/validator_${validator_index}_alerts.json"
            if [[ -f "${alerts_file}" ]]; then
                cat "${alerts_file}"
            else
                echo "{}"
            fi
            ;;
        all)
            local metrics=$(get_validator_data "${validator_index}" "metrics")
            local analysis=$(get_validator_data "${validator_index}" "analysis")
            local alerts=$(get_validator_data "${validator_index}" "alerts")
            
            # Combine all data
            echo "{\"metrics\":${metrics},\"analysis\":${analysis},\"alerts\":${alerts}}"
            ;;
        *)
            log_error "Unknown data type: ${data_type}"
            echo "{}"
            ;;
    esac
}

# Get list of all validators
function get_all_validators {
    # Look for validator files in metrics directory
    local validator_files=(${METRICS_DIR}/validator_*_metrics.json)
    
    if [[ ${#validator_files[@]} -eq 0 || ! -f "${validator_files[0]}" ]]; then
        log_warning "No validator metrics files found in ${METRICS_DIR}"
        echo "[]"
        return
    fi
    
    # Extract validator indices from filenames
    local validators=()
    for file in "${validator_files[@]}"; do
        local validator_index=$(basename "${file}" | sed -n 's/validator_\([0-9]*\)_metrics.json/\1/p')
        if [[ -n "${validator_index}" ]]; then
            validators+=("\"${validator_index}\"")
        fi
    done
    
    # Join with commas and wrap in array
    local joined_validators=$(printf ",%s" "${validators[@]}")
    joined_validators=${joined_validators:1} # Remove leading comma
    
    echo "[${joined_validators}]"
}

# Simple JSON API server using netcat
function start_api_server {
    log_info "Starting API server on port ${API_PORT}"
    
    # Check if port is already in use
    if netstat -tuln | grep -q ":${API_PORT} "; then
        log_error "Port ${API_PORT} is already in use"
        exit 1
    fi
    
    # Create API routes file
    local routes_file="${API_DIR}/api_routes.txt"
    cat > "${routes_file}" <<EOF
GET /validators list_validators
GET /validators/:id get_validator
GET /validators/:id/metrics get_validator_metrics
GET /validators/:id/analysis get_validator_analysis
GET /validators/:id/alerts get_validator_alerts
GET /health health_check
EOF
    
    # Create API server control script
    local server_script="${API_DIR}/api_server.sh"
    cat > "${server_script}" <<EOF
#!/bin/bash

PORT=${API_PORT}
ROUTES_FILE="${routes_file}"
LOG_FILE="${API_DIR}/logs/api_server.log"

function handle_request {
    local request=\$1
    local response_code="200"
    local content_type="application/json"
    local body="{}"
    
    # Parse request
    local method=\$(echo "\${request}" | head -n 1 | awk '{print \$1}')
    local path=\$(echo "\${request}" | head -n 1 | awk '{print \$2}')
    
    echo "\$(date -u +"%Y-%m-%dT%H:%M:%SZ") \${method} \${path}" >> "\${LOG_FILE}"
    
    # Match route
    local matched=false
    while read -r route_method route_path route_handler; do
        # Skip comments and empty lines
        [[ "\${route_method}" =~ ^# || -z "\${route_method}" ]] && continue
        
        # Check if method matches
        [[ "\${method}" != "\${route_method}" ]] && continue
        
        # Convert route path to regex pattern
        local pattern=\$(echo "\${route_path}" | sed 's/:[^/]*/:([^/]*)/g')
        pattern="^\${pattern}\$"
        
        # Check if path matches pattern
        if [[ "\${path}" =~ \${pattern} ]]; then
            matched=true
            
            # Extract parameters
            local params=()
            local param_names=(\$(echo "\${route_path}" | grep -o ':[^/]*' | sed 's/://g'))
            
            # Extract captured groups
            local i=1
            for param_name in "\${param_names[@]}"; do
                local param_value=\${BASH_REMATCH[\$i]}
                params+=("\${param_name}=\${param_value}")
                ((i++))
            done
            
            # Handle route
            case "\${route_handler}" in
                list_validators)
                    body=\$(${SCRIPT_DIR}/validator_external_integration.sh --mode data --base-dir "${BASE_DIR}" --list-validators)
                    ;;
                get_validator)
                    local validator_id=\$(echo "\${params[0]}" | cut -d= -f2)
                    body=\$(${SCRIPT_DIR}/validator_external_integration.sh --mode data --base-dir "${BASE_DIR}" --validator "\${validator_id}" --data-type all)
                    ;;
                get_validator_metrics)
                    local validator_id=\$(echo "\${params[0]}" | cut -d= -f2)
                    body=\$(${SCRIPT_DIR}/validator_external_integration.sh --mode data --base-dir "${BASE_DIR}" --validator "\${validator_id}" --data-type metrics)
                    ;;
                get_validator_analysis)
                    local validator_id=\$(echo "\${params[0]}" | cut -d= -f2)
                    body=\$(${SCRIPT_DIR}/validator_external_integration.sh --mode data --base-dir "${BASE_DIR}" --validator "\${validator_id}" --data-type analysis)
                    ;;
                get_validator_alerts)
                    local validator_id=\$(echo "\${params[0]}" | cut -d= -f2)
                    body=\$(${SCRIPT_DIR}/validator_external_integration.sh --mode data --base-dir "${BASE_DIR}" --validator "\${validator_id}" --data-type alerts)
                    ;;
                health_check)
                    body="{\"status\":\"ok\",\"timestamp\":\"\$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
                    ;;
                *)
                    response_code="500"
                    body="{\"error\":\"Unknown handler: \${route_handler}\"}"
                    ;;
            esac
            
            break
        fi
    done < "\${ROUTES_FILE}"
    
    if ! \$matched; then
        response_code="404"
        body="{\"error\":\"Not Found\",\"path\":\"\${path}\"}"
    fi
    
    # Send response
    echo -e "HTTP/1.1 \${response_code} OK\r\nContent-Type: \${content_type}\r\nAccess-Control-Allow-Origin: *\r\n\r\n\${body}"
}

# Infinite loop to handle connections
while true; do
    nc -l \${PORT} -c "handle_request \"\$(cat)\""
done
EOF
    
    # Make server script executable
    chmod +x "${server_script}"
    
    # Start server in background
    nohup "${server_script}" > "${API_DIR}/logs/api_stdout.log" 2> "${API_DIR}/logs/api_stderr.log" &
    echo $! > "${API_PID_FILE}"
    
    log_success "API server started with PID $(cat "${API_PID_FILE}")"
    log_info "API endpoints:"
    log_info "  GET http://localhost:${API_PORT}/validators - List all validators"
    log_info "  GET http://localhost:${API_PORT}/validators/:id - Get validator data"
    log_info "  GET http://localhost:${API_PORT}/validators/:id/metrics - Get validator metrics"
    log_info "  GET http://localhost:${API_PORT}/validators/:id/analysis - Get validator analysis"
    log_info "  GET http://localhost:${API_PORT}/validators/:id/alerts - Get validator alerts"
    log_info "  GET http://localhost:${API_PORT}/health - Health check"
}

# Stop API server
function stop_api_server {
    if [[ -f "${API_PID_FILE}" ]]; then
        local pid=$(cat "${API_PID_FILE}")
        if kill -0 "${pid}" 2>/dev/null; then
            log_info "Stopping API server (PID: ${pid})"
            kill "${pid}"
            rm "${API_PID_FILE}"
            log_success "API server stopped"
        else
            log_warning "API server not running (PID: ${pid} not found)"
            rm "${API_PID_FILE}"
        fi
    else
        log_warning "API server PID file not found"
    fi
}

# Push data to external system
function push_to_external_system {
    if [[ -z "${ENDPOINT}" ]]; then
        log_error "External endpoint URL is required for push mode"
        exit 1
    fi
    
    log_info "Pushing validator data to ${ENDPOINT}"
    
    # Get list of validators
    local validators_json=$(get_all_validators)
    local validators=($(echo "${validators_json}" | jq -r '.[]'))
    
    if [[ ${#validators[@]} -eq 0 ]]; then
        log_warning "No validators found to push"
        return
    fi
    
    log_info "Found ${#validators[@]} validators to push"
    
    # Push data for each validator
    for validator in "${validators[@]}"; do
        log_debug "Pushing data for validator ${validator}"
        
        # Get validator data
        local data=$(get_validator_data "${validator}" "all")
        
        # Build headers
        local headers=("-H" "Content-Type: application/json")
        if [[ -n "${API_KEY}" ]]; then
            headers+=("-H" "Authorization: Bearer ${API_KEY}")
        fi
        
        # Send data
        local response=$(curl -s -X POST "${ENDPOINT}/validators/${validator}" \
            "${headers[@]}" \
            -d "${data}" \
            -w "\n%{http_code}")
        
        local http_code=$(echo "${response}" | tail -n1)
        local response_body=$(echo "${response}" | sed '$d')
        
        if [[ "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
            log_success "Successfully pushed data for validator ${validator}"
        else
            log_error "Failed to push data for validator ${validator}: HTTP ${http_code}"
            log_debug "Response: ${response_body}"
        fi
    done
}

# Sync with external system
function sync_with_external_system {
    if [[ -z "${ENDPOINT}" ]]; then
        log_error "External endpoint URL is required for sync mode"
        exit 1
    fi
    
    log_info "Syncing with external system at ${ENDPOINT}"
    
    # Build headers
    local headers=("-H" "Content-Type: application/json")
    if [[ -n "${API_KEY}" ]]; then
        headers+=("-H" "Authorization: Bearer ${API_KEY}")
    fi
    
    # Get remote validators
    log_debug "Fetching validators from remote system"
    local response=$(curl -s -X GET "${ENDPOINT}/validators" \
        "${headers[@]}" \
        -w "\n%{http_code}")
    
    local http_code=$(echo "${response}" | tail -n1)
    local response_body=$(echo "${response}" | sed '$d')
    
    if [[ ! "${http_code}" =~ ^2[0-9][0-9]$ ]]; then
        log_error "Failed to fetch validators from remote system: HTTP ${http_code}"
        log_debug "Response: ${response_body}"
        return
    fi
    
    local remote_validators=($(echo "${response_body}" | jq -r '.[]'))
    log_info "Found ${#remote_validators[@]} validators on remote system"
    
    # Get local validators
    local local_validators_json=$(get_all_validators)
    local local_validators=($(echo "${local_validators_json}" | jq -r '.[]'))
    log_info "Found ${#local_validators[@]} validators locally"
    
    # Push local validators to remote
    for validator in "${local_validators[@]}"; do
        log_debug "Pushing data for validator ${validator} to remote"
        
        # Get validator data
        local data=$(get_validator_data "${validator}" "all")
        
        # Send data
        local push_response=$(curl -s -X POST "${ENDPOINT}/validators/${validator}" \
            "${headers[@]}" \
            -d "${data}" \
            -w "\n%{http_code}")
        
        local push_http_code=$(echo "${push_response}" | tail -n1)
        
        if [[ "${push_http_code}" =~ ^2[0-9][0-9]$ ]]; then
            log_success "Successfully pushed data for validator ${validator}"
        else
            local push_response_body=$(echo "${push_response}" | sed '$d')
            log_error "Failed to push data for validator ${validator}: HTTP ${push_http_code}"
            log_debug "Response: ${push_response_body}"
        fi
    done
    
    # Pull remote validators not in local
    for validator in "${remote_validators[@]}"; do
        # Check if validator exists locally
        if ! echo "${local_validators[@]}" | grep -q "${validator}"; then
            log_debug "Pulling data for new validator ${validator} from remote"
            
            # Get remote validator data
            local pull_response=$(curl -s -X GET "${ENDPOINT}/validators/${validator}" \
                "${headers[@]}" \
                -w "\n%{http_code}")
            
            local pull_http_code=$(echo "${pull_response}" | tail -n1)
            local pull_response_body=$(echo "${pull_response}" | sed '$d')
            
            if [[ "${pull_http_code}" =~ ^2[0-9][0-9]$ ]]; then
                # Save remote data locally
                mkdir -p "${METRICS_DIR}"
                echo "${pull_response_body}" | jq '.metrics' > "${METRICS_DIR}/validator_${validator}_metrics.json"
                
                mkdir -p "${ANALYSIS_DIR}"
                echo "${pull_response_body}" | jq '.analysis' > "${ANALYSIS_DIR}/validator_${validator}_analysis.json"
                
                mkdir -p "${BASE_DIR}/validator_metrics/alerts"
                echo "${pull_response_body}" | jq '.alerts' > "${BASE_DIR}/validator_metrics/alerts/validator_${validator}_alerts.json"
                
                log_success "Successfully pulled data for validator ${validator}"
            else
                log_error "Failed to pull data for validator ${validator}: HTTP ${pull_http_code}"
                log_debug "Response: ${pull_response_body}"
            fi
        fi
    done
}

# Return data for API server
function handle_data_mode {
    local list_validators=false
    local validator=""
    local data_type="all"
    
    # Parse data mode arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list-validators)
                list_validators=true
                shift
                ;;
            --validator)
                validator="$2"
                shift 2
                ;;
            --data-type)
                data_type="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ "${list_validators}" == "true" ]]; then
        get_all_validators
    elif [[ -n "${validator}" ]]; then
        get_validator_data "${validator}" "${data_type}"
    else
        echo "{}"
    fi
}

# Generate Prometheus metrics
function generate_prometheus_metrics {
    log_info "Generating Prometheus metrics"
    mkdir -p "${API_DIR}/prometheus"
    local metrics_file="${API_DIR}/prometheus/metrics"
    
    # Clear existing metrics file
    > "${metrics_file}"
    
    # Add validator metrics in Prometheus format
    echo "# HELP validator_status Current validator status (1=active, 0=inactive)" >> "${metrics_file}"
    echo "# TYPE validator_status gauge" >> "${metrics_file}"
    
    # Add sync status metrics
    echo "# HELP validator_sync_status Validator sync status (1=synced, 0=not synced)" >> "${metrics_file}"
    echo "# TYPE validator_sync_status gauge" >> "${metrics_file}"
    
    # Add performance metrics
    echo "# HELP validator_attestation_effectiveness Validator attestation effectiveness (0-100%)" >> "${metrics_file}"
    echo "# TYPE validator_attestation_effectiveness gauge" >> "${metrics_file}"
    
    echo "# HELP validator_balance Current validator balance in Gwei" >> "${metrics_file}"
    echo "# TYPE validator_balance gauge" >> "${metrics_file}"
    
    # Process each validator and add metrics
    for validator_dir in ${METRICS_DIR}/*; do
        if [[ -d "${validator_dir}" ]]; then
            local validator_index=$(basename "${validator_dir}")
            
            # Get latest metrics
            local latest_metrics_file=$(ls -t "${validator_dir}"/*.json 2>/dev/null | head -1)
            
            if [[ -f "${latest_metrics_file}" ]]; then
                local status=$(jq -r '.status // "unknown"' "${latest_metrics_file}")
                local sync_status=$(jq -r '.sync_status // "unknown"' "${latest_metrics_file}")
                local effectiveness=$(jq -r '.attestation_effectiveness // 0' "${latest_metrics_file}")
                local balance=$(jq -r '.balance // 0' "${latest_metrics_file}")
                
                # Convert status to numeric value
                local status_value=0
                if [[ "${status}" == "active" ]]; then
                    status_value=1
                fi
                
                # Convert sync status to numeric value
                local sync_value=0
                if [[ "${sync_status}" == "synced" ]]; then
                    sync_value=1
                fi
                
                # Add metrics to file
                echo "validator_status{validator=\"${validator_index}\"} ${status_value}" >> "${metrics_file}"
                echo "validator_sync_status{validator=\"${validator_index}\"} ${sync_value}" >> "${metrics_file}"
                echo "validator_attestation_effectiveness{validator=\"${validator_index}\"} ${effectiveness}" >> "${metrics_file}"
                echo "validator_balance{validator=\"${validator_index}\"} ${balance}" >> "${metrics_file}"
            fi
        fi
    done
    
    log_success "Generated Prometheus metrics at ${metrics_file}"
}

# Start Prometheus exporter
function start_prometheus_exporter {
    log_info "Starting Prometheus metrics exporter on port ${PROMETHEUS_PORT}"
    
    # Check if port is in use
    if netstat -tuln | grep -q ":${PROMETHEUS_PORT} "; then
        log_warning "Port ${PROMETHEUS_PORT} is already in use"
        # Try to kill existing process if it's our exporter
        if [[ -f "${PROMETHEUS_PID_FILE}" ]]; then
            local pid=$(cat "${PROMETHEUS_PID_FILE}")
            if kill -0 "${pid}" 2>/dev/null; then
                log_info "Stopping existing Prometheus exporter (PID ${pid})"
                kill "${pid}"
                sleep 1
            fi
            rm -f "${PROMETHEUS_PID_FILE}"
        else
            log_error "Cannot start Prometheus exporter, port ${PROMETHEUS_PORT} is in use by another process"
            return 1
        fi
    fi
    
    # Generate initial metrics
    generate_prometheus_metrics
    
    # Create exporter script
    local exporter_script="${API_DIR}/prometheus_exporter.sh"
    cat > "${exporter_script}" <<EOF
#!/bin/bash
while true; do
    nc -l ${PROMETHEUS_PORT} < ${API_DIR}/prometheus/metrics
    sleep 0.1
done
EOF
    
    chmod +x "${exporter_script}"
    
    # Start exporter in background
    ${exporter_script} &
    echo $! > "${PROMETHEUS_PID_FILE}"
    
    log_success "Prometheus exporter started on port ${PROMETHEUS_PORT}"
}

# Configure Grafana dashboards
function configure_grafana {
    log_info "Configuring Grafana dashboards"
    
    if [[ -z "${GRAFANA_KEY}" ]]; then
        log_error "Grafana API key is required for Grafana integration"
        return 1
    fi
    
    if [[ -z "${ENDPOINT}" ]]; then
        log_error "Grafana endpoint URL is required (use --endpoint)"
        return 1
    fi
    
    # Generate Grafana dashboard JSON
    local dashboard_file="${API_DIR}/grafana_dashboard.json"
    
    cat > "${dashboard_file}" <<EOF
{
  "dashboard": {
    "id": null,
    "title": "Ephemery Validator Dashboard",
    "description": "Comprehensive dashboard for Ephemery validators",
    "tags": ["ephemery", "validator", "monitoring"],
    "timezone": "browser",
    "editable": true,
    "refresh": "1m",
    "panels": [
      {
        "title": "Validator Status",
        "type": "stat",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "validator_status",
            "legendFormat": "{{validator}}"
          }
        ],
        "options": {
          "colorMode": "value",
          "graphMode": "area",
          "thresholdMarkers": true,
          "thresholds": {
            "mode": "absolute",
            "steps": [
              { "color": "red", "value": 0 },
              { "color": "green", "value": 1 }
            ]
          }
        }
      },
      {
        "title": "Validator Balance",
        "type": "graph",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "validator_balance",
            "legendFormat": "{{validator}}"
          }
        ]
      },
      {
        "title": "Attestation Effectiveness",
        "type": "gauge",
        "datasource": "Prometheus",
        "targets": [
          {
            "expr": "validator_attestation_effectiveness",
            "legendFormat": "{{validator}}"
          }
        ],
        "options": {
          "thresholds": [
            { "color": "red", "value": 0 },
            { "color": "yellow", "value": 80 },
            { "color": "green", "value": 95 }
          ]
        }
      }
    ]
  },
  "overwrite": false
}
EOF
    
    # Push dashboard to Grafana
    log_info "Pushing dashboard to Grafana at ${ENDPOINT}"
    local result=$(curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${GRAFANA_KEY}" "${ENDPOINT}/api/dashboards/db" -d @"${dashboard_file}")
    
    if echo "${result}" | jq -e '.success // false' > /dev/null; then
        log_success "Grafana dashboard created successfully"
    else
        log_error "Failed to create Grafana dashboard: $(echo ${result} | jq -r '.message // "Unknown error"')"
        return 1
    fi
}

# Create webhook endpoint handler
function setup_webhook_handler {
    log_info "Setting up webhook endpoint handler"
    
    local webhooks_dir="${API_DIR}/webhooks"
    mkdir -p "${webhooks_dir}"
    
    # Create webhook configuration
    local webhook_config="${webhooks_dir}/webhook_config.json"
    cat > "${webhook_config}" <<EOF
{
  "endpoints": [
    {
      "url": "${WEBHOOK_URL}",
      "events": ["alert", "status_change", "sync_issue", "performance_drop"],
      "format": "json",
      "active": true
    }
  ],
  "retry_count": 3,
  "retry_delay": 5,
  "max_batch_size": 10
}
EOF
    
    # Create webhook handler script
    local webhook_handler="${webhooks_dir}/webhook_handler.sh"
    cat > "${webhook_handler}" <<EOF
#!/bin/bash
# Webhook event publisher
CONFIG_FILE="${webhook_config}"
LOG_FILE="${webhooks_dir}/webhook.log"

function send_webhook {
    local event=\$1
    local payload=\$2
    local config=\$(cat "\${CONFIG_FILE}")
    
    # Get active endpoints for this event
    local endpoints=\$(echo "\${config}" | jq -r ".endpoints[] | select(.active == true and .events | contains([\"\${event}\"]) | .url")
    
    if [[ -z "\${endpoints}" ]]; then
        echo "\$(date): No active endpoints for event \${event}" >> "\${LOG_FILE}"
        return 0
    fi
    
    # Send to each endpoint
    echo "\${endpoints}" | while read url; do
        if [[ -n "\${url}" ]]; then
            echo "\$(date): Sending \${event} to \${url}" >> "\${LOG_FILE}"
            local result=\$(curl -s -X POST -H "Content-Type: application/json" "\${url}" -d "\${payload}")
            echo "\$(date): Result: \${result}" >> "\${LOG_FILE}"
        fi
    done
}

# Usage
if [[ \$# -lt 2 ]]; then
    echo "Usage: \$0 <event_type> <json_payload>"
    exit 1
fi

send_webhook "\$1" "\$2"
EOF
    
    chmod +x "${webhook_handler}"
    log_success "Webhook handler configured at ${webhook_handler}"
}

# Main function
function main {
    ensure_directories
    
    case "${MODE}" in
        api)
            start_api_server
            ;;
        push)
            push_to_external_system
            ;;
        sync)
            sync_with_external_system
            ;;
        prometheus)
            start_prometheus_exporter
            ;;
        grafana)
            configure_grafana
            ;;
        webhook)
            setup_webhook_handler
            ;;
        stop-api)
            stop_api_server
            ;;
        data)
            # Special mode used internally by the API server
            handle_data_mode "$@"
            ;;
        *)
            log_error "Unknown mode: ${MODE}"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"

exit 0 