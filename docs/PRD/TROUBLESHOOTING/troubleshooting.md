# Ephemery Troubleshooting Guide

This document provides solutions for common issues encountered when using the Ephemery testing network.

## Table of Contents

1. [Common Setup Issues](#common-setup-issues)
2. [Docker-Related Issues](#docker-related-issues)
3. [Network Connectivity Issues](#network-connectivity-issues)
4. [Client Synchronization Issues](#client-synchronization-issues)
5. [Validator Issues](#validator-issues)
6. [Mock Testing Framework Issues](#mock-testing-framework-issues)
7. [Debugging Tools](#debugging-tools)

## Common Setup Issues

### JWT Secret Generation Failure

**Symptoms:**
- Error message about JWT secret generation
- Clients cannot connect to each other

**Solutions:**
1. Check file permissions on the JWT directory:
   ```bash
   chmod 755 /path/to/jwt/directory
   ```
2. Generate the JWT secret manually:
   ```bash
   openssl rand -hex 32 > /path/to/jwt/secret
   chmod 644 /path/to/jwt/secret
   ```
3. Ensure both clients use the same JWT file path.

### Missing Dependencies

**Symptoms:**
- Script failures with "command not found" errors
- Docker container creation failures

**Solutions:**
1. Install required dependencies:
   ```bash
   # For Debian/Ubuntu
   sudo apt-get update
   sudo apt-get install -y docker.io docker-compose openssl curl jq
   
   # For CentOS/RHEL
   sudo yum install -y docker docker-compose openssl curl jq
   ```
2. Ensure Docker is running:
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

## Docker-Related Issues

### Container Fails to Start

**Symptoms:**
- Docker container exits immediately after starting
- Error messages in container logs

**Solutions:**
1. Check container logs:
   ```bash
   docker logs <container_name>
   ```
2. Ensure volume mounts have correct permissions:
   ```bash
   sudo chown -R <your_user>:<your_group> /path/to/volume/data
   ```
3. Verify Docker network exists:
   ```bash
   docker network ls
   docker network inspect ephemery
   ```
4. Try running with verbose flags:
   ```bash
   docker run --rm -it <image> <command> --verbosity=debug
   ```

### Port Conflicts

**Symptoms:**
- "port already in use" errors
- Clients cannot bind to required ports

**Solutions:**
1. Check which process is using the port:
   ```bash
   sudo lsof -i :<port_number>
   ```
2. Stop the conflicting process or change the port in your configuration.
3. Ensure no other instances of Ethereum clients are running:
   ```bash
   docker ps | grep -E 'geth|lighthouse|prysm'
   ```

## Network Connectivity Issues

### Clients Cannot Connect

**Symptoms:**
- Execution client cannot connect to consensus client
- Log entries about failed connections

**Solutions:**
1. Verify both clients are on the same Docker network:
   ```bash
   docker network inspect ephemery
   ```
2. Check that firewall rules allow necessary ports:
   ```bash
   # Common ports: 8545, 8551, 30303, 5052, 9000
   sudo ufw status
   sudo iptables -L
   ```
3. Ensure clients are using the correct hostnames/IPs:
   ```bash
   # Update execution client command with correct auth RPC address
   --authrpc.addr=0.0.0.0
   --authrpc.vhosts=*
   ```

### P2P Network Issues

**Symptoms:**
- Clients cannot find peers
- Sync progress stalls

**Solutions:**
1. Check if port forwarding is set up correctly on your router.
2. Ensure P2P ports are open (typically 30303 TCP/UDP for execution and 9000 TCP/UDP for consensus).
3. Try adding bootstrap nodes explicitly:
   ```bash
   --bootnodes=<enode_url>
   ```

## Client Synchronization Issues

### Slow or Stalled Sync

**Symptoms:**
- Client sync progress is very slow or stops entirely
- High disk or CPU usage

**Solutions:**
1. Check disk space and ensure enough free space:
   ```bash
   df -h
   ```
2. Monitor system resources:
   ```bash
   htop
   ```
3. Check client logs for sync status:
   ```bash
   docker logs -f <client_container> | grep -i sync
   ```
4. Consider pruning the database and restarting:
   ```bash
   # For Geth
   geth --datadir=/path/to/data snapshot prune-state
   ```

### Consensus Client Cannot Sync

**Symptoms:**
- Consensus client logs show sync issues
- Missing or invalid execution payload errors

**Solutions:**
1. Verify the execution client is fully synced first.
2. Check JWT authentication:
   ```bash
   # Ensure JWT secret file exists and has correct permissions
   ls -la /path/to/jwt/secret
   ```
3. Restart both clients in the correct order:
   ```bash
   docker restart geth_container
   sleep 10
   docker restart lighthouse_container
   ```

## Validator Issues

### Validator Not Attesting

**Symptoms:**
- Validator logs show missed attestations
- No blocks being proposed

**Solutions:**
1. Check if validators are correctly imported:
   ```bash
   docker exec -it lighthouse_validator_container lighthouse account list --datadir=/data
   ```
2. Verify validator keys have correct permissions:
   ```bash
   chmod 700 /path/to/validator/keys
   ```
3. Check validator balance through the beacon API:
   ```bash
   curl -X GET "http://localhost:5052/eth/v1/beacon/states/head/validators" | jq
   ```

### Validator Balance Not Increasing

**Symptoms:**
- Validator participation appears normal but balance is static

**Solutions:**
1. Check if the network has enough validators for finality.
2. Verify the validator is active and not pending:
   ```bash
   curl -X GET "http://localhost:5052/eth/v1/beacon/states/head/validators/<validator_pubkey>" | jq
   ```

## Mock Testing Framework Issues

### Tests Failing in Mock Mode

**Symptoms:**
- Tests pass with real dependencies but fail in mock mode
- Mock assertions failing

**Solutions:**
1. Check that all required functions are properly mocked:
   ```bash
   grep -r "mock_command" scripts/testing/tests/
   ```
2. Verify mock command implementations match expected output format:
   ```bash
   # Update mock output to match real command
   mock_command "curl" "echo '{\"result\":\"0x1\",\"id\":1,\"jsonrpc\":\"2.0\"}'"
   ```
3. Set more verbose logging:
   ```bash
   export MOCK_DEBUG=true
   ./scripts/testing/run_tests.sh --mock --verbose
   ```

### Script Path Issues

**Symptoms:**
- "File not found" errors when running tests
- Path-related errors in test scripts

**Solutions:**
1. Use absolute paths or correct relative paths:
   ```bash
   # Use the TEST_DIR variable set in init_test_env.sh
   source "${TEST_DIR}/../path/to/script.sh"
   ```
2. Check for symlink issues:
   ```bash
   readlink -f /path/to/script.sh
   ```

## Debugging Tools

### Log Analysis

Use these commands to examine logs and diagnose issues:

```bash
# Follow logs in real-time
docker logs -f <container_name>

# Filter logs for specific terms
docker logs <container_name> | grep -i error

# Tail last 100 lines
docker logs --tail 100 <container_name>

# Save logs to file
docker logs <container_name> > container_logs.txt
```

### Network Diagnostics

Tools for diagnosing network connectivity:

```bash
# Check if port is open
nc -zv localhost <port>

# Trace route to destination
traceroute <hostname>

# Monitor network connections
watch -n 1 "netstat -tuln | grep <port>"
```

### Resource Monitoring

Monitor system resources during operation:

```bash
# Monitor CPU, memory, disk I/O
htop

# Monitor disk usage
df -h

# Monitor I/O operations
iostat -x 2

# Monitor network traffic
iftop
```

### Getting Help

If you're still experiencing issues:

1. Check the [GitHub Issues](https://github.com/your-org/ansible-ephemery/issues) for similar problems.
2. Search the documentation for related topics.
3. Gather logs and system information before asking for help:
   ```bash
   # Create a support bundle
   ./scripts/utilities/create_support_bundle.sh
   ```
4. Open a new issue with detailed information about your environment and the problem. 