#!/usr/bin/env bash
# Version: 1.0.0
# Script to demonstrate a single Molecule scenario, then clean it up

set -eo pipefail

# Function to print usage
function print_usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -e, --execution CLIENT   Execution client (required)"
  echo "  -c, --consensus CLIENT   Consensus client (required)"
  echo "  -k, --keep              Keep the scenario after running (don't clean up)"
  echo "  -h, --help              Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --execution geth --consensus prysm"
  echo "  $0 -e nethermind -c lodestar -k"
}

# Default values
EL_CLIENT=""
CL_CLIENT=""
KEEP_SCENARIO=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -e | --execution)
      EL_CLIENT="$2"
      shift 2
      ;;
    -c | --consensus)
      CL_CLIENT="$2"
      shift 2
      ;;
    -k | --keep)
      KEEP_SCENARIO=true
      shift
      ;;
    -h | --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

# Validate inputs
if [[ -z "${EL_CLIENT}" || -z "${CL_CLIENT}" ]]; then
  echo "Error: Execution and consensus clients are both required"
  print_usage
  exit 1
fi

# Set up path variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/../../../" && pwd)"
GENERATE_SCRIPT="${SCRIPT_DIR}/generate_scenario.sh"

# Check if generate_scenario.sh exists
if [[ ! -f "${GENERATE_SCRIPT}" ]]; then
  echo "Error: Could not find generate_scenario.sh script at ${GENERATE_SCRIPT}"
  exit 1
fi

# Generate the scenario name
SCENARIO_NAME="${EL_CLIENT}-${CL_CLIENT}"

echo "==> Creating test scenario: ${SCENARIO_NAME}"
"${GENERATE_SCRIPT}" --type clients --execution "${EL_CLIENT}" --consensus "${CL_CLIENT}"

# Run the scenario
echo ""
echo "==> Running Molecule test for scenario: ${SCENARIO_NAME}"
cd "${PROJECT_DIR}" && molecule test -s "${SCENARIO_NAME}" || TEST_FAILED=true

# Clean up the scenario unless --keep was specified
if [[ "${KEEP_SCENARIO}" != true ]]; then
  echo ""
  echo "==> Cleaning up scenario: ${SCENARIO_NAME}"
  "${GENERATE_SCRIPT}" --cleanup "${SCENARIO_NAME}"
else
  echo ""
  echo "==> Keeping scenario as requested: ${SCENARIO_NAME}"
  echo "   You can manually clean it up later with:"
  echo "   ${GENERATE_SCRIPT} --cleanup ${SCENARIO_NAME}"
fi

# Exit with proper status
if [[ "${TEST_FAILED}" == true ]]; then
  echo "Test failed, but cleanup completed successfully."
  exit 1
fi

echo "Demo completed successfully!"
exit 0
