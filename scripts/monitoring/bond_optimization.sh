#!/bin/bash
# Version: 1.0.0
#
# Bond Optimization Algorithm for Lido CSM
# This script analyzes validator performance and bond requirements to recommend
# optimal bond amounts for CSM validators.
#
# Usage: ./bond_optimization.sh [options]
# Options:
#   --base-dir DIR         Base directory (default: /opt/ephemery)
#   --config-file FILE     Configuration file path
#   --risk-profile PROFILE Risk profile: conservative, balanced, aggressive (default: balanced)
#   --output FORMAT        Output format: json, csv, terminal (default: terminal)
#   --output-file FILE     Output file path (defaults to stdout if not specified)
#   --verbose              Enable verbose output
#   --help                 Show this help message

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
CONFIG_FILE="${SCRIPT_DIR}/config/bond_optimization.json"
CSM_CONFIG_FILE="${BASE_DIR}/config/lido-csm/config.yaml"
DATA_DIR="${BASE_DIR}/data/lido-csm/bond-optimization"
RISK_PROFILE="balanced"
OUTPUT_FORMAT="terminal"
OUTPUT_FILE=""
VERBOSE=false
BEACON_API_ENDPOINT="http://localhost:5052"
EXECUTION_API_ENDPOINT="http://localhost:8545"
CSM_API_ENDPOINT="http://localhost:9000"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir)
      BASE_DIR="$2"
      shift 2
      ;;
    --config-file)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --csm-config)
      CSM_CONFIG_FILE="$2"
      shift 2
      ;;
    --risk-profile)
      RISK_PROFILE="$2"
      shift 2
      ;;
    --output)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    --output-file)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    --beacon-api)
      BEACON_API_ENDPOINT="$2"
      shift 2
      ;;
    --execution-api)
      EXECUTION_API_ENDPOINT="$2"
      shift 2
      ;;
    --csm-api)
      CSM_API_ENDPOINT="$2"
      shift 2
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      echo "Bond Optimization Algorithm for Lido CSM"
      echo ""
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  --base-dir DIR         Base directory (default: ${BASE_DIR})"
      echo "  --config-file FILE     Configuration file path (default: ${CONFIG_FILE})"
      echo "  --csm-config FILE      CSM configuration file (default: ${CSM_CONFIG_FILE})"
      echo "  --risk-profile PROFILE Risk profile: conservative, balanced, aggressive (default: ${RISK_PROFILE})"
      echo "  --output FORMAT        Output format: json, csv, terminal (default: ${OUTPUT_FORMAT})"
      echo "  --output-file FILE     Output file path (defaults to stdout if not specified)"
      echo "  --beacon-api URL       Beacon API endpoint (default: ${BEACON_API_ENDPOINT})"
      echo "  --execution-api URL    Execution API endpoint (default: ${EXECUTION_API_ENDPOINT})"
      echo "  --csm-api URL          CSM API endpoint (default: ${CSM_API_ENDPOINT})"
      echo "  --verbose              Enable verbose output"
      echo "  --help                 Show this help message"
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Ensure data directory exists
mkdir -p "${DATA_DIR}" 2>/dev/null || {
  log_error "Failed to create data directory: ${DATA_DIR}"
  exit 1
}

# Load configuration
if [[ -f "${CONFIG_FILE}" ]]; then
  log_info "Loading configuration from ${CONFIG_FILE}"

  # Parse config file
  if [[ "${CONFIG_FILE}" == *.json ]]; then
    if ! command -v jq &>/dev/null; then
      log_error "jq is required for parsing JSON config files"
      exit 1
    fi

    # Extract configuration values
    if [[ -n "$(jq -r '.base_directory // empty' "${CONFIG_FILE}")" ]]; then
      BASE_DIR=$(jq -r '.base_directory' "${CONFIG_FILE}")
    fi
    if [[ -n "$(jq -r '.risk_profile // empty' "${CONFIG_FILE}")" ]]; then
      RISK_PROFILE=$(jq -r '.risk_profile' "${CONFIG_FILE}")
    fi
    if [[ -n "$(jq -r '.beacon_api // empty' "${CONFIG_FILE}")" ]]; then
      BEACON_API_ENDPOINT=$(jq -r '.beacon_api' "${CONFIG_FILE}")
    fi
    if [[ -n "$(jq -r '.execution_api // empty' "${CONFIG_FILE}")" ]]; then
      EXECUTION_API_ENDPOINT=$(jq -r '.execution_api' "${CONFIG_FILE}")
    fi
    if [[ -n "$(jq -r '.csm_api // empty' "${CONFIG_FILE}")" ]]; then
      CSM_API_ENDPOINT=$(jq -r '.csm_api' "${CONFIG_FILE}")
    fi
  else
    log_error "Unsupported config file format: ${CONFIG_FILE}"
    exit 1
  fi
