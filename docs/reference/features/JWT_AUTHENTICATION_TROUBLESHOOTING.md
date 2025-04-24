# JWT Authentication Troubleshooting Guide

## Overview

This document provides guidance on diagnosing and resolving JWT (JSON Web Token) authentication issues between Ethereum execution clients (e.g., Geth) and consensus clients (e.g., Lighthouse) when running an Ephemery node.

## Common JWT Authentication Issues

JWT authentication problems are among the most common causes of communication failures between execution and consensus clients. When these issues occur, clients may appear to be running properly but fail to synchronize or communicate with each other.

### Symptoms of JWT Authentication Issues

- Consensus client logs showing: "Execution endpoint is not synced"
- Execution client logs showing: "Beacon client online, but no consensus updates received"
- Communication timeout errors between clients
- Chain ID mismatches or incorrect network ID configuration
- Clients running but stuck in "syncing" or "optimistic" mode

## Root Causes

1. **Mismatched JWT Secret**: Different JWT secrets used by each client
2. **Incorrect JWT File Path**: Wrong path to JWT secret in container configuration
3. **Permission Issues**: JWT file with incorrect permissions
4. **Network Configuration**: Client containers unable to communicate over the network
5. **Chain ID Mismatch**: Execution client using incorrect chain ID for Ephemery network

## Step-by-Step Troubleshooting

### 1. Verify JWT Secret File

First, check if the JWT secret file exists and has the same content between containers:

```bash
# Check if JWT file exists
ssh root@your-server 'ls -la /root/.ephemeryd/config/jwtsecret'

# Check JWT file content hash to verify they match
ssh root@your-server 'docker exec ephemery-geth cat /config/jwt-secret | md5sum'
ssh root@your-server 'docker exec ephemery-lighthouse cat /config/jwt-secret | md5sum'
```

If the files don't exist or have different content, recreate the JWT secret:

```bash
ssh root@your-server 'openssl rand -hex 32 | tr -d "\n" > /root/.ephemeryd/config/jwtsecret && chmod 600 /root/.ephemeryd/config/jwtsecret'
```

### 2. Check Client Configuration

Ensure both clients are configured to use the correct JWT file path:

#### Geth Configuration

```bash
# Check Geth startup command
ssh root@your-server 'docker inspect ephemery-geth | grep -A 20 "Cmd"'
```

Ensure it includes: `--authrpc.jwtsecret=/config/jwt-secret`

#### Lighthouse Configuration

```bash
# Check Lighthouse startup command
ssh root@your-server 'docker inspect ephemery-lighthouse | grep -A 20 "Cmd"'
```

Ensure it includes: `--execution-jwt=/config/jwt-secret`

### 3. Verify Container Network

Check that the containers can communicate over the Docker network:

```bash
# List networks and connected containers
ssh root@your-server 'docker network inspect $(docker network ls | grep ephemery | awk "{print \$1}")'
```

Both containers should be on the same network and able to resolve each other by container name.

### 4. Check Chain ID Configuration

Verify that Geth is using the correct Ephemery network ID (39438144):

```bash
# Check Geth's chain ID
ssh root@your-server 'curl -s -X POST -H "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_chainId\",\"params\":[],\"id\":1}" http://127.0.0.1:8545'
```

The result should be: `{"jsonrpc":"2.0","id":1,"result":"0x259c740"}` (where 0x259c740 = 39438144 in hexadecimal)

### 5. Check Client Logs

Examine logs for explicit authentication errors:

```bash
# Check Geth logs for JWT issues
ssh root@your-server 'docker logs ephemery-geth | grep -E "jwt|beacon|auth"'

# Check Lighthouse logs for JWT issues
ssh root@your-server 'docker logs ephemery-lighthouse | grep -E "jwt|execution|auth"'
```

## Complete Fix for JWT Issues

For a comprehensive fix that addresses JWT authentication and related issues:

1. **Stop the containers**:
   ```bash
   ssh root@your-server 'docker stop ephemery-geth ephemery-lighthouse'
   ```

2. **Generate a new JWT secret**:
   ```bash
   ssh root@your-server 'openssl rand -hex 32 | tr -d "\n" > /root/.ephemeryd/config/jwtsecret && chmod 600 /root/.ephemeryd/config/jwtsecret'
   ```

3. **Create a minimal Geth configuration** file (if using config file):
   ```bash
   ssh root@your-server 'cat > /data/ephemery/geth-conf.toml << EOF
   [Eth]
   NetworkId = 39438144
   SyncMode = "snap"

   [Node]
   DataDir = "/data/geth-data"
   HTTPHost = "0.0.0.0"
   HTTPPort = 8545
   HTTPVirtualHosts = ["*"]
   HTTPModules = ["net", "web3", "eth"]
   AuthAddr = "0.0.0.0"
   AuthPort = 8551
   AuthVirtualHosts = ["*"]
   JWTSecret = "/config/jwtsecret"

   [Node.P2P]
   MaxPeers = 50
   NoDiscovery = false
   ListenAddr = ":30303"
   EOF'
   ```

4. **Restart containers with explicit parameters**:
   ```bash
   # Start Geth
   ssh root@your-server 'docker run -d --name ephemery-geth --network ephemery-network -v /root/.ephemeryd/config:/config -v /data/ephemery:/data -p 8545:8545 -p 8546:8546 -p 8551:8551 -p 30303:30303 -p 30303:30303/udp pk910/ephemery-geth:latest --datadir /data/geth-data --networkid=39438144 --http --http.addr=0.0.0.0 --http.api=eth,net,web3 --authrpc.addr=0.0.0.0 --authrpc.vhosts=* --authrpc.jwtsecret=/config/jwtsecret'

   # Wait for Geth to initialize
   ssh root@your-server 'sleep 15'

   # Start Lighthouse
   ssh root@your-server 'docker run -d --name ephemery-lighthouse --network ephemery-network -v /root/.ephemeryd/config:/config -v /data/ephemery:/data -p 5052:5052 -p 8008:8008 -p 9000:9000 -p 9000:9000/udp pk910/ephemery-lighthouse:latest lighthouse beacon --testnet-dir=/data/testnet --datadir=/data/lighthouse-data --execution-jwt=/config/jwtsecret --execution-endpoint=http://ephemery-geth:8551 --http --http-address=0.0.0.0 --http-port=5052 --metrics --metrics-address=0.0.0.0 --metrics-port=8008 --target-peers=100'
   ```

5. **Verify sync status**:
   ```bash
   ssh root@your-server 'sleep 30 && curl -s http://127.0.0.1:5052/eth/v1/node/syncing'
   ```

## Preventing JWT Issues

To prevent JWT authentication issues in future deployments:

1. **Use a dedicated volume** for the JWT secret file
2. **Include the correct chain ID** (39438144) in Geth configuration
3. **Ensure both clients** refer to the same JWT file path
4. **Set proper file permissions** (chmod 600) for the JWT secret
5. **Place containers on the same network** with proper hostname resolution

## References

- [Ethereum Engine API Authentication](https://github.com/ethereum/execution-apis/blob/main/src/engine/authentication.md)
- [Lighthouse Documentation](https://lighthouse-book.sigmaprime.io/)
- [Geth Documentation](https://geth.ethereum.org/docs/)
- [Ephemery Setup Guide](./EPHEMERY_SETUP.md)
