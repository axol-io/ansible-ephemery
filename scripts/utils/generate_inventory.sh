#!/bin/bash

# Script to generate inventory files from templates

# Set default values
TEMPLATE_TYPE="local"
OUTPUT_FILE=""
BASE_DIR="$HOME/ephemery"
DATA_DIR="$HOME/ephemery/data"
LOGS_DIR="$HOME/ephemery/logs"
GETH_IMAGE="ethereum/client-go:latest"
GETH_CACHE="4096"
GETH_MAX_PEERS="25"
LIGHTHOUSE_IMAGE="sigp/lighthouse:latest"
LIGHTHOUSE_TARGET_PEERS="30"
REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PORT="22"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Generate an inventory file from a template"
    echo ""
    echo "Options:"
    echo "  --type TYPE             Template type (local or remote) (default: local)"
    echo "  --output FILE           Output file (required)"
    echo "  --base-dir DIR          Base directory for Ephemery (default: $HOME/ephemery)"
    echo "  --data-dir DIR          Data directory (default: \$BASE_DIR/data)"
    echo "  --logs-dir DIR          Logs directory (default: \$BASE_DIR/logs)"
    echo "  --geth-image IMAGE      Geth Docker image (default: ethereum/client-go:latest)"
    echo "  --geth-cache SIZE       Geth cache size in MB (default: 4096)"
    echo "  --geth-max-peers NUM    Geth max peers (default: 25)"
    echo "  --lighthouse-image IMG  Lighthouse Docker image (default: sigp/lighthouse:latest)"
    echo "  --lighthouse-peers NUM  Lighthouse target peers (default: 30)"
    echo "  --remote-host HOST      Remote host (required for remote type)"
    echo "  --remote-user USER      Remote user (required for remote type)"
    echo "  --remote-port PORT      Remote SSH port (default: 22)"
    echo "  --help                  Display this help and exit"
    echo ""
    echo "Example local inventory:"
    echo "  $0 --type local --output my-local-inventory.yaml --base-dir /data/ephemery"
    echo ""
    echo "Example remote inventory:"
    echo "  $0 --type remote --output my-remote-inventory.yaml --remote-host example.com --remote-user admin"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            TEMPLATE_TYPE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --base-dir)
            BASE_DIR="$2"
            shift 2
            ;;
        --data-dir)
            DATA_DIR="$2"
            shift 2
            ;;
        --logs-dir)
            LOGS_DIR="$2"
            shift 2
            ;;
        --geth-image)
            GETH_IMAGE="$2"
            shift 2
            ;;
        --geth-cache)
            GETH_CACHE="$2"
            shift 2
            ;;
        --geth-max-peers)
            GETH_MAX_PEERS="$2"
            shift 2
            ;;
        --lighthouse-image)
            LIGHTHOUSE_IMAGE="$2"
            shift 2
            ;;
        --lighthouse-peers)
            LIGHTHOUSE_TARGET_PEERS="$2"
            shift 2
            ;;
        --remote-host)
            REMOTE_HOST="$2"
            shift 2
            ;;
        --remote-user)
            REMOTE_USER="$2"
            shift 2
            ;;
        --remote-port)
            REMOTE_PORT="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Output file is required" >&2
    usage
    exit 1
fi

# Validate template type
if [ "$TEMPLATE_TYPE" != "local" ] && [ "$TEMPLATE_TYPE" != "remote" ]; then
    echo "Error: Template type must be 'local' or 'remote'" >&2
    usage
    exit 1
fi

# Validate remote parameters if template type is remote
if [ "$TEMPLATE_TYPE" = "remote" ]; then
    if [ -z "$REMOTE_HOST" ] || [ -z "$REMOTE_USER" ]; then
        echo "Error: Remote host and user are required for remote template type" >&2
        usage
        exit 1
    fi
fi

# Generate the inventory file
if [ "$TEMPLATE_TYPE" = "local" ]; then
    # Generate local inventory file
    cat > "$OUTPUT_FILE" << EOF
# Local Ephemery Node Configuration
local:
  # Base directory for Ephemery
  base_dir: "$BASE_DIR"

  # Directory for node data
  data_dir: "$DATA_DIR"

  # Directory for logs
  logs_dir: "$LOGS_DIR"

  # Geth Configuration
  geth:
    image: "$GETH_IMAGE"
    cache: $GETH_CACHE
    max_peers: $GETH_MAX_PEERS

  # Lighthouse Configuration
  lighthouse:
    image: "$LIGHTHOUSE_IMAGE"
    target_peers: $LIGHTHOUSE_TARGET_PEERS
EOF
else
    # Generate remote inventory file
    cat > "$OUTPUT_FILE" << EOF
# Remote Ephemery Node Configuration
hosts:
  - host: $REMOTE_HOST
    user: $REMOTE_USER
    port: $REMOTE_PORT

# Node Configuration
remote:
  # Base directory for Ephemery
  base_dir: "$BASE_DIR"

  # Directory for node data
  data_dir: "$DATA_DIR"

  # Directory for logs
  logs_dir: "$LOGS_DIR"

  # Geth Configuration
  geth:
    image: "$GETH_IMAGE"
    cache: $GETH_CACHE
    max_peers: $GETH_MAX_PEERS

  # Lighthouse Configuration
  lighthouse:
    image: "$LIGHTHOUSE_IMAGE"
    target_peers: $LIGHTHOUSE_TARGET_PEERS
EOF
fi

echo "Inventory file generated: $OUTPUT_FILE"
exit 0
