#!/bin/bash
# Version: 1.0.0
#
# Deploy Key Performance Metrics Script
# =====================================
# This script deploys the key performance metrics system for validator keys.

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "${SCRIPT_DIR}")"
INVENTORY=${INVENTORY:-"${BASE_DIR}/inventory.yaml"}
PLAYBOOK="${BASE_DIR}/playbooks/deploy_key_performance_metrics.yml"
CLIENT_TYPE=""
BEACON_NODE_ENDPOINT=""
VALIDATOR_ENDPOINT=""
RETENTION_DAYS="7"
DEBUG=0

# Display help
show_help() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -i, --inventory INVENTORY    Specify inventory file (default: ${INVENTORY})"
  echo "  -c, --client CLIENT_TYPE     Specify client type (lighthouse, teku, prysm, nimbus)"
  echo "  -b, --beacon URL             Specify beacon node endpoint URL"
  echo "  -v, --validator URL          Specify validator client endpoint URL"
  echo "  -r, --retention DAYS         Specify metrics retention days (default: 7)"
  echo "  -d, --debug                  Enable debug mode for verbose output"
  echo "  -h, --help                   Show this help message"
  echo
  echo "Example:"
  echo "  $0 --client lighthouse --beacon http://localhost:5052 --validator http://localhost:5062"
  echo
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case ${key} in
    -i | --inventory)
      INVENTORY="$2"
      shift 2
      ;;
    -c | --client)
      CLIENT_TYPE="$2"
      shift 2
      ;;
    -b | --beacon)
      BEACON_NODE_ENDPOINT="$2"
      shift 2
      ;;
    -v | --validator)
      VALIDATOR_ENDPOINT="$2"
      shift 2
      ;;
    -r | --retention)
      RETENTION_DAYS="$2"
      shift 2
      ;;
    -d | --debug)
      DEBUG=1
      shift
      ;;
    -h | --help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Check if inventory file exists
if [[ ! -f "${INVENTORY}" ]]; then
  echo "Error: Inventory file not found: ${INVENTORY}"
  exit 1
fi

# Build extra vars
EXTRA_VARS=""

if [[ -n "${CLIENT_TYPE}" ]]; then
  EXTRA_VARS="${EXTRA_VARS} client_type=${CLIENT_TYPE}"
fi

if [[ -n "${BEACON_NODE_ENDPOINT}" ]]; then
  EXTRA_VARS="${EXTRA_VARS} beacon_node_endpoint=${BEACON_NODE_ENDPOINT}"
fi

if [[ -n "${VALIDATOR_ENDPOINT}" ]]; then
  EXTRA_VARS="${EXTRA_VARS} validator_endpoint=${VALIDATOR_ENDPOINT}"
fi

if [[ -n "${RETENTION_DAYS}" ]]; then
  EXTRA_VARS="${EXTRA_VARS} retention_days=${RETENTION_DAYS}"
fi

# Prepare ansible command
ANSIBLE_CMD="ansible-playbook -i ${INVENTORY} ${PLAYBOOK}"

if [[ -n "${EXTRA_VARS}" ]]; then
  ANSIBLE_CMD="${ANSIBLE_CMD} --extra-vars \"${EXTRA_VARS}\""
fi

if [[ ${DEBUG} -eq 1 ]]; then
  ANSIBLE_CMD="${ANSIBLE_CMD} -vvv"
fi

# Display configuration
echo "================================================"
echo "Deploying Key Performance Metrics"
echo "================================================"
echo "Inventory: ${INVENTORY}"
echo "Playbook: ${PLAYBOOK}"
if [[ -n "${CLIENT_TYPE}" ]]; then echo "Client Type: ${CLIENT_TYPE}"; fi
if [[ -n "${BEACON_NODE_ENDPOINT}" ]]; then echo "Beacon Node Endpoint: ${BEACON_NODE_ENDPOINT}"; fi
if [[ -n "${VALIDATOR_ENDPOINT}" ]]; then echo "Validator Endpoint: ${VALIDATOR_ENDPOINT}"; fi
echo "Retention Days: ${RETENTION_DAYS}"
echo "Debug Mode: $([ ${DEBUG} -eq 1 ] && echo "Enabled" || echo "Disabled")"
echo "================================================"
echo "Running: ${ANSIBLE_CMD}"
echo "================================================"

# Run ansible playbook
eval "${ANSIBLE_CMD}"

echo "================================================"
echo "Key Performance Metrics Deployment Complete"
echo "================================================"
echo "You can view the metrics dashboard at:"
echo "http://YOUR_SERVER_IP:3000/d/validator-key-performance"
echo
echo "Metrics are available at:"
echo "- JSON: /root/ephemery/data/metrics/key_metrics/key_metrics.json"
echo "- Summary: /root/ephemery/data/metrics/key_metrics/key_metrics_summary.json"
echo "- Prometheus: /root/ephemery/data/metrics/prometheus/key_metrics.prom"
echo "================================================"
