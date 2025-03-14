#!/bin/bash
#
# Validator Performance Monitoring Demo Script
# This script demonstrates the Advanced Validator Performance Monitoring system
# and can simulate different kinds of alerts for testing and demonstration purposes.
#
# Usage: ./demo_validator_monitoring.sh [options]
# Options:
#   --simulate-attestation-issue    Simulate low attestation effectiveness
#   --simulate-proposal-issue       Simulate missed proposal
#   --simulate-balance-decrease     Simulate balance decrease
#   --simulate-sync-issue           Simulate sync issues
#   --simulate-resource-issue       Simulate high resource usage
#   --simulate-peer-issue           Simulate low peer count
#   --check-alerts                  Check current alerts
#   --acknowledge-all               Acknowledge all alerts
#   --dashboard                     Start Grafana dashboard
#   --cleanup                       Remove simulated test data
#   --help                          Show this help message

set -e

# Define color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Default values
BASE_DIR="/opt/ephemery"
VALIDATOR_METRICS_DIR="${BASE_DIR}/validator_metrics"
METRICS_DIR="${VALIDATOR_METRICS_DIR}/metrics"
ALERTS_DIR="${VALIDATOR_METRICS_DIR}/alerts"
ALERTS_CONFIG="${ALERTS_DIR}/alerts_config.json"
ALERTS_SCRIPT="${BASE_DIR}/scripts/validator_alerts_system.sh"
ENABLE_DASHBOARD=false
CHECK_ALERTS=false
ACKNOWLEDGE_ALL=false
CLEANUP=false
SIMULATORS=()

# Script version
VERSION="1.0.0"

# Show banner
function show_banner() {
    echo -e "${BLUE}=============================================================${NC}"
    echo -e "${BLUE}    Validator Performance Monitoring Demo Script v${VERSION}  ${NC}"
    echo -e "${BLUE}=============================================================${NC}"
    echo -e "This script demonstrates the Advanced Validator Performance"
    echo -e "Monitoring system and can simulate different kinds of alerts."
    echo -e "${BLUE}=============================================================${NC}"
    echo ""
}

# Show usage information
function show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --simulate-attestation-issue    Simulate low attestation effectiveness"
    echo "  --simulate-proposal-issue       Simulate missed proposal"
    echo "  --simulate-balance-decrease     Simulate balance decrease"
    echo "  --simulate-sync-issue           Simulate sync issues"
    echo "  --simulate-resource-issue       Simulate high resource usage"
    echo "  --simulate-peer-issue           Simulate low peer count"
    echo "  --check-alerts                  Check current alerts"
    echo "  --acknowledge-all               Acknowledge all alerts"
    echo "  --dashboard                     Start Grafana dashboard"
    echo "  --cleanup                       Remove simulated test data"
    echo "  --help                          Show this help message"
    echo ""
}

# Parse command line arguments
function parse_args() {
    if [[ $# -eq 0 ]]; then
        show_banner
        show_usage
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --simulate-attestation-issue)
                SIMULATORS+=("attestation")
                shift
                ;;
            --simulate-proposal-issue)
                SIMULATORS+=("proposal")
                shift
                ;;
            --simulate-balance-decrease)
                SIMULATORS+=("balance")
                shift
                ;;
            --simulate-sync-issue)
                SIMULATORS+=("sync")
                shift
                ;;
            --simulate-resource-issue)
                SIMULATORS+=("resource")
                shift
                ;;
            --simulate-peer-issue)
                SIMULATORS+=("peer")
                shift
                ;;
            --check-alerts)
                CHECK_ALERTS=true
                shift
                ;;
            --acknowledge-all)
                ACKNOWLEDGE_ALL=true
                shift
                ;;
            --dashboard)
                ENABLE_DASHBOARD=true
                shift
                ;;
            --cleanup)
                CLEANUP=true
                shift
                ;;
            --help)
                show_banner
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}[ERROR]${NC} Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check if the monitoring system is installed
function check_installation() {
    echo -e "${BLUE}[INFO]${NC} Checking installation..."
    
    # Check if the alerts directory exists
    if [[ ! -d "${ALERTS_DIR}" ]]; then
        echo -e "${RED}[ERROR]${NC} Alerts directory does not exist: ${ALERTS_DIR}"
        echo -e "${YELLOW}[WARNING]${NC} The Advanced Validator Performance Monitoring system may not be installed."
        echo -e "${YELLOW}[WARNING]${NC} Please run the setup script first: ./scripts/monitoring/setup_validator_alerts.sh"
        exit 1
    fi
    
    # Check if the alerts script exists
    if [[ ! -f "${ALERTS_SCRIPT}" ]]; then
        echo -e "${RED}[ERROR]${NC} Alerts script does not exist: ${ALERTS_SCRIPT}"
        echo -e "${YELLOW}[WARNING]${NC} The Advanced Validator Performance Monitoring system may not be installed."
        echo -e "${YELLOW}[WARNING]${NC} Please run the setup script first: ./scripts/monitoring/setup_validator_alerts.sh"
        exit 1
    fi
    
    # Create directories if they don't exist (for demo purposes)
    mkdir -p "${METRICS_DIR}"
    
    echo -e "${GREEN}[SUCCESS]${NC} Installation check passed."
}

