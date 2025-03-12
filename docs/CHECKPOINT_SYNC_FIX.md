# Fixing Checkpoint Sync Issues in Ephemery

This document provides instructions for fixing checkpoint sync issues in the Ephemery network using the `fix_checkpoint_sync.yaml` playbook.

## Overview

Checkpoint sync is a method to significantly accelerate the initial sync process of consensus layer clients by starting from a recent trusted checkpoint rather than from genesis. However, checkpoint sync can sometimes fail due to various issues:

1. The checkpoint sync URL may be unreachable or not working
2. The checkpoint sync may be disabled in the configuration
3. There might be timeout issues with the checkpoint sync
4. The client configuration might not have proper optimization flags

The `fix_checkpoint_sync.yaml` playbook addresses these issues by:
- Testing multiple checkpoint sync URLs and selecting the best one
- Configuring Lighthouse with optimized parameters
- Implementing network optimizations
- Creating monitoring tools to ensure checkpoint sync is working correctly
- Providing automated alerting for sync issues with automatic recovery

## Prerequisites

Before running the fix, ensure:

1. You have SSH access to your Ephemery node
2. The ansible-ephemery repository is cloned and set up on your local machine
3. You have the correct inventory file configured with your node information

## Using the Fix Checkpoint Sync Playbook

### Running the Playbook

1. Navigate to your ansible-ephemery directory:
   ```
   cd /path/to/ansible-ephemery
   ```

2. Run the playbook:
   ```
   ansible-playbook fix_checkpoint_sync.yaml -i inventory.yaml
   ```

3. Wait for the playbook to complete. It will:
   - Test multiple checkpoint sync URLs
   - Update your inventory file with a working URL
   - Reset the Lighthouse database for a clean sync
   - Start Lighthouse with optimized parameters
   - Create monitoring scripts
   - Install an alert system for ongoing monitoring

### What the Playbook Does

1. **Tests checkpoint sync URLs**: The playbook tests multiple checkpoint sync URLs and selects the one that responds correctly.

2. **Updates inventory**: It updates your inventory file to enable checkpoint sync and use the working URL.

3. **Resets Lighthouse**: It stops the Lighthouse container, removes the database, and starts a new container with optimized settings.

4. **Adds network optimizations**: It applies network optimizations to improve sync performance.

5. **Creates monitoring**: It creates a monitoring script that can detect and recover from checkpoint sync issues.

6. **Installs alert system**: It sets up a systemd service that continuously monitors the checkpoint sync progress and sends alerts when issues are detected.

## Monitoring the Sync Progress

After running the playbook, you can monitor the sync progress using:

1. **Check sync status**:
   ```
   ./scripts/check_sync_status.sh
   ```
   This shows the current sync status of both execution and consensus clients.

2. **Monitor checkpoint sync**:
   ```
   ./scripts/checkpoint_sync_monitor.sh
   ```
   This script checks the sync progress over time and can automatically recover from stuck syncs.

3. **View alert logs**:
   ```
   sudo journalctl -u checkpoint-sync-alert
   ```
   This shows logs from the alert service, including any detected issues and actions taken.

## Alert System Configuration

The alert system is installed as a systemd service that continuously monitors your checkpoint sync progress. By default, it:

1. Checks sync progress every 15 minutes
2. Sends alerts if progress is too slow or if sync distance is too high
3. Automatically attempts to restart Lighthouse up to 3 times if issues are detected
4. Logs all events to `/var/log/ephemery/checkpoint_sync_alert.log`

### Configuring Alert Notifications

To receive notifications, edit the script at `{{ directories.scripts }}/checkpoint_sync_alert.sh` and set one or more of the following variables:

```bash
# For email alerts
ALERT_EMAIL="your-email@example.com"

# For Slack alerts
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# For Discord alerts
DISCORD_WEBHOOK="https://discord.com/api/webhooks/YOUR/DISCORD/WEBHOOK"
```

After making changes, restart the service:
```
sudo systemctl restart checkpoint-sync-alert
```

## Troubleshooting

If checkpoint sync still doesn't work after running the playbook:

1. **Check Lighthouse logs**:
   ```
   docker logs ephemery-lighthouse 2>&1 | grep -i checkpoint
   ```
   Look for errors related to checkpoint sync.

2. **Check alert service logs**:
   ```
   sudo journalctl -u checkpoint-sync-alert -f
   ```
   This will show real-time logs from the alert service, including any detected issues.

3. **Try fallback options**:
   If checkpoint sync continues to fail, consider using optimized genesis sync:

   ```yaml
   # In your inventory.yaml
   ephemery:
     hosts:
       ephemery-node1:
         use_checkpoint_sync: false
         clear_database: true
         cl_extra_opts: "--target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
         el_extra_opts: "--cache=4096 --txlookuplimit=0 --syncmode=snap --maxpeers=100"
   ```

4. **Check network connectivity**:
   Ensure your node can reach the checkpoint sync URL:
   ```
   curl -I <checkpoint_sync_url>/eth/v1/beacon/states/finalized
   ```

## Conclusion

The fix_checkpoint_sync.yaml playbook provides a systematic approach to resolving checkpoint sync issues. By testing multiple URLs, optimizing client configurations, implementing monitoring, and setting up automated alerts, it ensures your Ephemery node can sync quickly and reliably with minimal manual intervention.

If you continue to experience issues, please refer to the [main documentation](docs/CHECKPOINT_SYNC.md) for additional information on sync strategies.
