# Obol SquadStaking Integration for Ephemery

This integration adds support for Obol's Distributed Validator Technology (DVT) to the Ephemery testnet environment. Obol DVT allows multiple validator clients to work together to sign blocks and attestations, improving validator resilience and security.

## Overview

The Obol SquadStaking integration consists of:

1. **Deployment Script**: A shell script to set up and configure Obol Charon middleware and validator clients.
2. **Dashboard Integration**: Python modules and templates for monitoring and visualizing Obol SquadStaking metrics.

## Deployment

### Prerequisites

- Docker and Docker Compose
- Ephemery beacon node and execution client
- OpenSSL for key generation

### Installation

1. Run the setup script:

```bash
./scripts/deployment/setup_obol_squadstaking.sh
```

2. Optional parameters:

```
--base-dir DIR         Base directory (default: /opt/ephemery)
--cluster-size N       Number of nodes in the DV cluster (default: 4)
--threshold N          Consensus threshold (default: 3)
--reset                Reset existing installation
--yes                  Skip confirmation prompts
--verbose              Enable verbose output
```

### Configuration

The setup script creates the following configuration files:

- `charon.yaml`: Configuration for the Charon middleware
- `cluster-definition.json`: Definition of the distributed validator cluster
- `docker-compose.yaml`: Docker Compose configuration for running the services

## Dashboard Integration

The dashboard integration provides a web interface for monitoring Obol SquadStaking metrics.

### Features

- **Distributed Validator Health**: Overall health score, consensus rate, and attestation effectiveness
- **Performance Trends**: Historical trends for attestation and consensus performance
- **Cluster Configuration**: Information about the cluster size, threshold, and node status
- **Detailed Metrics**: Raw metrics from Charon and validator clients

### Accessing the Dashboard

1. Start the Ephemery dashboard:

```bash
cd dashboard
python app/app.py
```

2. Navigate to `http://localhost:8080/obol` in your web browser

## Architecture

### Components

- **Charon Middleware**: Coordinates between validator clients to achieve consensus
- **Validator Client**: Standard Ethereum validator client (Lighthouse)
- **Metrics Collector**: Collects and analyzes metrics from Charon and validator clients
- **Dashboard**: Visualizes metrics and provides monitoring interface

### Data Flow

1. Validator clients connect to Charon middleware
2. Charon middleware connects to the beacon node
3. Metrics are collected from Charon and validator clients
4. Dashboard displays metrics and analysis

## Metrics

The following metrics are collected and displayed:

- **Consensus Rate**: Percentage of duties that achieved consensus
- **Attestation Effectiveness**: Effectiveness of attestations
- **Missed Attestations**: Number of missed attestations
- **Missed Blocks**: Number of missed block proposals
- **Health Score**: Overall health score based on consensus rate and attestation effectiveness

## Troubleshooting

### Common Issues

1. **Charon not connecting to peers**:
   - Check network connectivity
   - Verify ENR private key is correctly generated
   - Check firewall settings for UDP port 3630

2. **Validator not connecting to Charon**:
   - Verify Charon is running and healthy
   - Check validator client configuration

3. **Missing metrics**:
   - Ensure Prometheus is configured to scrape Charon and validator metrics
   - Check that the metrics endpoints are accessible

### Logs

- Charon logs: `docker logs ephemery-obol-charon`
- Validator logs: `docker logs ephemery-obol-validator`
- Dashboard logs: Check the Flask application logs

## References

- [Obol Network Documentation](https://docs.obol.tech/)
- [Charon Documentation](https://github.com/ObolNetwork/charon)
- [Distributed Validator Specification](https://github.com/ethereum/distributed-validator-specs)
- [Ephemery Documentation](https://github.com/eth-clients/ephemery) 