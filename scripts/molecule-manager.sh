#!/bin/bash
# molecule-manager.sh - Consolidated script for Molecule management
# Combines functionality from:
# - update-all-molecule-configs.sh
# - update-molecule-configs.sh
# - run-molecule.sh
# - run-molecule-tests-macos.sh
# - test-all-scenarios.sh

set -e

# Constants
LOGS_DIR="molecule_logs"

# Print main usage information
function usage {
  echo "Usage: $0 <command> [options]"
  echo
  echo "Commands:"
  echo "  run             Run Molecule commands for a specific scenario"
  echo "  test-all        Run tests on all available scenarios"
  echo "  update-configs  Update Molecule configuration files for your environment"
  echo "  help            Show this help message"
  echo
  echo "Run '$0 <command> --help' for more information on a command."
}

# Print run command usage
function usage_run {
  echo "Usage: $0 run <molecule-command> [options]"
  echo
  echo "Run Molecule commands for a specific scenario."
  echo
  echo "Options:"
  echo "  -s, --scenario SCENARIO    Specify the scenario to run (default: default)"
  echo "  -d, --debug                Enable debug mode"
  echo "  -h, --help                 Show this help message"
  echo
  echo "Examples:"
  echo "  $0 run test                Run 'molecule test' on the default scenario"
  echo "  $0 run converge -s validator   Run 'molecule converge' on the validator scenario"
}

# Print test-all command usage
function usage_test_all {
  echo "Usage: $0 test-all [options]"
  echo
  echo "Run Molecule tests for all scenarios with proper logging."
  echo
  echo "Options:"
  echo "  -c, --command COMMAND      Molecule command to run (default: test)"
  echo "  -s, --scenario SCENARIO    Only test specific scenario(s)"
  echo "  -v, --verbose              Show output in real-time in addition to logging"
  echo "  -k, --keep-going           Continue testing scenarios even after failures"
  echo "  -h, --help                 Show this help message"
  echo
  echo "Examples:"
  echo "  $0 test-all                Run 'test' command on all scenarios"
  echo "  $0 test-all -c verify      Run 'verify' command on all scenarios"
  echo "  $0 test-all -s default -s validator  Test only these specific scenarios"
}

# Print update-configs command usage
function usage_update_configs {
  echo "Usage: $0 update-configs [options]"
  echo
  echo "Update all Molecule configuration files with the correct Docker settings"
  echo "for your environment (macOS or Linux)."
  echo
  echo "Options:"
  echo "  -d, --dry-run              Show what would be changed without making changes"
  echo "  -f, --force                Don't ask for confirmation before making changes"
  echo "  -s, --socket PATH          Specify Docker socket path manually"
  echo "  -h, --help                 Show this help message"
  echo
  echo "Examples:"
  echo "  $0 update-configs          Auto-detect and update"
  echo "  $0 update-configs --dry-run   Show what would change"
  echo "  $0 update-configs --socket /path/to/docker.sock  Use specific socket path"
}

# Function to run a molecule command
function run_molecule {
  local molecule_command="$1"
  local scenario="default"
  local debug=0

  # Parse specific arguments
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--scenario)
        scenario="$2"
        shift 2
        ;;
      -d|--debug)
        debug=1
        shift
        ;;
      *)
        echo "Unknown option: $1"
        usage_run
        exit 1
        ;;
    esac
  done

  echo "Running molecule $molecule_command on scenario: $scenario"

  # Set Docker context based on OS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    if docker context ls | grep -q "desktop-linux"; then
      docker context use desktop-linux > /dev/null
    fi
  fi

  # Execute molecule command
  if [ $debug -eq 1 ]; then
    MOLECULE_DEBUG=1 molecule "$molecule_command" -s "$scenario"
  else
    molecule "$molecule_command" -s "$scenario"
  fi
}