else
  log_warning "Configuration file not found: ${CONFIG_FILE}"
  log_info "Using default configuration"
fi

# Load CSM configuration
if [[ -f "${CSM_CONFIG_FILE}" ]]; then
  log_info "Loading CSM configuration from ${CSM_CONFIG_FILE}"

  # Extract current bond configuration
  if [[ "${CSM_CONFIG_FILE}" == *.yaml || "${CSM_CONFIG_FILE}" == *.yml ]]; then
    # Use grep and awk for simple YAML parsing
    CURRENT_BOND_AMOUNT=$(grep -A 10 "bond:" "${CSM_CONFIG_FILE}" | grep "initial_amount:" | awk '{print $2}')
    MINIMUM_BOND_RATIO=$(grep -A 10 "bond:" "${CSM_CONFIG_FILE}" | grep "minimum_ratio:" | awk '{print $2}')
    CLAIM_THRESHOLD=$(grep -A 10 "bond:" "${CSM_CONFIG_FILE}" | grep "claim_threshold:" | awk '{print $2}')
    AUTO_OPTIMIZATION=$(grep -A 10 "bond:" "${CSM_CONFIG_FILE}" | grep "automatic_optimization:" | awk '{print $2}')
  else
    log_error "Unsupported CSM config file format: ${CSM_CONFIG_FILE}"
    exit 1
  fi
else
  log_warning "CSM configuration file not found: ${CSM_CONFIG_FILE}"
  # Set default values
  CURRENT_BOND_AMOUNT=2.0
  MINIMUM_BOND_RATIO=0.1
  CLAIM_THRESHOLD=0.5
  AUTO_OPTIMIZATION=false
fi

log_debug "Current bond amount: ${CURRENT_BOND_AMOUNT} ETH"
log_debug "Minimum bond ratio: ${MINIMUM_BOND_RATIO}"
log_debug "Claim threshold: ${CLAIM_THRESHOLD}"
log_debug "Auto optimization: ${AUTO_OPTIMIZATION}"

# Function to fetch validator information from beacon API
fetch_validator_info() {
  local validator_indices="$1"
  local url="${BEACON_API_ENDPOINT}/eth/v1/beacon/states/head/validators"

  log_debug "Fetching validator info from: ${url}"

  local response
  response=$(curl -s "${url}?id=${validator_indices}")

  if [[ $? -ne 0 ]]; then
    log_error "Failed to fetch validator info"
    return 1
  fi

  echo "${response}"
}

# Function to fetch CSM metrics
fetch_csm_metrics() {
  local url="${CSM_API_ENDPOINT}/metrics"

  log_debug "Fetching CSM metrics from: ${url}"

  local response
  response=$(curl -s "${url}")

  if [[ $? -ne 0 ]]; then
    log_error "Failed to fetch CSM metrics"
    return 1
  fi

  echo "${response}"
}

# Function to extract metrics from Prometheus format
extract_metric() {
  local metrics="$1"
  local metric_name="$2"

  echo "${metrics}" | grep "^${metric_name} " | awk '{print $2}'
}

# Function to fetch historical validator performance
fetch_historical_performance() {
  local validator_id="$1"
  local history_file="${DATA_DIR}/history_${validator_id}.json"

  if [[ ! -f "${history_file}" ]]; then
    log_warning "No historical data found for validator ${validator_id}"
    echo "[]"
    return 0
  fi

  cat "${history_file}"
}

