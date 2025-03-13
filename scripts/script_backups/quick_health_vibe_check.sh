#!/bin/bash
#
# Health check script for Ephemery nodes

set -e

# Check execution client
check_el() {
  local host=$1
  echo "Checking execution client on $host..."
  curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' "http://$host:8545"
}

# Check consensus client
check_cl() {
  local host=$1
  echo "Checking consensus client on $host..."
  curl -s "http://$host:5052/eth/v1/node/health"
}

# Main
if [ -z "$1" ]; then
  echo "Usage: $0 <hostname>"
  exit 1
fi

check_el "$1"
check_cl "$1"