# Function to run tests on all scenarios
function test_all_scenarios {
  # Create logs directory
  mkdir -p "${LOGS_DIR}"

  # Get list of all scenarios
  mapfile -t SCENARIOS < <(find molecule -mindepth 1 -maxdepth 1 -type d -not -path "molecule/shared" | sort | xargs -n1 basename)

  # Default values
  local command="test"
  local verbose=0
  local continue_on_error=0
  local selected_scenarios=()

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -c|--command)
        command="$2"
        shift 2
        ;;
      -s|--scenario)
        selected_scenarios+=("$2")
        shift 2
        ;;
      -v|--verbose)
        verbose=1
        shift
        ;;
      -k|--keep-going)
        continue_on_error=1
        shift
        ;;
      *)
        echo "Unknown option: $1"
        usage_test_all
        exit 1
        ;;
    esac
  done

  # If specific scenarios were selected, use those instead
  if [ ${#selected_scenarios[@]} -gt 0 ]; then
    SCENARIOS=("${selected_scenarios[@]}")
  fi

  # Print header
  echo "================================================================"
  echo "Running Molecule '${command}' on ${#SCENARIOS[@]} scenarios"
  echo "Output will be logged to ${LOGS_DIR}/scenario-*.log"
  if [ $verbose -eq 1 ]; then
    echo "Verbose mode: Output will also be displayed in real-time"
  fi
  if [ $continue_on_error -eq 1 ]; then
    echo "Keep-going mode: Testing will continue even after failures"
  fi
  echo "================================================================"
  echo ""

  # Initialize counters
  local passed=0
  local failed=0
  local skipped=0
  local failed_scenarios=()

  # Get start time
  local start_time=$(date +%s)

  # Run test for each scenario
  for scenario in "${SCENARIOS[@]}"; do
    echo -n "Testing scenario '${scenario}'... "

    local log_file="${LOGS_DIR}/scenario-${scenario}.log"

    # Check if the scenario directory actually exists
    if [ ! -d "molecule/${scenario}" ]; then
      echo "SKIPPED (directory not found)"
      skipped=$((skipped+1))
      continue
    fi

    # Run the test
    if [ $verbose -eq 1 ]; then
      run_molecule "$command" -s "$scenario" | tee "${log_file}"
      local exit_code=${PIPESTATUS[0]}
    else
      run_molecule "$command" -s "$scenario" > "${log_file}" 2>&1
      local exit_code=$?
    fi

    if [ $exit_code -eq 0 ]; then
      echo "PASSED"
      passed=$((passed+1))
    else
      echo "FAILED (see ${log_file} for details)"
      failed=$((failed+1))
      failed_scenarios+=("${scenario}")

      # Exit if we're not continuing on error
      if [ $continue_on_error -eq 0 ]; then
        echo ""
        echo "Stopping due to failure. Use -k to continue past errors."
        break
      fi
    fi
  done

  # Get end time and calculate duration
  local end_time=$(date +%s)
  local duration=$((end_time - start_time))
  local minutes=$((duration / 60))
  local seconds=$((duration % 60))

  # Print summary
  echo ""
  echo "================================================================"
  echo "TEST SUMMARY"
  echo "================================================================"
  echo "Total scenarios: ${#SCENARIOS[@]}"
  echo "Passed: ${passed}"
  echo "Failed: ${failed}"
  echo "Skipped: ${skipped}"
  echo "Duration: ${minutes}m ${seconds}s"
  echo ""

  if [ $failed -gt 0 ]; then
    echo "Failed scenarios:"
    for scenario in "${failed_scenarios[@]}"; do
      echo "  - ${scenario} (log: ${LOGS_DIR}/scenario-${scenario}.log)"
    done
    return 1
  else
    echo "All tests passed successfully!"
    return 0
  fi
}

# Function to update Molecule configurations
function update_configs {
  local dry_run=false
  local force=false
  local manual_socket=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--dry-run)
        dry_run=true
        shift
        ;;
      -f|--force)
        force=true
        shift
        ;;
      -s|--socket)
        manual_socket="$2"
        shift 2
        ;;
      *)
        echo "Unknown option: $1"
        usage_update_configs
        exit 1
        ;;
    esac
  done

  # Determine the OS and set appropriate Docker socket path
  if [ -n "$manual_socket" ]; then
    DOCKER_SOCKET="$manual_socket"
    echo "Using manually specified Docker socket: $DOCKER_SOCKET"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    echo "Detected macOS environment"

    # Check common macOS Docker socket paths
    POSSIBLE_PATHS=(
      "/Users/$USER/.docker/run/docker.sock"
      "/Users/$USER/Library/Containers/com.docker.docker/Data/docker-cli.sock"
      "/var/run/docker.sock"
    )

    for path in "${POSSIBLE_PATHS[@]}"; do
      if [ -S "$path" ]; then
        DOCKER_SOCKET="$path"
        echo "Found Docker socket at: $DOCKER_SOCKET"
        break
      fi
    done

    CGROUP_MOUNT="rw"
    NEEDS_CGROUPNS="true"
    DOCKER_CONTEXT="desktop-linux"
  else
    # Linux
    echo "Detected Linux environment"
    DOCKER_SOCKET="/var/run/docker.sock"
    CGROUP_MOUNT="ro"
    NEEDS_CGROUPNS="false"
    DOCKER_CONTEXT="default"
  fi

  # Verify the Docker socket exists
  if [ -z "$DOCKER_SOCKET" ] || [ ! -S "$DOCKER_SOCKET" ]; then
    echo "Error: Could not find Docker socket at $DOCKER_SOCKET"
    echo "Please ensure Docker is running and update the script with the correct path."
    echo "You can specify the socket path manually with --socket PATH"
    exit 1
  fi

  # Find all molecule.yml files
  MOLECULE_FILES=$(find molecule -name "molecule.yml" | sort)
  FILE_COUNT=$(echo "$MOLECULE_FILES" | wc -l | tr -d ' ')

  echo "Found $FILE_COUNT Molecule configuration files"
  echo "Docker socket: $DOCKER_SOCKET"
  echo "cgroup mount: $CGROUP_MOUNT"
  echo "cgroupns_mode: $([ "$NEEDS_CGROUPNS" = "true" ] && echo "host" || echo "not needed")"
  echo "Docker context: $DOCKER_CONTEXT"
  echo ""

  if [ "$dry_run" = true ]; then
    echo "DRY RUN: No changes will be made"
    echo ""
  fi

  # Ask for confirmation unless forced
  if [ "$force" != true ] && [ "$dry_run" != true ]; then
    read -p "Update all $FILE_COUNT Molecule configuration files? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "Operation cancelled."
      exit 0
    fi
  fi

  # Process each file
  echo "$MOLECULE_FILES" | while read -r FILE; do
    echo "Processing $FILE..."

    if [ "$dry_run" = true ]; then
      # Just show what would be changed
      echo "  Would update Docker socket path to: $DOCKER_SOCKET"
      echo "  Would set cgroup mount to: $CGROUP_MOUNT"
      if [ "$NEEDS_CGROUPNS" = "true" ]; then
        echo "  Would add cgroupns_mode: host"
      fi
      continue
    fi

    # Create a backup
    cp "$FILE" "${FILE}.bak"

    # Add or update driver options section
    sed -i.tmp '/driver:/,/platforms:/ {
      /options:/,/platforms:/ {
        /platforms:/b
        /options:/!s/platforms:/  options:\n    docker_host: "unix:\/\/'"$DOCKER_SOCKET"'"\nplatforms:/
      }
      /options:/b
      s/driver:/driver:\n  options:\n    docker_host: "unix:\/\/'"$DOCKER_SOCKET"'"/
    }' "$FILE"

    # Update volume mounts
    sed -i.tmp 's|/var/run/docker.sock:/var/run/docker.sock|'"$DOCKER_SOCKET"':/var/run/docker.sock|g' "$FILE"
    sed -i.tmp 's|/Users/.*/\.docker/run/docker\.sock:/var/run/docker.sock|'"$DOCKER_SOCKET"':/var/run/docker.sock|g' "$FILE"
    sed -i.tmp 's|/Users/.*/Library/Containers/com.docker.docker/Data/docker-cli.sock:/var/run/docker.sock|'"$DOCKER_SOCKET"':/var/run/docker.sock|g' "$FILE"

    # Update cgroup mount
    sed -i.tmp 's|/sys/fs/cgroup:/sys/fs/cgroup:ro|/sys/fs/cgroup:/sys/fs/cgroup:'"$CGROUP_MOUNT"'|g' "$FILE"
    sed -i.tmp 's|/sys/fs/cgroup:/sys/fs/cgroup:rw|/sys/fs/cgroup:/sys/fs/cgroup:'"$CGROUP_MOUNT"'|g' "$FILE"

    # Add cgroupns_mode if needed (macOS with Docker Desktop)
    if [ "$NEEDS_CGROUPNS" = "true" ]; then
      if ! grep -q "cgroupns_mode:" "$FILE"; then
        sed -i.tmp '/command:/a\\    cgroupns_mode: host' "$FILE"
      fi
    fi

    # Clean up temporary files
    rm -f "${FILE}.tmp"

    echo "  Updated $FILE"
  done

  echo ""
  echo "All Molecule configurations have been updated."
  echo "To reset the changes, you can restore from the .bak files:"
  echo "  find molecule -name \"*.bak\" -exec bash -c 'cp \"{}\" \"\${0%.bak}\"' {} \\;"
  echo ""
  echo "Remember to use these Docker context settings:"
  echo "----------------------------------------------"
  echo "  docker context use $DOCKER_CONTEXT"
  echo ""
  echo "You can now run Molecule tests with:"
  echo "  $0 run test"
}

# Main command processing
if [ $# -eq 0 ]; then
  usage
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
  run)
    if [ $# -eq 0 ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
      usage_run
      exit 0
    fi

    MOLECULE_COMMAND="$1"
    shift
    run_molecule "$MOLECULE_COMMAND" "$@"
    ;;

  test-all)
    if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
      usage_test_all
      exit 0
    fi

    test_all_scenarios "$@"
    ;;

  update-configs)
    if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
      usage_update_configs
      exit 0
    fi

    update_configs "$@"
    ;;

  help)
    usage
    exit 0
    ;;

  *)
    echo "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