# Function to calculate risk factor based on validator performance
calculate_risk_factor() {
  local validator_data="$1"
  local risk_profile="$2"

  # Extract performance metrics
  local effectiveness=$(echo "${validator_data}" | jq -r '.effectiveness // 99')
  local missed_attestations=$(echo "${validator_data}" | jq -r '.missed_attestations // 0')
  local missed_proposals=$(echo "${validator_data}" | jq -r '.missed_proposals // 0')
  local slashed=$(echo "${validator_data}" | jq -r '.slashed // false')

  # Convert slashed to numeric
  local slashed_value=0
  if [[ "${slashed}" == "true" ]]; then
    slashed_value=1
  fi

  # Calculate base risk factor
  local base_risk=$(echo "scale=4; (100 - ${effectiveness}) / 100 + (${missed_attestations} * 0.01) + (${missed_proposals} * 0.1) + (${slashed_value} * 0.5)" | bc)

  # Apply risk profile multiplier
  local risk_multiplier=1.0
  case "${risk_profile}" in
    conservative)
      risk_multiplier=1.5
      ;;
    balanced)
      risk_multiplier=1.0
      ;;
    aggressive)
      risk_multiplier=0.7
      ;;
    *)
      log_warning "Unknown risk profile: ${risk_profile}, using balanced"
      risk_multiplier=1.0
      ;;
  esac

  local final_risk=$(echo "scale=4; ${base_risk} * ${risk_multiplier}" | bc)

  # Ensure risk factor is between 0 and 1
  if (($(echo "${final_risk} > 1" | bc -l))); then
    final_risk=1
  elif (($(echo "${final_risk} < 0" | bc -l))); then
    final_risk=0
  fi

  echo "${final_risk}"
}

# Function to calculate optimal bond amount
calculate_optimal_bond() {
  local validator_count="$1"
  local risk_factor="$2"
  local current_bond="$3"
  local min_ratio="$4"

  # Base bond calculation (32 ETH per validator * minimum ratio)
  local base_bond=$(echo "scale=4; ${validator_count} * 32 * ${min_ratio}" | bc)

  # Risk-adjusted bond
  local risk_adjustment=$(echo "scale=4; ${base_bond} * (1 + ${risk_factor})" | bc)

  # Round to 2 decimal places
  local optimal_bond=$(echo "scale=2; ${risk_adjustment}" | bc)

  # Ensure optimal bond is not less than minimum required
  if (($(echo "${optimal_bond} < ${base_bond}" | bc -l))); then
    optimal_bond=${base_bond}
  fi

  echo "${optimal_bond}"
}

# Function to calculate bond efficiency
calculate_bond_efficiency() {
  local current_bond="$1"
  local optimal_bond="$2"

  if (($(echo "${current_bond} <= 0 || ${optimal_bond} <= 0" | bc -l))); then
    echo "0"
    return
  fi

  # If current bond is less than optimal, efficiency is reduced
  if (($(echo "${current_bond} < ${optimal_bond}" | bc -l))); then
    local efficiency=$(echo "scale=2; 100 * ${current_bond} / ${optimal_bond}" | bc)
    echo "${efficiency}"
    return
  fi

  # If current bond is more than optimal, calculate excess efficiency loss
  local excess_ratio=$(echo "scale=4; ${current_bond} / ${optimal_bond}" | bc)

  # Efficiency decreases as excess increases (diminishing returns)
  if (($(echo "${excess_ratio} > 2" | bc -l))); then
    local efficiency=$(echo "scale=2; 100 * (1 - (${excess_ratio} - 2) * 0.1)" | bc)
    # Ensure efficiency doesn't go below 50%
    if (($(echo "${efficiency} < 50" | bc -l))); then
      efficiency=50
    fi
    echo "${efficiency}"
  else
    # If excess is less than 2x, efficiency is still 100%
    echo "100"
  fi
}

# Function to determine if bond claim is eligible
determine_claim_eligibility() {
  local current_bond="$1"
  local optimal_bond="$2"
  local claim_threshold="$3"

  # Calculate excess bond
  local excess_bond=$(echo "scale=4; ${current_bond} - ${optimal_bond}" | bc)

  # Check if excess is greater than threshold
  if (($(echo "${excess_bond} > ${claim_threshold}" | bc -l))); then
    echo "true"
  else
    echo "false"
  fi
}

