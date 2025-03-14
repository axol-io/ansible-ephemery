#!/bin/bash
#
# Validator Monitoring Optimization Script
# This script optimizes the validator monitoring system for large validator sets
# and improves overall performance of the alerting and analytics components.
#
# Usage: ./optimize_validator_monitoring.sh [options]
# Options:
#   --base-dir DIR         Base directory (default: /opt/ephemery)
#   --validator-count N    Expected number of validators (for tuning)
#   --analyze-only         Only analyze current performance without changes
#   --apply-optimizations  Apply recommended optimizations
#   --config-file FILE     Configuration file path
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

# Default values
BASE_DIR="/opt/ephemery"
METRICS_DIR="${BASE_DIR}/validator_metrics/metrics"
CONFIG_DIR="${BASE_DIR}/config"
CONFIG_FILE="${CONFIG_DIR}/validator_monitoring.yaml"
ALERTS_CONFIG="${CONFIG_DIR}/validator_alerts.yaml"
PROMETHEUS_CONFIG="${CONFIG_DIR}/prometheus.yml"
VALIDATOR_COUNT=0
ANALYZE_ONLY=false
APPLY_OPTIMIZATIONS=false
VERBOSE=false
OPTIMIZATION_REPORT="${BASE_DIR}/validator_metrics/optimization_report.json"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-dir)
            BASE_DIR="$2"
            shift 2
            ;;
        --validator-count)
            VALIDATOR_COUNT="$2"
            shift 2
            ;;
        --analyze-only)
            ANALYZE_ONLY=true
            shift
            ;;
        --apply-optimizations)
            APPLY_OPTIMIZATIONS=true
            shift
            ;;
        --config-file)
            CONFIG_FILE="$2"
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
    echo -e "${BLUE}Validator Monitoring Optimization Script${NC}"
    echo ""
    echo "This script optimizes the validator monitoring system for better performance."
    echo ""
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --base-dir DIR         Base directory (default: ${BASE_DIR})"
    echo "  --validator-count N    Expected number of validators (for tuning)"
    echo "  --analyze-only         Only analyze current performance without changes"
    echo "  --apply-optimizations  Apply recommended optimizations"
    echo "  --config-file FILE     Configuration file path (default: ${CONFIG_FILE})"
    echo "  --verbose              Enable verbose output"
    echo "  --help                 Show this help message"
}