# Simulate attestation issue
function simulate_attestation_issue() {
    echo -e "${BLUE}[INFO]${NC} Simulating low attestation effectiveness..."
    
    # Create a metrics file with low attestation effectiveness
    cat > "${METRICS_DIR}/attestation_performance.json" << EOF
{
    "timestamp": $(date +%s),
    "validators": [
        {
            "pubkey": "0x8000000000000000000000000000000000000000000000000000000000000000",
            "index": 1,
            "effectiveness": 0.75,
            "expected_attestations": 100,
            "successful_attestations": 75,
            "last_attestation_slot": $(( $(date +%s) / 12 ))
        },
        {
            "pubkey": "0x8000000000000000000000000000000000000000000000000000000000000001",
            "index": 2,
            "effectiveness": 0.88,
            "expected_attestations": 100,
            "successful_attestations": 88,
            "last_attestation_slot": $(( $(date +%s) / 12 ))
        }
    ],
    "average_effectiveness": 0.815
}
EOF
    
    echo -e "${GREEN}[SUCCESS]${NC} Simulated low attestation effectiveness (81.5% average)"
}

# Simulate proposal issue
function simulate_proposal_issue() {
    echo -e "${BLUE}[INFO]${NC} Simulating missed proposal..."
    
    # Create a metrics file with missed proposal
    cat > "${METRICS_DIR}/proposal_performance.json" << EOF
{
    "timestamp": $(date +%s),
    "validators": [
        {
            "pubkey": "0x8000000000000000000000000000000000000000000000000000000000000000",
            "index": 1,
            "success_rate": 0.8,
            "expected_proposals": 5,
            "successful_proposals": 4,
            "missed_proposals": 1,
            "last_proposal_slot": $(( $(date +%s) / 12 ))
        },
        {
            "pubkey": "0x8000000000000000000000000000000000000000000000000000000000000001",
            "index": 2,
            "success_rate": 1.0,
            "expected_proposals": 3,
            "successful_proposals": 3,
            "missed_proposals": 0,
            "last_proposal_slot": $(( $(date +%s) / 12 ))
        }
    ],
    "average_success_rate": 0.9
}
EOF
    
    echo -e "${GREEN}[SUCCESS]${NC} Simulated missed proposal (90% average success rate)"
}

# Simulate balance decrease
function simulate_balance_decrease() {
    echo -e "${BLUE}[INFO]${NC} Simulating balance decrease..."
    
    # Create a metrics file with balance decrease
    cat > "${METRICS_DIR}/balance_trend.json" << EOF
{
    "timestamp": $(date +%s),
    "validators": [
        {
            "pubkey": "0x8000000000000000000000000000000000000000000000000000000000000000",
            "index": 1,
            "current_balance": 31.92,
            "previous_balance": 32.1,
            "change_percentage": -0.0056,
            "change_absolute": -0.18,
            "total_earnings": 0
        },
        {
            "pubkey": "0x8000000000000000000000000000000000000000000000000000000000000001",
            "index": 2,
            "current_balance": 31.75,
            "previous_balance": 32.0,
            "change_percentage": -0.0078,
            "change_absolute": -0.25,
            "total_earnings": 0
        }
    ],
    "average_change_percentage": -0.0067
}
EOF

    # Create file in analysis directory for deeper analysis
    mkdir -p "${VALIDATOR_METRICS_DIR}/analysis"
    cp "${METRICS_DIR}/balance_trend.json" "${VALIDATOR_METRICS_DIR}/analysis/balance_trend.json"
    
    echo -e "${GREEN}[SUCCESS]${NC} Simulated balance decrease (-0.67% average)"
}