# Function to generate bond optimization recommendations
generate_bond_recommendations() {
  local current_bond="$1"
  local optimal_bond="$2"
  local bond_efficiency="$3"
  local claim_eligible="$4"

  local recommendations="[]"

  # Check if bond needs adjustment
  if (($(echo "${current_bond} < ${optimal_bond}" | bc -l))); then
    local bond_deficit=$(echo "scale=2; ${optimal_bond} - ${current_bond}" | bc)
    recommendations=$(echo "${recommendations}" | jq -r ". + [{
            \"type\": \"increase_bond\",
            \"severity\": \"medium\",
            \"description\": \"Bond amount is below optimal level by ${bond_deficit} ETH\",
            \"action\": \"Consider increasing bond to ${optimal_bond} ETH to improve security and capacity\"
        }]")
  elif [[ "${claim_eligible}" == "true" ]]; then
    local excess_bond=$(echo "scale=2; ${current_bond} - ${optimal_bond}" | bc)
    recommendations=$(echo "${recommendations}" | jq -r ". + [{
            \"type\": \"claim_excess\",
            \"severity\": \"low\",
            \"description\": \"Bond amount exceeds optimal level by ${excess_bond} ETH\",
            \"action\": \"Consider claiming excess bond to improve capital efficiency\"
        }]")
  fi

  # Check bond efficiency
  if (($(echo "${bond_efficiency} < 80" | bc -l))); then
    recommendations=$(echo "${recommendations}" | jq -r ". + [{
            \"type\": \"efficiency_warning\",
            \"severity\": \"medium\",
            \"description\": \"Bond efficiency is suboptimal at ${bond_efficiency}%\",
            \"action\": \"Adjust bond amount to improve capital efficiency\"
        }]")
  fi

  echo "${recommendations}"
}

# Main function to run bond optimization
run_bond_optimization() {
  log_info "Starting bond optimization analysis"
  log_info "Risk profile: ${RISK_PROFILE}"

  # Fetch CSM metrics
  local csm_metrics
  csm_metrics=$(fetch_csm_metrics)
  if [[ $? -ne 0 ]]; then
    log_error "Failed to fetch CSM metrics, using default values"
    csm_metrics=""
  fi

  # Extract validator count from metrics or use default
  local validator_count
  if [[ -n "${csm_metrics}" ]]; then
    validator_count=$(extract_metric "${csm_metrics}" "csm_validators_total")
    if [[ -z "${validator_count}" ]]; then
      validator_count=10
      log_warning "Could not determine validator count from metrics, using default: ${validator_count}"
    fi
  else
    validator_count=10
    log_warning "Using default validator count: ${validator_count}"
  fi

  log_debug "Validator count: ${validator_count}"

  # Fetch validator indices
  local validator_indices=""
  if [[ -n "${csm_metrics}" ]]; then
    # This would extract validator indices from metrics in a real implementation
    # For now, simulate with a range
    for i in $(seq 0 $((validator_count - 1))); do
      if [[ -n "${validator_indices}" ]]; then
        validator_indices="${validator_indices},${i}"
      else
        validator_indices="${i}"
      fi
    done
  else
    # Generate dummy indices
    for i in $(seq 0 $((validator_count - 1))); do
      if [[ -n "${validator_indices}" ]]; then
        validator_indices="${validator_indices},${i}"
      else
        validator_indices="${i}"
      fi
    done
  fi

  log_debug "Validator indices: ${validator_indices}"

  # Fetch validator information
  local validator_info
  validator_info=$(fetch_validator_info "${validator_indices}")
  if [[ $? -ne 0 ]]; then
    log_error "Failed to fetch validator information"
    # Continue with limited information
  fi

  # Calculate aggregate performance metrics
  local aggregate_effectiveness=99
  local aggregate_missed_attestations=0
  local aggregate_missed_proposals=0
  local aggregate_slashed=false

  if [[ -n "${validator_info}" ]]; then
    # Extract performance metrics from validator info
    # This is a simplified approach; real implementation would parse the actual response
    aggregate_effectiveness=$(echo "${validator_info}" | jq -r '.data | map(.status) | map(select(. == "active_ongoing")) | length / length * 100')
    aggregate_missed_attestations=$(echo "${validator_info}" | jq -r '.data | map(.validator.slashed) | map(select(. == true)) | length')
    aggregate_slashed=$(echo "${validator_info}" | jq -r '.data | map(.validator.slashed) | any')
  fi

  # Create aggregate validator data
  local validator_data=$(echo "{
        \"effectiveness\": ${aggregate_effectiveness},
        \"missed_attestations\": ${aggregate_missed_attestations},
        \"missed_proposals\": ${aggregate_missed_proposals},
        \"slashed\": ${aggregate_slashed}
    }")

  # Calculate risk factor
  local risk_factor
  risk_factor=$(calculate_risk_factor "${validator_data}" "${RISK_PROFILE}")
  log_debug "Risk factor: ${risk_factor}"

  # Calculate optimal bond
  local optimal_bond
  optimal_bond=$(calculate_optimal_bond "${validator_count}" "${risk_factor}" "${CURRENT_BOND_AMOUNT}" "${MINIMUM_BOND_RATIO}")
  log_debug "Optimal bond: ${optimal_bond} ETH"

  # Calculate bond efficiency
  local bond_efficiency
  bond_efficiency=$(calculate_bond_efficiency "${CURRENT_BOND_AMOUNT}" "${optimal_bond}")
  log_debug "Bond efficiency: ${bond_efficiency}%"

  # Determine claim eligibility
  local claim_eligible
  claim_eligible=$(determine_claim_eligibility "${CURRENT_BOND_AMOUNT}" "${optimal_bond}" "${CLAIM_THRESHOLD}")
  log_debug "Claim eligible: ${claim_eligible}"

  # Calculate excess bond
  local excess_bond=0
  if [[ "${claim_eligible}" == "true" ]]; then
    excess_bond=$(echo "scale=2; ${CURRENT_BOND_AMOUNT} - ${optimal_bond}" | bc)
  fi

  # Generate recommendations
  local recommendations
  recommendations=$(generate_bond_recommendations "${CURRENT_BOND_AMOUNT}" "${optimal_bond}" "${bond_efficiency}" "${claim_eligible}")

  # Build result object
  local result=$(echo "{
        \"timestamp\": $(date +%s),
        \"risk_profile\": \"${RISK_PROFILE}\",
        \"validator_count\": ${validator_count},
        \"current_bond\": ${CURRENT_BOND_AMOUNT},
        \"optimal_bond\": ${optimal_bond},
        \"bond_efficiency\": ${bond_efficiency},
        \"risk_factor\": ${risk_factor},
        \"claim_eligible\": ${claim_eligible},
        \"excess_bond\": ${excess_bond},
        \"recommendations\": ${recommendations}
    }")

  # Format and output results
  format_results "${result}"
}

