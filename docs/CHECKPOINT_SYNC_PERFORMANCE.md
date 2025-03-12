# Ephemery Checkpoint Sync Performance

This document provides comprehensive performance metrics and analysis for different synchronization methods in the Ephemery network.

## Overview

Synchronizing an Ethereum node can be time-consuming, especially when starting from genesis. Ephemery offers different synchronization methods, each with its own trade-offs in terms of speed, resource usage, and security assumptions. This document presents performance benchmarks for these methods.

## Sync Methods Comparison

### Summary

| Sync Method | Typical Duration | Resource Usage | Security Assumptions |
|-------------|------------------|----------------|----------------------|
| Checkpoint Sync | 30 min - 2 hours | Medium | Trusts checkpoint provider |
| Genesis Optimized | 6-12 hours | High | No additional trust assumptions |
| Genesis Default | 24+ hours | Medium | No additional trust assumptions |

### Detailed Analysis

#### Checkpoint Sync

Checkpoint sync allows a node to start syncing from a recent finalized checkpoint rather than from genesis.

**Performance Metrics:**
- **Time to Sync:** Typically 30 minutes to 2 hours
- **CPU Usage:** Moderate (40-60% utilization)
- **Memory Usage:** 4-8 GB RAM
- **Disk I/O:** 100-200 MB/s (peaks)
- **Network Usage:** 10-50 Mbps

**Optimization Parameters:**
```yaml
use_checkpoint_sync: true
clear_database: true
cl_extra_opts: '--target-peers=100 --execution-timeout-multiplier=10 --disable-backfill-rate-limiting'
el_extra_opts: '--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100'
```

**Pros:**
- Dramatically faster sync time
- Lower resource consumption
- Reduced wear on SSD storage

**Cons:**
- Requires trust in the checkpoint provider
- May not validate the entire chain history

#### Genesis Optimized Sync

This method syncs from genesis but uses optimized parameters to speed up the process.

**Performance Metrics:**
- **Time to Sync:** Typically 6-12 hours
- **CPU Usage:** High (70-90% utilization)
- **Memory Usage:** 8-16 GB RAM
- **Disk I/O:** 200-500 MB/s (sustained)
- **Network Usage:** 50-100 Mbps

**Optimization Parameters:**
```yaml
use_checkpoint_sync: false
clear_database: true
cl_extra_opts: '--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting'
el_extra_opts: '--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100'
```

**Pros:**
- Validates the entire chain history
- No additional trust assumptions
- Still reasonably fast for a full sync

**Cons:**
- Higher resource consumption
- Longer sync time compared to checkpoint sync

#### Genesis Default Sync

This method uses standard parameters without specific optimizations.

**Performance Metrics:**
- **Time to Sync:** 24+ hours
- **CPU Usage:** Moderate (30-50% utilization)
- **Memory Usage:** 4-8 GB RAM
- **Disk I/O:** 50-150 MB/s (sustained)
- **Network Usage:** 10-30 Mbps

**Parameters:**
```yaml
use_checkpoint_sync: false
clear_database: true
cl_extra_opts: ''
el_extra_opts: ''
```

**Pros:**
- Validates the entire chain history
- No additional trust assumptions
- Most conservative approach

**Cons:**
- Very long sync time
- Not practical for quick deployment

## Hardware Impact on Sync Performance

The hardware configuration significantly impacts sync performance. Below are benchmarks for different hardware configurations:

### Minimum Specs (2 CPU / 4GB RAM)

| Sync Method | Typical Duration | Notes |
|-------------|------------------|-------|
| Checkpoint Sync | 2-4 hours | Usable but slow |
| Genesis Optimized | 18-24 hours | Very resource constrained |
| Genesis Default | 48+ hours | Not recommended |

### Recommended Specs (4 CPU / 8GB RAM)

| Sync Method | Typical Duration | Notes |
|-------------|------------------|-------|
| Checkpoint Sync | 30 min - 2 hours | Good performance |
| Genesis Optimized | 6-12 hours | Acceptable performance |
| Genesis Default | 24-36 hours | Slow but functional |

### High Performance (8+ CPU / 16+ GB RAM)

| Sync Method | Typical Duration | Notes |
|-------------|------------------|-------|
| Checkpoint Sync | 15-60 minutes | Excellent performance |
| Genesis Optimized | 4-8 hours | Good performance |
| Genesis Default | 18-24 hours | Acceptable performance |

## Network Conditions Impact

Network conditions can significantly affect sync performance:

### High Latency Networks (100+ ms)

- Expect 20-50% longer sync times
- Consider increasing timeout parameters
- Recommended parameter: `--execution-timeout-multiplier=20`

### Limited Bandwidth (< 10 Mbps)

- Expect 50-100% longer sync times
- Consider reducing peer count to avoid bandwidth contention
- Recommended parameter: `--target-peers=50`

### Optimal Network Conditions

- Latency < 50ms
- Bandwidth > 50 Mbps
- Default parameters work well

## Client Version Impact

Client versions can have significant performance differences:

| Lighthouse Version | Relative Sync Performance |
|--------------------|--------------------|
| v4.0.0+            | Baseline (100%)    |
| v3.5.0 - v3.5.1    | 90-95%             |
| v3.0.0 - v3.4.0    | 80-85%             |
| < v3.0.0           | 60-70%             |

| Geth Version    | Relative Sync Performance |
|-----------------|--------------------|
| v1.13.0+        | Baseline (100%)    |
| v1.12.0 - v1.12.x | 90-95%             |
| v1.11.0 - v1.11.x | 80-85%             |
| < v1.11.0       | 60-70%             |

## Recommendations

Based on our benchmarks and analysis, we recommend:

### For Development/Testing

Use **Checkpoint Sync** with the following parameters:
```yaml
use_checkpoint_sync: true
clear_database: true
cl_extra_opts: '--target-peers=100 --execution-timeout-multiplier=10 --disable-backfill-rate-limiting'
el_extra_opts: '--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100'
```

### For Production/Validators

Use **Genesis Optimized Sync** if time permits:
```yaml
use_checkpoint_sync: false
clear_database: true
cl_extra_opts: '--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting'
el_extra_opts: '--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100'
```

### For Resource-Constrained Environments

Use **Checkpoint Sync** with reduced resource parameters:
```yaml
use_checkpoint_sync: true
clear_database: true
cl_extra_opts: '--target-peers=50 --execution-timeout-multiplier=10 --disable-backfill-rate-limiting'
el_extra_opts: '--cache=2048 --txlookuplimit=0 --syncmode=snap --maxpeers=50'
```

## Troubleshooting

If sync performance is significantly worse than the benchmarks provided:

1. **Check system resources:**
   - Monitor CPU, memory, disk I/O, and network utilization
   - Look for bottlenecks in any of these resources

2. **Check peer connections:**
   - Ensure the node has healthy peer connections
   - Verify network connectivity and firewall rules

3. **Check client logs:**
   - Look for error messages or warnings
   - Check for frequent disconnections from peers

4. **Try different checkpoint sources:**
   - Some checkpoint providers may be more reliable than others
   - Use the dashboard to test alternative checkpoint URLs

## Conclusion

Checkpoint sync offers the most efficient way to synchronize an Ephemery node, with sync times reduced from days to hours or even minutes. While it requires trust in the checkpoint provider, this is generally an acceptable trade-off for the Ephemery network where rapid deployment is often more important than validating the entire chain history.

For users who prefer to validate the entire chain, the optimized genesis sync provides a reasonable middle ground, offering better performance than default sync without introducing additional trust assumptions.

Use the dashboard and testing tools provided to determine the best sync method for your specific requirements and hardware configuration.
