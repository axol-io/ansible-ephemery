# JWT Authentication Setup for Ephemery Nodes

## Overview

This guide provides step-by-step instructions for setting up secure JWT authentication between execution and consensus clients on Ephemery nodes. Proper JWT configuration is critical for the successful operation of an Ethereum node.

## Prerequisites

* Docker installed
* Basic understanding of Ethereum node operation
* Access to the server where Ephemery nodes will run

## JWT Authentication Setup Process

### 1. Generate a Secure JWT Secret

The JWT secret must be a 32-byte hexadecimal value (64 characters) with a '0x' prefix. Use this command to generate it:

```bash
# Generate new JWT secret
openssl rand -hex 32 | tr -d "\n" | sed 's/^/0x/' > /root/ephemery/jwt.hex

# Set secure permissions
chmod 600 /root/ephemery/jwt.hex
```

### 2. Verify the JWT Secret

Check that the JWT secret is formatted correctly:

```bash
# View JWT secret (first 10 characters)
JWT_SECRET=$(cat /root/ephemery/jwt.hex)
echo "JWT secret (first 10 chars): ${JWT_SECRET:0:10}..."

# Verify length and format
if [[ "${JWT_SECRET}" =~ ^0x[0-9a-fA-F]{64}$ ]]; then
  echo "✓ JWT secret is valid"
else
  echo "✗ JWT secret is invalid - regenerate it"
fi
```

### 3. Configure the Execution Client (Geth)

Ensure Geth is configured to use the JWT secret:

```bash
docker run -d --name ephemery-geth \
  --network ephemery-network \
  -v /root/ephemery/jwt.hex:/config/jwt-secret \
  -v /root/ephemery/data/geth:/ethdata \
  -p 8545:8545 -p 8546:8546 -p 8551:8551 -p 30303:30303/tcp -p 30303:30303/udp \
  pk910/ephemery-geth:latest \
  --datadir /ethdata \
  --networkid=39438144 \
  --http --http.addr=0.0.0.0 --http.api=eth,net,web3 \
  --authrpc.addr=0.0.0.0 --authrpc.vhosts=* --authrpc.jwtsecret=/config/jwt-secret
```

### 4. Configure the Consensus Client (Lighthouse)

Configure Lighthouse to use the same JWT secret:

```bash
docker run -d --name ephemery-lighthouse \
  --network ephemery-network \
  -v /root/ephemery/jwt.hex:/config/jwt-secret \
  -v /root/ephemery/data/lighthouse:/ethdata \
  -p 5052:5052 -p 9000:9000/tcp -p 9000:9000/udp -p 8008:8008 \
  pk910/ephemery-lighthouse:latest \
  lighthouse beacon \
  --datadir /ethdata \
  --testnet-dir /ephemery_config \
  --execution-jwt /config/jwt-secret \
  --execution-endpoint http://ephemery-geth:8551 \
  --http --http-address 0.0.0.0 --http-port 5052 \
  --target-peers=100
```

### 5. Avoid Container Name Resolution Issues

If you experience JWT authentication failures, it may be due to container name resolution issues. In this case, use the IP address instead of the container name:

```bash
# Get Geth IP address
GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-geth)

# Use the IP in the Lighthouse configuration
--execution-endpoint http://${GETH_IP}:8551
```

### 6. Set Up Automated Testing for JWT Authentication

Deploy the JWT authentication test script to regularly verify your configuration:

```bash
# Copy the test script
cp /path/to/scripts/testing/tests/test_jwt_auth.sh /root/ephemery/scripts/

# Set up a cron job to run it every 30 minutes
(crontab -l 2>/dev/null; echo "*/30 * * * * /root/ephemery/scripts/test_jwt_auth.sh >> /root/ephemery/logs/jwt_auth_test.log 2>&1") | crontab -
```

### 7. Configure Prometheus Alerts

Set up monitoring alerts for JWT authentication issues:

```bash
# Create the rules directory if it doesn't exist
mkdir -p /etc/prometheus/rules

# Copy the JWT authentication alert rules
cp /path/to/config/monitoring/jwt_authentication_alerts.yaml /etc/prometheus/rules/

# Restart Prometheus
docker restart prometheus
```

## Troubleshooting

If you encounter JWT authentication issues:

1. Verify both clients are using the same JWT token:
   ```bash
   # Check JWT token in Geth
   docker exec ephemery-geth cat /config/jwt-secret

   # Check JWT token in Lighthouse
   docker exec ephemery-lighthouse cat /config/jwt-secret
   ```

2. Check for JWT authentication errors in the logs:
   ```bash
   # Check Geth logs
   docker logs ephemery-geth | grep -E "jwt|auth"

   # Check Lighthouse logs
   docker logs ephemery-lighthouse | grep -E "jwt|auth"
   ```

3. Ensure the chain ID is correct (39438144 for Ephemery):
   ```bash
   curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' http://localhost:8545
   ```

4. Run the automated test script:
   ```bash
   /root/ephemery/scripts/test_jwt_auth.sh
   ```

## Common Issues and Solutions

1. **JWT Secret File Permission Issues**
   - Solution: `chmod 600 /root/ephemery/jwt.hex`

2. **Container Name Resolution**
   - Solution: Use IP address instead of container name

3. **Incorrect Chain ID**
   - Solution: Ensure Geth is started with `--networkid=39438144`

4. **Mismatched JWT Tokens**
   - Solution: Generate a new token and update both containers

## See Also

- [JWT Authentication Troubleshooting Guide](../FEATURES/JWT_AUTHENTICATION_TROUBLESHOOTING.md)
- [Chain ID Mismatch Troubleshooting](../TROUBLESHOOTING/CHAIN_ID_MISMATCH.md)
- [Ephemery Node Deployment Guide](./EPHEMERY_SETUP.md)