# Analyze current configuration and performance
function analyze_current_performance {
    log_info "Analyzing current monitoring system performance"
    
    local metrics_files_count=0
    local alerts_count=0
    local validation_error_count=0
    local performance_issues=()
    local optimization_recommendations=()
    
    # Count number of validator metrics files
    if [[ -d "${METRICS_DIR}" ]]; then
        metrics_files_count=$(find "${METRICS_DIR}" -name "validator_*_metrics.json" | wc -l)
    fi
    
    log_info "Found ${metrics_files_count} validator metrics files"
    
    # If validator count was not provided, estimate from metrics files
    if [[ $VALIDATOR_COUNT -eq 0 ]]; then
        VALIDATOR_COUNT=$metrics_files_count
        log_info "Estimated validator count: ${VALIDATOR_COUNT}"
    fi
    
    # Check alerts configuration
    if [[ -f "${ALERTS_CONFIG}" ]]; then
        # Count alert rules in the config
        alerts_count=$(grep -c "threshold:" "${ALERTS_CONFIG}" || echo 0)
        log_info "Found ${alerts_count} alert rules in configuration"
        
        # Check for any validation errors in the config
        validation_error_count=$(grep -c "ERROR" "${BASE_DIR}/validator_metrics/logs/alerts_validation.log" 2>/dev/null || echo 0)
        
        if [[ $validation_error_count -gt 0 ]]; then
            log_warning "Found ${validation_error_count} validation errors in alerts configuration"
            performance_issues+=("alerts_config_errors")
            optimization_recommendations+=("Fix validation errors in alerts configuration")
        fi
    else
        log_warning "Alerts configuration file not found at ${ALERTS_CONFIG}"
        performance_issues+=("missing_alerts_config")
        optimization_recommendations+=("Create alerts configuration file")
    fi
    
    # Check for large metrics files
    local large_files_count=$(find "${METRICS_DIR}" -name "validator_*_metrics.json" -size +1M 2>/dev/null | wc -l || echo 0)
    if [[ $large_files_count -gt 0 ]]; then
        log_warning "Found ${large_files_count} oversized metrics files (>1MB)"
        performance_issues+=("large_metrics_files")
        optimization_recommendations+=("Implement metrics data retention policy")
    fi
    
    # Check Prometheus configuration
    if [[ -f "${PROMETHEUS_CONFIG}" ]]; then
        local scrape_interval=$(grep "scrape_interval:" "${PROMETHEUS_CONFIG}" | head -n 1 | awk '{print $2}')
        
        if [[ -n "$scrape_interval" && "$scrape_interval" == *s ]]; then
            local interval_seconds=$(echo "$scrape_interval" | sed 's/s//')
            
            if [[ $VALIDATOR_COUNT -gt 100 && $interval_seconds -lt 30 ]]; then
                log_warning "Prometheus scrape interval (${scrape_interval}) may be too frequent for ${VALIDATOR_COUNT} validators"
                performance_issues+=("high_scrape_frequency")
                optimization_recommendations+=("Increase Prometheus scrape interval")
            fi
        fi
    fi
    
    # Check for excessive logging
    local log_dir="${BASE_DIR}/validator_metrics/logs"
    if [[ -d "$log_dir" ]]; then
        local log_size=$(du -sm "$log_dir" 2>/dev/null | awk '{print $1}' || echo 0)
        
        if [[ $log_size -gt 500 ]]; then
            log_warning "Log directory size (${log_size}MB) is excessive"
            performance_issues+=("excessive_logging")
            optimization_recommendations+=("Implement log rotation and reduce log verbosity")
        fi
    fi
    
    # Check for alert processing performance
    if [[ -f "${BASE_DIR}/validator_metrics/logs/alert_processing_times.log" ]]; then
        local avg_processing_time=$(awk '{sum+=$1; count++} END {print sum/count}' "${BASE_DIR}/validator_metrics/logs/alert_processing_times.log" 2>/dev/null || echo 0)
        
        if [[ $(echo "$avg_processing_time > 5" | bc -l) -eq 1 ]]; then
            log_warning "Alert processing time (${avg_processing_time}s) is above optimal threshold"
            performance_issues+=("slow_alert_processing")
            optimization_recommendations+=("Optimize alert processing or implement batching")
        fi
    fi
    
    # Check for database optimization if using a database
    if [[ -d "${BASE_DIR}/validator_metrics/db" ]]; then
        log_info "Database storage detected, checking optimization"
        
        local db_size=$(du -sm "${BASE_DIR}/validator_metrics/db" 2>/dev/null | awk '{print $1}' || echo 0)
        log_info "Database size: ${db_size}MB"
        
        if [[ $db_size -gt 1000 ]]; then
            log_warning "Database size (${db_size}MB) is large, may need optimization"
            performance_issues+=("large_database")
            optimization_recommendations+=("Implement database pruning and indexing")
        fi
    fi
    
    # Generate optimization report
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local issues_json=$(printf '"%s"' "${performance_issues[@]}" | jq -R . | jq -s .)
    local recommendations_json=$(printf '"%s"' "${optimization_recommendations[@]}" | jq -R . | jq -s .)
    
    # Create performance analysis result
    mkdir -p "$(dirname "${OPTIMIZATION_REPORT}")"
    cat > "${OPTIMIZATION_REPORT}" <<EOF
{
  "timestamp": "${timestamp}",
  "validator_count": ${VALIDATOR_COUNT},
  "metrics_files_count": ${metrics_files_count},
  "alerts_count": ${alerts_count},
  "validation_error_count": ${validation_error_count},
  "performance_issues": ${issues_json},
  "optimization_recommendations": ${recommendations_json}
}
EOF
    
    log_success "Performance analysis completed. Report saved to ${OPTIMIZATION_REPORT}"
    
    # Display summary
    log_info "Performance Analysis Summary:"
    log_info "  Validator count: ${VALIDATOR_COUNT}"
    log_info "  Metrics files: ${metrics_files_count}"
    log_info "  Alert rules: ${alerts_count}"
    log_info "  Performance issues found: ${#performance_issues[@]}"
    
    if [[ ${#performance_issues[@]} -gt 0 ]]; then
        log_info "Recommended optimizations:"
        local i=1
        for rec in "${optimization_recommendations[@]}"; do
            log_info "  ${i}. ${rec}"
            ((i++))
        done
    fi
}

# Apply optimizations based on analysis
function apply_optimizations {
    log_info "Applying performance optimizations"
    
    if [[ ! -f "${OPTIMIZATION_REPORT}" ]]; then
        log_error "Optimization report not found. Run analysis first."
        exit 1
    fi
    
    # Read performance issues from report
    local performance_issues=($(jq -r '.performance_issues[]' "${OPTIMIZATION_REPORT}"))
    
    # Process each performance issue
    for issue in "${performance_issues[@]}"; do
        log_info "Addressing performance issue: ${issue}"
        
        case "${issue}" in
            alerts_config_errors)
                fix_alerts_config
                ;;
            large_metrics_files)
                implement_data_retention
                ;;
            high_scrape_frequency)
                optimize_prometheus_config
                ;;
            excessive_logging)
                optimize_logging
                ;;
            slow_alert_processing)
                optimize_alert_processing
                ;;
            large_database)
                optimize_database
                ;;
            missing_alerts_config)
                create_alerts_config
                ;;
            *)
                log_warning "No automated fix available for issue: ${issue}"
                ;;
        esac
    done
    
    log_success "Applied performance optimizations"
}

