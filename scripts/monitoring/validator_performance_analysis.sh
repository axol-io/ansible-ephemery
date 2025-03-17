#!/bin/bash
# Version: 1.0.0
#
# Validator Performance Analysis Script for Ephemery
# This script analyzes historical validator performance data and generates trend reports
# It works in conjunction with advanced_validator_monitoring.sh to provide insights into
# long-term validator performance and identify trends.

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
COMMON_SCRIPT="${REPO_ROOT}/scripts/core/common.sh"
if [[ -f "${COMMON_SCRIPT}" ]]; then
  source "${COMMON_SCRIPT}"
fi

# Default values
OUTPUT_DIR="${REPO_ROOT}/validator_metrics"
REPORT_FILE="${OUTPUT_DIR}/validator_report.json"
HISTORY_DIR="${OUTPUT_DIR}/history"
ANALYSIS_DIR="${OUTPUT_DIR}/analysis"
TRENDS_FILE="${ANALYSIS_DIR}/performance_trends.json"
REPORT_PERIOD="7d"
GENERATE_CHARTS=false
GENERATE_PDF=false
INCLUDE_VALIDATORS="all"
ANALYSIS_TYPE="standard"
VERBOSE=false

# Function to display help
function show_help {
  echo -e "${BLUE}Validator Performance Analysis Script for Ephemery${NC}"
  echo ""
  echo "This script analyzes historical validator performance data and generates trend reports."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -o, --output DIR      Output directory for metrics (default: ${OUTPUT_DIR})"
  echo "  -p, --period PERIOD   Analysis period (1d, 7d, 30d, 90d, all) (default: 7d)"
  echo "  -v, --validators LIST Comma-separated list of validator indices or 'all' (default: all)"
  echo "  -t, --type TYPE       Analysis type (standard, detailed, minimal) (default: standard)"
  echo "  -c, --charts          Generate performance charts using gnuplot"
  echo "  -f, --pdf             Generate PDF report (requires wkhtmltopdf)"
  echo "  --verbose             Enable verbose output"
  echo "  -h, --help            Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --period 30d                    # Analyze last 30 days of data"
  echo "  $0 --validators 123,456,789 --charts # Analyze specific validators with charts"
  echo "  $0 --type detailed --pdf           # Generate detailed PDF report"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -o | --output)
      OUTPUT_DIR="$2"
      REPORT_FILE="${OUTPUT_DIR}/validator_report.json"
      HISTORY_DIR="${OUTPUT_DIR}/history"
      ANALYSIS_DIR="${OUTPUT_DIR}/analysis"
      TRENDS_FILE="${ANALYSIS_DIR}/performance_trends.json"
      shift 2
      ;;
    -p | --period)
      REPORT_PERIOD="$2"
      shift 2
      ;;
    -v | --validators)
      INCLUDE_VALIDATORS="$2"
      shift 2
      ;;
    -t | --type)
      ANALYSIS_TYPE="$2"
      shift 2
      ;;
    -c | --charts)
      GENERATE_CHARTS=true
      shift
      ;;
    -f | --pdf)
      GENERATE_PDF=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      show_help
      exit 1
      ;;
  esac
done

# Function to check dependencies
function check_dependencies {
  local missing_deps=()

  # Check for required commands
  for cmd in jq curl; do
    if ! command -v ${cmd} &>/dev/null; then
      missing_deps+=("${cmd}")
    fi
  done

  # Check for optional commands based on options
  if [[ "${GENERATE_CHARTS}" == "true" ]]; then
    if ! command -v gnuplot &>/dev/null; then
      missing_deps+=("gnuplot (required for chart generation)")
    fi
  fi

  if [[ "${GENERATE_PDF}" == "true" ]]; then
    if ! command -v wkhtmltopdf &>/dev/null; then
      missing_deps+=("wkhtmltopdf (required for PDF generation)")
    fi
  fi

  # Report missing dependencies
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo -e "${RED}Error: Missing required dependencies:${NC}"
    for dep in "${missing_deps[@]}"; do
      echo "  - ${dep}"
    done
    echo "Please install these dependencies and try again."
    exit 1
  fi
}

