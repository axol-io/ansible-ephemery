#!/bin/bash

# Script to run Ephemery with Geth and Lighthouse on a remote host
set -e

# Function to display help
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -i, --inventory FILE     Specify inventory file (required)"
    echo "  -h, --help               Display this help message"
    echo
    echo "Examples:"
    echo "  $0 --inventory config/remote-inventory.yaml"
    echo "  $0 -i my-inventory.yaml"
    echo
    echo "You can create an inventory file based on the example in config/remote-inventory.yaml.example"
}

# Parse command line options
INVENTORY_FILE=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -i|--inventory)
            INVENTORY_FILE="$2"
            shift
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if inventory file is provided
if [ -z "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file is required"
    show_help
    exit 1
fi

# Source the inventory parser utility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/parse_inventory.sh"

# Check if inventory file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file '$INVENTORY_FILE' not found"
    exit 1
fi

# Parse inventory file
echo "Loading configuration from $INVENTORY_FILE"
parse_remote_inventory "$INVENTORY_FILE"

echo "Deploying Ephemery to remote host: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT"
echo "--------------------------------------------------------------"

# Create temporary deployment script
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOF'
#!/bin/bash
set -e

# Base directories
EPHEMERY_BASE_DIR=$HOME/ephemery
EPHEMERY_DATA_DIR=$EPHEMERY_BASE_DIR/data
EPHEMERY_LOGS_DIR=$EPHEMERY_BASE_DIR/logs
JWT_SECRET_PATH=$EPHEMERY_BASE_DIR/jwt.hex

# Create directories
mkdir -p $EPHEMERY_BASE_DIR
mkdir -p $EPHEMERY_DATA_DIR/geth
mkdir -p $EPHEMERY_DATA_DIR/lighthouse
mkdir -p $EPHEMERY_LOGS_DIR

# Generate JWT secret
if [ ! -f $JWT_SECRET_PATH ]; then
    echo "Generating JWT secret..."
    openssl rand -hex 32 | tr -d "\n" > $JWT_SECRET_PATH
    chmod 600 $JWT_SECRET_PATH
fi

# Create Docker network
if ! docker network inspect ephemery &>/dev/null; then
    docker network create ephemery
fi

# Clean existing containers
echo "Removing any existing containers..."
docker rm -f ephemery-geth 2>/dev/null || true
docker rm -f ephemery-lighthouse 2>/dev/null || true

# Start Geth with optimizations
echo "Starting Geth execution client with optimizations..."
docker run -d --name ephemery-geth \
    --network ephemery \
    --restart unless-stopped \
    -v $EPHEMERY_DATA_DIR/geth:/ethdata \
    -v $JWT_SECRET_PATH:/config/jwt-secret \
    -p 8545-8546:8545-8546 -p 8551:8551 -p 30303:30303 -p 30303:30303/udp \
    pk910/ephemery-geth:v1.15.3 \
    --datadir /ethdata \
    --http --http.api eth,net,engine,admin --http.addr 0.0.0.0 \
    --authrpc.addr 0.0.0.0 --authrpc.port 8551 --authrpc.jwtsecret /config/jwt-secret \
    --cache=4096 \
    --txlookuplimit=0 \
    --syncmode=snap \
    --maxpeers=100 \
    --db.engine=pebble

# Wait for Geth
echo "Waiting for Geth to initialize..."
sleep 10

# Start Lighthouse with optimizations
echo "Starting Lighthouse consensus client with optimizations..."
docker run -d --name ephemery-lighthouse \
    --network ephemery \
    --restart unless-stopped \
    -v $EPHEMERY_DATA_DIR/lighthouse:/ethdata \
    -v $JWT_SECRET_PATH:/config/jwt-secret \
    -p 5052:5052 -p 9000:9000 -p 9000:9000/udp -p 8008:8008 \
    pk910/ephemery-lighthouse:latest \
    lighthouse beacon \
    --datadir /ethdata \
    --testnet-dir /ephemery_config \
    --execution-jwt /config/jwt-secret \
    --execution-endpoint http://ephemery-geth:8551 \
    --http --http-address 0.0.0.0 --http-port 5052 \
    --target-peers=100 \
    --execution-timeout-multiplier=5 \
    --allow-insecure-genesis-sync \
    --genesis-backfill \
    --disable-backfill-rate-limiting \
    --disable-deposit-contract-sync

echo "Ephemery node is running with optimized settings"
echo "Geth execution API: http://localhost:8545"
echo "Lighthouse consensus API: http://localhost:5052"
EOF

# Make script executable
chmod +x "$TEMP_SCRIPT"

# Copy script to remote host
echo "Copying deployment script to remote host..."
scp -P "$REMOTE_PORT" "$TEMP_SCRIPT" "$REMOTE_USER@$REMOTE_HOST:~/deploy-ephemery.sh"

# Execute script on remote host
echo "Executing deployment script on remote host..."
ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "bash ~/deploy-ephemery.sh"

# Clean up
rm "$TEMP_SCRIPT"

echo "--------------------------------------------------------------"
echo "Ephemery node has been deployed to $REMOTE_USER@$REMOTE_HOST"
echo "Geth execution API: http://$REMOTE_HOST:8545"
echo "Lighthouse consensus API: http://$REMOTE_HOST:5052"
echo
echo "To monitor the sync status, SSH into the server and run:"
echo "  docker logs -f ephemery-geth"
echo "  docker logs -f ephemery-lighthouse"
echo
echo "To stop the nodes:"
echo "  docker stop ephemery-geth ephemery-lighthouse"
echo "--------------------------------------------------------------" 