#!/bin/bash
# Version: 1.0.0
#
# CSM Analytics Suite
# This script provides a comprehensive interface to all CSM analytics tools,
# integrating validator performance monitoring, predictive analytics, and bond optimization.
#
# Usage: ./csm_analytics_suite.sh [command] [options]
# Commands:
#   monitor         - Run validator performance monitoring
#   analyze         - Run predictive analytics
#   optimize        - Run bond optimization
#   dashboard       - Generate comprehensive analytics dashboard
#   automate        - Set up automated analytics (cron jobs)
#   help            - Show this help message
#
# For command-specific options, run:
#   ./csm_analytics_suite.sh [command] --help

set -e

# Define color codes for output

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source common functions if available
COMMON_SCRIPT="${REPO_ROOT}/scripts/utilities/common_functions.sh"
if [[ -f "${COMMON_SCRIPT}" ]]; then
  source "${COMMON_SCRIPT}"
else
  # Define minimal required functions if common_functions.sh is not available
  function log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
  function log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
  function log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" >&2; }
  function log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
  function log_debug() { if [[ "${VERBOSE}" == "true" ]]; then echo -e "${CYAN}[DEBUG]${NC} $*"; fi; }
fi

# Check for required tools
for cmd in jq bc awk curl; do
  if ! command -v ${cmd} &>/dev/null; then
    log_error "${cmd} is required but not installed. Please install it and try again."
    exit 1
  fi
done

# Default values
BASE_DIR="/opt/ephemery"
DATA_DIR="/var/lib/validator/data"
METRICS_DIR="/var/lib/validator/metrics"
CONFIG_DIR="${SCRIPT_DIR}/config"
OUTPUT_FORMAT="terminal"
OUTPUT_FILE=""
VERBOSE=false

# Define paths to component scripts
PERFORMANCE_SCRIPT="${SCRIPT_DIR}/csm_validator_performance.sh"
PREDICTIVE_SCRIPT="${SCRIPT_DIR}/validator_predictive_analytics.sh"
BOND_SCRIPT="${SCRIPT_DIR}/bond_optimization.sh"

# Check if scripts exist
if [[ ! -f "${PERFORMANCE_SCRIPT}" ]]; then
  log_error "Validator performance script not found: ${PERFORMANCE_SCRIPT}"
  exit 1
fi

if [[ ! -f "${PREDICTIVE_SCRIPT}" ]]; then
  log_warning "Predictive analytics script not found: ${PREDICTIVE_SCRIPT}"
  log_warning "Predictive analytics features will be disabled"
  PREDICTIVE_AVAILABLE=false
else
  PREDICTIVE_AVAILABLE=true
fi

if [[ ! -f "${BOND_SCRIPT}" ]]; then
  log_warning "Bond optimization script not found: ${BOND_SCRIPT}"
  log_warning "Bond optimization features will be disabled"
  BOND_AVAILABLE=false
else
  BOND_AVAILABLE=true
fi

