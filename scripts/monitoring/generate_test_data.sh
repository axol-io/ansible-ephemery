#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
#
# Generate Test Data for Validator Monitoring
# This script creates sample historical data for testing the validator predictive analytics system

set -e

# Define color codes for output

# Default values
DATA_DIR="/var/lib/validator/data"
METRICS_DIR="/var/lib/validator/metrics"
NUM_VALIDATORS=3
DAYS_OF_HISTORY=30
SEED=${RANDOM}

# Help function
function show_help() {
  echo -e "${BLUE}Generate Test Data for Validator Monitoring${NC}"
  echo ""
  echo "This script creates sample historical data for testing the validator predictive analytics system."
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --data-dir DIR       Data directory (default: ${DATA_DIR})"
  echo "  --metrics-dir DIR    Metrics directory (default: ${METRICS_DIR})"
  echo "  --validators N       Number of validators to generate data for (default: ${NUM_VALIDATORS})"
  echo "  --days N             Days of historical data to generate (default: ${DAYS_OF_HISTORY})"
  echo "  --seed N             Random seed for reproducible data (default: random)"
  echo "  --help               Show this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --data-dir)
      DATA_DIR="$2"
      shift 2
      ;;
    --metrics-dir)
      METRICS_DIR="$2"
      shift 2
      ;;
    --validators)
      NUM_VALIDATORS="$2"
      shift 2
      ;;
    --days)
      DAYS_OF_HISTORY="$2"
      shift 2
      ;;
    --seed)
      SEED="$2"
      shift 2
      ;;
    --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Ensure directories exist
mkdir -p "${DATA_DIR}"
mkdir -p "${METRICS_DIR}"

echo -e "${BLUE}Generating test data with seed: ${SEED}${NC}"
RANDOM=${SEED}

# Function to generate a random number within a range
random_range() {
  local min=$1
  local max=$2
  echo $((RANDOM % (max - min + 1) + min))
}

# Function to generate a random float within a range with decimal places
random_float() {
  local min=$1
  local max=$2
  local decimals=$3
  local scale=$((10 ** decimals))
  local range=$(((max - min) * scale))
  echo "scale=${decimals}; (${RANDOM} % ${range}) / ${scale} + ${min}" | bc
}

