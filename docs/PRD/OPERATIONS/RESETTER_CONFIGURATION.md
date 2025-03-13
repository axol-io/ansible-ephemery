# Resetter Configuration Guide

## Overview

The Ephemery testnet is designed to reset periodically, allowing for clean-slate testing environments. This guide provides detailed instructions for configuring, customizing, and monitoring the resetter script (`retention.sh`) that manages these resets for your Ephemery node.

## Understanding the Reset Mechanism

### Reset Cycle

The Ephemery testnet resets on a regular schedule, typically every few days. During each reset:

1. A new genesis state is generated
2. All blockchain data is wiped clean
3. Validators from the registry are included in the new genesis state
4. The network restarts from the new genesis block

### The Resetter Script

The `retention.sh` script is responsible for:

1. Detecting when a reset has occurred
2. Downloading the latest genesis configuration
3. Initializing your execution and consensus clients with the new genesis
4. Restarting your node with the updated configuration

## Basic Setup

### Prerequisites

Before configuring the resetter:

- Ensure you have a working Ethereum node (execution and consensus clients)
- Install required dependencies: `jq`, `curl`, `git`
- Ensure you have cron configured and running

### Getting the Script

1. Clone the Ephemery Genesis repository:

   ```bash
   git clone https://github.com/ephemery-testnet/ephemery-genesis.git
   cd ephemery-genesis
   ```

2. Review the `retention.sh` script to understand its operation:

   ```bash
   cat retention.sh
   ```

## Customizing the Resetter

The script requires customization to work with your specific node setup. You'll need to modify the following key functions:

### 1. Detecting Resets

The `get_last_reset_time` function retrieves the latest reset timestamp:

```bash
function get_last_reset_time() {
  # Default implementation
  curl -s https://raw.githubusercontent.com/ephemery-testnet/ephemery-genesis/master/genesis_time.txt
}
```

Customize if you need alternative sources or caching mechanisms.

### 2. Execution Client Initialization

The `initialize_el` function prepares your execution client for the new genesis:

```bash
function initialize_el() {
  # Example for Geth
  rm -rf /path/to/geth/data
  geth init --datadir /path/to/geth/data /path/to/genesis.json
}
```

Modify this function for your specific execution client (Geth, Nethermind, Besu, etc.).

### 3. Consensus Client Initialization

The `initialize_cl` function prepares your consensus client for the new genesis:

```bash
function initialize_cl() {
  # Example for Lighthouse
  rm -rf /path/to/lighthouse/data
  lighthouse --network ephemery bn --datadir /path/to/lighthouse/data
}
```

Customize for your consensus client (Lighthouse, Prysm, Teku, etc.).

### 4. Client Restart

The `restart_clients` function handles restarting your node services:

```bash
function restart_clients() {
  # Example using systemd
  systemctl restart geth.service
  systemctl restart lighthouse-beacon.service
  systemctl restart lighthouse-validator.service
}
```

Adjust for your service management system (systemd, Docker, etc.).

## Advanced Configuration

### Client-Specific Configurations

#### Geth (Execution Client)

```bash
function initialize_el() {
  rm -rf /path/to/geth/chaindata
  /usr/local/bin/geth init --datadir /path/to/geth /path/to/genesis.json
}
```

#### Nethermind (Execution Client)

```bash
function initialize_el() {
  rm -rf /path/to/nethermind/data
  # Nethermind reads the genesis file from its configuration
  cp /path/to/genesis.json /path/to/nethermind/config/
}
```

#### Lighthouse (Consensus Client)

```bash
function initialize_cl() {
  rm -rf /path/to/lighthouse/beacon
  # Lighthouse automatically uses the new genesis when restarted
}
```

#### Prysm (Consensus Client)

```bash
function initialize_cl() {
  rm -rf /path/to/prysm/beacon
  # Prysm reads genesis from its configuration
  cp /path/to/genesis.ssz /path/to/prysm/config/
}
```

### Docker-Based Configuration

If you're using Docker containers:

```bash
function initialize_el() {
  docker-compose stop execution
  rm -rf /path/to/mounted/el-data
  docker-compose run --rm execution init --datadir /data /genesis/genesis.json
}

function restart_clients() {
  docker-compose down
  docker-compose up -d
}
```

### Validator Key Management

If your validators need special handling during resets:

```bash
function handle_validator_keys() {
  # Backup validator keys before reset
  cp -r /path/to/validator/keys /path/to/backup/

  # Restore after initialization
  mkdir -p /path/to/validator/keys
  cp -r /path/to/backup/* /path/to/validator/keys/

  # Set proper permissions
  chmod 700 /path/to/validator/keys
}
```

Add a call to this function in your script as needed.

## Setting Up Cron

1. Edit your crontab:

   ```bash
   crontab -e
   ```

2. Add the following entry to run every 5 minutes:

   ```
   */5 * * * * /path/to/ephemery-genesis/retention.sh >> /var/log/ephemery-reset.log 2>&1
   ```