# Function to validate input parameters
function validate_parameters {
  # Validate period
  case "${REPORT_PERIOD}" in
    1d | 7d | 30d | 90d | all)
      # Valid period
      ;;
    *)
      echo -e "${RED}Error: Invalid period '${REPORT_PERIOD}'. Must be 1d, 7d, 30d, 90d, or all.${NC}"
      exit 1
      ;;
  esac

  # Validate analysis type
  case "${ANALYSIS_TYPE}" in
    standard | detailed | minimal)
      # Valid type
      ;;
    *)
      echo -e "${RED}Error: Invalid analysis type '${ANALYSIS_TYPE}'. Must be standard, detailed, or minimal.${NC}"
      exit 1
      ;;
  esac

  # Ensure output directories exist
  if [[ ! -d "${OUTPUT_DIR}" ]]; then
    echo -e "${YELLOW}Warning: Output directory does not exist. Creating ${OUTPUT_DIR}${NC}"
    mkdir -p "${OUTPUT_DIR}"
  fi

  if [[ ! -d "${HISTORY_DIR}" ]]; then
    echo -e "${YELLOW}Warning: History directory does not exist. Creating ${HISTORY_DIR}${NC}"
    mkdir -p "${HISTORY_DIR}"
  fi

  if [[ ! -d "${ANALYSIS_DIR}" ]]; then
    echo -e "${YELLOW}Warning: Analysis directory does not exist. Creating ${ANALYSIS_DIR}${NC}"
    mkdir -p "${ANALYSIS_DIR}"
  fi

  # Check if report file exists
  if [[ ! -f "${REPORT_FILE}" ]]; then
    echo -e "${RED}Error: Validator report file ${REPORT_FILE} does not exist.${NC}"
    echo "Run advanced_validator_monitoring.sh first to generate validator data."
    exit 1
  fi
}

# Function to calculate timeframe for analysis
function calculate_timeframe {
  local period="$1"
  local now=$(date +%s)
  local start_time

  case "${period}" in
    1d)
      # 1 day (24 hours) ago
      start_time=$((now - 86400))
      ;;
    7d)
      # 7 days ago
      start_time=$((now - 604800))
      ;;
    30d)
      # 30 days ago
      start_time=$((now - 2592000))
      ;;
    90d)
      # 90 days ago
      start_time=$((now - 7776000))
      ;;
    all)
      # Use earliest available data
      start_time=0
      ;;
  esac

  echo "${start_time}"
}

