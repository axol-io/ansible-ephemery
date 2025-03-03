#!/bin/bash
# Helper script for running Molecule tests with proper Docker configuration

# Show help if requested
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Runs Molecule with proper Docker configuration for your environment."
    echo ""
    echo "Commands:"
    echo "  test      Run a full test sequence (default if no command specified)"
    echo "  verify    Run just the verification step"
    echo "  list      List all scenarios and instances"
    echo "  [any]     Any valid Molecule command"
    echo ""
    echo "Options:"
    echo "  -s, --scenario SCENARIO   Run against a specific scenario"
    echo "  -h, --help                Show this help message"
    echo "  --debug                   Enable debug mode (verbose output)"
    echo ""
    echo "Examples:"
    echo "  $0 test                   Run all tests with default scenario"
    echo "  $0 test -s validator      Test the validator scenario"
    echo "  $0 verify                 Just run the verify step"
    echo "  $0 list                   List all scenarios"
    exit 0
fi

# Enable debug mode with set -x if requested
if [[ "$*" == *"--debug"* ]]; then
    set -x
fi

# Auto-detect the Docker socket path
function find_docker_socket() {
    local socket_paths=(
        "/Users/$USER/.docker/run/docker.sock"
        "/Users/$USER/Library/Containers/com.docker.docker/Data/docker-cli.sock"
        "/var/run/docker.sock"
    )

    for socket in "${socket_paths[@]}"; do
        if [ -S "$socket" ]; then
            echo "$socket"
            return 0
        fi
    done

    echo "ERROR: Could not find Docker socket. Is Docker running?" >&2
    return 1
}

# Switch to the desktop-linux Docker context which we know works on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Setting Docker context to desktop-linux..."
    docker context use desktop-linux >/dev/null
else
    echo "Using default Docker context for Linux..."
fi

# Check if Docker Desktop is running
echo "Checking Docker status..."
if ! docker ps >/dev/null 2>&1; then
    echo "Docker doesn't seem to be running or accessible."
    echo "Please make sure Docker Desktop is running."
    echo "You may need to open Docker Desktop application first."
    exit 1
fi

# Set Docker environment variables - using the auto-detected path
DOCKER_SOCKET=$(find_docker_socket)
if [ $? -ne 0 ]; then
    exit 1
fi

export DOCKER_HOST="unix://${DOCKER_SOCKET}"
echo "Using Docker host: $DOCKER_HOST"

# Reset Molecule state if not just listing or we're forcing it
if [[ "$1" != "list" && "$1" != "matrix" && "$*" != *"--no-reset"* ]]; then
    echo "Resetting Molecule state..."
    molecule reset
fi

# Run the specified Molecule command or default to test
if [ $# -eq 0 ]; then
    echo "Running default Molecule command: molecule test"
    molecule test
else
    echo "Running Molecule command: molecule $*"
    molecule "$@"
fi