3. Verify the cron job is active:

   ```bash
   crontab -l
   ```

## Logging and Monitoring

### Basic Logging

The recommended cron configuration redirects all output to a log file:

```
*/5 * * * * /path/to/ephemery-genesis/retention.sh >> /var/log/ephemery-reset.log 2>&1
```

You can track resets with:

```bash
grep "Reset detected" /var/log/ephemery-reset.log
```

### Enhanced Logging

Add more detailed logging to your script:

```bash
function log_message() {
  echo "[$(date -u)] $1"
}

# Then use throughout the script
log_message "Reset detected, initializing new genesis state"
```

### Monitoring Reset Status

Create a simple status file that monitoring systems can check:

```bash
function update_status() {
  echo "{\"last_reset\":\"$(date -u)\",\"status\":\"$1\",\"genesis_time\":\"$GENESIS_TIME\"}" > /var/lib/ephemery/status.json
}

# Use in script
update_status "reset_started"
# ... perform reset actions ...
update_status "reset_completed"
```

### Prometheus Integration

Create a simple exporter that Prometheus can scrape:

```bash
function update_prometheus_metrics() {
  cat > /var/lib/node_exporter/ephemery_reset.prom << EOF
# HELP ephemery_last_reset_timestamp_seconds Unix timestamp of the last successful reset
# TYPE ephemery_last_reset_timestamp_seconds gauge
ephemery_last_reset_timestamp_seconds $(date +%s)

# HELP ephemery_reset_success Whether the last reset was successful (1) or failed (0)
# TYPE ephemery_reset_success gauge
ephemery_reset_success $1
EOF
}

# Use in script
update_prometheus_metrics 1  # Successful reset
# or
update_prometheus_metrics 0  # Failed reset
```

## Alerting

### Simple Email Alerts

Add email notifications for reset events:

```bash
function send_alert() {
  echo "$1" | mail -s "Ephemery Reset Alert: $2" your-email@example.com
}

# Use in script
send_alert "Reset failed: could not initialize execution client" "Reset Failure"
```

### Integration with Monitoring Systems

For more advanced alerting, integrate with systems like Grafana or PagerDuty:

```bash
function send_webhook_alert() {
  curl -X POST \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"Ephemery Reset Alert: $1\"}" \
    https://your-webhook-url.example.com
}
```

## Troubleshooting

### Common Issues

1. **Script Not Running**
   - Check cron is running: `systemctl status cron`
   - Verify script permissions: `chmod +x retention.sh`
   - Check cron syntax: `crontab -l`

2. **Reset Detection Failures**
   - Verify network connectivity to GitHub
   - Check curl is installed: `which curl`
   - Implement a local fallback mechanism

3. **Client Initialization Failures**
   - Check disk space: `df -h`
   - Verify file permissions on data directories
   - Check client binary paths

4. **Client Restart Failures**
   - Verify service names in systemd: `systemctl list-units`
   - Check service user permissions
   - Review client logs for startup errors

### Debugging Tips

1. **Run Manually with Verbose Logging**

   ```bash
   bash -x ./retention.sh
   ```

2. **Check Specific Function Operation**

   Create a test script:

   ```bash
   #!/bin/bash
   source ./retention.sh
   initialize_el
   echo "EL initialization completed"
   ```

3. **Verify Genesis Files**

   ```bash
   # Check if genesis file was downloaded
   ls -la /path/to/genesis.json

   # Validate JSON format
   jq . /path/to/genesis.json
   ```

## Advanced Features

### Automatic Backups

Add automatic database backups before resets:

```bash
function backup_before_reset() {
  DATE=$(date -u +"%Y-%m-%d-%H-%M")
  tar -czf "/var/backups/ephemery-$DATE.tar.gz" /path/to/client/data
}
```

### Multiple Client Support

Configure the script to handle multiple client configurations:

```bash
function initialize_el() {
  case "$EL_CLIENT" in
    "geth")
      # Geth initialization
      ;;
    "nethermind")
      # Nethermind initialization
      ;;
    *)
      echo "Unknown execution client: $EL_CLIENT"
      exit 1
      ;;
  esac
}
```

### Checkpoint Sync Integration

Add checkpoint sync support to speed up restarts:

```bash
function initialize_cl_with_checkpoint() {
  rm -rf /path/to/consensus/data

  # Try checkpoint sync first
  if lighthouse beacon_node --network ephemery --checkpoint-sync-url https://checkpoint.example.com; then
    log_message "Checkpoint sync successful"
  else
    log_message "Checkpoint sync failed, starting from genesis"
    # Regular initialization here
  fi
}
```

## Best Practices

1. **Test Thoroughly**
   - Test your modified script manually before enabling cron
   - Verify all functions work as expected
   - Create a test environment if possible

