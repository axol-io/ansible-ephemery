#!/bin/bash
# Script to update all Molecule scenario configurations with the correct Docker settings
# This is a more comprehensive version of update-molecule-configs.sh

set -e

# Print usage information
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Updates all Molecule configuration files with the correct Docker settings"
  echo "for your environment (macOS or Linux)."
  echo ""
  echo "Options:"
  echo "  -h, --help        Show this help message"
  echo "  -d, --dry-run     Show what would be changed without making changes"
  echo "  -f, --force       Don't ask for confirmation before making changes"
  echo "  -s, --socket PATH Specify Docker socket path manually"
  echo ""
  echo "Examples:"
  echo "  $0                           # Auto-detect and update"
  echo "  $0 --dry-run                 # Show what would change"
  echo "  $0 --socket /path/to/docker.sock  # Use specific socket path"
}

# Parse command line arguments
DRY_RUN=false
FORCE=false
MANUAL_SOCKET=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      usage
      exit 0
      ;;
    -d|--dry-run)
      DRY_RUN=true
      shift
      ;;
    -f|--force)
      FORCE=true
      shift
      ;;
    -s|--socket)
      MANUAL_SOCKET="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Determine the OS and set appropriate Docker socket path
if [ -n "$MANUAL_SOCKET" ]; then
    DOCKER_SOCKET="$MANUAL_SOCKET"
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

if [ "$DRY_RUN" = true ]; then
    echo "DRY RUN: No changes will be made"
    echo ""
fi

# Ask for confirmation unless forced
if [ "$FORCE" != true ] && [ "$DRY_RUN" != true ]; then
    read -p "Update all $FILE_COUNT Molecule configuration files? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Process each file
echo "$MOLECULE_FILES" | while read -r FILE; do
    echo "Processing $FILE..."

    if [ "$DRY_RUN" = true ]; then
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
echo "  ./run-molecule.sh test"
