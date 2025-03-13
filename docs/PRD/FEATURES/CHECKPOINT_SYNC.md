# Optimized Sync for Ephemery

This document explains how to optimize sync performance for both Execution Layer (EL) and Consensus Layer (CL) clients in the Ephemery network.

## Overview

There are two sync strategies available for Consensus Layer clients in the Ephemery network:

1. **Genesis Sync**: More thorough sync from genesis block, but slower without optimizations
2. **Checkpoint Sync**: Faster initial sync by using a trusted checkpoint provider

**NOTE:** As of our latest testing, Ephemery offers flexible sync options:
- **Enhanced checkpoint sync** with our automatic URL testing and recovery system is recommended for faster initial sync
- **Genesis sync with optimized parameters** is available as an alternative for environments where checkpoint sync isn't working

For details on the enhanced checkpoint sync system, see [Checkpoint Sync Fix](./CHECKPOINT_SYNC_FIX.md).

## Implementation Status

Checkpoint sync has been implemented in the following components:

1. **Ansible Playbooks**: Fully implemented with automated URL testing and fallback
2. **Standalone Scripts**:
   - `setup_ephemery.sh` now includes checkpoint sync by default
   - `setup_ephemery_validator.sh` coordinates with checkpoint sync settings
   - Command-line options for enabling/disabling checkpoint sync in all scripts

This implementation is based on comprehensive technical findings documented in [Node Setup Technical Findings](./NODE_SETUP_TECHNICAL_FINDINGS.md).

## Optimized Configuration

### Recommended Settings

For optimal sync performance in both execution and consensus layers, use these settings in your inventory or host_vars file:

```yaml
ephemery:
  hosts:
    ephemery-node1:
      # Set to true for checkpoint sync (recommended), false for genesis sync
      use_checkpoint_sync: true
      # Clear database for a fresh start
      clear_database: true
      # Lighthouse optimization parameters for faster sync
      cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
      # Geth optimization parameters for faster sync
      el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"
```

These optimized parameters provide:
- Faster execution layer sync using Geth's snap sync and optimized cache
- Accelerated consensus layer sync with checkpoint sync and network optimizations
- Better resource utilization and peer connections

## Standalone Script Usage

The standalone scripts now support checkpoint sync with the following options:

```bash
# Enable checkpoint sync (default)
./setup_ephemery.sh

# Disable checkpoint sync
./setup_ephemery.sh --no-checkpoint-sync

# Specify a custom checkpoint sync URL
./setup_ephemery.sh --checkpoint-url https://custom-checkpoint-provider.example.com

# Reset database and use checkpoint sync
./setup_ephemery.sh --reset --checkpoint-sync
```

These options provide flexibility for different deployment scenarios while maintaining the performance benefits of checkpoint sync.

## Configuration Options

The Ephemery Ansible playbooks provide the following variables to control sync strategy:

| Variable | Description | Recommended Value |
|----------|-------------|------------------|
| `use_checkpoint_sync` | Whether to use checkpoint sync (true) or genesis sync (false) | `true` for speed, `false` for environments where checkpoint sync isn't working |
| `clear_database` | Whether to clear the database before starting the client (useful for resetting) | `true` |
| `cl_extra_opts` | Extra optimization flags for the consensus client | See recommended settings |
| `el_extra_opts` | Extra optimization flags for the execution client | See recommended settings |

## Execution Layer (Geth) Optimization Flags

The following flags are recommended for Geth to optimize sync performance:

| Flag | Recommended Value | Description |
|------|------------------|-------------|
| `--cache` | `4096` | Memory allocated for internal caching (MB) |
| `--txlookuplimit` | `0` | Number of recent blocks to maintain transactions index (0 = entire chain) |
| `--syncmode` | `snap` | Blockchain sync mode (snap is faster than full) |
| `--maxpeers` | `100` | Maximum number of network peers |

## Consensus Layer (Lighthouse) Optimization Flags

The following flags are recommended for Lighthouse to optimize sync performance:

| Flag | Description |
|------|-------------|
| `--target-peers` | Target number of peer connections to maintain |
| `--execution-timeout-multiplier` | Multiplier for execution engine timeouts |
| `--allow-insecure-genesis-sync` | Allow faster but slightly less secure genesis sync |
| `--genesis-backfill` | Speeds up genesis sync by backfilling blocks |
| `--disable-backfill-rate-limiting` | Removes rate limits on backfill process |

## Enhanced Checkpoint Sync

We recommend using our enhanced checkpoint sync system which:

1. Automatically tests multiple checkpoint sync URLs
2. Selects the fastest responding URL
3. Configures clients with optimized parameters
4. Monitors synchronization progress
5. Provides recovery mechanisms for stalled syncs

For more information, see the [Checkpoint Sync Fix](./CHECKPOINT_SYNC_FIX.md) documentation.

## Troubleshooting Sync Issues

If you encounter sync issues:

1. **Try enhanced checkpoint sync**: Run the enhanced checkpoint sync script:
   ```bash
   ./scripts/maintenance/enhanced_checkpoint_sync.sh --apply
   ```
2. **Clear databases and restart**: Set `clear_database: true` and re-run the playbook
3. **Check peer connectivity**: Ensure your node can connect to a sufficient number of peers
4. **Verify system resources**: Ensure your system meets minimum hardware requirements
5. **Review client logs**: Check for errors in the client logs (available in `/var/log/ethereum/`)
6. **Try genesis sync**: If checkpoint sync continues to fail, try setting `use_checkpoint_sync: false` as a fallback

## Technical Findings

Our comprehensive node setup evaluations have revealed several technical findings related to checkpoint sync:

1. **Sync Speed Improvement**: Checkpoint sync reduces initial synchronization time by 60-80%
2. **Peer Connection Impact**: Initial peer count is critical for checkpoint sync success
3. **Common Error Patterns**: "Missing parent" errors are significantly reduced with checkpoint sync
4. **Resource Utilization**: Database and CPU loads are more evenly distributed during checkpoint sync

For more detailed findings, refer to [Node Setup Technical Findings](./NODE_SETUP_TECHNICAL_FINDINGS.md).

## Related Documentation

- [Checkpoint Sync Fix](./CHECKPOINT_SYNC_FIX.md)
- [Enhanced Checkpoint Sync](./ENHANCED_CHECKPOINT_SYNC.md)
- [Node Setup Technical Findings](./NODE_SETUP_TECHNICAL_FINDINGS.md)
- [Genesis Validator Guide](../OPERATIONS/GENESIS_VALIDATOR.md)
- [Resetter Configuration](../OPERATIONS/RESETTER_CONFIGURATION.md)
- [Sync Monitoring](./SYNC_MONITORING.md)

## Support

If you continue to experience sync issues after trying these recommendations, please reach out to the Ephemery community for assistance.
