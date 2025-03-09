# Ephemery Testnet Setup Guide with Electra/Pectra Support

This guide outlines the process for setting up an Ephemery testnet node with support for the Electra/Pectra fork. This includes configuring both execution and consensus clients properly to ensure synchronization and connectivity with the Ephemery network.

## Prerequisites

- A server with at least 16GB RAM and 4 CPU cores
- At least 100GB of free disk space
- Docker installed
- SSH access to the server

## Directory Structure

First, create the necessary directory structure:

```bash
mkdir -p /opt/ephemery/data/geth
mkdir -p /opt/ephemery/data/lighthouse
mkdir -p /opt/ephemery/data/validator
mkdir -p /opt/ephemery/config/ephemery_network
```

## JWT Token Setup

Create a JWT token for secure communication between execution and consensus clients:

```bash
openssl rand -hex 32 > /opt/ephemery/jwt.hex
```

## Execution Client Setup (Geth)

We'll use `pk910/ephemery-geth`, which is specifically designed for the Ephemery testnet.

1. Pull the latest image:

```bash
docker pull pk910/ephemery-geth:latest
```

2. Run Geth with the proper configuration for Electra/Pectra support:

```bash
docker run -d --name ephemery-geth \
  --restart=unless-stopped \
  --network=host \
  -v /opt/ephemery/data/geth:/data \
  -v /opt/ephemery/jwt.hex:/jwt.hex \
  -v /opt/ephemery/config/ephemery_network:/ephemery_config \
  pk910/ephemery-geth:latest \
  --http \
  --http.addr=0.0.0.0 \
  --http.port=8545 \
  --http.api=eth,web3,net,admin,debug \
  --authrpc.jwtsecret=/jwt.hex \
  --authrpc.addr=0.0.0.0
```

## Consensus Client Setup (Lighthouse)

We'll use the standard `sigp/lighthouse` image with proper configuration for Ephemery.

1. Pull the Lighthouse image:

```bash
docker pull sigp/lighthouse:v5.3.0
```

2. Run Lighthouse with proper configuration:

```bash
docker run -d --name ephemery-lighthouse \
  --restart=unless-stopped \
  --network=host \
  -v /opt/ephemery/data/lighthouse:/data \
  -v /opt/ephemery/jwt.hex:/jwt.hex \
  -v /opt/ephemery/config/ephemery_network:/ephemery_config \
  sigp/lighthouse:v5.3.0 \
  lighthouse bn \
  --datadir=/data \
  --execution-jwt=/jwt.hex \
  --execution-endpoint=http://127.0.0.1:8551 \
  --http \
  --http-address=0.0.0.0 \
  --http-port=5052 \
  --metrics \
  --metrics-address=0.0.0.0 \
  --metrics-port=5054 \
  --testnet-dir=/ephemery_config \
  --boot-nodes=enr:-Iq4QNMYHuJGbnXyBj6FPS2UkOQ-hnxT-mIdNMMr7evR9UYtLemaluorL6J10RoUG1V4iTPTEbl3huijSNs5_ssBWFiGAYhBNHOzgmlkgnY0gmlwhIlKy_CJc2VjcDI1NmsxoQNULnJBzD8Sakd9EufSXhM4rQTIkhKBBTmWVJUtLCp8KoN1ZHCCIyk,enr:-Jq4QG8kommqwFYVbEqCUqJ6npHXdBw744AXgLtD2Fu6ZEvGLbF4HfgXghexazfh1rrGx8majjFNVP6PBOyEJKzHDxQBhGV0aDKQthie0mAAEBsKAAAAAAAAAIJpZIJ2NIJpcIRBbZouiXNlY3AyNTZrMaEDWBWEKcVGoF9-RyZUuqBsZBQgabSHqHbW4lYVNhduKHeDdWRwgiMp \
  --disable-upnp \
  --discovery-port=9000 \
  --target-peers=10 \
  --subscribe-all-subnets \
  --import-all-attestations \
  --allow-insecure-genesis-sync
```