# Simulate sync issue
function simulate_sync_issue() {
    echo -e "${BLUE}[INFO]${NC} Simulating sync issues..."
    
    # Create a metrics file with sync issues
    cat > "${METRICS_DIR}/sync_status.json" << EOF
{
    "timestamp": $(date +%s),
    "beacon_node": {
        "syncing": true,
        "head_slot": $(( $(date +%s) / 12 - 60 )),
        "current_justified_epoch": $(( $(date +%s) / 12 / 32 - 2 )),
        "finalized_epoch": $(( $(date +%s) / 12 / 32 - 3 )),
        "seconds_behind": 120,
        "sync_percentage": 99.5
    },
    "execution_node": {
        "syncing": true,
        "current_block": $(( $(date +%s) / 12 - 50 )),
        "highest_block": $(( $(date +%s) / 12 )),
        "seconds_behind": 100,
        "sync_percentage": 99.8
    }
}
EOF
    
    echo -e "${GREEN}[SUCCESS]${NC} Simulated sync issues (120 seconds behind)"
}

# Simulate resource issue
function simulate_resource_issue() {
    echo -e "${BLUE}[INFO]${NC} Simulating high resource usage..."
    
    # Create a metrics file with high resource usage
    cat > "${METRICS_DIR}/system_resources.json" << EOF
{
    "timestamp": $(date +%s),
    "cpu": {
        "usage_percentage": 87.5,
        "load_1min": 2.15,
        "load_5min": 1.92,
        "load_15min": 1.45
    },
    "memory": {
        "total_gb": 16,
        "used_gb": 13.6,
        "usage_percentage": 85,
        "swap_used_percentage": 10
    },
    "disk": {
        "total_gb": 500,
        "used_gb": 400,
        "usage_percentage": 80,
        "io_utilization": 25
    },
    "network": {
        "in_mbps": 5.2,
        "out_mbps": 12.8,
        "total_connections": 35
    }
}
EOF
    
    echo -e "${GREEN}[SUCCESS]${NC} Simulated high resource usage (CPU: 87.5%, Memory: 85%, Disk: 80%)"
}