2. **Implement Error Handling**
   - Add proper error checking to all functions
   - Implement fallback mechanisms
   - Ensure script exits gracefully on errors

3. **Security Considerations**
   - Run the script with minimal required permissions
   - Avoid using root user when possible
   - Protect validator keys and sensitive data

4. **Performance Optimization**
   - Minimize the downtime during resets
   - Implement efficient database cleaning
   - Consider incremental backups for large databases

## Resetter Script Template

Below is a template that incorporates best practices:

```bash
#!/bin/bash
# Ephemery Testnet Resetter Script
# Configuration variables
EL_CLIENT="geth"  # Options: geth, nethermind, besu, erigon
CL_CLIENT="lighthouse"  # Options: lighthouse, prysm, teku, nimbus, lodestar
DATA_DIR="/var/lib/ephemery"
LOG_FILE="$DATA_DIR/reset.log"
GENESIS_REPO="https://github.com/ephemery-testnet/ephemery-genesis"

# Logging function
log_message() {
  echo "[$(date -u)] $1" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
  log_message "ERROR: $1"
  update_status "reset_failed"
  exit 1
}

# Get last reset time
get_last_reset_time() {
  curl -s https://raw.githubusercontent.com/ephemery-testnet/ephemery-genesis/master/genesis_time.txt || handle_error "Failed to fetch genesis time"
}

# Initialize execution client
initialize_el() {
  log_message "Initializing execution client: $EL_CLIENT"
  case "$EL_CLIENT" in
    "geth")
      rm -rf "$DATA_DIR/geth/chaindata"
      geth init --datadir "$DATA_DIR/geth" "$DATA_DIR/genesis.json" || handle_error "Failed to initialize geth"
      ;;
    # Add other clients here
    *)
      handle_error "Unknown execution client: $EL_CLIENT"
      ;;
  esac
}

# Initialize consensus client
initialize_cl() {
  log_message "Initializing consensus client: $CL_CLIENT"
  case "$CL_CLIENT" in
    "lighthouse")
      rm -rf "$DATA_DIR/lighthouse/beacon"
      # Lighthouse auto-initializes on start
      ;;
    # Add other clients here
    *)
      handle_error "Unknown consensus client: $CL_CLIENT"
      ;;
  esac
}

# Restart clients
restart_clients() {
  log_message "Restarting clients"
  systemctl restart "$EL_CLIENT.service" || handle_error "Failed to restart execution client"
  systemctl restart "$CL_CLIENT-beacon.service" || handle_error "Failed to restart beacon client"
  systemctl restart "$CL_CLIENT-validator.service" || handle_error "Failed to restart validator client"
}

# Update status
update_status() {
  echo "{\"last_check\":\"$(date -u)\",\"status\":\"$1\",\"genesis_time\":\"$GENESIS_TIME\"}" > "$DATA_DIR/status.json"
}

# Main function
main() {
  mkdir -p "$DATA_DIR"
  log_message "Starting Ephemery reset check"
  update_status "checking"

  # Get current genesis time
  GENESIS_TIME=$(get_last_reset_time)
  log_message "Current genesis time: $GENESIS_TIME"

  # Check if we need to reset
  if [ -f "$DATA_DIR/last_genesis_time.txt" ]; then
    LAST_GENESIS_TIME=$(cat "$DATA_DIR/last_genesis_time.txt")
    if [ "$GENESIS_TIME" = "$LAST_GENESIS_TIME" ]; then
      log_message "No reset needed, genesis time unchanged"
      update_status "up_to_date"
      exit 0
    fi
  fi

  # Reset needed
  log_message "Reset detected, initializing for genesis time: $GENESIS_TIME"
  update_status "resetting"

  # Download latest genesis files
  log_message "Downloading latest genesis files"
  curl -s "https://raw.githubusercontent.com/ephemery-testnet/ephemery-genesis/master/genesis.json" > "$DATA_DIR/genesis.json" || handle_error "Failed to download genesis.json"
  curl -s "https://raw.githubusercontent.com/ephemery-testnet/ephemery-genesis/master/genesis.ssz" > "$DATA_DIR/genesis.ssz" || handle_error "Failed to download genesis.ssz"

  # Initialize clients
  initialize_el
  initialize_cl

  # Restart services
  restart_clients

  # Update last genesis time
  echo "$GENESIS_TIME" > "$DATA_DIR/last_genesis_time.txt"

  log_message "Reset completed successfully"
  update_status "reset_completed"
}

# Run main function
main
```

## Related Resources

- [Genesis Validator Guide](./GENESIS_VALIDATOR.md)
- [Client Configuration Guide](./CLIENT_CONFIGURATION.md)
- [Monitoring Setup Guide](./MONITORING_SETUP.md)

## Changelog

- **v1.0.0** - Initial guide creation
- **v1.0.1** - Added advanced monitoring recommendations
- **v1.1.0** - Added multi-client configuration examples