# Fix alerts configuration validation errors
function fix_alerts_config {
    if [[ ! -f "${ALERTS_CONFIG}" ]]; then
        log_error "Alerts configuration not found at ${ALERTS_CONFIG}"
        return
    }
    
    log_info "Fixing alerts configuration"
    
    # Backup original config
    cp "${ALERTS_CONFIG}" "${ALERTS_CONFIG}.bak"
    log_info "Created backup at ${ALERTS_CONFIG}.bak"
    
    # Common fixes for alerts configuration
    # 1. Fix indentation issues
    sed -i 's/^[ \t]*/  /' "${ALERTS_CONFIG}"
    
    # 2. Fix missing quotes around string values
    sed -i 's/\(severity: \)\([a-z]*\)/\1"\2"/' "${ALERTS_CONFIG}"
    
    # 3. Fix non-numeric threshold values
    sed -i 's/\(threshold: \)\([a-zA-Z]\)/\1"0"/' "${ALERTS_CONFIG}"
    
    log_success "Applied fixes to alerts configuration"
}

# Implement data retention policy for metrics files
function implement_data_retention {
    log_info "Implementing metrics data retention policy"
    
    # Create retention script
    local retention_script="${BASE_DIR}/scripts/metrics_retention.sh"
    
    cat > "${retention_script}" <<'EOF'
#!/bin/bash

METRICS_DIR="$1"
MAX_AGE_DAYS=30
MAX_SIZE_MB=5

if [[ ! -d "${METRICS_DIR}" ]]; then
    echo "Error: Metrics directory not found: ${METRICS_DIR}"
    exit 1
fi

# Process files based on age
find "${METRICS_DIR}" -name "validator_*_metrics.json" -type f -mtime +${MAX_AGE_DAYS} -delete

# Process large files
find "${METRICS_DIR}" -name "validator_*_metrics.json" -type f -size +${MAX_SIZE_MB}M | while read -r file; do
    # Keep only last 1000 data points
    jq '.data |= if length > 1000 then [.[-1000:][]] else . end' "$file" > "${file}.new"
    mv "${file}.new" "$file"
done

echo "Retention completed at $(date -u)"
EOF
    
    chmod +x "${retention_script}"
    
    # Create cron job for regular execution
    if ! crontab -l | grep -q "${retention_script}"; then
        (crontab -l 2>/dev/null; echo "0 2 * * * ${retention_script} ${METRICS_DIR}") | crontab -
        log_success "Added retention script to crontab"
    else
        log_info "Retention script already in crontab"
    fi
    
    # Run retention script immediately
    "${retention_script}" "${METRICS_DIR}"
    
    log_success "Implemented data retention policy"
}

# Optimize Prometheus configuration
function optimize_prometheus_config {
    if [[ ! -f "${PROMETHEUS_CONFIG}" ]]; then
        log_error "Prometheus configuration not found at ${PROMETHEUS_CONFIG}"
        return
    }
    
    log_info "Optimizing Prometheus configuration"
    
    # Backup original config
    cp "${PROMETHEUS_CONFIG}" "${PROMETHEUS_CONFIG}.bak"
    log_info "Created backup at ${PROMETHEUS_CONFIG}.bak"
    
    # Calculate optimal scrape interval based on validator count
    local optimal_interval=15
    if [[ $VALIDATOR_COUNT -gt 100 ]]; then
        optimal_interval=30
    fi
    if [[ $VALIDATOR_COUNT -gt 500 ]]; then
        optimal_interval=60
    fi
    
    # Update global scrape interval
    if grep -q "^global:" "${PROMETHEUS_CONFIG}"; then
        sed -i "/^global:/,/^[a-z]/ s/scrape_interval:.*/scrape_interval: ${optimal_interval}s/" "${PROMETHEUS_CONFIG}"
    else
        # Add global section if it doesn't exist
        sed -i "1i global:\n  scrape_interval: ${optimal_interval}s\n  evaluation_interval: ${optimal_interval}s\n" "${PROMETHEUS_CONFIG}"
    fi
    
    # Add Prometheus optimizations for large validator sets
    if ! grep -q "query.max-samples" "${PROMETHEUS_CONFIG}"; then
        cat >> "${PROMETHEUS_CONFIG}" <<EOF

