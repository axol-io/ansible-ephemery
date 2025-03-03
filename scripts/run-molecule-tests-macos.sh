#!/bin/bash
# run-molecule-tests-macos.sh
# Helper script to run Molecule tests on macOS with Docker Desktop

set -e

echo "Setting up environment for Molecule tests on macOS..."

# Check if Docker is running in a more macOS-friendly way
if ! docker ps &> /dev/null; then
    echo "ERROR: Docker is not accessible. Please ensure Docker Desktop is running."
    echo "Start Docker Desktop and try again."
    exit 1
fi

echo "Docker is running!"

# Get the active Docker context
ACTIVE_CONTEXT=$(docker context ls --format '{{if .Current}}{{.Name}}{{end}}')
echo "Active Docker context: $ACTIVE_CONTEXT"

# Get the Docker socket path using the active context
DOCKER_SOCKET_PATH=$(docker context inspect $ACTIVE_CONTEXT --format '{{range $k,$v := .Endpoints}}{{if eq $k "docker"}}{{$v.Host}}{{end}}{{end}}')

# If that fails, try a simpler approach
if [ -z "$DOCKER_SOCKET_PATH" ]; then
    echo "Could not determine socket path from context, trying alternative method..."
    if [ -S "/var/run/docker.sock" ]; then
        DOCKER_SOCKET_PATH="unix:///var/run/docker.sock"
    elif [ -S "$HOME/Library/Containers/com.docker.docker/Data/docker.sock" ]; then
        DOCKER_SOCKET_PATH="unix://$HOME/Library/Containers/com.docker.docker/Data/docker.sock"
    elif [ -S "$HOME/.docker/run/docker.sock" ]; then
        DOCKER_SOCKET_PATH="unix://$HOME/.docker/run/docker.sock"
    else
        echo "ERROR: Could not locate Docker socket. Please specify it manually."
        exit 1
    fi
fi

echo "Using Docker socket path: $DOCKER_SOCKET_PATH"

# Validate the scenario parameter
if [ -z "$1" ]; then
    echo "ERROR: No scenario specified."
    echo "Usage: $0 <scenario>"
    echo "Available scenarios:"
    ls -1 molecule/
    exit 1
fi

# Create temporary molecule config with the correct socket path
TARGET_DIR=molecule/$1
if [ ! -d "$TARGET_DIR" ]; then
    echo "ERROR: Scenario $1 not found."
    echo "Available scenarios:"
    ls -1 molecule/
    exit 1
fi

# Backup the original molecule.yml if it exists
if [ -f "$TARGET_DIR/molecule.yml" ]; then
    cp "$TARGET_DIR/molecule.yml" "$TARGET_DIR/molecule.yml.bak"
    echo "Backed up original molecule.yml"
fi

# Update the molecule.yml using macOS-compatible sed
# Note: macOS sed requires a space after -i
echo "Updating molecule.yml with Docker socket path..."
sed -i '' -e "s|docker_host:.*|docker_host: $DOCKER_SOCKET_PATH|" "$TARGET_DIR/molecule.yml" || {
    echo "ERROR: sed command failed. Trying alternate method..."
    # If the above fails, create a new file and move it
    cat "$TARGET_DIR/molecule.yml" | sed "s|docker_host:.*|docker_host: $DOCKER_SOCKET_PATH|" > "$TARGET_DIR/molecule.yml.new"
    mv "$TARGET_DIR/molecule.yml.new" "$TARGET_DIR/molecule.yml"
}

# Export the Docker host environment variable
export DOCKER_HOST=$DOCKER_SOCKET_PATH

# Run the molecule test
echo "Running molecule test for scenario $1..."
molecule test -s $1

# Restore the original molecule.yml
if [ -f "$TARGET_DIR/molecule.yml.bak" ]; then
    mv "$TARGET_DIR/molecule.yml.bak" "$TARGET_DIR/molecule.yml"
    echo "Restored original molecule.yml"
fi

echo "Done!"
