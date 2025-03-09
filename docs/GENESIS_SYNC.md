# Checkpoint Sync for Lighthouse

This document provides information on how to use and troubleshoot checkpoint sync for the Lighthouse consensus client in the Ephemery network.

## What is Checkpoint Sync?

Checkpoint sync allows a consensus client to sync from a trusted checkpoint rather than starting from genesis. This significantly reduces the time required to sync a new node, from days to minutes.

## Configuration

Checkpoint sync is enabled by default in the Ephemery Ansible playbooks. The following parameters are used:

```yaml
cl_extra_opts: "--checkpoint-sync-url=https://checkpoint-sync.ephemery.ethpandaops.io/ --genesis-backfill --database-schema=v11 --target-peers=70 --disable-deposit-contract-sync --prune-payloads --allow-insecure-genesis-sync --enable-backfill-rate-limiting --execution-timeout-multiplier=60 --heap-profiling-dir=/data/heap_profiles"
```

Key parameters:
- `--checkpoint-sync-url`: The URL of the checkpoint sync service
- `--allow-insecure-genesis-sync`: Allows syncing from a checkpoint even if the genesis block doesn't match
- `--genesis-backfill`: Backfills blocks from the checkpoint to genesis
- `--enable-backfill-rate-limiting`: Limits the rate of backfilling to prevent resource exhaustion

## Using Checkpoint Sync

To deploy a node with checkpoint sync:

1. Ensure your inventory.yaml file includes the checkpoint sync parameters in `cl_extra_opts`
2. Run the standard deployment playbook:
   ```
   ansible-playbook -i ansible/inventory.yaml ansible/playbooks/main.yaml
   ```

To restart a node with checkpoint sync (useful if you need to clear the database and start fresh):

1. Run the restart_lighthouse.yaml playbook:
   ```
   ansible-playbook -i ansible/inventory.yaml ansible/playbooks/restart_lighthouse.yaml -e "clear_database=true"
   ```

## Checking Sync Status

A script is provided to check the status of checkpoint sync:

```bash
/path/to/ephemery/scripts/check_checkpoint_sync.sh
```

This script will:
- Check if the Lighthouse container is running
- Query the Lighthouse API for sync status
- Check logs for checkpoint sync activity
- Report any errors or issues

## Troubleshooting

### Common Issues

1. **Block root mismatch**

   If you see errors like "Block root in checkpoint response does not match expected genesis block root", try:
   - Adding `--allow-insecure-genesis-sync` to your cl_extra_opts
   - Clearing the database and restarting: `ansible-playbook -i ansible/inventory.yaml ansible/playbooks/restart_lighthouse.yaml -e "clear_database=true"`

2. **JWT authentication issues**

   If you see errors related to JWT authentication:
   - Ensure the JWT secret file exists and is accessible to both the execution and consensus clients
   - Check that the path to the JWT file is correct in both client configurations

3. **Connection to execution client fails**

   If Lighthouse cannot connect to the execution client:
   - Ensure Geth is running and the Engine API is enabled
   - Check that the execution endpoint URL is correct
   - Verify that the execution client is fully synced

4. **Checkpoint sync service unavailable**

   If the checkpoint sync service is unavailable:
   - Try an alternative checkpoint sync URL
   - Available alternatives:
     - `https://beaconstate.ethstaker.cc`
     - `https://sync-mainnet.beaconcha.in`
     - `https://mainnet-checkpoint-sync.attestant.io`

## Alternative Checkpoint Sync URLs

If the default checkpoint sync URL is not working, you can try one of these alternatives:

For Ephemery network:
- `https://checkpoint-sync.ephemery.ethpandaops.io/`

For Mainnet (if you're adapting this for mainnet):
- `https://beaconstate.ethstaker.cc`
- `https://sync-mainnet.beaconcha.in`
- `https://mainnet-checkpoint-sync.attestant.io`

## Monitoring Sync Progress

You can monitor the sync progress using the Lighthouse API:

```bash
curl -s http://localhost:5052/eth/v1/node/syncing | jq
```

This will show the current head slot and sync distance, which indicates how many slots are left to sync.
