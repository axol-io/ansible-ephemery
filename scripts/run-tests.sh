#!/bin/bash
# Version: 1.0.0
# run-tests.sh - Wrapper script to run Molecule tests with any driver from any directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MOLECULE_DIR="${PROJECT_ROOT}/molecule"

# Check that the molecule directory exists
if [ ! -d "${MOLECULE_DIR}" ]; then
  echo "❌ Error: Molecule directory not found at ${MOLECULE_DIR}"
  exit 1
fi

# Print help information
show_help() {
  echo "Ephemery Molecule Test Runner"
  echo ""
  echo "Usage: $(basename "$0") [options] [scenario]"
  echo ""
  echo "Options:"
  echo "  -h, --help                Show this help message"
  echo "  -d, --driver DRIVER       Use specific driver (docker or delegated)"
  echo "  -v, --verbose             Increase verbosity"
  echo "  --docker-sock PATH        Specify custom Docker socket path"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0")                        # Run default scenario with docker driver"
  echo "  $(basename "$0") --driver delegated     # Run with delegated driver (no Docker required)"
  echo "  $(basename "$0") clients/geth-lighthouse # Run specific scenario"
  echo "  $(basename "$0") --docker-sock /path/to/docker.sock # Use custom Docker socket"
  echo ""
  exit 0
}

# Parse arguments
SCENARIO=""
VERBOSE=0
MOLECULE_DRIVER=${MOLECULE_DRIVER:-docker}
DOCKER_HOST_SOCK=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      show_help
      ;;
    -d | --driver)
      MOLECULE_DRIVER="$2"
      shift 2
      ;;
    --docker-sock)
      DOCKER_HOST_SOCK="$2"
      shift 2
      ;;
    -v | --verbose)
      VERBOSE=1
      shift
      ;;
    *)
      SCENARIO="$1"
      shift
      ;;
  esac
done

# Validate driver
if [[ "${MOLECULE_DRIVER}" != "docker" && "${MOLECULE_DRIVER}" != "delegated" ]]; then
  echo "❌ Invalid driver: ${MOLECULE_DRIVER}. Must be 'docker' or 'delegated'."
  exit 1
fi

# Export variables
export MOLECULE_DRIVER
if [ -n "${DOCKER_HOST_SOCK}" ]; then
  export DOCKER_HOST_SOCK
fi

# Set verbosity
if [ ${VERBOSE} -eq 1 ]; then
  export MOLECULE_VERBOSITY=2
fi

echo "🧪 Running Molecule tests with ${MOLECULE_DRIVER} driver"
if [ -n "${SCENARIO}" ]; then
  echo "📁 Scenario: ${SCENARIO}"
else
  echo "📁 Scenario: default"
fi

# Change to molecule directory and run tests
cd "${MOLECULE_DIR}"
if [ -n "${SCENARIO}" ]; then
  ./run-tests.sh "${SCENARIO}"
else
  ./run-tests.sh
fi