# Simulate peer issue
function simulate_peer_issue() {
    echo -e "${BLUE}[INFO]${NC} Simulating low peer count..."
    
    # Create a metrics file with low peer count
    cat > "${METRICS_DIR}/network_status.json" << EOF
{
    "timestamp": $(date +%s),
    "beacon_node": {
        "peer_count": 8,
        "connected_peers": [
            "16Uiu2HAmJT4sd8CFQUwJAXsZtavMqLrTvCpi9n6vUTQQsRHV9eqc",
            "16Uiu2HAmVFXWt4U9WKtk5j8z8GGrxemGx4Hhnv3zxKFxSL3NcZTm",
            "16Uiu2HAmQqGBsPufUw9V3ygQDaUdpg4fxuXKs9WqffdpuKyxcDZK",
            "16Uiu2HAmEUNBaLySmJcqLv1X7zeCpZpKVhmHAIJdYn6QifPQStim",
            "16Uiu2HAmJNkKMZnbg4fVwDKwDMHTq8ShGEwqCVPEUBHcGnWrfSME",
            "16Uiu2HAmBcNcCKbKv2Zav7SUvrFmd9uBHZ9QNdK7A3yn3JKw45sv",
            "16Uiu2HAm4xfBSdmdNZx1XZSAHdMcKg6Rh4Nz2Y5cCy7nB8qdiLpm",
            "16Uiu2HAmH5hFCGQwuhp8oKyn8HoQwkiTYrHMDyJRPgKGPUQAbCge"
        ],
        "connection_directions": {
            "inbound": 3,
            "outbound": 5
        }
    },
    "execution_node": {
        "peer_count": 6,
        "connected_peers": [
            "enode://f24c962b518f381f7a43d7f528a0c8b9a22b768688ae58d006d5cf6a8ae3ae24e358ce74e55d6cefef89dd6bf909db5f6f686c15524b22aaaed5d4ccbb32b84a",
            "enode://ca344c9f2d172e6c9d63e5e9874114918d5de867cbf11deef577d691541fbbbfca3021bfd5cb6b6d15c4f7a45b1d0261bd9d9bd6fcd62d17a1d6c696318da43c",
            "enode://6f8a80d14311c39f35f516fa664deaaaa13e85b2f7493f37f6144d86991ec012937307647bd3b9a82abe2974e1407241d54947bbb39763a4cac9f77166ad92a0",
            "enode://7a83fce40ee63c38118ae0465fe620d550415b22e4d6df39007882365520358f095b79c3161eeea715e5b926d9d38fe47f496caa98c3bcb263391285eaecfb97",
            "enode://6f8a80d14311c39f35f516fa664deaaaa13e85b2f7493f37f6144d86991ec012937307647bd3b9a82abe2974e1407241d54947bbb39763a4cac9f77166ad92a0",
            "enode://f24c962b518f381f7a43d7f528a0c8b9a22b768688ae58d006d5cf6a8ae3ae24e358ce74e55d6cefef89dd6bf909db5f6f686c15524b22aaaed5d4ccbb32b84a"
        ]
    }
}
EOF
    
    echo -e "${GREEN}[SUCCESS]${NC} Simulated low peer count (Beacon: 8, Execution: 6)"
}

# Check current alerts
function check_current_alerts() {
    echo -e "${BLUE}[INFO]${NC} Checking current alerts..."
    
    # Check if the alerts script exists
    if [[ ! -f "${ALERTS_SCRIPT}" ]]; then
        echo -e "${RED}[ERROR]${NC} Alerts script does not exist: ${ALERTS_SCRIPT}"
        return 1
    fi
    
    # Run the alerts script with check option
    echo -e "${YELLOW}[RUNNING]${NC} ${ALERTS_SCRIPT} --check"
    "${ALERTS_SCRIPT}" --check
    
    # Check if alerts JSON file exists
    if [[ -f "${ALERTS_DIR}/alerts.json" ]]; then
        echo -e "${BLUE}[INFO]${NC} Current alerts from ${ALERTS_DIR}/alerts.json:"
        jq -r '.alerts[] | "[\(.severity | ascii_upcase)] \(.type): \(.message)"' "${ALERTS_DIR}/alerts.json" 2>/dev/null || echo "No alerts found."
    else
        echo -e "${YELLOW}[WARNING]${NC} No alerts file found at ${ALERTS_DIR}/alerts.json"
    fi
}

# Acknowledge all alerts
function acknowledge_all_alerts() {
    echo -e "${BLUE}[INFO]${NC} Acknowledging all alerts..."
    
    # Check if the alerts JSON file exists
    if [[ ! -f "${ALERTS_DIR}/alerts.json" ]]; then
        echo -e "${YELLOW}[WARNING]${NC} No alerts file found at ${ALERTS_DIR}/alerts.json"
        return 0
    fi
    
    # Create a temporary file with all alerts acknowledged
    local tmpfile=$(mktemp)
    jq '.alerts[] |= (.acknowledged = true)' "${ALERTS_DIR}/alerts.json" > "${tmpfile}"
    mv "${tmpfile}" "${ALERTS_DIR}/alerts.json"
    
    echo -e "${GREEN}[SUCCESS]${NC} All alerts acknowledged."
}

