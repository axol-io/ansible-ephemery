#!/usr/bin/env bash
# Script to generate Molecule scenario files

set -eo pipefail

# Function to print usage
function print_usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -t, --type TYPE          Scenario type (clients, custom)"
  echo "  -n, --name NAME          Scenario name"
  echo "  -e, --execution CLIENT   Execution client (for clients type)"
  echo "  -c, --consensus CLIENT   Consensus client (for clients type)"
  echo "  -v, --var KEY=VALUE      Additional variables (can be used multiple times)"
  echo "  --temp                   Create a temporary scenario that can be automatically cleaned up"
  echo "  --cleanup NAME           Clean up a previously created scenario"
  echo "  -h, --help               Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --type clients --execution nethermind --consensus lodestar"
  echo "  $0 --type clients --execution geth --consensus prysm --temp"
  echo "  $0 --cleanup geth-prysm"
  echo "  $0 --type custom --name high-memory --var memory=8192M --var cpu=2.0"
}

# Function to cleanup a scenario
function cleanup_scenario() {
  local scenario_name="$1"
  local scenario_dir="$PROJECT_DIR/molecule/${scenario_name}"

  if [[ ! -d "$scenario_dir" ]]; then
    echo "Error: Scenario directory not found: $scenario_dir"
    exit 1
  fi

  echo "Cleaning up scenario: $scenario_name"

  # First run molecule destroy to clean up any resources
  cd "$PROJECT_DIR" && molecule destroy -s "$scenario_name" || true

  # Then remove the scenario directory
  rm -rf "$scenario_dir"

  echo "Scenario $scenario_name has been removed."
}

# Default values
TYPE=""
NAME=""
EL_CLIENT=""
CL_CLIENT=""
ADDITIONAL_VARS=()
TEMP_SCENARIO=false
CLEANUP_MODE=false
CLEANUP_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -t|--type)
      TYPE="$2"
      shift 2
      ;;
    -n|--name)
      NAME="$2"
      shift 2
      ;;
    -e|--execution)
      EL_CLIENT="$2"
      shift 2
      ;;
    -c|--consensus)
      CL_CLIENT="$2"
      shift 2
      ;;
    -v|--var)
      ADDITIONAL_VARS+=("$2")
      shift 2
      ;;
    --temp)
      TEMP_SCENARIO=true
      shift
      ;;
    --cleanup)
      CLEANUP_MODE=true
      CLEANUP_NAME="$2"
      shift 2
      ;;
    -h|--help)
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

# Set up path variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get the root directory of the project (one level up from molecule)
PROJECT_DIR="$(cd "$SCRIPT_DIR/../../../" && pwd)"

# If in cleanup mode, just do cleanup and exit
if [[ "$CLEANUP_MODE" == true ]]; then
  if [[ -z "$CLEANUP_NAME" ]]; then
    echo "Error: Scenario name is required for cleanup"
    print_usage
    exit 1
  fi

  cleanup_scenario "$CLEANUP_NAME"
  exit 0
fi

# Validate inputs
if [[ -z "$TYPE" ]]; then
  echo "Error: Scenario type is required"
  print_usage
  exit 1
fi

# Handle client scenarios
if [[ "$TYPE" == "clients" ]]; then
  if [[ -z "$EL_CLIENT" || -z "$CL_CLIENT" ]]; then
    echo "Error: Execution and consensus clients are required for client scenarios"
    print_usage
    exit 1
  fi

  NAME="${EL_CLIENT}-${CL_CLIENT}"
  # Create the scenario directory directly under molecule/
  SCENARIO_DIR="$PROJECT_DIR/molecule/${NAME}"

  # Build variable string for j2
  J2_VARS="-D el_client=$EL_CLIENT -D cl_client=$CL_CLIENT"

  # Add any additional variables
  for var in "${ADDITIONAL_VARS[@]}"; do
    key="${var%%=*}"
    value="${var#*=}"
    J2_VARS="$J2_VARS -D $key=\"$value\""
  done

