# Common Troubleshooting Issues

## Overview

This document covers common issues and solutions for Ephemery nodes.

## Quick Solutions Table

| Issue | Symptoms | Quick Fix |
|-------|----------|-----------|
| JWT Secret Issues | Clients cannot communicate | Check JWT secret permissions and format |
| Node Not Syncing | Node remains at same block height | Check network connectivity and port forwarding |
| Client Crashes | Service repeatedly restarting | Check logs and increase memory limits |
| API Endpoint Unavailable | Cannot connect to RPC endpoints | Check service status and firewall rules |
| Disk Space Issues | Services failing with disk errors | Prune chain data or expand disk |

## Common Issues

### Issue 1: JWT Secret Configuration Problems

**Symptoms**:
- Execution client cannot connect to consensus client
- Error messages about invalid JWT token
- Authentication failures in logs

**Cause**:
Improper JWT secret configuration, including wrong format, incorrect permissions, or wrong path.

**Solution**:

1. Check JWT secret format:
   ```bash
   # Verify JWT is 64-character hex without 0x prefix
   hexdump -C /etc/ethereum/jwt.hex
   ```

2. Fix JWT permissions:
   ```bash
   # Set correct permissions
   sudo chmod 600 /etc/ethereum/jwt.hex
   ```

3. Ensure both clients use the same JWT path:
   ```bash
   # Check client configurations
   grep jwt /etc/ethereum/*/config.toml
   ```

**Prevention**:
Use the common role's JWT management task to ensure consistent JWT configuration.

### Issue 2: Node Not Syncing

**Symptoms**:
- Block height does not increase
- Peer count is low or zero
- Timeout errors in logs

**Cause**:
Network connectivity issues, incorrect network configuration, or insufficient resources.

**Solution**:

1. Check network connectivity:
   ```bash
   # Test internet connectivity
   ping etherscan.io
   ```

2. Verify peers are connecting:
   ```bash
   # Check peer count via RPC
   curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545
   ```

3. Check port forwarding:
   ```bash
   # Verify ports are listening
   sudo netstat -tulpn | grep geth
   ```

**Prevention**:
Configure firewalls properly and ensure adequate bandwidth for syncing.

### Issue 3: Client Crashes or Out of Memory

**Symptoms**:
- Services repeatedly restarting
- Out of memory errors in logs
- System becomes unresponsive

**Cause**:
Insufficient memory allocation, memory leaks, or resource constraints.

**Solution**:

1. Check memory usage:
   ```bash
   # View memory usage
   free -h
   ```

2. Increase memory limits:
   ```bash
   # Edit client systemd service file
   sudo systemctl edit geth.service
   # Add/modify memory limit
   # [Service]
   # MemoryLimit=8G
   ```

3. Restart service:
   ```bash
   sudo systemctl restart geth
   ```

**Prevention**:
Allocate sufficient resources and monitor memory usage regularly.

## Diagnostic Tools

### Tool 1: Client Health Check

Use the health check script to diagnose common issues:

```bash
./scripts/monitoring/check_node_health.sh -h your-node-ip
```

### Tool 2: Log Analysis

Check client logs for errors:

```bash
# View execution client logs
sudo journalctl -u geth -n 100 --no-pager

# View consensus client logs
sudo journalctl -u lighthouse -n 100 --no-pager
```

## Log Analysis

### Important Log Locations

- Execution client logs: `journalctl -u geth`
- Consensus client logs: `journalctl -u lighthouse`
- System logs: `/var/log/syslog`

### Common Error Messages

| Error Message | Meaning | Resolution |
|---------------|---------|------------|
| `Failed to authenticate with execution client` | JWT authentication issue | Check JWT secret configuration |
| `Error connecting to peer` | Network connectivity issues | Check firewall and network settings |
| `Disk space low` | Insufficient disk space | Prune chain data or expand disk |
| `OOM killer terminated process` | Out of memory | Increase memory limits or reduce resource usage |

## Getting Help

If you cannot resolve the issue using this guide, you can:

1. Check the [GitHub issues](https://github.com/yourusername/ephemery/issues) for similar problems
2. Join the [Ephemery Discord](https://discord.gg/example) for community support
3. Review the detailed logs and include them when seeking help