# Function to format results based on output format
format_results() {
  local result="$1"

  case "${OUTPUT_FORMAT}" in
    json)
      if [[ -n "${OUTPUT_FILE}" ]]; then
        echo "${result}" | jq '.' >"${OUTPUT_FILE}"
        log_success "Results saved to ${OUTPUT_FILE}"
      else
        echo "${result}" | jq '.'
      fi
      ;;
    csv)
      # Convert JSON to CSV format
      local csv_header="timestamp,risk_profile,validator_count,current_bond,optimal_bond,bond_efficiency,risk_factor,claim_eligible,excess_bond"
      local csv_data=$(echo "${result}" | jq -r '[
                .timestamp,
                .risk_profile,
                .validator_count,
                .current_bond,
                .optimal_bond,
                .bond_efficiency,
                .risk_factor,
                .claim_eligible,
                .excess_bond
            ] | join(",")')

      if [[ -n "${OUTPUT_FILE}" ]]; then
        echo "${csv_header}" >"${OUTPUT_FILE}"
        echo "${csv_data}" >>"${OUTPUT_FILE}"
        log_success "Results saved to ${OUTPUT_FILE}"
      else
        echo "${csv_header}"
        echo "${csv_data}"
      fi
      ;;
    terminal)
      # Format for terminal output
      display_terminal_results "${result}"
      ;;
    *)
      log_error "Unsupported output format: ${OUTPUT_FORMAT}"
      exit 1
      ;;
  esac
}

