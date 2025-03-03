#!/bin/bash
# Script to update all Molecule scenario configurations with the correct Docker settings

# Determine the OS and set appropriate Docker socket path
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    DOCKER_SOCKET="/Users/$USER/.docker/run/docker.sock"
    if [ ! -S "$DOCKER_SOCKET" ]; then
        # Try alternative macOS socket path
        DOCKER_SOCKET="/Users/$USER/Library/Containers/com.docker.docker/Data/docker-cli.sock"
    fi
    CGROUP_MOUNT="rw"
    NEEDS_CGROUPNS="true"
else
    # Linux
    DOCKER_SOCKET="/var/run/docker.sock"
    CGROUP_MOUNT="ro"
    NEEDS_CGROUPNS="false"
fi

# Verify the Docker socket exists
if [ ! -S "$DOCKER_SOCKET" ]; then
    echo "Error: Could not find Docker socket at $DOCKER_SOCKET"
    echo "Please ensure Docker is running and update the script with the correct path."
    exit 1
fi

echo "Found Docker socket at: $DOCKER_SOCKET"
echo "Updating all Molecule scenario configurations..."

# Find all molecule.yml files and update them
find molecule -name "molecule.yml" | while read -r FILE; do
    echo "Updating $FILE..."

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
    sed -i.tmp 's|/sys/fs/cgroup:/sys/fs/cgroup:ro|/sys/fs/cgroup:/sys/fs/cgroup:'"$CGROUP_MOUNT"'|g' "$FILE"

    # Add cgroupns_mode if needed (macOS with Docker Desktop)
    if [ "$NEEDS_CGROUPNS" = "true" ]; then
        sed -i.tmp '/command:/a\\    cgroupns_mode: host' "$FILE"
    fi

    # Clean up temporary files
    rm -f "${FILE}.tmp"

    echo "Updated $FILE"
done

echo "All Molecule configurations have been updated."
echo "To reset the changes, you can restore from the .bak files."
echo ""
echo "Remember to use these Docker context settings:"
echo "----------------------------------------------"
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "For macOS: docker context use desktop-linux"
else
    echo "For Linux: docker context use default"
fi
echo ""
echo "You can now run Molecule tests with:"
echo "./run-molecule.sh test"
