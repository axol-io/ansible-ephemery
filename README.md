# Ephemery Node Setup

This repository contains scripts and instructions for setting up an Ephemery network node using Docker containers.

## What is Ephemery?

Ephemery is an Ethereum test network that resets itself periodically, providing a fresh testing environment. The network uses the same parameters and configuration as the Ethereum mainnet, but is ephemeral in nature, which makes it ideal for testing applications without spending real ETH.

## Prerequisites

- Docker installed and running
- Basic knowledge of Ethereum and Docker
- Approximately 10GB of free disk space
- Port forwarding for 8545, 8551, 30303, 5052, 9000, and 8008

## Quick Setup

For a quick setup, run the provided setup script:

```bash
./setup_ephemery.sh
```

This script will:
1. Create necessary directories
2. Set up a Docker network for container communication
3. Generate a JWT secret for authentication
4. Start the Geth execution client
5. Start the Lighthouse consensus client

## Validator Setup

If you want to run validators on the Ephemery network, place your validator keys in a zip file at `ansible/files/validator_keys/validator_keys.zip` and run:

```bash
./setup_ephemery_validator.sh
```

This script will:
1. Extract the validator keys from the zip file
2. Create password files for the validators
3. Start a Lighthouse validator client
4. Import the validator keys into the client

Note: Your beacon node must be fully synced before validators can participate in the network.

## Manual Setup

If you prefer to set up the nodes manually, follow these steps:

### 1. Create directories

```bash
mkdir -p ~/ephemery/data/geth
mkdir -p ~/ephemery/data/lighthouse
mkdir -p ~/ephemery/config
mkdir -p ~/ephemery/logs
mkdir -p ~/ephemery/secrets
```

### 2. Create Docker network

```bash
docker network create ephemery-net
```

### 3. Create JWT secret

```bash
openssl rand -hex 32 > ~/ephemery/jwt.hex
chmod 600 ~/ephemery/jwt.hex
```

### 4. Start Geth (Execution Layer)

```bash
docker run -d --name ephemery-geth --network ephemery-net \
  -v ~/ephemery/data/geth:/ethdata \
  -v ~/ephemery/jwt.hex:/config/jwt-secret \
  -p 8545-8546:8545-8546 -p 8551:8551 -p 30303:30303 -p 30303:30303/udp \
  pk910/ephemery-geth:latest \
  --http.addr 0.0.0.0 --authrpc.addr 0.0.0.0 --authrpc.vhosts "*" \
  --authrpc.jwtsecret /config/jwt-secret
```

### 5. Start Lighthouse (Consensus Layer)

```bash
docker run -d --name ephemery-lighthouse --network ephemery-net \
  -v ~/ephemery/data/lighthouse:/ethdata \
  -v ~/ephemery/jwt.hex:/config/jwt-secret \
  -v ~/ephemery/config:/ephemery_config \
  -p 5052:5052 -p 9000:9000 -p 9000:9000/udp -p 8008:8008 \
  pk910/ephemery-lighthouse:latest \
  lighthouse beacon --datadir /ethdata --testnet-dir=/ephemery_config \
  --execution-jwt /config/jwt-secret --execution-endpoint http://ephemery-geth:8551 \
  --http --http-address 0.0.0.0 --http-port 5052 \
  --metrics --metrics-address 0.0.0.0 --metrics-port 8008 \
  --target-peers 100 --execution-timeout-multiplier 5
```

### 6. Manual Validator Setup

To manually set up validators:

```bash
# Create validator directories
mkdir -p ~/ephemery/data/lighthouse-validator
mkdir -p ~/ephemery/data/validator-keys
mkdir -p ~/ephemery/secrets/validator-passwords

# Extract validator keys and create password files
# ... (Custom steps for your validator keys)

# Start Lighthouse validator client
docker run -d --name ephemery-validator --network ephemery-net \
  -v ~/ephemery/data/lighthouse-validator:/validatordata \
  -v ~/ephemery/data/validator-keys:/validator-keys \
  -v ~/ephemery/secrets/validator-passwords:/validator-passwords \
  pk910/ephemery-lighthouse:latest \
  lighthouse validator \
  --datadir /validatordata \
  --beacon-nodes http://ephemery-lighthouse:5052 \
  --testnet-dir=/ephemery_config \
  --init-slashing-protection \
  --metrics \
  --metrics-address 0.0.0.0 \
  --metrics-port 5064 \
  --suggested-fee-recipient 0x0000000000000000000000000000000000000000

# Import validator keys
docker exec ephemery-validator lighthouse \
  --testnet-dir=/ephemery_config \
  account validator import \
  --directory=/validator-keys \
  --datadir=/validatordata \
  --password-file=/validator-passwords/validator-1.txt
```

## Verification

To verify that your nodes are running correctly:

### Geth API

```bash
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
  http://localhost:8545
```

### Lighthouse API

```bash
curl -X GET http://localhost:5052/eth/v1/node/syncing -H "Content-Type: application/json"
```

### Validator Status

```bash
curl -X GET http://localhost:5052/eth/v1/beacon/states/head/validators -H "Content-Type: application/json"
```

## Monitoring

You can monitor the logs of the containers:

```bash
# Use the monitoring script
./monitor_ephemery.sh [options]

# Options:
#   -g, --geth         Monitor Geth logs only
#   -l, --lighthouse   Monitor Lighthouse logs only
#   -c, --combined     Monitor both logs in split view (default, requires tmux)
#   -s, --status       Show current node status
#   -h, --help         Show this help message

# Monitor validator logs
docker logs -f ephemery-validator
```

## Health Check

You can run health checks on your Ephemery node to identify issues and monitor performance:

```bash
# Use the health check script
./health_check_ephemery.sh [options]

# Options:
#   -b, --basic         Run basic health checks (default)
#   -f, --full          Run comprehensive health checks
#   -p, --performance   Run performance checks
#   -n, --network       Run network checks
#   --base-dir PATH     Specify a custom base directory
#   -h, --help          Show this help message
```

The health check script provides:
- Container status checks
- Sync status monitoring
- Disk space analysis
- Performance monitoring
- Network connectivity checks
- Validator status information

## Data Management

### Disk Space Management

You can use the pruning script to manage disk space usage:

```bash
# Use the pruning script (dry run by default, no changes made)
./prune_ephemery_data.sh [options]

# Options:
#   -s, --safe              Safe pruning (removes only non-essential data, default)
#   -a, --aggressive        Aggressive pruning (removes more data, may affect performance)
#   -f, --full              Full pruning (completely resets nodes, requires resync)
#   -e, --execution-only    Prune only execution layer data
#   -c, --consensus-only    Prune only consensus layer data
#   -d, --dry-run           Show what would be pruned without making changes (default)
#   -y, --yes               Skip confirmation prompts
```

### Validator Backup and Restore

To backup and restore validator keys and slashing protection data:

```bash
# Create a backup
./backup_restore_validators.sh backup [options]

# Restore from a backup
./backup_restore_validators.sh restore --file BACKUP_FILE [options]

# Options:
#   -d, --dir DIR          Directory to store backups or read from
#   -f, --file FILE        Specific backup file to restore from (for restore mode)
#   -e, --encrypt          Encrypt the backup (backup mode)
#   --no-slashing          Exclude slashing protection data (backup mode)
```

**Important:** Always keep validator key backups secure as they control access to staked funds.

## Troubleshooting

### Common Issues

1. **JWT Authentication Failures**
   - Ensure both containers are using the same JWT file
   - Make sure the JWT file permissions are set correctly (600)

2. **Container Communication Issues**
   - Verify the containers are on the same Docker network
   - Check that the container names are resolved correctly within the network

3. **Sync Issues**
   - Initial sync may take several hours
   - It's normal to see execution payload errors during the initial sync

4. **Validator Issues**
   - Ensure validator keys are properly imported
   - Check that the beacon node is fully synced before expecting validator participation
   - Verify validator client is connected to the beacon node

### Restarting Containers

If you need to restart the containers:

```bash
docker restart ephemery-geth ephemery-lighthouse ephemery-validator
```

## Additional Resources

- [Ephemery Official Documentation](https://ephemery.dev/)
- [Geth Documentation](https://geth.ethereum.org/docs/)
- [Lighthouse Documentation](https://lighthouse-book.sigmaprime.io/)

## Repository Maintenance

### Linting and Formatting

To maintain code quality and consistency in the repository, a comprehensive linting and formatting script is provided. This script fixes common issues:

- Trailing whitespace
- Missing end-of-file newlines
- YAML file extensions (converts .yml to .yaml)
- Python code formatting (using isort and black)

To run the linting script:

```bash
# Navigate to the repository root
cd ansible-ephemery

# Run the linting script
./scripts/maintenance/fix-repository-linting.sh
```

If you don't have Python formatting tools installed (isort, black), you can run:

```bash
./scripts/maintenance/fix-repository-linting.sh --no-python-format
```

After the script runs, review the changes and commit them if satisfactory.

### Pre-commit Hooks

This repository uses pre-commit hooks to ensure code quality. The hooks check for issues like:

- Trailing whitespace
- End-of-file newlines
- YAML syntax
- Python formatting

When you encounter a pre-commit hook failure, you can either:

1. Fix the issues manually
2. Use the linting script to automatically fix common issues
3. Use `git commit --no-verify` to bypass the hooks (not recommended for regular use)

Install the pre-commit hooks with:

```bash
pip install pre-commit
pre-commit install
```