# Launch Grafana dashboard
function launch_dashboard() {
    echo -e "${BLUE}[INFO]${NC} Launching Grafana dashboard..."
    
    # Check if Grafana is running
    if command -v systemctl &> /dev/null && systemctl is-active --quiet grafana-server; then
        echo -e "${GREEN}[SUCCESS]${NC} Grafana server is running."
        echo -e "${BLUE}[INFO]${NC} Access the dashboard at: http://localhost:3000/d/validator-performance-advanced"
    else
        echo -e "${YELLOW}[WARNING]${NC} Grafana server may not be running."
        echo -e "${YELLOW}[WARNING]${NC} To start Grafana server, run: systemctl start grafana-server"
        echo -e "${YELLOW}[WARNING]${NC} Once started, access the dashboard at: http://localhost:3000/d/validator-performance-advanced"
    fi
    
    # If using Docker, show alternative command
    if command -v docker &> /dev/null; then
        echo -e "${BLUE}[INFO]${NC} If using Docker, you can start Grafana with:"
        echo -e "${CYAN}docker-compose -f ${REPO_ROOT}/dashboard/docker-compose.yaml up -d${NC}"
    fi
}

# Clean up simulated data
function cleanup_simulation() {
    echo -e "${BLUE}[INFO]${NC} Cleaning up simulated data..."
    
    # Remove simulation files
    rm -f "${METRICS_DIR}/attestation_performance.json"
    rm -f "${METRICS_DIR}/proposal_performance.json"
    rm -f "${METRICS_DIR}/balance_trend.json"
    rm -f "${METRICS_DIR}/sync_status.json"
    rm -f "${METRICS_DIR}/system_resources.json"
    rm -f "${METRICS_DIR}/network_status.json"
    rm -f "${VALIDATOR_METRICS_DIR}/analysis/balance_trend.json"
    
    # Remove alerts
    if [[ -f "${ALERTS_DIR}/alerts.json" ]]; then
        rm -f "${ALERTS_DIR}/alerts.json"
        echo -e "${BLUE}[INFO]${NC} Removed alerts file."
    fi
    
    echo -e "${GREEN}[SUCCESS]${NC} Cleanup complete."
}

# Run the appropriate simulations
function run_simulations() {
    for simulator in "${SIMULATORS[@]}"; do
        case "${simulator}" in
            attestation)
                simulate_attestation_issue
                ;;
            proposal)
                simulate_proposal_issue
                ;;
            balance)
                simulate_balance_decrease
                ;;
            sync)
                simulate_sync_issue
                ;;
            resource)
                simulate_resource_issue
                ;;
            peer)
                simulate_peer_issue
                ;;
            *)
                echo -e "${YELLOW}[WARNING]${NC} Unknown simulator: ${simulator}"
                ;;
        esac
    done
}

# Main function
function main() {
    show_banner
    parse_args "$@"
    check_installation
    
    # Run simulations if any were specified
    if [[ ${#SIMULATORS[@]} -gt 0 ]]; then
        run_simulations
    fi
    
    # Check alerts if requested
    if [[ "${CHECK_ALERTS}" == "true" ]]; then
        check_current_alerts
    fi
    
    # Acknowledge all alerts if requested
    if [[ "${ACKNOWLEDGE_ALL}" == "true" ]]; then
        acknowledge_all_alerts
    fi
    
    # Launch Grafana dashboard if requested
    if [[ "${ENABLE_DASHBOARD}" == "true" ]]; then
        launch_dashboard
    fi
    
    # Clean up if requested
    if [[ "${CLEANUP}" == "true" ]]; then
        cleanup_simulation
    fi
    
    echo -e "${GREEN}[SUCCESS]${NC} Demo script completed successfully."
    
    # Provide hints for next steps
    if [[ ${#SIMULATORS[@]} -gt 0 && "${CHECK_ALERTS}" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} Simulated issues have been created. To check for alerts, run:"
        echo -e "${CYAN}$0 --check-alerts${NC}"
    fi
    
    if [[ ${#SIMULATORS[@]} -gt 0 && "${ENABLE_DASHBOARD}" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} To visualize in the dashboard, run:"
        echo -e "${CYAN}$0 --dashboard${NC}"
    fi
    
    if [[ "${CLEANUP}" != "true" && ( ${#SIMULATORS[@]} -gt 0 || "${CHECK_ALERTS}" == "true" || "${ACKNOWLEDGE_ALL}" == "true" ) ]]; then
        echo -e "${BLUE}[INFO]${NC} To clean up simulated data, run:"
        echo -e "${CYAN}$0 --cleanup${NC}"
    fi
}

# Run the script
main "$@" 