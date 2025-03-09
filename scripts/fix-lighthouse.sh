#!/bin/bash
# Script to directly fix the Lighthouse container command line

echo "Stopping and removing problematic containers..."
ssh root@103.214.23.174 'docker stop ephemery-lighthouse || true'
ssh root@103.214.23.174 'docker rm ephemery-lighthouse || true'

echo "Clearing Lighthouse database to start fresh..."
ssh root@103.214.23.174 'rm -rf /opt/ephemery/ephemery/data/lighthouse/beacon'

echo "Starting Lighthouse with fixed bootstrap nodes..."
ssh root@103.214.23.174 'docker run -d --name ephemery-lighthouse \
  --restart=unless-stopped \
  --network=host \
  -v /opt/ephemery/jwt.hex:/jwt.hex \
  -v /opt/ephemery/ephemery/data/lighthouse:/data \
  -v /opt/ephemery/ephemery/config/ephemery_network:/ephemery_config \
  sigp/lighthouse:v5.3.0 \
  lighthouse beacon_node \
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
  --target-peers=150 \
  --execution-timeout-multiplier=10 \
  --disable-deposit-contract-sync \
  --import-all-attestations \
  --disable-backfill-rate-limiting \
  --checkpoint-sync-url=https://checkpoint-sync.ephemery.ethpandaops.io/ \
  --boot-nodes=/ip4/157.90.35.151/tcp/9000/udp/9000/p2p/16Uiu2HAmVZnsqvTNQ2ya1YG2qi6DQchqX57jF9zN2CukZnQY84wJ,/ip4/136.243.15.66/tcp/9000/udp/9000/p2p/16Uiu2HAmAwGWqGShumBQeUuivDyRMmCZjvbZsQwcEWYYLDVKvFjG,/ip4/88.198.2.150/tcp/9000/udp/9000/p2p/16Uiu2HAm8cEfaKtweXbT4koAuifKKJPm8q7TdpaVfWk9j5E5L2m3,/ip4/135.181.91.151/tcp/9000/udp/9000/p2p/16Uiu2HAmEP7X3JDcdAYLagNQxpJ24n3HDwLGxVVsWyv2aUHrXA5b,/ip4/95.217.131.28/tcp/9000/udp/9000/p2p/16Uiu2HAm4ijy2FE8SntNeBTFqKqLxKVWUqZ2QHPz4m8tQcJNvvBc,/ip4/159.69.65.98/tcp/9000/udp/9000/p2p/16Uiu2HAmTACwFnTRoTWZRen4whDMMgcR7QAQoJKBrsBLNJqJiEkD,/ip4/95.217.99.173/tcp/9000/udp/9000/p2p/16Uiu2HAkvq1xTJR2fNy4wY2bZ4xtCGZrLx7Zc9VpBLmAXmVeYYBD'

echo "Waiting for services to start..."
sleep 15

echo "Checking container status..."
ssh root@103.214.23.174 'docker ps | grep ephemery'

echo "Fixing complete. Waiting for Lighthouse to connect to peers..."
echo "Run the following command to check sync status in a minute:"
echo "ssh root@103.214.23.174 '/opt/ephemery/ephemery/scripts/check_sync_status.sh'"

echo "If checkpoint sync still fails, you can try without checkpoint sync using this command:"
echo "ssh root@103.214.23.174 'docker stop ephemery-lighthouse && docker rm ephemery-lighthouse && docker run -d --name ephemery-lighthouse --restart=unless-stopped --network=host -v /opt/ephemery/jwt.hex:/jwt.hex -v /opt/ephemery/ephemery/data/lighthouse:/data -v /opt/ephemery/ephemery/config/ephemery_network:/ephemery_config sigp/lighthouse:v5.3.0 lighthouse beacon_node --datadir=/data --execution-jwt=/jwt.hex --execution-endpoint=http://127.0.0.1:8551 --http --http-address=0.0.0.0 --http-port=5052 --metrics --metrics-address=0.0.0.0 --metrics-port=5054 --testnet-dir=/ephemery_config --target-peers=150 --execution-timeout-multiplier=10 --disable-deposit-contract-sync --import-all-attestations --disable-backfill-rate-limiting --boot-nodes=/ip4/157.90.35.151/tcp/9000/udp/9000/p2p/16Uiu2HAmVZnsqvTNQ2ya1YG2qi6DQchqX57jF9zN2CukZnQY84wJ,/ip4/136.243.15.66/tcp/9000/udp/9000/p2p/16Uiu2HAmAwGWqGShumBQeUuivDyRMmCZjvbZsQwcEWYYLDVKvFjG,/ip4/88.198.2.150/tcp/9000/udp/9000/p2p/16Uiu2HAm8cEfaKtweXbT4koAuifKKJPm8q7TdpaVfWk9j5E5L2m3,/ip4/135.181.91.151/tcp/9000/udp/9000/p2p/16Uiu2HAmEP7X3JDcdAYLagNQxpJ24n3HDwLGxVVsWyv2aUHrXA5b,/ip4/95.217.131.28/tcp/9000/udp/9000/p2p/16Uiu2HAm4ijy2FE8SntNeBTFqKqLxKVWUqZ2QHPz4m8tQcJNvvBc,/ip4/159.69.65.98/tcp/9000/udp/9000/p2p/16Uiu2HAmTACwFnTRoTWZRen4whDMMgcR7QAQoJKBrsBLNJqJiEkD,/ip4/95.217.99.173/tcp/9000/udp/9000/p2p/16Uiu2HAkvq1xTJR2fNy4wY2bZ4xtCGZrLx7Zc9VpBLmAXmVeYYBD'"