# Generate historical data for each validator
for ((v = 1; v <= NUM_VALIDATORS; v++)); do
  VALIDATOR_ID="validator_${v}"
  echo -e "${GREEN}Generating historical data for ${VALIDATOR_ID}${NC}"

  # Initialize base metrics
  # We'll generate trends with some random variation
  BASE_BALANCE=32000000000 # 32 ETH
  BASE_ATTESTATION_SUCCESS_RATE=0.98
  BASE_INCLUSION_DISTANCE=1

  # Add some randomness to base values
  if [[ ${v} -eq 1 ]]; then
    # First validator - improving trend
    BALANCE_TREND=0.0001
    ATTESTATION_TREND=0.0005
    INCLUSION_TREND=-0.02
  elif [[ ${v} -eq 2 ]]; then
    # Second validator - stable
    BALANCE_TREND=0
    ATTESTATION_TREND=0
    INCLUSION_TREND=0
  else
    # Other validators - random or declining trends
    BALANCE_TREND=$(random_float -0.0002 0.0002 6)
    ATTESTATION_TREND=$(random_float -0.001 0.001 6)
    INCLUSION_TREND=$(random_float -0.05 0.05 6)
  fi

  # Create history file
  HISTORY_FILE="${DATA_DIR}/history_${VALIDATOR_ID}.json"
  echo -e "${BLUE}Writing to ${HISTORY_FILE}${NC}"

  # Create JSON array for historical data
  echo "{\"data\": [" >"${HISTORY_FILE}"

  # Generate data points
  for ((day = DAYS_OF_HISTORY; day >= 1; day--)); do
    # Calculate timestamp
    TIMESTAMP=$(date -v-${day}d +%s 2>/dev/null || date -d "${day} days ago" +%s)

    # Calculate metrics with trend and random noise
    DAY_NOISE=$(random_float -0.5 0.5 6)
    BALANCE=$(echo "scale=0; ${BASE_BALANCE} * (1 + ${BALANCE_TREND} * (${DAYS_OF_HISTORY} - ${day}) + ${DAY_NOISE} / 1000)" | bc)

    ATTESTATION_NOISE=$(random_float -0.02 0.02 6)
    ATTESTATION_RATE=$(echo "scale=6; ${BASE_ATTESTATION_SUCCESS_RATE} + ${ATTESTATION_TREND} * (${DAYS_OF_HISTORY} - ${day}) + ${ATTESTATION_NOISE}" | bc)
    ATTESTATION_RATE=$(echo "if (${ATTESTATION_RATE} > 1) 1 else if (${ATTESTATION_RATE} < 0) 0 else ${ATTESTATION_RATE}" | bc)

    # Calculate attestations based on rate
    TOTAL_ATTESTATIONS=225 # Average attestations per day
    SUCCESSFUL_ATTESTATIONS=$(echo "scale=0; ${TOTAL_ATTESTATIONS} * ${ATTESTATION_RATE}" | bc)
    MISSED_ATTESTATIONS=$(echo "scale=0; ${TOTAL_ATTESTATIONS} - ${SUCCESSFUL_ATTESTATIONS}" | bc)

    INCLUSION_NOISE=$(random_float -0.3 0.3 6)
    INCLUSION_DISTANCE=$(echo "scale=2; ${BASE_INCLUSION_DISTANCE} + ${INCLUSION_TREND} * (${DAYS_OF_HISTORY} - ${day}) + ${INCLUSION_NOISE}" | bc)
    INCLUSION_DISTANCE=$(echo "if (${INCLUSION_DISTANCE} < 1) 1 else ${INCLUSION_DISTANCE}" | bc)

    # Generate data point
    DATA_POINT=$(
      cat <<EOF
{
  "timestamp": ${TIMESTAMP},
  "date": "$(date -r "${TIMESTAMP}" "+%Y-%m-%d" 2>/dev/null || date -d @"${TIMESTAMP}" "+%Y-%m-%d")",
  "balance": ${BALANCE},
  "successful_attestations": ${SUCCESSFUL_ATTESTATIONS},
  "missed_attestations": ${MISSED_ATTESTATIONS},
  "inclusion_distance": ${INCLUSION_DISTANCE},
  "sync_committee_participation": $(random_range 90 100)
}
EOF
    )

    # Add comma if not the last element
    if [[ ${day} -ne 1 ]]; then
      DATA_POINT="${DATA_POINT},"
    fi

    # Add to history file
    echo "${DATA_POINT}" >>"${HISTORY_FILE}"
  done

  # Close JSON array
  echo "]}" >>"${HISTORY_FILE}"

  # Also create current metrics file
  METRICS_FILE="${METRICS_DIR}/${VALIDATOR_ID}.json"
  echo -e "${BLUE}Writing current metrics to ${METRICS_FILE}${NC}"

  # Calculate current metrics
  CURRENT_TIMESTAMP=$(date +%s)
  CURRENT_BALANCE=$(echo "scale=0; ${BASE_BALANCE} * (1 + ${BALANCE_TREND} * ${DAYS_OF_HISTORY})" | bc)
  CURRENT_ATTESTATION_RATE=$(echo "scale=6; ${BASE_ATTESTATION_SUCCESS_RATE} + ${ATTESTATION_TREND} * ${DAYS_OF_HISTORY}" | bc)
  CURRENT_ATTESTATION_RATE=$(echo "if (${CURRENT_ATTESTATION_RATE} > 1) 1 else if (${CURRENT_ATTESTATION_RATE} < 0) 0 else ${CURRENT_ATTESTATION_RATE}" | bc)
  CURRENT_INCLUSION_DISTANCE=$(echo "scale=2; ${BASE_INCLUSION_DISTANCE} + ${INCLUSION_TREND} * ${DAYS_OF_HISTORY}" | bc)
  CURRENT_INCLUSION_DISTANCE=$(echo "if (${CURRENT_INCLUSION_DISTANCE} < 1) 1 else ${CURRENT_INCLUSION_DISTANCE}" | bc)

  # Calculate current attestations
  TOTAL_ATTESTATIONS=225
  SUCCESSFUL_ATTESTATIONS=$(echo "scale=0; ${TOTAL_ATTESTATIONS} * ${CURRENT_ATTESTATION_RATE}" | bc)
  MISSED_ATTESTATIONS=$(echo "scale=0; ${TOTAL_ATTESTATIONS} - ${SUCCESSFUL_ATTESTATIONS}" | bc)

  # Create current metrics JSON
  cat >"${METRICS_FILE}" <<EOF
{
  "timestamp": ${CURRENT_TIMESTAMP},
  "date": "$(date -r "${CURRENT_TIMESTAMP}" "+%Y-%m-%d" 2>/dev/null || date -d @"${CURRENT_TIMESTAMP}" "+%Y-%m-%d")",
  "balance": ${CURRENT_BALANCE},
  "successful_attestations": ${SUCCESSFUL_ATTESTATIONS},
  "missed_attestations": ${MISSED_ATTESTATIONS},
  "inclusion_distance": ${CURRENT_INCLUSION_DISTANCE},
  "sync_committee_participation": $(random_range 90 100)
}
EOF
done

echo -e "${GREEN}Test data generation complete!${NC}"
echo "Generated data for ${NUM_VALIDATORS} validators covering ${DAYS_OF_HISTORY} days"
echo ""
echo "Historical data stored in: ${DATA_DIR}"
echo "Current metrics stored in: ${METRICS_DIR}"
echo ""
echo "To run predictive analytics on this data:"
echo "  ./validator_predictive_analytics.sh --data-dir ${DATA_DIR} --metrics-dir ${METRICS_DIR}"