# Function to display terminal-formatted results
display_terminal_results() {
  local result="$1"

  local timestamp=$(echo "${result}" | jq -r '.timestamp')
  local risk_profile=$(echo "${result}" | jq -r '.risk_profile')
  local validator_count=$(echo "${result}" | jq -r '.validator_count')
  local current_bond=$(echo "${result}" | jq -r '.current_bond')
  local optimal_bond=$(echo "${result}" | jq -r '.optimal_bond')
  local bond_efficiency=$(echo "${result}" | jq -r '.bond_efficiency')
  local risk_factor=$(echo "${result}" | jq -r '.risk_factor')
  local claim_eligible=$(echo "${result}" | jq -r '.claim_eligible')
  local excess_bond=$(echo "${result}" | jq -r '.excess_bond')

  echo -e "${BLUE}=========================================${NC}"
  echo -e "${GREEN}Bond Optimization Analysis Report${NC}"
  echo -e "${BLUE}=========================================${NC}"
  echo -e "Analysis time: $(date -d @"${timestamp}")"
  echo -e "Risk profile: ${CYAN}${risk_profile}${NC}"
  echo ""

  echo -e "${BLUE}Current Configuration:${NC}"
  echo -e "Validator count: ${CYAN}${validator_count}${NC}"
  echo -e "Current bond amount: ${GREEN}${current_bond} ETH${NC}"
  echo -e "Minimum bond ratio: ${CYAN}${MINIMUM_BOND_RATIO}${NC}"
  echo ""

  echo -e "${BLUE}Optimization Results:${NC}"
  echo -e "Risk factor: ${YELLOW}${risk_factor}${NC}"
  echo -e "Optimal bond amount: ${GREEN}${optimal_bond} ETH${NC}"
  echo -e "Bond efficiency: ${CYAN}${bond_efficiency}%${NC}"

  # Determine bond status color
  local bond_status_color="${GREEN}"
  local bond_status="Optimal"
  if (($(echo "${current_bond} < ${optimal_bond}" | bc -l))); then
    bond_status_color="${YELLOW}"
    bond_status="Below optimal"
  elif (($(echo "${current_bond} > ${optimal_bond} * 1.5" | bc -l))); then
    bond_status_color="${RED}"
    bond_status="Significantly above optimal"
  elif (($(echo "${current_bond} > ${optimal_bond}" | bc -l))); then
    bond_status_color="${CYAN}"
    bond_status="Above optimal"
  fi

  echo -e "Bond status: ${bond_status_color}${bond_status}${NC}"

  if [[ "${claim_eligible}" == "true" ]]; then
    echo -e "Excess bond: ${GREEN}${excess_bond} ETH${NC} (eligible for claim)"
  else
    echo -e "Excess bond: ${YELLOW}0 ETH${NC} (not eligible for claim)"
  fi

  echo ""
  echo -e "${BLUE}Recommendations:${NC}"

  local rec_count=$(echo "${result}" | jq -r '.recommendations | length')
  if [[ "${rec_count}" -gt 0 ]]; then
    echo "${result}" | jq -r '.recommendations[]' | while read -r rec; do
      local rec_type=$(echo "${rec}" | jq -r '.type')
      local rec_severity=$(echo "${rec}" | jq -r '.severity')
      local rec_description=$(echo "${rec}" | jq -r '.description')
      local rec_action=$(echo "${rec}" | jq -r '.action')

      # Determine severity color
      local severity_color="${BLUE}"
      if [[ "${rec_severity}" == "high" ]]; then
        severity_color="${RED}"
      elif [[ "${rec_severity}" == "medium" ]]; then
        severity_color="${YELLOW}"
      elif [[ "${rec_severity}" == "low" ]]; then
        severity_color="${CYAN}"
      fi

      echo -e "  - [${severity_color}${rec_severity}${NC}] ${rec_description}"
      echo -e "    ${GREEN}Action:${NC} ${rec_action}"
      echo ""
    done
  else
    echo -e "  ${GREEN}No recommendations at this time. Bond configuration is optimal.${NC}"
  fi

  # Save results to file if output directory is specified
  local timestamp_str=$(date -d @"${timestamp}" +"%Y%m%d_%H%M%S")
  local output_file="${DATA_DIR}/bond_optimization_${timestamp_str}.json"
  echo "${result}" >"${output_file}"
  echo -e "${GREEN}Report saved to:${NC} ${output_file}"
}

# Run the bond optimization
run_bond_optimization

exit 0
