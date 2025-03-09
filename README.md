# ansible-ephemery

Ansible playbook for deploying and managing [Ephemery](https://ephemery.dev/) Ethereum testnet nodes using Docker.

## What is Ephemery?

A short-lived Ethereum testnet that resets every 24 hours, providing a clean environment for testing without the resource requirements of permanent testnets.

## Key Features

- **Multi-client support**: Geth, Besu, Nethermind, Reth, Erigon (execution) and Lighthouse, Teku, Prysm, Lodestar (consensus)
- **Specialized images**: Optimized Docker images with built-in Ephemery configuration
- **Reliable sync**: Uses genesis sync for consistent and reliable initial sync
- **Monitoring**: Grafana, Prometheus, Node Exporter, and cAdvisor
- **Security**: Firewall, JWT secrets, secure defaults
- **Automation**: Backups, health checks, resource management, automatic resets
- **Resource-efficient**: Configurable memory allocation

## Prerequisites

- Ansible 2.10+ on control machine
- Target hosts with Docker, SSH access, and sufficient resources (4+ CPU cores, 8+ GB RAM)

## Quick Start

```bash
# Clone repository
git clone https://github.com/hydepwns/ansible-ephemery.git && cd ansible-ephemery

# Install requirements
ansible-galaxy collection install -r requirements.yaml
pip install -r requirements.txt

# Configure inventory
cp example-inventory.yaml inventory.yaml
# Edit inventory.yaml with your target hosts

# Run playbook
ansible-playbook -i inventory.yaml ephemery.yaml
```

**New to Ansible?** See our detailed [Getting Started Guide](docs/GETTING_STARTED.md) for step-by-step instructions.

## Getting Started for Ansible Beginners

If you're new to Ansible, follow these steps to get your Ephemery node running:

1. **Set up your inventory file**:

   ```bash
   cp example-inventory.yaml inventory.yaml
   ```

   Edit `inventory.yaml` and replace:
   - Host names (e.g., `ephemery-node1`)
   - IP addresses (`ansible_host: 192.168.1.101`)
   - User account (`ansible_user: root`)
   - Client selections (`el: geth`, `cl: lighthouse`)

2. **Configure host variables** (optional but recommended):

   ```bash
   mkdir -p ansible/host_vars
   cp ansible/host_vars/example-host.yaml ansible/host_vars/your-node-name.yaml
   ```

   Edit `ansible/host_vars/your-node-name.yaml` and set:
   - `ansible_host`: Your server's IP address
   - `ansible_user`: SSH username
   - Client selection: `el: geth`, `cl: lighthouse`
   - `monitoring_enabled`: Set to `true` for monitoring
   - `validator_enabled`: Set to `true` to run a validator

3. **Run the playbook**:

   ```bash
   ansible-playbook -i inventory.yaml ephemery.yaml
   ```

4. **Access your node**:
   - Execution API: `http://your-server-ip:8545`
   - Consensus API: `http://your-server-ip:5052`
   - Grafana (if enabled): `http://your-server-ip:3000`

For a more detailed step-by-step guide, see [Getting Started Guide](docs/GETTING_STARTED.md).

## Configuration

### Basic Settings

```yaml
el: "geth"                # Execution client
cl: "lighthouse"          # Consensus client

# Features
validator_enabled: false
monitoring_enabled: true
backup_enabled: true
firewall_enabled: true
```

### Resource Management

```yaml
# 90% of system memory allocated in these proportions
el_memory_percentage: 0.5      # Execution client
cl_memory_percentage: 0.4      # Consensus client
validator_memory_percentage: 0.1  # Validator (if enabled)
```

### Automatic Reset

```yaml
ephemery_automatic_reset: true      # Enable via cron
ephemery_reset_frequency: "0 0 * * *"  # Midnight daily
```

## Directory Structure

```
/opt/ephemery/
├── data/        # Node data (el/ and cl/)
├── logs/        # Log files
├── scripts/     # Operational scripts
└── backups/     # Backup files
```

## Repository Structure

```
ansible-ephemery/
├── ansible/                # Ansible related files
│   ├── tasks/              # Task definitions
│   ├── playbooks/          # Additional playbooks
│   ├── templates/          # Jinja2 templates
│   ├── defaults/           # Default variables
│   ├── vars/               # Non-default variables
│   ├── meta/               # Role metadata
│   ├── group_vars/         # Group-specific variables
│   ├── host_vars/          # Host-specific variables
│   ├── files/              # Static files
│   └── inventory.yaml      # Inventory file
├── molecule/               # Testing framework
│   ├── clients/            # Client combinations
│   │   ├── geth-lighthouse/  # Example client pair
│   │   └── ...             # Other client pairs
│   ├── shared/             # Shared test resources
│   ├── default/            # Basic tests
│   └── ...                 # Other test scenarios
└── scripts/                # Utility scripts
```

## Validator Configuration

Three options available:

1. **Automatic Generation**: Enable validator without specifying keys
2. **Compressed Keys**: Place archive in `files/validator_keys/validator_keys.zip`
3. **Individual Key Files**: Configure paths to keystore files and password

For details, see [docs/VALIDATOR_README.md](docs/VALIDATOR_README.md).

## Client Combinations

Ephemery-specific images used when available:

- `pk910/ephemery-geth`
- `pk910/ephemery-lighthouse`

See [docs/CLIENT_COMBINATIONS.md](docs/CLIENT_COMBINATIONS.md) for compatibility details.

## Monitoring

Tools included for comprehensive monitoring:

- Grafana, Prometheus, Node Exporter, cAdvisor

For configuration and troubleshooting, see [docs/MONITORING.md](docs/MONITORING.md).

## Sync Optimization

Optimize your Ephemery node sync times with these tested techniques:

- **Bootstrap Node Formatting**: Ensure correct format with UDP ports (`/ip4/IP/tcp/9000/udp/9000/p2p/ID`)
- **Ephemery-Specific Images**: Use pk910 images (`pk910/ephemery-geth`, `pk910/ephemery-lighthouse`) for best compatibility
- **Genesis Sync Strategy**: Our testing shows best results using genesis sync with optimized flags rather than checkpoint sync
- **Execution Client Optimization**: Use these proven Geth parameters: `--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100`
- **Consensus Client Optimization**: Use these Lighthouse flags: `--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting`
- **Resource Allocation**: Properly divide memory between clients: 50% for execution client, 40% for consensus client, 10% for validator

Example inventory configuration:
```yaml
ephemery:
  hosts:
    ephemery-node1:
      # Disable checkpoint sync since it often fails
      use_checkpoint_sync: false
      # Clear database for a fresh start
      clear_database: true
      # Lighthouse optimization parameters for faster sync
      cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
      # Geth optimization parameters for faster sync
      el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"
```

For detailed optimization instructions, see our updated guides:
- [Optimized Sync Guide](docs/CHECKPOINT_SYNC.md)
- [Client Optimization Guide](docs/LIGHTHOUSE_OPTIMIZATION.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

## Testing

The role includes comprehensive Molecule tests for all supported client combinations and features.

```bash
# Install test dependencies
pip install -r requirements-dev.txt

# Run tests (Linux)
molecule test -s geth-lighthouse

# Run tests (macOS)
# For Docker Desktop users
export DOCKER_HOST=unix:///Users/<username>/.docker/run/docker.sock
molecule test -s geth-lighthouse

# For OrbStack users
export DOCKER_HOST=unix:///Users/<username>/.orbstack/run/docker.sock
molecule test -s geth-lighthouse

# OR use our helper script that works with both Docker Desktop and OrbStack
./scripts/run-molecule-tests-macos.sh geth-lighthouse
```

See [Molecule Testing](./molecule/README.md) and [Testing Documentation](./docs/TESTING.md) for more details.

## Documentation

- [Getting Started Guide](docs/GETTING_STARTED.md)
- [Genesis Sync](docs/GENESIS_SYNC.md)
- [Client-Specific Configuration](docs/CLIENT_SPECIFIC.md)
- [Ephemery-Specific Information](docs/EPHEMERY_SPECIFIC.md)
- [Monitoring Setup](docs/MONITORING.md)
- [Security Considerations](docs/SECURITY.md)
- [Validator Setup](docs/VALIDATOR_SETUP.md)

## Additional Resources

- [Ephemery Website](https://ephemery.dev/)
- [Ephemery Resources](https://github.com/ephemery-testnet/ephemery-resources)
- [Ephemery Scripts](https://github.com/ephemery-testnet/ephemery-scripts)

## License

MIT