# Performance optimizations for large validator sets
# Added by ${0} on $(date -u)
command_line_flags:
  - "--storage.tsdb.retention.time=15d"
  - "--query.max-samples=100000000"
  - "--storage.tsdb.wal-compression"
EOF
    fi
    
    log_success "Optimized Prometheus configuration"
}

# Optimize logging configuration
function optimize_logging {
    log_info "Optimizing logging configuration"
    
    # Create log rotation configuration
    local logrotate_config="/etc/logrotate.d/validator_metrics"
    
    # Check if we can write to logrotate directory
    if [[ -d "/etc/logrotate.d" && -w "/etc/logrotate.d" ]]; then
        cat > "${logrotate_config}" <<EOF
${BASE_DIR}/validator_metrics/logs/*.log {
  daily
  rotate 7
  compress
  delaycompress
  missingok
  notifempty
  create 0640 root root
}
EOF
        log_success "Created logrotate configuration at ${logrotate_config}"
    else
        # Create a custom log rotation script if we can't write to system logrotate
        local rotation_script="${BASE_DIR}/scripts/rotate_logs.sh"
        
        cat > "${rotation_script}" <<'EOF'
#!/bin/bash

LOG_DIR="$1"
MAX_AGE_DAYS=7

if [[ ! -d "${LOG_DIR}" ]]; then
    echo "Error: Log directory not found: ${LOG_DIR}"
    exit 1
fi

# Compress logs older than 1 day
find "${LOG_DIR}" -name "*.log" -type f -mtime +1 -not -name "*.gz" | while read -r file; do
    gzip -9 "$file"
done

# Delete logs older than MAX_AGE_DAYS
find "${LOG_DIR}" -name "*.gz" -type f -mtime +${MAX_AGE_DAYS} -delete

echo "Log rotation completed at $(date -u)"
EOF
        
        chmod +x "${rotation_script}"
        
        # Create cron job for regular execution
        if ! crontab -l | grep -q "${rotation_script}"; then
            (crontab -l 2>/dev/null; echo "0 1 * * * ${rotation_script} ${BASE_DIR}/validator_metrics/logs") | crontab -
            log_success "Added log rotation script to crontab"
        else
            log_info "Log rotation script already in crontab"
        fi
    fi
    
    # Update logging level in monitoring scripts
    for script in "${SCRIPT_DIR}"/*validator*.sh; do
        if [[ -f "$script" ]]; then
            # Reduce default log level if set to debug
            if grep -q "LOG_LEVEL=\"debug\"" "$script"; then
                sed -i 's/LOG_LEVEL="debug"/LOG_LEVEL="info"/' "$script"
                log_info "Updated log level in $(basename "$script")"
            fi
        fi
    done
    
    log_success "Optimized logging configuration"
}

# Optimize alert processing
function optimize_alert_processing {
    log_info "Optimizing alert processing"
    
    # Look for alert system script
    local alert_script="${SCRIPT_DIR}/validator_alerts_system.sh"
    
    if [[ ! -f "${alert_script}" ]]; then
        log_warning "Alert system script not found at ${alert_script}"
        return
    }
    
    log_info "Optimizing ${alert_script}"
    
    # Backup original script
    cp "${alert_script}" "${alert_script}.bak"
    log_info "Created backup at ${alert_script}.bak"
    
    # Read the script content
    local script_content=$(cat "${alert_script}")
    
    # Check if the script already has batching
    if ! grep -q "process_alerts_batch" "${alert_script}"; then
        # Add batching functions
        script_content=$(awk '
        /^# Default configurations/ {
            print "# Added optimizations for large validator sets";
            print "BATCH_SIZE=20  # Process validators in batches of this size";
            print "USE_BATCHING=true";
            print "";
            print $0;
            next;
        }
        /^function process_validator_alerts/ {
            print "# Process alerts for multiple validators in a batch";
            print "function process_alerts_batch {";
            print "    local validators=($@)";
            print "    local batch_results=()";
            print "    local batch_start_time=$(date +%s.%N)";
            print "";
            print "    # Process each validator in the batch";
            print "    for validator_index in \"${validators[@]}\"; do";
            print "        # Get validator alerts without sending notifications";
            print "        local result=$(process_validator_alerts \"${validator_index}\" true)";
            print "        batch_results+=(\"${result}\")";
            print "    done";
            print "";
            print "    # Send consolidated notifications for the batch";
            print "    if [[ ${#batch_results[@]} -gt 0 ]]; then";
            print "        send_batch_notifications \"${batch_results[@]}\"";
            print "    fi";
            print "";
            print "    local batch_end_time=$(date +%s.%N)";
            print "    local batch_duration=$(echo \"${batch_end_time} - ${batch_start_time}\" | bc)";
            print "    log_debug \"Processed batch of ${#validators[@]} validators in ${batch_duration}s\"";
            print "}";
            print "";
            print "# Send consolidated notifications for a batch of alerts";
            print "function send_batch_notifications {";
            print "    local alerts=($@)";
            print "    ";
            print "    # Skip if no alerts";
            print "    if [[ ${#alerts[@]} -eq 0 ]]; then";
            print "        return";
            print "    fi";
            print "    ";
            print "    # Group alerts by type and severity";
            print "    # Implementation would consolidate similar alerts";
            print "    # and prepare batch notifications";
            print "    ";
            print "    # Example of consolidated email notification";
            print "    if [[ \"${NOTIFICATION_EMAIL}\" == \"true\" ]]; then";
            print "        send_email_notification \"Batch Validator Alerts\" \"$(printf \"%s\\n\" \"${alerts[@]}\")\"";
            print "    fi";
            print "    ";
            print "    # Similar batching for other notification types";
            print "}";
            print "";
            print $0;
            next;
        }
        /^# Main function/ {
            print "# Split validators into batches and process them";
            print "function process_validators_in_batches {";
            print "    local validators=($@)";
            print "    local total_validators=${#validators[@]}";
            print "    local batch_count=$(( (total_validators + BATCH_SIZE - 1) / BATCH_SIZE ))";
            print "";
            print "    log_info \"Processing ${total_validators} validators in ${batch_count} batches of up to ${BATCH_SIZE}\"";
            print "";
            print "    for ((i=0; i<batch_count; i++)); do";
            print "        local start_idx=$((i * BATCH_SIZE))";
            print "        local end_idx=$(( (i+1) * BATCH_SIZE - 1 ))";
            print "        if [[ $end_idx -ge $total_validators ]]; then";
            print "            end_idx=$((total_validators - 1))";
            print "        fi";
            print "";
            print "        local batch_validators=()";
            print "        for ((j=start_idx; j<=end_idx; j++)); do";
            print "            batch_validators+=(\"${validators[j]}\")";
            print "        done";
            print "";
            print "        log_debug \"Processing batch $((i+1))/${batch_count}: ${#batch_validators[@]} validators\"";
            print "        process_alerts_batch \"${batch_validators[@]}\"";
            print "    done";
            print "}";
            print "";
            print $0;
            next;
        }
        {print}' <<< "${script_content}")
        
        # Update main function to use batching
        script_content=$(sed '/# Process each validator/,/done/c\
    # Process validators in batches or individually\
    if [[ "${USE_BATCHING}" == "true" && ${#validators[@]} -gt ${BATCH_SIZE} ]]; then\
        process_validators_in_batches "${validators[@]}"\
    else\
        # Process each validator individually (original code)\
        for validator_index in "${validators[@]}"; do\
            log_debug "Processing validator ${validator_index}"\
            process_validator_alerts "${validator_index}" false\
        done\
    fi' <<< "${script_content}")
        
        # Write updated script
        echo "${script_content}" > "${alert_script}"
        chmod +x "${alert_script}"
        
        log_success "Added batch processing to alert system script"
    else
        log_info "Alert system script already has batch processing"
    fi
    
    # Update alert configuration for performance
    if [[ -f "${ALERTS_CONFIG}" ]]; then
        # Add performance settings if not present
        if ! grep -q "performance:" "${ALERTS_CONFIG}"; then
            cat >> "${ALERTS_CONFIG}" <<EOF

# Performance optimization settings
# Added by optimize_validator_monitoring.sh on $(date -u)
performance:
  batch_size: $((VALIDATOR_COUNT / 10 > 20 ? VALIDATOR_COUNT / 10 : 20))
  use_batching: true
  cache_ttl: 300
  parallel_processing: true
EOF
            log_success "Added performance settings to alerts configuration"
        fi
    fi
}

# Optimize database if present
function optimize_database {
    local db_dir="${BASE_DIR}/validator_metrics/db"
    
    if [[ ! -d "${db_dir}" ]]; then
        log_warning "Database directory not found at ${db_dir}"
        return
    }
    
    log_info "Optimizing database storage"
    
    # Create database optimization script
    local db_script="${BASE_DIR}/scripts/optimize_db.sh"
    
    cat > "${db_script}" <<'EOF'
#!/bin/bash

DB_DIR="$1"
MAX_AGE_DAYS=60

if [[ ! -d "${DB_DIR}" ]]; then
    echo "Error: Database directory not found: ${DB_DIR}"
    exit 1
fi

# Check for SQLite databases
find "${DB_DIR}" -name "*.db" -type f | while read -r db_file; do
    echo "Optimizing SQLite database: ${db_file}"
    
    # Run VACUUM to reclaim space
    sqlite3 "${db_file}" "VACUUM;"
    
    # Create indexes if they don't exist
    sqlite3 "${db_file}" <<SQL
CREATE INDEX IF NOT EXISTS idx_timestamp ON metrics(timestamp);
CREATE INDEX IF NOT EXISTS idx_validator ON metrics(validator_id);
ANALYZE;
SQL
    
    # Delete old data
    sqlite3 "${db_file}" "DELETE FROM metrics WHERE timestamp < datetime('now', '-${MAX_AGE_DAYS} days');"
    
    # Run VACUUM again after deletion
    sqlite3 "${db_file}" "VACUUM;"
done

# Check for other database files
# Add custom handling for other database types here

echo "Database optimization completed at $(date -u)"
EOF
    
    chmod +x "${db_script}"
    
    # Create cron job for regular execution
    if ! crontab -l | grep -q "${db_script}"; then
        (crontab -l 2>/dev/null; echo "0 3 * * 0 ${db_script} ${db_dir}") | crontab -
        log_success "Added database optimization script to crontab (weekly)"
    else
        log_info "Database optimization script already in crontab"
    fi
    
    # Run optimization script immediately
    "${db_script}" "${db_dir}"
    
    log_success "Optimized database storage"
}

# Create a basic alerts configuration if missing
function create_alerts_config {
    if [[ -f "${ALERTS_CONFIG}" ]]; then
        log_info "Alerts configuration already exists at ${ALERTS_CONFIG}"
        return
    }
    
    log_info "Creating basic alerts configuration"
    
    mkdir -p "$(dirname "${ALERTS_CONFIG}")"
    
    cat > "${ALERTS_CONFIG}" <<EOF
# Validator Alerts Configuration
# Created by optimize_validator_monitoring.sh on $(date -u)

alerts:
  missed_attestation:
    threshold: 2
    period: "1h"
    severity: "warning"
  missed_proposal:
    threshold: 1
    period: "1d"
    severity: "critical"
  performance_decrease:
    threshold: 10
    period: "1d"
    severity: "warning"
  balance_decrease:
    threshold: 0.01
    period: "1d"
    severity: "warning"
  client_disconnect:
    threshold: 300
    period: "10m"
    severity: "critical"

notifications:
  console: true
  email: false
  webhook: false
  telegram: false
  discord: false

# Performance optimization settings
performance:
  batch_size: $((VALIDATOR_COUNT / 10 > 20 ? VALIDATOR_COUNT / 10 : 20))
  use_batching: true
  cache_ttl: 300
  parallel_processing: $(( VALIDATOR_COUNT > 100 ? "true" : "false" ))
EOF
    
    log_success "Created basic alerts configuration at ${ALERTS_CONFIG}"
}

# Main function
function main {
    # Always perform analysis
    analyze_current_performance
    
    # Apply optimizations if requested
    if [[ "${APPLY_OPTIMIZATIONS}" == "true" ]]; then
        apply_optimizations
    elif [[ "${ANALYZE_ONLY}" != "true" ]]; then
        # If neither --analyze-only nor --apply-optimizations specified, ask user
        read -p "Do you want to apply the recommended optimizations? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            apply_optimizations
        else
            log_info "No optimizations applied. Use --apply-optimizations to apply them later."
        fi
    else
        log_info "Analysis complete. Use --apply-optimizations to apply optimizations."
    fi
    
    log_success "Optimization script completed"
}

# Run main function
main

exit 0 