# Function to show help
show_help() {
  local command="$1"

  case "${command}" in
    monitor)
      echo "CSM Validator Performance Monitoring"
      echo ""
      echo "Usage: $0 monitor [options]"
      echo "Options:"
      echo "  --base-dir DIR         Base directory (default: ${BASE_DIR})"
      echo "  --data-dir DIR         Data directory (default: ${DATA_DIR})"
      echo "  --metrics-dir DIR      Metrics directory (default: ${METRICS_DIR})"
      echo "  --config-file FILE     Configuration file path"
      echo "  --output FORMAT        Output format: json, csv, html, terminal (default: ${OUTPUT_FORMAT})"
      echo "  --output-file FILE     Output file path (defaults to stdout if not specified)"
      echo "  --monitoring-interval N Number of minutes between monitoring runs (default: 60)"
      echo "  --alert-threshold N    Alert threshold for performance deviation (default: 10)"
      echo "  --compare-network      Compare with network averages (requires API)"
      echo "  --verbose              Enable verbose output"
      ;;
    analyze)
      echo "Validator Predictive Analytics"
      echo ""
      echo "Usage: $0 analyze [options]"
      echo "Options:"
      echo "  --base-dir DIR         Base directory (default: ${BASE_DIR})"
      echo "  --forecast-days N      Number of days to forecast (default: 7)"
      echo "  --analysis-type TYPE   Type of analysis: basic, advanced, comprehensive (default: advanced)"
      echo "  --output FORMAT        Output format: json, csv, html (default: json)"
      echo "  --output-file FILE     Output file path (defaults to stdout if not specified)"
      echo "  --config-file FILE     Configuration file path"
      echo "  --verbose              Enable verbose output"
      ;;
    optimize)
      echo "Bond Optimization for Lido CSM"
      echo ""
      echo "Usage: $0 optimize [options]"
      echo "Options:"
      echo "  --base-dir DIR         Base directory (default: ${BASE_DIR})"
      echo "  --config-file FILE     Configuration file path"
      echo "  --risk-profile PROFILE Risk profile: conservative, balanced, aggressive (default: balanced)"
      echo "  --output FORMAT        Output format: json, csv, terminal (default: terminal)"
      echo "  --output-file FILE     Output file path (defaults to stdout if not specified)"
      echo "  --verbose              Enable verbose output"
      ;;
    dashboard)
      echo "CSM Analytics Dashboard"
      echo ""
      echo "Usage: $0 dashboard [options]"
      echo "Options:"
      echo "  --base-dir DIR         Base directory (default: ${BASE_DIR})"
      echo "  --data-dir DIR         Data directory (default: ${DATA_DIR})"
      echo "  --metrics-dir DIR      Metrics directory (default: ${METRICS_DIR})"
      echo "  --output-file FILE     Output file path (defaults to stdout if not specified)"
      echo "  --time-period PERIOD   Time period to analyze: 1d, 7d, 30d, all (default: 7d)"
      echo "  --refresh              Regenerate all analytics before creating dashboard"
      echo "  --verbose              Enable verbose output"
      ;;
    automate)
      echo "Set Up Automated Analytics"
      echo ""
      echo "Usage: $0 automate [options]"
      echo "Options:"
      echo "  --base-dir DIR         Base directory (default: ${BASE_DIR})"
      echo "  --monitoring-interval N Number of minutes between monitoring runs (default: 60)"
      echo "  --analysis-interval N  Number of hours between analytics runs (default: 24)"
      echo "  --optimization-interval N Number of hours between optimization runs (default: 24)"
      echo "  --dashboard-interval N Number of hours between dashboard generation (default: 4)"
      echo "  --disable COMPONENT    Disable a component: monitoring, analytics, optimization, dashboard"
      echo "  --verbose              Enable verbose output"
      ;;
    *)
      echo "CSM Analytics Suite"
      echo ""
      echo "Usage: $0 [command] [options]"
      echo "Commands:"
      echo "  monitor         - Run validator performance monitoring"
      echo "  analyze         - Run predictive analytics"
      echo "  optimize        - Run bond optimization"
      echo "  dashboard       - Generate comprehensive analytics dashboard"
      echo "  automate        - Set up automated analytics (cron jobs)"
      echo "  help            - Show this help message"
      echo ""
      echo "For command-specific options, run:"
      echo "  $0 [command] --help"
      ;;
  esac
}

# Function to run validator performance monitoring
run_monitoring() {
  log_info "Running CSM validator performance monitoring"

  # Construct command with passed options
  local cmd="${PERFORMANCE_SCRIPT}"

  # Add options
  for arg in "$@"; do
    cmd="${cmd} ${arg}"
  done

  # Execute command
  log_debug "Executing: ${cmd}"
  eval "${cmd}"

  log_success "Validator performance monitoring completed"
}

# Function to run predictive analytics
run_analytics() {
  if [[ "${PREDICTIVE_AVAILABLE}" != "true" ]]; then
    log_error "Predictive analytics script not available"
    return 1
  fi

  log_info "Running validator predictive analytics"

  # Construct command with passed options
  local cmd="${PREDICTIVE_SCRIPT}"

  # Add options
  for arg in "$@"; do
    cmd="${cmd} ${arg}"
  done

  # Execute command
  log_debug "Executing: ${cmd}"
  eval "${cmd}"

  log_success "Validator predictive analytics completed"
}

# Function to run bond optimization
run_optimization() {
  if [[ "${BOND_AVAILABLE}" != "true" ]]; then
    log_error "Bond optimization script not available"
    return 1
  fi

  log_info "Running bond optimization"

  # Construct command with passed options
  local cmd="${BOND_SCRIPT}"

  # Add options
  for arg in "$@"; do
    cmd="${cmd} ${arg}"
  done

  # Execute command
  log_debug "Executing: ${cmd}"
  eval "${cmd}"

  log_success "Bond optimization completed"
}

