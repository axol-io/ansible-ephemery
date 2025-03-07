#!/bin/bash

# run-molecule-tests-macos.sh
# Helper script for running molecule tests on macOS with Docker Desktop

set -e

# Check if a scenario name was provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <scenario-name> [molecule-command]"
    echo "Example: $0 geth-lighthouse"
    echo "Example with specific command: $0 geth-lighthouse verify"
    exit 1
fi

SCENARIO=$1
COMMAND=${2:-"test"}  # Default to 'test' if no command specified

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running Molecule ${COMMAND} for scenario '${SCENARIO}' on macOS${NC}"

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}Docker is not running. Please start Docker Desktop and try again.${NC}"
    exit 1
fi

# Determine Docker socket path for the current user on macOS
CURRENT_USER=$(id -un)
DOCKER_SOCKET="/var/run/docker.sock"  # Default

# Check for common macOS Docker Desktop socket locations
if [ -S ~/Library/Containers/com.docker.docker/Data/docker-cli.sock ]; then
    DOCKER_SOCKET="/Users/${CURRENT_USER}/Library/Containers/com.docker.docker/Data/docker-cli.sock"
    echo -e "${GREEN}Found Docker socket at: ${DOCKER_SOCKET}${NC}"
elif [ -S ~/Library/Containers/com.docker.docker/Data/docker.sock ]; then
    DOCKER_SOCKET="/Users/${CURRENT_USER}/Library/Containers/com.docker.docker/Data/docker.sock"
    echo -e "${GREEN}Found Docker socket at: ${DOCKER_SOCKET}${NC}"
elif [ -S ~/.docker/run/docker.sock ]; then
    DOCKER_SOCKET="/Users/${CURRENT_USER}/.docker/run/docker.sock"
    echo -e "${GREEN}Found Docker socket at: ${DOCKER_SOCKET}${NC}"
else
    # Try getting socket path from Docker info
    INFO_SOCKET=$(docker info --format '{{index .Labels "com.docker.desktop.address"}}' 2>/dev/null || echo "")
    if [[ "$INFO_SOCKET" == unix://* ]]; then
        DOCKER_SOCKET="${INFO_SOCKET#unix://}"
        echo -e "${GREEN}Found Docker socket from docker info: ${DOCKER_SOCKET}${NC}"
    fi
fi

# Set Docker environment variables
export DOCKER_HOST="unix://${DOCKER_SOCKET}"
echo -e "${GREEN}Setting DOCKER_HOST=${DOCKER_HOST}${NC}"

# Create a temporary patch file for molecule.yml
create_molecule_patch() {
    local SCENARIO=$1
    local MOLECULE_YML="molecule/${SCENARIO}/molecule.yml"
    
    if [ ! -f "$MOLECULE_YML" ]; then
        echo -e "${RED}Cannot find molecule.yml at ${MOLECULE_YML}${NC}"
        return 1
    fi
    
    # Create a backup if it doesn't already exist
    if [ ! -f "${MOLECULE_YML}.original" ]; then
        cp "$MOLECULE_YML" "${MOLECULE_YML}.original"
    fi
    
    # Update the Docker socket path in molecule.yml
    sed -i '' "s|/var/run/docker.sock|${DOCKER_SOCKET}|g" "$MOLECULE_YML"
    
    # Update driver settings
    if ! grep -q "docker_host:" "$MOLECULE_YML"; then
        # Create a temporary file with the correct driver section
        cat > /tmp/driver_section.yml << EOF
driver:
  name: docker
  docker_host: "${DOCKER_HOST}"
EOF
        # Replace the existing driver section with our new one
        sed -i '' '/^driver:/,/^[a-z]/{//!d}' "$MOLECULE_YML"
        sed -i '' "/^driver:/{r /tmp/driver_section.yml
d}" "$MOLECULE_YML"
        rm /tmp/driver_section.yml
    else
        # Just update the existing docker_host value
        sed -i '' "s|docker_host:.*|docker_host: \"${DOCKER_HOST}\"|g" "$MOLECULE_YML"
    fi
    
    # Update cgroup mount options for macOS
    sed -i '' "s|/sys/fs/cgroup:/sys/fs/cgroup:ro|/sys/fs/cgroup:/sys/fs/cgroup:rw|g" "$MOLECULE_YML"
    
    # Add cgroupns_mode: host if not present
    if ! grep -q "cgroupns_mode:" "$MOLECULE_YML"; then
        sed -i '' "/privileged: true/a\\
\ \ \ \ cgroupns_mode: host" "$MOLECULE_YML"
    fi
    
    echo -e "${GREEN}Updated ${MOLECULE_YML} for macOS compatibility${NC}"
}

# Generate scenario if it doesn't exist
if [ ! -d "molecule/${SCENARIO}" ]; then
    echo -e "${YELLOW}Scenario '${SCENARIO}' does not exist. Generating it...${NC}"
    
    # Check if this is a client combination
    if [[ "$SCENARIO" == *"-"* ]]; then
        EXECUTION_CLIENT=${SCENARIO%-*}
        CONSENSUS_CLIENT=${SCENARIO#*-}
        
        echo -e "${YELLOW}Generating client scenario: ${EXECUTION_CLIENT}-${CONSENSUS_CLIENT}${NC}"
        
        if [ -f "molecule/shared/scripts/generate_scenario.sh" ]; then
            molecule/shared/scripts/generate_scenario.sh --type clients --execution $EXECUTION_CLIENT --consensus $CONSENSUS_CLIENT
            
            if [ $? -ne 0 ]; then
                echo -e "${RED}Failed to generate scenario.${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Could not find generator script at: molecule/shared/scripts/generate_scenario.sh${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Cannot automatically create non-client scenario '${SCENARIO}'${NC}"
        exit 1
    fi
fi

# Patch the molecule.yml for macOS compatibility
create_molecule_patch "$SCENARIO"

# Export environment variables for molecule
export ANSIBLE_FORCE_COLOR=true
export MOLECULE_NO_LOG=false

# Run the molecule command
echo -e "${GREEN}Running: molecule ${COMMAND} -s ${SCENARIO}${NC}"
molecule ${COMMAND} -s ${SCENARIO}
RESULT=$?

# Restore original file if needed
if [ -f "molecule/${SCENARIO}/molecule.yml.original" ]; then
    mv "molecule/${SCENARIO}/molecule.yml.original" "molecule/${SCENARIO}/molecule.yml"
    echo -e "${GREEN}Restored original molecule.yml${NC}"
fi

# Exit with the result of the molecule command
if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}Molecule ${COMMAND} completed successfully for scenario '${SCENARIO}'${NC}"
else
    echo -e "${RED}Molecule ${COMMAND} failed for scenario '${SCENARIO}'${NC}"
fi

exit $RESULT 