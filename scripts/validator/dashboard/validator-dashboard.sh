#!/bin/bash
# Version: 1.0.0
#
# Validator Dashboard Launcher for Ephemery
# This script launches the enhanced validator dashboard with various options
#
# Usage: ./validator-dashboard.sh [options]
# Options:
#   -b, --beacon URL      Beacon node API URL (default: http://localhost:5052)
#   -v, --validator URL   Validator API URL (default: http://localhost:5064)
#   -r, --refresh N       Refresh interval in seconds (default: 10)
#   -c, --compact         Use compact view (summary only)
#   -d, --detailed        Use detailed view (includes validator details)
#   -f, --full            Use full view with all information (default)
#   -a, --analyze         Generate historical performance analysis report
#   --period PERIOD       Analysis period (1d, 7d, 30d, 90d, all) for historical analysis
#   --charts              Generate performance charts (requires gnuplot)
#   -h, --help            Show this help message

# Set color codes
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Check if monitoring script exists
DASHBOARD_SCRIPT="${SCRIPT_DIR}/monitoring/validator_dashboard.sh"
if [[ ! -f "${DASHBOARD_SCRIPT}" ]]; then
    echo -e "${RED}Error: Validator dashboard script not found at ${DASHBOARD_SCRIPT}${NC}"
    echo "Make sure you are running this script from the repository root."
    exit 1
fi

# Display banner
cat << EOF
${BLUE}=============================================${NC}
${BLUE}   Ephemery Enhanced Validator Dashboard    ${NC}
${BLUE}=============================================${NC}

EOF

# Check for command line arguments
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    # Display help message
    ${DASHBOARD_SCRIPT} --help
    exit 0
fi

if [[ "$1" == "--analyze" || "$1" == "-a" ]]; then
    echo -e "${BLUE}Launching Historical Performance Analysis...${NC}"
    # Pass all arguments to the dashboard script
    ${DASHBOARD_SCRIPT} "$@"
    exit $?
fi

# Check dependencies for the dashboard
function check_dependencies {
    local missing_deps=()
    
    # Check for required commands
    for cmd in jq curl watch; do
        if ! command -v ${cmd} &> /dev/null; then
            missing_deps+=("${cmd}")
        fi
    done
    
    # Check for optional commands
    if [[ "$*" == *"--charts"* ]]; then
        if ! command -v gnuplot &> /dev/null; then
            echo -e "${YELLOW}Warning: gnuplot is not installed. Chart generation will be unavailable.${NC}"
        fi
    fi
    
    # Report missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${RED}Error: Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - ${dep}"
        done
        echo "Please install these dependencies and try again."
        exit 1
    fi
}

# Check if validator client is running
function check_validator_client {
    local validator_url="${1:-http://localhost:5064}"
    
    echo -e "${BLUE}Checking validator client availability...${NC}"
    if curl -s -f "${validator_url}/lighthouse/health" > /dev/null; then
        echo -e "${GREEN}Validator client is running.${NC}"
        return 0
    else
        echo -e "${YELLOW}Warning: Validator client not detected at ${validator_url}${NC}"
        echo "The dashboard will still show limited information from the beacon node."
        return 1
    fi
}

# Check if beacon node is running
function check_beacon_node {
    local beacon_url="${1:-http://localhost:5052}"
    
    echo -e "${BLUE}Checking beacon node availability...${NC}"
    if curl -s -f "${beacon_url}/eth/v1/node/health" > /dev/null; then
        echo -e "${GREEN}Beacon node is running.${NC}"
        return 0
    else
        echo -e "${RED}Error: Beacon node not detected at ${beacon_url}${NC}"
        echo "The dashboard requires a running beacon node."
        return 1
    fi
}

# Check dependencies
check_dependencies "$@"

# Extract beacon and validator URLs from arguments, if provided
BEACON_URL="http://localhost:5052"
VALIDATOR_URL="http://localhost:5064"

for ((i=1; i<=$#; i++)); do
    if [[ "${!i}" == "--beacon" || "${!i}" == "-b" ]]; then
        j=$((i+1))
        BEACON_URL="${!j}"
    elif [[ "${!i}" == "--validator" || "${!i}" == "-v" ]]; then
        j=$((i+1))
        VALIDATOR_URL="${!j}"
    fi
done

# Check if services are running
check_beacon_node "${BEACON_URL}" || { echo "Cannot continue without beacon node."; exit 1; }
check_validator_client "${VALIDATOR_URL}"

# Launch the dashboard
echo -e "${BLUE}Launching Enhanced Validator Dashboard...${NC}"
echo -e "${BLUE}Press Ctrl+C to exit${NC}"
echo

# Pass all arguments to the dashboard script
${DASHBOARD_SCRIPT} "$@" 