# Function to generate comprehensive dashboard
generate_dashboard() {
  log_info "Generating CSM analytics dashboard"

  # Parse options
  local output_file=""
  local time_period="7d"
  local refresh=false
  local remaining_args=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output-file)
        output_file="$2"
        shift 2
        ;;
      --time-period)
        time_period="$2"
        shift 2
        ;;
      --refresh)
        refresh=true
        shift
        ;;
      *)
        remaining_args+=("$1")
        shift
        ;;
    esac
  done

  # Check if output file is specified
  if [[ -z "${output_file}" ]]; then
    output_file="${METRICS_DIR}/csm_dashboard_$(date +%Y%m%d_%H%M%S).html"
  fi

  # If refresh is requested, run all analytics
  if [[ "${refresh}" == "true" ]]; then
    log_info "Refreshing all analytics before generating dashboard"

    # Run monitoring
    run_monitoring "${remaining_args[@]}" --output json --output-file "${METRICS_DIR}/latest_monitoring.json"

    # Run predictive analytics if available
    if [[ "${PREDICTIVE_AVAILABLE}" == "true" ]]; then
      run_analytics "${remaining_args[@]}" --output json --output-file "${METRICS_DIR}/latest_analytics.json"
    fi

    # Run bond optimization if available
    if [[ "${BOND_AVAILABLE}" == "true" ]]; then
      run_optimization "${remaining_args[@]}" --output json --output-file "${METRICS_DIR}/latest_optimization.json"
    fi
  fi

  # Generate dashboard HTML
  log_info "Creating dashboard with time period: ${time_period}"

  # Load latest monitoring data
  local monitoring_data="{}"
  if [[ -f "${METRICS_DIR}/latest_monitoring.json" ]]; then
    monitoring_data=$(cat "${METRICS_DIR}/latest_monitoring.json")
  else
    log_warning "No monitoring data found, dashboard will be incomplete"
  fi

  # Load latest analytics data
  local analytics_data="{}"
  if [[ -f "${METRICS_DIR}/latest_analytics.json" ]]; then
    analytics_data=$(cat "${METRICS_DIR}/latest_analytics.json")
  else
    log_warning "No analytics data found, dashboard will be incomplete"
  fi

  # Load latest optimization data
  local optimization_data="{}"
  if [[ -f "${METRICS_DIR}/latest_optimization.json" ]]; then
    optimization_data=$(cat "${METRICS_DIR}/latest_optimization.json")
  else
    log_warning "No optimization data found, dashboard will be incomplete"
  fi

  # Create dashboard HTML
  local dashboard_html=$(
    cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CSM Analytics Dashboard</title>
    <style>
        body {
            font-family: Arial, Helvetica, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #f5f5f5;
            color: #333;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            background-color: #2c3e50;
            color: white;
            padding: 20px;
            text-align: center;
            margin-bottom: 20px;
            border-radius: 5px;
        }
        .section {
            background-color: white;
            padding: 20px;
            margin-bottom: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        .card {
            background-color: #f9f9f9;
            padding: 15px;
            margin-bottom: 15px;
            border-radius: 5px;
            border-left: 4px solid #3498db;
        }
        .card-warning {
            border-left-color: #f39c12;
        }
        .card-danger {
            border-left-color: #e74c3c;
        }
        .card-success {
            border-left-color: #2ecc71;
        }
        .flex-container {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
        }
        .flex-item {
            flex: 1;
            min-width: 300px;
        }
        .metric {
            display: flex;
            justify-content: space-between;
            margin-bottom: 10px;
        }
        .metric-name {
            font-weight: bold;
        }
        .metric-value {
            font-family: monospace;
        }
        .status-good {
            color: #2ecc71;
        }
        .status-warning {
            color: #f39c12;
        }
        .status-critical {
            color: #e74c3c;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 8px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f2f2f2;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .footer {
            text-align: center;
            margin-top: 20px;
            padding: 10px;
            color: #7f8c8d;
            font-size: 0.8em;
        }
        .recommendations {
            margin-top: 15px;
        }
        .recommendation {
            padding: 10px;
            margin-bottom: 10px;
            border-radius: 5px;
            background-color: #f8f9fa;
        }
        .recommendation-high {
            border-left: 4px solid #e74c3c;
        }
        .recommendation-medium {
            border-left: 4px solid #f39c12;
        }
        .recommendation-low {
            border-left: 4px solid #3498db;
        }
        .alert {
            background-color: #ffeded;
            border-left: 4px solid #e74c3c;
            padding: 10px;
            margin-bottom: 10px;
            border-radius: 0 5px 5px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>CSM Analytics Dashboard</h1>
            <p>Generated on $(date)</p>
            <p>Time Period: ${time_period}</p>
        </div>
EOF
  )

  # Add Validator Performance Section
  dashboard_html+=$(
    cat <<EOF
        <div class="section">
            <h2>Validator Performance</h2>
EOF
  )

  # Add validator performance data if available
  if [[ "${monitoring_data}" != "{}" ]]; then
    # Get validator count
    local validator_count=$(echo "${monitoring_data}" | jq '.validators | length')

    # Add validator overview
    dashboard_html+=$(
      cat <<EOF
            <div class="card">
                <h3>Overview</h3>
                <div class="flex-container">
                    <div class="flex-item">
                        <div class="metric">
                            <span class="metric-name">Total Validators:</span>
                            <span class="metric-value">${validator_count}</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Monitoring Interval:</span>
                            <span class="metric-value">$(echo "${monitoring_data}" | jq -r '.monitoring_interval') minutes</span>
                        </div>
EOF
    )

    # Add network comparison if available
    if [[ "$(echo "${monitoring_data}" | jq -r '.compare_network')" == "true" ]]; then
      dashboard_html+=$(
        cat <<EOF
                        <div class="metric">
                            <span class="metric-name">Network Average Effectiveness:</span>
                            <span class="metric-value">$(echo "${monitoring_data}" | jq -r '.network_average.average_effectiveness')%</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Network Average Balance:</span>
                            <span class="metric-value">$(echo "${monitoring_data}" | jq -r '.network_average.average_balance') gwei</span>
                        </div>
EOF
      )
    fi

    dashboard_html+=$(
      cat <<EOF
                    </div>
                </div>
            </div>
EOF
    )

    # Add alerts if any
    local alerts_count=$(echo "${monitoring_data}" | jq '.alerts | length')
    if [[ "${alerts_count}" -gt 0 ]]; then
      dashboard_html+=$(
        cat <<EOF
            <div class="card card-warning">
                <h3>Active Alerts (${alerts_count})</h3>
EOF
      )

      # Process each alert
      for i in $(seq 0 $((${alerts_count} - 1))); do
        local alert_type=$(echo "${monitoring_data}" | jq -r ".alerts[${i}].type")
        local alert_severity=$(echo "${monitoring_data}" | jq -r ".alerts[${i}].severity")
        local alert_message=$(echo "${monitoring_data}" | jq -r ".alerts[${i}].message")

        dashboard_html+=$(
          cat <<EOF
                <div class="alert">
                    <strong>[${alert_severity}] ${alert_type}:</strong> ${alert_message}
                </div>
EOF
        )
      done

      dashboard_html+=$(
        cat <<EOF
            </div>
EOF
      )
    fi

    # Add validator table
    dashboard_html+=$(
      cat <<EOF
            <h3>Validator Status</h3>
            <table>
                <tr>
                    <th>Index</th>
                    <th>Status</th>
                    <th>Effectiveness</th>
                    <th>Balance</th>
                    <th>Rating</th>
                </tr>
EOF
    )

    # Process each validator
    for i in $(seq 0 $((${validator_count} - 1))); do
      local index=$(echo "${monitoring_data}" | jq -r ".validators[${i}].validator_index")
      local status=$(echo "${monitoring_data}" | jq -r ".validators[${i}].status")
      local effectiveness=$(echo "${monitoring_data}" | jq -r ".validators[${i}].performance.effectiveness")
      local balance=$(echo "${monitoring_data}" | jq -r ".validators[${i}].performance.balance")
      local rating=$(echo "${monitoring_data}" | jq -r ".validators[${i}].performance.rating")

      # Determine rating class
      local rating_class="status-warning"
      if ((rating >= 90)); then
        rating_class="status-good"
      elif ((rating < 70)); then
        rating_class="status-critical"
      fi

      dashboard_html+=$(
        cat <<EOF
                <tr>
                    <td>${index}</td>
                    <td>${status}</td>
                    <td>${effectiveness}%</td>
                    <td>${balance} gwei</td>
                    <td class="${rating_class}">${rating}%</td>
                </tr>
EOF
      )
    done

    dashboard_html+=$(
      cat <<EOF
            </table>
EOF
    )
  else
    dashboard_html+=$(
      cat <<EOF
            <div class="card card-warning">
                <h3>No Monitoring Data Available</h3>
                <p>Run monitoring to collect validator performance data.</p>
            </div>
EOF
    )
  fi

  dashboard_html+=$(
    cat <<EOF
        </div>
EOF
  )

  # Add Predictive Analytics Section if available
  if [[ "${PREDICTIVE_AVAILABLE}" == "true" ]]; then
    dashboard_html+=$(
      cat <<EOF
        <div class="section">
            <h2>Predictive Analytics</h2>
EOF
    )

    if [[ "${analytics_data}" != "{}" ]]; then
      # Add analytics overview
      dashboard_html+=$(
        cat <<EOF
            <div class="card">
                <h3>Analysis Overview</h3>
                <div class="flex-container">
                    <div class="flex-item">
                        <div class="metric">
                            <span class="metric-name">Analysis Type:</span>
                            <span class="metric-value">$(echo "${analytics_data}" | jq -r '.analysis_type')</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Forecast Days:</span>
                            <span class="metric-value">$(echo "${analytics_data}" | jq -r '.forecast_days')</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Analyzed Validators:</span>
                            <span class="metric-value">$(echo "${analytics_data}" | jq -r '.validators | length')</span>
                        </div>
                    </div>
                </div>
            </div>
EOF
      )

      # Add validator-specific analytics
      local validator_count=$(echo "${analytics_data}" | jq '.validators | length')
      for i in $(seq 0 $((${validator_count} - 1))); do
        local validator_id=$(echo "${analytics_data}" | jq -r ".validators[${i}].validator_id")
        local trend=$(echo "${analytics_data}" | jq -r ".validators[${i}].attestation_trend.trend")
        local forecast_rate=$(echo "${analytics_data}" | jq -r ".validators[${i}].performance_forecast.forecast[-1].attestation_rate")

        # Determine trend class
        local trend_class="status-warning"
        if [[ "${trend}" == "improving" ]]; then
          trend_class="status-good"
        elif [[ "${trend}" == "declining" ]]; then
          trend_class="status-critical"
        fi

        dashboard_html+=$(
          cat <<EOF
            <div class="card">
                <h3>Validator ${validator_id}</h3>
                <div class="flex-container">
                    <div class="flex-item">
                        <div class="metric">
                            <span class="metric-name">Performance Trend:</span>
                            <span class="metric-value ${trend_class}">${trend}</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Forecasted Success Rate:</span>
                            <span class="metric-value">$(printf "%.2f" "${forecast_rate}")%</span>
                        </div>
                    </div>
                </div>

                <h4>Recommendations</h4>
                <div class="recommendations">
EOF
        )

        # Add recommendations
        local recommendations_count=$(echo "${analytics_data}" | jq -r ".validators[${i}].recommendations | length")
        if [[ "${recommendations_count}" -gt 0 ]]; then
          for j in $(seq 0 $((${recommendations_count} - 1))); do
            local rec_type=$(echo "${analytics_data}" | jq -r ".validators[${i}].recommendations[${j}].type")
            local rec_severity=$(echo "${analytics_data}" | jq -r ".validators[${i}].recommendations[${j}].severity")
            local rec_description=$(echo "${analytics_data}" | jq -r ".validators[${i}].recommendations[${j}].description")
            local rec_action=$(echo "${analytics_data}" | jq -r ".validators[${i}].recommendations[${j}].action")

            dashboard_html+=$(
              cat <<EOF
                    <div class="recommendation recommendation-${rec_severity}">
                        <strong>${rec_type}</strong> (${rec_severity})
                        <p>${rec_description}</p>
                        <p><em>Recommended Action:</em> ${rec_action}</p>
                    </div>
EOF
            )
          done
        else
          dashboard_html+=$(
            cat <<EOF
                    <p>No recommendations at this time.</p>
EOF
          )
        fi

        dashboard_html+=$(
          cat <<EOF
                </div>
            </div>
EOF
        )
      done
    else
      dashboard_html+=$(
        cat <<EOF
            <div class="card card-warning">
                <h3>No Analytics Data Available</h3>
                <p>Run predictive analytics to generate performance forecasts and recommendations.</p>
            </div>
EOF
      )
    fi

    dashboard_html+=$(
      cat <<EOF
        </div>
EOF
    )
  fi

  # Add Bond Optimization Section if available
  if [[ "${BOND_AVAILABLE}" == "true" ]]; then
    dashboard_html+=$(
      cat <<EOF
        <div class="section">
            <h2>Bond Optimization</h2>
EOF
    )

    if [[ "${optimization_data}" != "{}" ]]; then
      # Add optimization overview
      dashboard_html+=$(
        cat <<EOF
            <div class="card">
                <h3>Bond Overview</h3>
                <div class="flex-container">
                    <div class="flex-item">
                        <div class="metric">
                            <span class="metric-name">Risk Profile:</span>
                            <span class="metric-value">$(echo "${optimization_data}" | jq -r '.risk_profile')</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Validator Count:</span>
                            <span class="metric-value">$(echo "${optimization_data}" | jq -r '.validator_count')</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Current Bond:</span>
                            <span class="metric-value">$(echo "${optimization_data}" | jq -r '.current_bond') ETH</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Optimal Bond:</span>
                            <span class="metric-value">$(echo "${optimization_data}" | jq -r '.optimal_bond') ETH</span>
                        </div>
                    </div>
                    <div class="flex-item">
                        <div class="metric">
                            <span class="metric-name">Bond Efficiency:</span>
                            <span class="metric-value">$(echo "${optimization_data}" | jq -r '.bond_efficiency')%</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Risk Factor:</span>
                            <span class="metric-value">$(echo "${optimization_data}" | jq -r '.risk_factor')</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Claim Eligible:</span>
                            <span class="metric-value">$(echo "${optimization_data}" | jq -r '.claim_eligible')</span>
                        </div>
                        <div class="metric">
                            <span class="metric-name">Excess Bond:</span>
                            <span class="metric-value">$(echo "${optimization_data}" | jq -r '.excess_bond') ETH</span>
                        </div>
                    </div>
                </div>
            </div>

            <h3>Bond Recommendations</h3>
            <div class="recommendations">
EOF
      )

      # Add recommendations
      local recommendations_count=$(echo "${optimization_data}" | jq -r '.recommendations | length')
      if [[ "${recommendations_count}" -gt 0 ]]; then
        for i in $(seq 0 $((${recommendations_count} - 1))); do
          local rec_type=$(echo "${optimization_data}" | jq -r ".recommendations[${i}].type")
          local rec_severity=$(echo "${optimization_data}" | jq -r ".recommendations[${i}].severity")
          local rec_description=$(echo "${optimization_data}" | jq -r ".recommendations[${i}].description")
          local rec_action=$(echo "${optimization_data}" | jq -r ".recommendations[${i}].action")

          dashboard_html+=$(
            cat <<EOF
                <div class="recommendation recommendation-${rec_severity}">
                    <strong>${rec_type}</strong> (${rec_severity})
                    <p>${rec_description}</p>
                    <p><em>Recommended Action:</em> ${rec_action}</p>
                </div>
EOF
          )
        done
      else
        dashboard_html+=$(
          cat <<EOF
                <p>No recommendations at this time. Bond configuration is optimal.</p>
EOF
        )
      fi

      dashboard_html+=$(
        cat <<EOF
            </div>
EOF
      )
    else
      dashboard_html+=$(
        cat <<EOF
            <div class="card card-warning">
                <h3>No Bond Optimization Data Available</h3>
                <p>Run bond optimization to generate bond recommendations.</p>
            </div>
EOF
      )
    fi

    dashboard_html+=$(
      cat <<EOF
        </div>
EOF
    )
  fi

  # Close HTML
  dashboard_html+=$(
    cat <<EOF
        <div class="footer">
            <p>CSM Analytics Suite | Generated by the Ephemery Node Project</p>
        </div>
    </div>
</body>
</html>
EOF
  )

  # Save dashboard to file
  echo "${dashboard_html}" >"${output_file}"
  log_success "Analytics dashboard generated: ${output_file}"

  # Open the dashboard in a browser if possible
  if command -v xdg-open &>/dev/null; then
    xdg-open "${output_file}"
  elif command -v open &>/dev/null; then
    open "${output_file}"
  else
    log_info "Dashboard saved to: ${output_file}"
  fi
}

# Function to set up automated analytics
setup_automation() {
  log_info "Setting up automated analytics"

  # Parse options
  local monitoring_interval=60
  local analysis_interval=24
  local optimization_interval=24
  local dashboard_interval=4
  local disabled_components=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --monitoring-interval)
        monitoring_interval="$2"
        shift 2
        ;;
      --analysis-interval)
        analysis_interval="$2"
        shift 2
        ;;
      --optimization-interval)
        optimization_interval="$2"
        shift 2
        ;;
      --dashboard-interval)
        dashboard_interval="$2"
        shift 2
        ;;
      --disable)
        disabled_components+=("$2")
        shift 2
        ;;
      *)
        shift
        ;;
    esac
  done

  # Create cron directory if it doesn't exist
  local cron_dir="${BASE_DIR}/cron"
  mkdir -p "${cron_dir}"

  # Create cron file
  local cron_file="${cron_dir}/csm_analytics.cron"

  # Add monitoring job if not disabled
  if [[ ! " ${disabled_components[@]} " =~ " monitoring " ]]; then
    echo "*/${monitoring_interval} * * * * ${SCRIPT_DIR}/csm_analytics_suite.sh monitor --output json --output-file ${METRICS_DIR}/latest_monitoring.json" >>"${cron_file}"
    log_info "Added monitoring job (every ${monitoring_interval} minutes)"
  fi

  # Add analytics job if not disabled and available
  if [[ ! " ${disabled_components[@]} " =~ " analytics " ]] && [[ "${PREDICTIVE_AVAILABLE}" == "true" ]]; then
    echo "0 */${analysis_interval} * * * ${SCRIPT_DIR}/csm_analytics_suite.sh analyze --output json --output-file ${METRICS_DIR}/latest_analytics.json" >>"${cron_file}"
    log_info "Added analytics job (every ${analysis_interval} hours)"
  fi

  # Add optimization job if not disabled and available
  if [[ ! " ${disabled_components[@]} " =~ " optimization " ]] && [[ "${BOND_AVAILABLE}" == "true" ]]; then
    echo "30 */${optimization_interval} * * * ${SCRIPT_DIR}/csm_analytics_suite.sh optimize --output json --output-file ${METRICS_DIR}/latest_optimization.json" >>"${cron_file}"
    log_info "Added optimization job (every ${optimization_interval} hours)"
  fi

  # Add dashboard job if not disabled
  if [[ ! " ${disabled_components[@]} " =~ " dashboard " ]]; then
    echo "45 */${dashboard_interval} * * * ${SCRIPT_DIR}/csm_analytics_suite.sh dashboard --output-file ${METRICS_DIR}/csm_dashboard.html" >>"${cron_file}"
    log_info "Added dashboard job (every ${dashboard_interval} hours)"
  fi

  # Instructions for installing cron jobs
  log_success "Cron configuration created: ${cron_file}"
  log_info "To install cron jobs, run:"
  log_info "  crontab ${cron_file}"

  # Create a convenience script to install cron jobs
  local install_script="${cron_dir}/install_cron.sh"
  cat >"${install_script}" <<EOF
#!/bin/bash
crontab "${cron_file}"
echo "CSM analytics cron jobs installed successfully!"
EOF

  chmod +x "${install_script}"
  log_info "Or run the convenience script:"
  log_info "  ${install_script}"
}

# Main function
main() {
  # Check if a command is provided
  if [[ $# -eq 0 ]]; then
    log_error "No command specified"
    show_help
    exit 1
  fi

  # Parse command
  local command="$1"
  shift

  # Check for help flag
  if [[ "$1" == "--help" ]]; then
    show_help "${command}"
    exit 0
  fi

  # Execute command
  case "${command}" in
    monitor)
      run_monitoring "$@"
      ;;
    analyze)
      run_analytics "$@"
      ;;
    optimize)
      run_optimization "$@"
      ;;
    dashboard)
      generate_dashboard "$@"
      ;;
    automate)
      setup_automation "$@"
      ;;
    help)
      show_help "$1"
      ;;
    *)
      log_error "Unknown command: ${command}"
      show_help
      exit 1
      ;;
  esac
}

# Run main function
main "$@"

exit 0
