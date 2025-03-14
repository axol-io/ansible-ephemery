#!/bin/bash

# run_ansible.sh
# A wrapper script for running Ansible playbooks with better output management
# Usage: ./scripts/run_ansible.sh playbook.yml [options]

set -e

# Default values
LOG_DIR="logs"
VERBOSITY=""
FILTER_OUTPUT=false
LOG_FILE=""
PLAYBOOK=""
EXTRA_ARGS=""
CALLBACK="minimal"
SUMMARY_ONLY=false
QUIET=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -v|--verbose)
      VERBOSITY="-v"
      shift
      ;;
    -vv|--more-verbose)
      VERBOSITY="-vv"
      shift
      ;;
    -vvv|--debug)
      VERBOSITY="-vvv"
      shift
      ;;
    -f|--filter)
      FILTER_OUTPUT=true
      shift
      ;;
    -l|--log)
      mkdir -p "$LOG_DIR"
      LOG_FILE="$LOG_DIR/ansible-$(date +%Y%m%d-%H%M%S).log"
      shift
      ;;
    -c|--callback)
      CALLBACK="$2"
      shift 2
      ;;
    -s|--summary-only)
      SUMMARY_ONLY=true
      shift
      ;;
    -q|--quiet)
      QUIET=true
      shift
      ;;
    -e|--extra-args)
      EXTRA_ARGS="$2"
      shift 2
      ;;
    *)
      PLAYBOOK="$1"
      shift
      ;;
  esac
done

if [ -z "$PLAYBOOK" ]; then
  echo "Error: No playbook specified"
  echo "Usage: $0 playbook.yml [options]"
  echo "Options:"
  echo "  -v, --verbose       Increase verbosity (single level)"
  echo "  -vv, --more-verbose Increase verbosity (two levels)"
  echo "  -vvv, --debug       Maximum verbosity for debugging"
  echo "  -f, --filter        Filter output to show only important information"
  echo "  -l, --log           Log output to file (in logs directory)"
  echo "  -c, --callback      Specify callback plugin (minimal, yaml, json, unixy, dense)"
  echo "  -s, --summary-only  Show only the play recap summary"
  echo "  -q, --quiet         Suppress all output except errors"
  echo "  -e, --extra-args    Pass additional arguments to ansible-playbook"
  exit 1
fi

# Set environment variable for callback if specified
if [ -n "$CALLBACK" ]; then
  export ANSIBLE_STDOUT_CALLBACK="$CALLBACK"
fi

# Construct the command
CMD="ansible-playbook $PLAYBOOK $VERBOSITY $EXTRA_ARGS"

# Execute with appropriate output handling
if [ "$QUIET" = true ]; then
  # Quiet mode - suppress all output except errors
  echo "Running: $CMD (quiet mode)"
  if [ -n "$LOG_FILE" ]; then
    echo "Logging to $LOG_FILE"
    $CMD > "$LOG_FILE" 2>&1 || { echo "Ansible playbook failed"; cat "$LOG_FILE" | grep -E "ERROR|fatal:|failed="; exit 1; }
  else
    $CMD > /dev/null 2>&1 || { echo "Ansible playbook failed"; exit 1; }
  fi
elif [ "$SUMMARY_ONLY" = true ]; then
  # Summary only mode - show only the play recap
  echo "Running: $CMD (summary only)"
  if [ -n "$LOG_FILE" ]; then
    echo "Logging to $LOG_FILE"
    $CMD 2>&1 | tee "$LOG_FILE" | grep -E "PLAY RECAP|failed=|ok=|changed=|unreachable="
  else
    $CMD 2>&1 | grep -E "PLAY RECAP|failed=|ok=|changed=|unreachable="
  fi
elif [ "$FILTER_OUTPUT" = true ] && [ -n "$LOG_FILE" ]; then
  # Filter and log
  echo "Running: $CMD"
  echo "Filtering output and logging to $LOG_FILE"
  $CMD 2>&1 | tee "$LOG_FILE" | ./scripts/filter_ansible_output.sh
elif [ "$FILTER_OUTPUT" = true ]; then
  # Filter only
  echo "Running: $CMD"
  echo "Filtering output"
  $CMD 2>&1 | ./scripts/filter_ansible_output.sh
elif [ -n "$LOG_FILE" ]; then
  # Log only
  echo "Running: $CMD"
  echo "Logging to $LOG_FILE"
  $CMD 2>&1 | tee "$LOG_FILE"
else
  # No filtering or logging
  echo "Running: $CMD"
  $CMD
fi

# Check exit status
EXIT_CODE=${PIPESTATUS[0]}
if [ $EXIT_CODE -ne 0 ]; then
  echo "Ansible playbook failed with exit code $EXIT_CODE"
  if [ -n "$LOG_FILE" ]; then
    echo "See $LOG_FILE for details"
  fi
  exit $EXIT_CODE
fi

echo "Ansible playbook completed successfully"
if [ -n "$LOG_FILE" ]; then
  echo "Full log available at $LOG_FILE"
fi 