# Fixing Checkpoint Sync Bottlenecks in Ephemery

This document provides detailed instructions on how to fix checkpoint sync bottlenecks in the Ephemery testnet nodes.

## Background

The Ephemery testnet nodes may experience significant sync time bottlenecks when using genesis sync, as reported in the client sync status report. This can result in sync times of up to 24 days, which is impractical for a testnet environment. The primary issue is that the consensus client (Lighthouse) is not properly utilizing checkpoint sync.

## Solutions Implemented

We've created two tools to fix these bottlenecks:

1. **fix_checkpoint_sync.yaml playbook**: An Ansible playbook to reconfigure and restart the Lighthouse client with proper checkpoint sync settings.
2. **check_sync_status.sh script**: A diagnostic script to monitor the sync progress and verify that checkpoint sync is working correctly.

## How to Fix Checkpoint Sync Bottlenecks

### Option 1: Run the Fix Playbook (Recommended)

The fastest way to fix checkpoint sync issues is to run the provided Ansible playbook:

```bash
ansible-playbook fix_checkpoint_sync.yaml -i your_inventory.yaml
```

This playbook will:
- Stop the existing Lighthouse container
- Clear the consensus client database (to start fresh)
- Configure checkpoint sync with optimal settings
- Add additional bootstrap nodes for better peer connectivity
- Restart the Lighthouse client with the proper configuration
- Verify the sync has started properly

### Option 2: Manual Configuration Updates

If you prefer to make the changes manually:

1. **Update Configuration**:
   Edit your inventory or host_vars file to include:

   ```yaml
   use_checkpoint_sync: true
   clear_database: true  # Set to true for the first run, then set back to false
   checkpoint_sync_url: "https://checkpoint-sync.ephemery.ethpandaops.io/"
   ```

2. **Add Bootstrap Nodes**:
   Include additional bootstrap nodes for better connectivity:

   ```yaml
   bootstrap_nodes:
     - "/ip4/157.90.35.151/tcp/9000/p2p/16Uiu2HAmVZnsqvTNQ2ya1YG2qi6DQchqX57jF9zN2CukZnQY84wJ"
     - "/ip4/136.243.15.66/tcp/9000/p2p/16Uiu2HAmAwGWqGShumBQeUuivDyRMmCZjvbZsQwcEWYYLDVKvFjG"
     - "/ip4/88.198.2.150/tcp/9000/p2p/16Uiu2HAm8cEfaKtweXbT4koAuifKKJPm8q7TdpaVfWk9j5E5L2m3"
     - "/ip4/135.181.91.151/tcp/9000/p2p/16Uiu2HAmEP7X3JDcdAYLagNQxpJ24n3HDwLGxVVsWyv2aUHrXA5b"
   ```

3. **Restart the Node**:
   Run the main Ephemery playbook to apply your changes:

   ```bash
   ansible-playbook ephemery.yaml -i your_inventory.yaml
   ```

## Monitoring Sync Progress

Use the included diagnostic script to check sync progress:

```bash
./scripts/check_sync_status.sh
```

This script will show:
- Container status
- Execution client (Geth) sync status
- Consensus client (Lighthouse) sync status
- Whether checkpoint sync is working
- Estimated time to completion
- Recommendations for fixing any detected issues

## Troubleshooting Common Issues

### Checkpoint Sync Not Working

If checkpoint sync is still not working after running the fix:

1. **Check Checkpoint URL**:
   Verify that the checkpoint sync URL is accessible and contains valid data for Ephemery:

   ```bash
   curl https://checkpoint-sync.ephemery.ethpandaops.io/
   ```

2. **Check Lighthouse Logs**:
   Look for any errors related to checkpoint sync:

   ```bash
   docker logs ephemery-lighthouse | grep -i checkpoint
   ```

3. **Force Database Reset**:
   Sometimes a complete reset of the database is needed:

   ```bash
   ansible-playbook fix_checkpoint_sync.yaml -i your_inventory.yaml -e "clear_database=true"
   ```

### Low Peer Count

If your node has fewer than 5 peers:

1. **Check Network Connectivity**:
   Ensure ports 9000 TCP/UDP are open in your firewall.

2. **Add More Bootstrap Nodes**:
   You can add more bootstrap nodes to your configuration if needed.

3. **Check Discord or Community Resources**:
   The Ephemery community may have additional bootstrap nodes to try.

### Execution Client Not Syncing

If your execution client (Geth) isn't syncing:

1. **Verify JWT Authentication**:
   Ensure the JWT secret is properly configured and shared between clients:

   ```bash
   ls -la /opt/ephemery/jwt.hex
   ```

2. **Check Engine API Configuration**:
   Verify that the Engine API is properly configured between Geth and Lighthouse.

3. **Restart Geth**:
   Sometimes restarting the execution client helps:

   ```bash
   docker restart ephemery-geth
   ```

## Expected Results

After implementing these fixes, you should see:

1. Lighthouse head slot increasing rapidly
2. Sync distance decreasing significantly
3. Estimated sync time reduced from days to hours
4. Peer count increasing to 10+ peers
5. Once the consensus client syncs, the execution client will also begin syncing

## Conclusion

By enabling checkpoint sync and adding proper bootstrap nodes, the Ephemery node sync time should be dramatically reduced from weeks to hours. This makes the network much more usable for testing and development purposes.

If you continue to experience issues, please reach out to the Ephemery community on Discord or GitHub.
