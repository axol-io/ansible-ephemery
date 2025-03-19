# Chain ID Mismatch Troubleshooting Guide

## Overview

This guide provides solutions for addressing chain ID mismatches when running an Ephemery node. The Ephemery network uses a specific chain ID (`39438144`), and any mismatch can cause transaction failures, synchronization issues, and authentication problems between execution and consensus clients.

## Symptoms of Chain ID Mismatch

- Transactions from external tools fail with "wrong chain ID" errors
- Consensus client unable to communicate with execution client
- Validator cannot attest or propose blocks
- JWT authentication failures despite correct JWT file configuration
- "Invalid genesis" errors in client logs

## Checking Chain ID

You can check the current chain ID of your execution client using the following command:

```bash
curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://localhost:8545
```

The response should show:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "0x259c740"
}
```

Where `0x259c740` is the hexadecimal representation of `39438144`.

## Fixing Chain ID Issues

### For Geth

1. **Stop the Geth container**:
   ```bash
   docker stop ephemery-geth
   ```

2. **Modify the container startup command** to include the correct network ID:
   ```bash
   docker run -d --name ephemery-geth \
     --network ephemery-network \
     -v /root/ephemery/jwt.hex:/config/jwt-secret \
     -v /root/ephemery/data/geth:/ethdata \
     -p 8545:8545 -p 8546:8546 -p 8551:8551 -p 30303:30303 -p 30303:30303/udp \
     pk910/ephemery-geth:latest \
     --datadir /ethdata \
     --networkid=39438144 \
     --http --http.addr=0.0.0.0 --http.api=eth,net,web3,debug \
     --authrpc.addr=0.0.0.0 --authrpc.vhosts=* --authrpc.jwtsecret=/config/jwt-secret
   ```

3. **Verify the chain ID** after restart:
   ```bash
   curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://localhost:8545
   ```

### Using Config File (Preferred Method)

For a more permanent solution, create a configuration file:

1. **Create the geth config file**:
   ```bash
   cat > /root/ephemery/config/geth-config.toml << EOF
   [Eth]
   NetworkId = 39438144
   SyncMode = "snap"
   
   [Node]
   DataDir = "/ethdata"
   HTTPHost = "0.0.0.0"
   HTTPPort = 8545
   HTTPVirtualHosts = ["*"]
   HTTPModules = ["net", "web3", "eth"]
   AuthAddr = "0.0.0.0"
   AuthPort = 8551
   AuthVirtualHosts = ["*"]
   JWTSecret = "/config/jwt-secret"
   
   [Node.P2P]
   MaxPeers = 50
   NoDiscovery = false
   ListenAddr = ":30303"
   EOF
   ```

2. **Restart with the config file**:
   ```bash
   docker run -d --name ephemery-geth \
     --network ephemery-network \
     -v /root/ephemery/jwt.hex:/config/jwt-secret \
     -v /root/ephemery/data/geth:/ethdata \
     -v /root/ephemery/config/geth-config.toml:/geth-config.toml \
     -p 8545:8545 -p 8546:8546 -p 8551:8551 -p 30303:30303 -p 30303:30303/udp \
     pk910/ephemery-geth:latest \
     --config /geth-config.toml
   ```

### For Other Execution Clients

#### Nethermind
```bash
--config=ephemery
--Network.ChainId=39438144
```

#### Besu
```bash
--network-id=39438144
--genesis-file=/config/ephemery-genesis.json
```

## Common Issues and Solutions

### 1. Chaindata from Wrong Network

If you have chaindata from another network, you need to clear it before starting with the correct chain ID:

```bash
docker stop ephemery-geth
rm -rf /root/ephemery/data/geth/*
# Then restart Geth with correct chain ID
```

### 2. Changing Chain ID Without Clearing Data

Attempting to change the chain ID without clearing data will result in errors. Always clear the database when switching networks.

### 3. JWT Authentication Tied to Chain ID

JWT authentication between execution and consensus clients can fail if the chain ID is incorrect, even if the JWT token is valid. Always check the chain ID when troubleshooting authentication issues.

### 4. Genesis Block Mismatch

If your node has synced to a different network, you may see "invalid genesis hash" errors. This requires clearing the database and restarting with the correct chain ID.

## Automated Verification

The `test_jwt_auth.sh` script includes chain ID verification. Run it to automatically check if your execution client is using the correct chain ID:

```bash
/root/ephemery/scripts/test_jwt_auth.sh
```

## See Also

- [JWT Authentication Troubleshooting Guide](../FEATURES/JWT_AUTHENTICATION_TROUBLESHOOTING.md)
- [Ephemery Network Setup Guide](../DEPLOYMENT/EPHEMERY_SETUP.md) 