# Handle custom scenarios
elif [[ "$TYPE" == "custom" ]]; then
  if [[ -z "$NAME" ]]; then
    echo "Error: Scenario name is required for custom scenarios"
    print_usage
    exit 1
  fi

  # Create the scenario directory directly under molecule/
  SCENARIO_DIR="$PROJECT_DIR/molecule/${NAME}"

  # Build variable string for j2
  J2_VARS="-D scenario_name=$NAME"

  # Add any additional variables
  for var in "${ADDITIONAL_VARS[@]}"; do
    key="${var%%=*}"
    value="${var#*=}"
    J2_VARS="$J2_VARS -D $key=\"$value\""
  done
else
  echo "Error: Unknown scenario type: $TYPE"
  print_usage
  exit 1
fi

# Create scenario directory
mkdir -p "$SCENARIO_DIR"

# Replace the Python-based template rendering with a simpler approach
if [[ "$TYPE" == "clients" ]]; then
  # Create molecule.yml file directly
  cat > "$SCENARIO_DIR/molecule.yml" << EOF
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: ephemery-${EL_CLIENT}-${CL_CLIENT}
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    pre_build_image: true
    privileged: true
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
      - /var/run/docker.sock:/var/run/docker.sock:rw
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        el: ${EL_CLIENT}
        cl: ${CL_CLIENT}
verifier:
  name: ansible
EOF
  echo "Successfully generated: $SCENARIO_DIR/molecule.yml"
fi

# Create or link converge.yml and verify.yml if they don't exist
if [[ "$TYPE" == "clients" ]]; then
  # For client scenarios, we can link to the shared playbooks in the parent directory
  if [[ ! -f "$SCENARIO_DIR/converge.yml" ]]; then
    cat > "$SCENARIO_DIR/converge.yml" << EOF
---
- name: Converge
  hosts: all
  tasks:
    - name: Include ephemery role
      include_role:
        name: ansible-ephemery
      vars:
        execution_client: ${EL_CLIENT}
        consensus_client: ${CL_CLIENT}
EOF
  fi

  if [[ ! -f "$SCENARIO_DIR/verify.yml" ]]; then
    cat > "$SCENARIO_DIR/verify.yml" << EOF
---
- name: Verify
  hosts: all
  tasks:
    - name: Check if execution client is running
      command: systemctl status ephemery-${EL_CLIENT}
      register: el_status
      changed_when: false
      failed_when: el_status.rc != 0

    - name: Check if consensus client is running
      command: systemctl status ephemery-${CL_CLIENT}
      register: cl_status
      changed_when: false
      failed_when: cl_status.rc != 0
EOF
  fi
else
  # For custom scenarios, create empty playbooks if they don't exist
  if [[ ! -f "$SCENARIO_DIR/converge.yml" ]]; then
    echo "---" > "$SCENARIO_DIR/converge.yml"
    echo "- name: Converge" >> "$SCENARIO_DIR/converge.yml"
    echo "  hosts: all" >> "$SCENARIO_DIR/converge.yml"
    echo "  tasks:" >> "$SCENARIO_DIR/converge.yml"
    echo "    - name: Include role" >> "$SCENARIO_DIR/converge.yml"
    echo "      include_role:" >> "$SCENARIO_DIR/converge.yml"
    echo "        name: ansible-ephemery" >> "$SCENARIO_DIR/converge.yml"
  fi

  if [[ ! -f "$SCENARIO_DIR/verify.yml" ]]; then
    echo "---" > "$SCENARIO_DIR/verify.yml"
    echo "- name: Verify" >> "$SCENARIO_DIR/verify.yml"
    echo "  hosts: all" >> "$SCENARIO_DIR/verify.yml"
    echo "  tasks:" >> "$SCENARIO_DIR/verify.yml"
    echo "    - name: Example verification task" >> "$SCENARIO_DIR/verify.yml"
    echo "      command: echo 'Success'" >> "$SCENARIO_DIR/verify.yml"
  fi
fi

echo "Scenario $NAME has been generated in $SCENARIO_DIR"

if [[ "$TEMP_SCENARIO" == true ]]; then
  echo "This is a temporary scenario. You can clean it up later with:"
  echo "  $0 --cleanup $NAME"
fi

echo "You can run it with: cd $PROJECT_DIR && molecule test -s $NAME"