Note the important flags:
- `--allow-insecure-genesis-sync`: Required to sync from genesis without checkpoint sync
- `--subscribe-all-subnets` and `--import-all-attestations`: Improves sync efficiency
- The boot node ENRs are specific to Ephemery network

## Validator Client Setup (Lighthouse)

Once your beacon node is running and syncing, set up the validator client:

```bash
docker run -d --name ephemery-validator-lighthouse \
  --restart=unless-stopped \
  --network=host \
  -v /opt/ephemery/data/validator:/data \
  -v /opt/ephemery/jwt.hex:/jwt.hex \
  -v /opt/ephemery/config/ephemery_network:/ephemery_config \
  sigp/lighthouse:v5.3.0 \
  lighthouse vc \
  --datadir=/data \
  --beacon-nodes=http://127.0.0.1:5052 \
  --testnet-dir=/ephemery_config
```

## Checking Client Status

### Geth Status

```bash
# Check if Geth is connected to peers
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"id":"1","jsonrpc":"2.0","method":"net_peerCount"}' \
  http://localhost:8545

# Check if Geth is syncing
curl -s -X POST -H 'Content-Type: application/json' \
  --data '{"id":"1","jsonrpc":"2.0","method":"eth_syncing"}' \
  http://localhost:8545
```

### Lighthouse Status

```bash
# Check if Lighthouse is connected to peers
curl -s http://localhost:5052/eth/v1/node/peer_count

# Check if Lighthouse is syncing
curl -s http://localhost:5052/eth/v1/node/syncing
```

## Troubleshooting

### Geth Issues

1. **Chain ID Mismatch**: Ensure Geth is using the correct chain ID (39438143) for Ephemery.

2. **RPC Accessibility**: If you can't connect to Geth's RPC, ensure the `--http` and related flags are set correctly, including `--http.addr=0.0.0.0`.

3. **JWT Token**: Verify the JWT token is correctly set up and accessible to both clients.

### Lighthouse Issues

1. **Genesis Sync Error**: If Lighthouse refuses to sync from genesis, use the `--allow-insecure-genesis-sync` flag.

2. **Checkpoint Sync Issues**: If checkpoint sync fails with SSZ errors, revert to genesis sync with the allow-insecure flag.

3. **Boot Nodes**: Ensure correct boot nodes are provided to help Lighthouse discover peers.

4. **Peer Connectivity**: If Lighthouse cannot find peers, verify your network settings and that the specified ports are accessible.

### Electra/Pectra Support

1. **Version Requirements**:
   - For Geth: Use v1.15.0 or later (pk910/ephemery-geth:latest contains v1.15.5)
   - For Lighthouse: Use v5.3.0 or later

2. **Configuration Files**: Ensure the testnet directory contains the correct configuration for Electra/Pectra.

## Maintenance

### Monitoring

Regularly check the status of your clients:

```bash
# View Geth logs
docker logs ephemery-geth

# View Lighthouse logs
docker logs ephemery-lighthouse

# View Validator logs
docker logs ephemery-validator-lighthouse
```

### Client Updates

When updates are needed:

1. Stop the containers:
```bash
docker stop ephemery-geth ephemery-lighthouse ephemery-validator-lighthouse
```

2. Remove the containers:
```bash
docker rm ephemery-geth ephemery-lighthouse ephemery-validator-lighthouse
```

3. Pull the latest images:
```bash
docker pull pk910/ephemery-geth:latest
docker pull sigp/lighthouse:v5.3.0
```

4. Start the containers again with the commands provided earlier.

## Important Notes

1. **Network Resets**: Ephemery is an ephemeral testnet that resets periodically. After a reset, you may need to clear data directories and restart from genesis.

2. **Validator Keys**: To add validator keys, use the standard Lighthouse validator key import process.

3. **Hardware Requirements**: As the chain grows, you may need to adjust hardware resources.

4. **Firewall Rules**: Ensure ports 30303 (TCP/UDP), 9000 (TCP/UDP), and 8545 (TCP) are accessible if you need external connectivity.

5. **Security Considerations**: The RPC endpoints should not be publicly exposed without proper authentication and access controls.

By following this guide, you should have a functioning Ephemery testnet node with proper support for the Electra/Pectra fork.