# Function to collect historical data
function collect_historical_data {
  local start_timestamp="$1"
  local verbose="$2"
  local history_files=()

  echo -e "${BLUE}Collecting historical data for analysis...${NC}"

  # Find all history files that match our timeframe
  if [[ "${start_timestamp}" -eq 0 ]]; then
    # Use all available history files
    history_files=($(find "${HISTORY_DIR}" -name "validator_metrics_*.json" | sort))
  else
    # Filter history files by timestamp in filename
    for file in $(find "${HISTORY_DIR}" -name "validator_metrics_*.json" | sort); do
      filename=$(basename "${file}")
      # Extract timestamp from filename (format: validator_metrics_TIMESTAMP.json)
      file_timestamp=$(echo "${filename}" | sed -E 's/validator_metrics_([0-9]+)\.json/\1/')

      if [[ "${file_timestamp}" -ge "${start_timestamp}" ]]; then
        history_files+=("${file}")
      fi
    done
  fi

  # Check if we have enough data to analyze
  if [[ ${#history_files[@]} -lt 2 ]]; then
    echo -e "${YELLOW}Warning: Not enough historical data available for the requested period.${NC}"
    echo "Minimum of 2 data points required for trend analysis."
    if [[ ${#history_files[@]} -eq 0 ]]; then
      echo -e "${RED}Error: No historical data found.${NC}"
      exit 1
    fi
  fi

  if [[ "${verbose}" == "true" ]]; then
    echo "Found ${#history_files[@]} historical data files for analysis"
  fi

  echo "${history_files[@]}"
}

# Function to analyze balance trends
function analyze_balance_trends {
  local history_files=("$@")
  local output_file="${ANALYSIS_DIR}/balance_trends.json"
  local validator_data="{}"

  echo -e "${BLUE}Analyzing validator balance trends...${NC}"

  # Initialize validator data
  validator_data=$(jq -r '.validators | keys | reduce .[] as $key ({}; . + { ($key): {"balance_history": [], "trend": "stable", "total_change": 0, "percent_change": 0} })' "${REPORT_FILE}")

  # Process each history file
  for history_file in "${history_files[@]}"; do
    # Extract timestamp from filename
    filename=$(basename "${history_file}")
    timestamp=$(echo "${filename}" | sed -E 's/validator_metrics_([0-9]+)\.json/\1/')

    # Process each validator's balance from this file
    validator_data=$(jq --argjson data "${validator_data}" --arg timestamp "${timestamp}" '
            .validators as $vals |
            reduce ($vals | keys[]) as $key (
                $data;
                if $vals[$key] then
                    .[$key].balance_history += [{
                        "timestamp": ($timestamp | tonumber),
                        "balance": ($vals[$key].balance | tonumber)
                    }]
                else
                    .
                end
            )
        ' "${history_file}")
  done

  # Calculate trends and changes for each validator
  validator_data=$(echo "${validator_data}" | jq '
        reduce keys[] as $key (
            .;
            if .[$key].balance_history | length >= 2 then
                .[$key].total_change = (
                    (.[$key].balance_history[-1].balance) -
                    (.[$key].balance_history[0].balance)
                ) |
                .[$key].percent_change = (
                    ((.[$key].balance_history[-1].balance) -
                    (.[$key].balance_history[0].balance)) /
                    (.[$key].balance_history[0].balance) * 100
                ) |
                if .[$key].percent_change > 1 then
                    .[$key].trend = "increasing"
                elif .[$key].percent_change < -1 then
                    .[$key].trend = "decreasing"
                else
                    .[$key].trend = "stable"
                end
            else
                .[$key].trend = "insufficient_data"
            end
        )
    ')

  # Write the analysis to file
  echo "${validator_data}" >"${output_file}"

  # Return the data
  echo "${validator_data}"
}

# Function to analyze attestation performance
function analyze_attestation_performance {
  local history_files=("$@")
  local output_file="${ANALYSIS_DIR}/attestation_performance.json"
  local att_data="{}"

  echo -e "${BLUE}Analyzing validator attestation performance...${NC}"

  # Initialize attestation data
  att_data=$(jq -r '.validators | keys | reduce .[] as $key ({}; . + { ($key): {"attestation_history": [], "effectiveness": 0, "missed_count": 0, "total_count": 0} })' "${REPORT_FILE}")

  # Process each history file
  for history_file in "${history_files[@]}"; do
    # Extract timestamp from filename
    filename=$(basename "${history_file}")
    timestamp=$(echo "${filename}" | sed -E 's/validator_metrics_([0-9]+)\.json/\1/')

    # Process each validator's attestation data from this file
    if jq -e '.validator_attestations' "${history_file}" >/dev/null 2>&1; then
      att_data=$(jq --argjson data "${att_data}" --arg timestamp "${timestamp}" '
                .validator_attestations as $atts |
                reduce ($atts | keys[]) as $key (
                    $data;
                    if $atts[$key] then
                        .[$key].attestation_history += [{
                            "timestamp": ($timestamp | tonumber),
                            "effectiveness": ($atts[$key].effectiveness | tonumber),
                            "missed": ($atts[$key].missed_count | tonumber),
                            "total": ($atts[$key].total_count | tonumber)
                        }]
                    else
                        .
                    end
                )
            ' "${history_file}")
    fi
  done

  # Calculate overall attestation effectiveness for each validator
  att_data=$(echo "${att_data}" | jq '
        reduce keys[] as $key (
            .;
            if .[$key].attestation_history | length > 0 then
                .[$key].missed_count = (.[$key].attestation_history | map(.missed) | add) |
                .[$key].total_count = (.[$key].attestation_history | map(.total) | add) |
                if .[$key].total_count > 0 then
                    .[$key].effectiveness = (
                        (.[$key].total_count - .[$key].missed_count) /
                        .[$key].total_count * 100
                    )
                else
                    .[$key].effectiveness = 0
                end
            else
                .[$key].effectiveness = 0
            end
        )
    ')

  # Write the analysis to file
  echo "${att_data}" >"${output_file}"

  # Return the data
  echo "${att_data}"
}

# Function to generate performance report
function generate_performance_report {
  local balance_data="$1"
  local attestation_data="$2"
  local output_file="${ANALYSIS_DIR}/performance_report.html"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

  echo -e "${BLUE}Generating performance report...${NC}"

  # Create HTML report
  cat >"${output_file}" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Validator Performance Analysis</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            color: #333;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        h1, h2, h3 {
            color: #2c3e50;
        }
        h1 {
            border-bottom: 2px solid #3498db;
            padding-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px 15px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #3498db;
            color: white;
        }
        tr:nth-child(even) {
            background-color: #f2f2f2;
        }
        .trend-increasing {
            color: green;
        }
        .trend-decreasing {
            color: red;
        }
        .trend-stable {
            color: orange;
        }
        .summary {
            background-color: #ebf5fb;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .footer {
            margin-top: 30px;
            font-size: 12px;
            color: #7f8c8d;
            text-align: center;
        }
        .chart-container {
            margin: 20px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Validator Performance Analysis</h1>
        <p>Report generated on: ${timestamp}</p>
        <p>Analysis period: ${REPORT_PERIOD}</p>

        <div class="summary">
            <h2>Performance Summary</h2>
            <p>This report provides an analysis of validator performance over the selected time period.</p>
        </div>

        <h2>Balance Trends</h2>
        <table>
            <thead>
                <tr>
                    <th>Validator Index</th>
                    <th>Current Balance</th>
                    <th>Total Change</th>
                    <th>Percent Change</th>
                    <th>Trend</th>
                </tr>
            </thead>
            <tbody>
EOF

  # Add validator balance data to the report
  echo "${balance_data}" | jq -r '
        to_entries[] |
        "\(.key)\t\(.value.balance_history[-1].balance // "Unknown")\t\(.value.total_change // 0)\t\(.value.percent_change | tostring | .[0:5])%\t\(.value.trend)"
    ' | while IFS=$'\t' read -r validator_index current_balance total_change percent_change trend; do
    trend_class=""
    if [[ "${trend}" == "increasing" ]]; then
      trend_class="trend-increasing"
    elif [[ "${trend}" == "decreasing" ]]; then
      trend_class="trend-decreasing"
    elif [[ "${trend}" == "stable" ]]; then
      trend_class="trend-stable"
    fi

    echo "<tr>" >>"${output_file}"
    echo "  <td>${validator_index}</td>" >>"${output_file}"
    echo "  <td>${current_balance}</td>" >>"${output_file}"
    echo "  <td>${total_change}</td>" >>"${output_file}"
    echo "  <td>${percent_change}%</td>" >>"${output_file}"
    echo "  <td class=\"${trend_class}\">${trend}</td>" >>"${output_file}"
    echo "</tr>" >>"${output_file}"
  done

  # Add attestation performance data
  cat >>"${output_file}" <<EOF
            </tbody>
        </table>

        <h2>Attestation Performance</h2>
        <table>
            <thead>
                <tr>
                    <th>Validator Index</th>
                    <th>Effectiveness</th>
                    <th>Missed</th>
                    <th>Total</th>
                    <th>Performance Rating</th>
                </tr>
            </thead>
            <tbody>
EOF

  # Add validator attestation data to the report
  echo "${attestation_data}" | jq -r '
        to_entries[] |
        "\(.key)\t\(.value.effectiveness | tostring | .[0:5])%\t\(.value.missed_count // 0)\t\(.value.total_count // 0)"
    ' | while IFS=$'\t' read -r validator_index effectiveness missed total; do
    performance=""
    performance_class=""

    if (($(echo "${effectiveness} > 99" | bc -l))); then
      performance="Excellent"
      performance_class="trend-increasing"
    elif (($(echo "${effectiveness} > 95" | bc -l))); then
      performance="Good"
      performance_class="trend-stable"
    elif (($(echo "${effectiveness} > 90" | bc -l))); then
      performance="Fair"
      performance_class="trend-stable"
    else
      performance="Poor"
      performance_class="trend-decreasing"
    fi

    echo "<tr>" >>"${output_file}"
    echo "  <td>${validator_index}</td>" >>"${output_file}"
    echo "  <td>${effectiveness}%</td>" >>"${output_file}"
    echo "  <td>${missed}</td>" >>"${output_file}"
    echo "  <td>${total}</td>" >>"${output_file}"
    echo "  <td class=\"${performance_class}\">${performance}</td>" >>"${output_file}"
    echo "</tr>" >>"${output_file}"
  done

  # Finish the HTML file
  cat >>"${output_file}" <<EOF
            </tbody>
        </table>

        <div class="footer">
            <p>Generated by Ephemery Validator Performance Analysis Tool</p>
        </div>
    </div>
</body>
</html>
EOF

  echo -e "${GREEN}Performance report generated: ${output_file}${NC}"

  # Generate PDF if requested
  if [[ "${GENERATE_PDF}" == "true" ]]; then
    local pdf_file="${ANALYSIS_DIR}/performance_report.pdf"
    echo -e "${BLUE}Generating PDF report...${NC}"

    if wkhtmltopdf "${output_file}" "${pdf_file}"; then
      echo -e "${GREEN}PDF report generated: ${pdf_file}${NC}"
    else
      echo -e "${RED}Failed to generate PDF report${NC}"
    fi
  fi
}

# Function to generate performance charts using gnuplot
function generate_charts {
  local balance_data="$1"
  local attestation_data="$2"

  if [[ "${GENERATE_CHARTS}" != "true" ]]; then
    return
  fi

  echo -e "${BLUE}Generating performance charts...${NC}"

  # Check if gnuplot is available
  if ! command -v gnuplot &>/dev/null; then
    echo -e "${RED}Error: gnuplot is not installed. Charts cannot be generated.${NC}"
    return 1
  fi

  local charts_dir="${ANALYSIS_DIR}/charts"
  mkdir -p "${charts_dir}"

  # Generate balance trend chart data
  balance_chart_data="${charts_dir}/balance_trends.dat"
  attestation_chart_data="${charts_dir}/attestation_trends.dat"

  # Process validator data to create chart data files
  # This is a simplified version; in production, you would want to be more selective
  # about which validators to include in the charts
  echo -e "${BLUE}Preparing chart data...${NC}"

  # Process validator indices filter
  local validator_filter=""
  if [[ "${INCLUDE_VALIDATORS}" != "all" ]]; then
    # Convert comma-separated list to array
    IFS=',' read -ra VALIDATOR_ARRAY <<<"${INCLUDE_VALIDATORS}"
    # Create jq filter expression
    validator_filter="map(select(.key == \"${VALIDATOR_ARRAY[0]}\""
    for ((i = 1; i < ${#VALIDATOR_ARRAY[@]}; i++)); do
      validator_filter="${validator_filter} or .key == \"${VALIDATOR_ARRAY[${i}]}\""
    done
    validator_filter="${validator_filter})) | "
  fi

  # Extract and format balance data for gnuplot
  echo "${balance_data}" | jq -r "to_entries | ${validator_filter}[].value.balance_history | map(\"\(.timestamp) \(.balance)\") | .[]" >"${balance_chart_data}"

  # Extract and format attestation data for gnuplot
  echo "${attestation_data}" | jq -r "to_entries | ${validator_filter}[].value.attestation_history | map(\"\(.timestamp) \(.effectiveness)\") | .[]" >"${attestation_chart_data}"

  # Create gnuplot script for balance trends
  local balance_plot_script="${charts_dir}/balance_plot.gp"
  cat >"${balance_plot_script}" <<EOF
set terminal pngcairo enhanced font "sans,10" size 800,500
set output "${charts_dir}/balance_trends.png"
set title "Validator Balance Trends"
set xlabel "Time"
set ylabel "Balance (GWEI)"
set xdata time
set timefmt "%s"
set format x "%m/%d"
set grid
set key outside right
plot "${balance_chart_data}" using 1:2 with lines lw 2 title "Validator Balance"
EOF

  # Create gnuplot script for attestation performance
  local attestation_plot_script="${charts_dir}/attestation_plot.gp"
  cat >"${attestation_plot_script}" <<EOF
set terminal pngcairo enhanced font "sans,10" size 800,500
set output "${charts_dir}/attestation_trends.png"
set title "Validator Attestation Effectiveness"
set xlabel "Time"
set ylabel "Effectiveness (%)"
set xdata time
set timefmt "%s"
set format x "%m/%d"
set yrange [0:100]
set grid
set key outside right
plot "${attestation_chart_data}" using 1:2 with lines lw 2 title "Attestation Effectiveness"
EOF

  # Run gnuplot scripts
  echo -e "${BLUE}Generating balance trend chart...${NC}"
  if gnuplot "${balance_plot_script}"; then
    echo -e "${GREEN}Balance trend chart generated: ${charts_dir}/balance_trends.png${NC}"
  else
    echo -e "${RED}Failed to generate balance trend chart${NC}"
  fi

  echo -e "${BLUE}Generating attestation performance chart...${NC}"
  if gnuplot "${attestation_plot_script}"; then
    echo -e "${GREEN}Attestation performance chart generated: ${charts_dir}/attestation_trends.png${NC}"
  else
    echo -e "${RED}Failed to generate attestation performance chart${NC}"
  fi
}

# Main execution function
function main {
  # Display banner
  echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}    Ephemery Validator Performance Analysis Tool${NC}"
  echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"

  # Check dependencies
  check_dependencies

  # Validate parameters
  validate_parameters

  # Calculate analysis timeframe
  start_timestamp=$(calculate_timeframe "${REPORT_PERIOD}")

  # Collect historical data
  history_files=($(collect_historical_data "${start_timestamp}" "${VERBOSE}"))

  if [[ "${VERBOSE}" == "true" ]]; then
    echo "Analyzing data from ${#history_files[@]} files"
    echo "Time period: $(date -r "${start_timestamp}") to $(date)"
  fi

  # Analyze balance trends
  balance_data=$(analyze_balance_trends "${history_files[@]}")

  # Analyze attestation performance
  attestation_data=$(analyze_attestation_performance "${history_files[@]}")

  # Generate combined performance report
  generate_performance_report "${balance_data}" "${attestation_data}"

  # Generate charts if requested
  if [[ "${GENERATE_CHARTS}" == "true" ]]; then
    generate_charts "${balance_data}" "${attestation_data}"
  fi

  echo -e "${GREEN}Validator performance analysis completed successfully${NC}"
  echo -e "${GREEN}View the report at ${ANALYSIS_DIR}/performance_report.html${NC}"
}

# Execute main function
main
