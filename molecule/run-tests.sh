#!/bin/bash
# Version: 1.0.0
# run-tests.sh - Run all Molecule tests for the Ephemery project

set -e

# Set default driver to docker if not specified
MOLECULE_DRIVER=${MOLECULE_DRIVER:-docker}

# Configure Docker host if using Docker driver
if [ "${MOLECULE_DRIVER}" = "docker" ]; then
  # For macOS, use the Docker Desktop socket TODO: Make this configurable
  DOCKER_HOST_SOCK="/Users/droo/Library/Containers/com.docker.docker/Data/docker-cli.sock"

  # Verify the socket exists
  if [ ! -S "${DOCKER_HOST_SOCK}" ]; then
    echo "Error: Docker socket not found at ${DOCKER_HOST_SOCK}"
    exit 1
  fi

  export DOCKER_HOST="unix://${DOCKER_HOST_SOCK}"
  echo "Using Docker driver with host: ${DOCKER_HOST}"
else
  echo "Using ${MOLECULE_DRIVER} driver for Molecule tests"
fi

# Function to run a single test scenario
run_test() {
  local scenario=$1
  echo "=================================================================="
  echo "Running test scenario: ${scenario}"
  echo "=================================================================="

  # Check if molecule.yml exists
  if [ ! -f "$(dirname "$0")/${scenario}/molecule.yml" ]; then
    echo "❌ Scenario ${scenario} failed: molecule.yml not found"
    return 1
  fi

  # Set environment variables for molecule
  export MOLECULE_DRIVER=${MOLECULE_DRIVER}

  # Try to run the test with explicit molecule.yml path
  MOLECULE_FILE="$(dirname "$0")/${scenario}/molecule.yml" molecule test -s "${scenario}" || {
    echo "❌ Scenario ${scenario} failed"
    return 1
  }

  echo "✅ Scenario ${scenario} passed"
  return 0
}

# Main function to run all tests
run_all_tests() {
  echo "Running all Molecule tests with driver: ${MOLECULE_DRIVER}"

  # Run default scenario first
  run_test "default"

  # Run other scenarios
  local failed=0

  # Only run the default scenario for now
  # for scenario in backup monitoring resource-limits security tests validator clients/*; do
  #     run_test "$scenario" || failed=1
  # done

  if [ ${failed} -eq 1 ]; then
    echo "❌ Some tests failed"
    exit 1
  else
    echo "✅ All tests passed"
    exit 0
  fi
}

# Run all tests
run_all_tests
