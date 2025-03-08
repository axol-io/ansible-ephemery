# Lighthouse Optimization Guide for Ephemery Network

This document provides guidance on optimizing Lighthouse for the Ephemery network, including recommended parameters, monitoring, and maintenance procedures.

## Recommended Runtime Parameters

The following parameters are recommended for optimal Lighthouse performance on Ephemery network:

```yaml
cl_extra_opts: >-
  --execution-endpoint=http://localhost:8551
  --checkpoint-sync-url=https://checkpoint-sync.ephemery.dev
  --testnet-dir=/ephemery_config
  --metrics
  --metrics-address=0.0.0.0
  --metrics-port=5054
  --heap-profiling-dir=/data/heap_profiles
  --execution-timeout=60
  --genesis-backfill
  --database-schema=v11
  --target-peers=70
  --disable-deposit-contract-sync
  --prune-payloads
```

### Parameter Explanations:

- `--checkpoint-sync-url`: Enables fast sync from a trusted checkpoint
- `--genesis-backfill`: Fills in historical blocks from genesis in the background
- `--database-schema=v11`: Uses the optimized v11 database schema
- `--target-peers=70`: Maintains a healthy network connection
- `--disable-deposit-contract-sync`: Reduces unnecessary operations for testnet
- `--prune-payloads`: Reduces disk usage by pruning execution payloads

## System Optimization

### Memory Management

For optimal Lighthouse performance, configure the following system parameters:

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

### Resource Allocation

Allocate appropriate resources to Lighthouse:

- **Memory**: Minimum 8GB, recommended 16GB
- **CPU**: Minimum 4 cores, recommended 8 cores
- **Disk**: Minimum 100GB SSD, recommended 200GB NVMe SSD

## Database Maintenance

Regular database maintenance helps keep Lighthouse running efficiently:

### Weekly Database Compaction

```bash
# Run manually
./lighthouse_db_maintenance.sh compact

# Or set up a cron job (recommended)
0 3 * * 0 /path/to/lighthouse_db_maintenance.sh compact >> /path/to/logs/cron.log 2>&1
```

### Database Integrity Check

If you suspect database corruption:

```bash
./lighthouse_db_maintenance.sh check
```

## Monitoring and Troubleshooting

### Key Metrics to Monitor

1. **Sync Status**
   - Ensure sync percentage is advancing
   - Monitor for "Synced" message in logs

2. **Database Performance**
   - RocksDB compaction stats
   - Database size growth over time

3. **Memory Usage**
   - Heap usage patterns (using `--heap-profiling-dir`)
   - GC cycle frequency and duration

4. **Network Performance**
   - Peer count (should be close to target)
   - Gossip message validation rate

### Common Issues and Solutions

#### Slow Sync

If sync is progressing slowly:

1. Verify you're using checkpoint sync
2. Check network connectivity and peer count
3. Increase resource allocation if possible
4. Consider database compaction if disk I/O is high

#### High Memory Usage

If memory usage is excessive:

1. Analyze heap profiles
2. Consider adjusting garbage collection settings
3. Ensure proper memory allocation between clients

#### Database Corruption

If you encounter database errors:

1. Stop Lighthouse
2. Run database integrity check
3. If issues persist, consider rebuilding the database with checkpoint sync

## Advanced Optimization

For further optimization, consider the following:

### Custom RocksDB Options

```yaml
cl_extra_opts: >-
  ... existing options ...
  --db-cache-size=2GB
  --db-backup-path=/path/to/backups
  --unsafe-db-tuning-level=3
```

### Garbage Collection Tuning

For advanced JVM-based garbage collection tuning (applicable to newer Lighthouse versions):

```yaml
cl_extra_opts: >-
  ... existing options ...
  --gc=parallel
  --gc-threads=4
```

## Ephemery-Specific Considerations

Since Ephemery is reset periodically, consider:

1. Automating database cleanup after resets
2. Using checkpoint sync after each reset
3. Monitoring for network changes post-reset

## Resources

- [Lighthouse Documentation](https://lighthouse-book.sigmaprime.io/)
- [Ephemery Network Resources](https://github.com/ephemery-testnet/ephemery-resources)
- [RocksDB Tuning Guide](https://github.com/facebook/rocksdb/wiki/RocksDB-Tuning-Guide)
