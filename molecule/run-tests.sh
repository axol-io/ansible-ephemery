#!/bin/bash
# Script to run molecule tests for the Ephemery project

set -e

SCENARIO="$1"

# Function to detect Docker socket
detect_docker_socket() {
  if [ -S "/var/run/docker.sock" ]; then
    echo "unix:///var/run/docker.sock"
  elif [ -S "$HOME/.docker/run/docker.sock" ]; then
    echo "unix:///$HOME/.docker/run/docker.sock"
  elif [ -S "$HOME/.orbstack/run/docker.sock" ]; then
    echo "unix:///$HOME/.orbstack/run/docker.sock"
  elif [ -S "$HOME/Library/Containers/com.docker.docker/Data/docker.sock" ]; then
    echo "unix:///$HOME/Library/Containers/com.docker.docker/Data/docker.sock"
  else
    echo "Could not find Docker socket. Please make sure Docker is running."
    exit 1
  fi
}

# Set Docker host if not already set
if [ -z "$DOCKER_HOST" ]; then
  DOCKER_SOCKET=$(detect_docker_socket)
  export DOCKER_HOST="$DOCKER_SOCKET"
  echo "Using Docker host: $DOCKER_HOST"
fi

# Run tests
if [ -z "$SCENARIO" ]; then
  echo "Running all Molecule tests..."

  # Get all scenarios
  # First, get all symlinks at the top level (these point to client directories)
  CLIENT_SYMLINKS=$(find . -maxdepth 1 -type l | sed 's|^./||' | sort)

  # Then get regular directories (excluding shared and clients)
  REGULAR_DIRS=$(find . -maxdepth 1 -type d -not -path "." -not -path "./shared" -not -path "./clients" | sed 's|^./||' | sort)

  # Combine all scenarios
  SCENARIOS="$REGULAR_DIRS $CLIENT_SYMLINKS"

  # Run each scenario
  for s in $SCENARIOS; do
    echo "=================================================================="
    echo "Running test scenario: $s"
    echo "=================================================================="
    if molecule test -s "$s"; then
      echo "✅ Scenario $s passed"
    else
      echo "❌ Scenario $s failed"
      FAILED=1
    fi
    echo ""
  done

  if [ -n "$FAILED" ]; then
    echo "❌ Some tests failed"
    exit 1
  else
    echo "✅ All tests passed"
  fi
else
  echo "Running Molecule test for scenario: $SCENARIO"
  molecule test -s "$SCENARIO"
fi
