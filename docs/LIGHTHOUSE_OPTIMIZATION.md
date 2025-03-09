# Client Optimization Guide for Ephemery Network

This document provides guidance on optimizing both Lighthouse (Consensus Layer) and Geth (Execution Layer) for the Ephemery network, including recommended parameters, resource allocation, and monitoring procedures.

## Recommended Consensus Layer (Lighthouse) Parameters

```yaml
cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
```

### Parameter Explanations:

- `--target-peers=100`: Increases target peer count for faster data acquisition
- `--execution-timeout-multiplier=5`: Increases timeout multiplier to prevent execution client timeouts
- `--allow-insecure-genesis-sync`: Enables genesis sync for faster initial sync without requiring checkpoint sync
- `--genesis-backfill`: Optimizes historical data sync from genesis
- `--disable-backfill-rate-limiting`: Removes rate limiting for faster backfill operation

## Recommended Execution Layer (Geth) Parameters

```yaml
el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"
```

### Parameter Explanations:

- `--cache=4096`: Allocates 4GB of memory to the database cache for faster processing
- `--txlookuplimit=0`: Disables transaction lookup limit to reduce database size
- `--syncmode=snap`: Uses snap sync mode which is faster than full sync
- `--maxpeers=100`: Increases maximum peer connections for better network connectivity

## Resource Allocation Strategy

For optimal performance, allocate system resources as follows:

```yaml
# Resource allocation percentages (from total available system memory)
el_memory_percentage: 0.5  # 50% for execution client (Geth)
cl_memory_percentage: 0.4  # 40% for consensus client (Lighthouse)
validator_memory_percentage: 0.1  # 10% for validator (if enabled)
```

### Recommended Hardware:

- **Memory**: Minimum 8GB, recommended 16GB
- **CPU**: Minimum 4 cores, recommended 8 cores
- **Disk**: Minimum 100GB SSD, recommended 200GB NVMe SSD

## System Optimization

### Memory Management

For optimal client performance, configure the following system parameters:

```bash
# Set via sysctl
sysctl -w vm.max_map_count=262144
sysctl -w vm.swappiness=10
sysctl -w fs.file-max=65536

# Make permanent by adding to /etc/sysctl.conf
echo "vm.max_map_count=262144" >> /etc/sysctl.conf
echo "vm.swappiness=10" >> /etc/sysctl.conf
echo "fs.file-max=65536" >> /etc/sysctl.conf
```

## Client-Specific Images

Always use the Ephemery-specific client images for best performance:

```yaml
client_images:
  geth: 'pk910/ephemery-geth:v1.15.3'
  lighthouse: 'pk910/ephemery-lighthouse:latest'
  validator: 'pk910/ephemery-lighthouse:latest'
```

## Sync Strategy

For optimal sync performance:

```yaml
# Recommended sync settings
use_checkpoint_sync: false  # Genesis sync with optimizations is more reliable
clear_database: true  # Starts with a clean database
```

## Monitoring and Troubleshooting

### Monitoring Sync Progress

```bash
# Check EL sync status
docker logs ephemery-geth | grep -i sync | tail

# Check CL sync status
docker logs ephemery-lighthouse | grep -i sync | tail

# Check CL peer count
curl -s http://localhost:5052/eth/v1/node/peer_count | jq
```

### Key Metrics to Monitor

1. **Execution Layer Sync Status**
   - Watch for "Imported new chain segment" messages
   - Verify "Snap sync" is properly enabled

2. **Consensus Layer Sync Status**
   - Monitor decreasing "distance" metrics in sync logs
   - Track peer count (should be close to target)

3. **Resource Utilization**
   - CPU usage (should not consistently be at 100%)
   - Memory usage (watch for OOM errors)
   - Disk I/O (high sustained I/O can indicate bottlenecks)

### Common Issues and Solutions

#### Slow or Stalled Sync

If sync is progressing slowly or stalled:

1. **Check peer connections**:
   ```bash
   curl -s http://localhost:5052/eth/v1/node/peer_count | jq
   ```
   If low, ensure your firewall allows port 9000 (TCP/UDP) and 30303 (TCP/UDP)

2. **Verify JWT authentication**:
   ```bash
   # Check for JWT-related errors in logs
   docker logs ephemery-geth | grep -i jwt
   docker logs ephemery-lighthouse | grep -i jwt
   ```

3. **Increase resource allocation** if possible

4. **Reset the databases** if corruption is suspected:
   ```yaml
   ephemery:
     hosts:
       ephemery-node1:
         clear_database: true
   ```

## Advanced Manual Deployment

For advanced users who prefer manual deployment:

```bash
# Stop and remove existing containers
docker stop ephemery-lighthouse ephemery-geth
docker rm ephemery-lighthouse ephemery-geth

# Clear databases
sudo rm -rf /opt/ephemery/data/lighthouse/*
sudo rm -rf /opt/ephemery/data/geth/*

# Start Geth with optimized flags
docker run -d --name ephemery-geth --restart=unless-stopped --network=host \
  -v /opt/ephemery/data/geth:/data \
  -v /opt/ephemery/jwt.hex:/jwt.hex \
  pk910/ephemery-geth:v1.15.3 \
  --datadir=/data \
  --authrpc.jwtsecret=/jwt.hex \
  --http --http.api=eth,net,web3,engine \
  --http.addr=0.0.0.0 --http.corsdomain=* --http.vhosts=* \
  --ws --ws.api=eth,net,web3,engine \
  --ws.addr=0.0.0.0 --ws.origins=* \
  --cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100

# Start Lighthouse with optimized flags
docker run -d --name ephemery-lighthouse --restart=unless-stopped --network=host \
  -v /opt/ephemery/jwt.hex:/jwt.hex \
  -v /opt/ephemery/data/lighthouse:/data \
  -v /opt/ephemery/config/ephemery_network:/ephemery_config \
  pk910/ephemery-lighthouse:latest lighthouse beacon_node \
  --datadir=/data --execution-jwt=/jwt.hex --execution-endpoint=http://127.0.0.1:8551 \
  --http --http-address=0.0.0.0 --http-port=5052 --metrics --metrics-address=0.0.0.0 \
  --metrics-port=5054 --testnet-dir=/ephemery_config --target-peers=100 \
  --execution-timeout-multiplier=5 --allow-insecure-genesis-sync \
  --genesis-backfill --disable-backfill-rate-limiting
```

## Ephemery-Specific Considerations

Since Ephemery is reset periodically:

1. Consider scheduling your own resets to align with network resets
2. Maintain backups of important validator data
3. Verify client compatibility after each reset

## Resources

- [Ephemery Network Resources](https://github.com/ephemery-testnet/ephemery-resources)
- [Lighthouse Documentation](https://lighthouse-book.sigmaprime.io/)
- [Geth Documentation](https://geth.ethereum.org/docs/)
