#!/usr/bin/env bash
# Version: 1.0.0
# Wrapper script for generating client scenarios

set -eo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if we have 2 arguments
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <execution_client> <consensus_client> [additional_vars...]"
  echo "Example: $0 nethermind lodestar memory=4096M"
  exit 1
fi

EL_CLIENT="$1"
CL_CLIENT="$2"
shift 2

# Construct variable arguments
VAR_ARGS=""
for var in "$@"; do
  VAR_ARGS="${VAR_ARGS} --var ${var}"
done

# Call the main script
"${SCRIPT_DIR}/generate_scenario.sh" --type clients --execution "${EL_CLIENT}" --consensus "${CL_CLIENT}" "${VAR_ARGS}"
# Compare this snippet from molecule/shared/scripts/generate_scenario.sh:
