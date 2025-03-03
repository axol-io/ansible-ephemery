#!/bin/bash

# Wrapper script for running molecule tests with consistent settings
# Usage: ./run-tests.sh [scenario] [command]

# Parse arguments
SCENARIO="${1:-default}"
COMMAND="${2:-test}"

# Validate inputs
if [ "$SCENARIO" == "help" ] || [ "$SCENARIO" == "--help" ] || [ "$SCENARIO" == "-h" ]; then
  echo "Usage: $0 [scenario] [command]"
  echo "  scenario: The molecule scenario to run (default: default)"
  echo "  command: The molecule command to run (default: test)"
  echo ""
  echo "Examples:"
  echo "  $0                       # Run 'molecule test' on default scenario"
  echo "  $0 geth-lighthouse test  # Run 'molecule test' on geth-lighthouse scenario"
  echo "  $0 validator converge    # Run 'molecule converge' on validator scenario"
  echo "  $0 all test              # Run 'molecule test' on all scenarios"
  exit 0
fi

# Set environment variables for consistency
export ANSIBLE_FORCE_COLOR=true
export MOLECULE_NO_LOG=false
export ANSIBLE_VERBOSITY=1

# Function to run molecule command on a specific scenario
run_molecule() {
  local scenario="$1"
  local cmd="$2"

  echo "==================================================================="
  echo "Running molecule $cmd on scenario: $scenario"
  echo "==================================================================="

  # Execute molecule command
  molecule "$cmd" -s "$scenario"
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    echo "Error: molecule $cmd failed for scenario $scenario"
    return $exit_code
  fi

  echo "Done running $cmd on $scenario"
  return 0
}

# Run on all scenarios if requested
if [ "$SCENARIO" == "all" ]; then
  SCENARIOS=$(find "$(dirname "$0")" -maxdepth 1 -type d -not -path "$(dirname "$0")" -not -path "*/\.*" -not -path "*/shared" | sort | xargs -n1 basename)

  for s in $SCENARIOS; do
    if [ -f "$(dirname "$0")/$s/molecule.yml" ]; then
      run_molecule "$s" "$COMMAND"
      if [ $? -ne 0 ]; then
        exit 1
      fi
    fi
  done
else
  # Run on a single scenario
  run_molecule "$SCENARIO" "$COMMAND"
  exit $?
fi
