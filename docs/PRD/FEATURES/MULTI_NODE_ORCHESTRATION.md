# Multi-Node Orchestration

This document describes the Multi-Node Orchestration feature for Ephemery validators, which enables deploying and managing multiple Ephemery nodes with load balancing and distributed genesis validator support.

## Overview

The Multi-Node Orchestration system provides a comprehensive solution for deploying and managing a cluster of Ephemery nodes, offering improved reliability, scalability, and performance. It enables distributed validator deployments across multiple nodes with automatic failover capabilities.

## Features

### 1. Multi-Node Deployment

- **Cluster Deployment**: Deploy multiple Ephemery nodes with a single command
- **Client Diversity**: Automatically configure different client combinations across nodes
- **Unified Configuration**: Centralized inventory management for the entire cluster
- **Scalable Architecture**: Easily add or remove nodes as needed

### 2. Load Balancing

- **High Availability**: Distribute requests across multiple nodes
- **Automatic Failover**: Redirect traffic from unhealthy nodes
- **Multiple Load Balancer Options**: Support for NGINX and HAProxy
- **Optimized Routing**: Smart load distribution based on node health and capacity

### 3. Distributed Genesis Validator Support

- **Key Distribution**: Distribute validator keys across multiple nodes
- **Coordinated Operations**: Synchronize validator operations across the cluster
- **Fault Tolerance**: Continue validator operations even if some nodes fail
- **Dynamic Rebalancing**: Redistribute validator keys as needed

### 4. Health Monitoring

- **Comprehensive Health Checks**: Monitor all aspects of node health
- **Automatic Recovery**: Detect and recover from common issues
- **Coordinated Resets**: Manage Ephemery resets across the cluster
- **Alerting Integration**: Send notifications on critical issues

## Architecture

The Multi-Node Orchestration system consists of several components:

1. **Command-Line Interface (CLI)**: Provides a user-friendly interface for managing the cluster
2. **Inventory Management**: Manages node configurations and roles
3. **Load Balancer**: Distributes traffic across nodes
4. **Health Monitoring System**: Monitors node health and performs failover
5. **Validator Distribution System**: Manages validator keys across nodes

![Multi-Node Architecture](../assets/multi_node_architecture.png)

## Components

### Command-Line Interface

The Multi-Node Orchestration CLI provides commands for:

- **Deploying** a new cluster
- Checking cluster **status**
- **Scaling** the cluster up or down
- **Rebalancing** validator keys
- Triggering manual **failover**
- Coordinating **reset** across all nodes
- Running **health** checks
- **Cleaning up** the deployment

### Load Balancer

The load balancer distributes traffic to:

- **HTTP RPC Endpoints**: Execution client JSON-RPC API
- **WebSocket Endpoints**: Execution client WebSocket API
- **Consensus API Endpoints**: Consensus client Beacon API

It provides:

- **Health-based routing**: Routes requests only to healthy nodes
- **Automatic failover**: Redirects traffic from unhealthy nodes
- **Weighted load balancing**: Distributes load based on node capacity
- **Session persistence**: Maintains consistent connections for WebSocket

### Health Monitoring System

The health monitoring system:

- **Performs regular health checks** on all nodes
- **Detects unhealthy nodes** and removes them from the load balancer
- **Triggers automatic failover** when the primary node fails
- **Sends notifications** on critical events
- **Attempts automatic recovery** for common issues

### Validator Distribution System

The validator distribution system:

- **Distributes validator keys** across multiple nodes
- **Ensures validator redundancy** for fault tolerance
- **Manages validator assignments** during node scaling
- **Coordinates validator operations** during Ephemery resets

## Usage

### Deploying a Multi-Node Cluster

Deploy a new multi-node cluster with:

```bash
./scripts/deployment/multi_node_orchestration.sh deploy --nodes 5 --load-balancer nginx --distributed
```

This command:
- Deploys 5 Ephemery nodes with different client combinations
- Configures an NGINX load balancer
- Sets up distributed validators across all nodes
- Configures health monitoring and automatic failover

### Checking Cluster Status

Check the status of the cluster with:

```bash
./scripts/deployment/multi_node_orchestration.sh status
```

This shows:
- The status of all nodes
- Load balancer configuration
- Validator distribution
- Recent health check results

### Scaling the Cluster

Scale the cluster up or down with:

```bash
./scripts/deployment/multi_node_orchestration.sh scale --nodes 7
```

This:
- Adds or removes nodes as needed
- Updates load balancer configuration
- Redistributes validator keys (if distributed validators are enabled)
- Reconfigures monitoring system

### Rebalancing Validator Keys

Redistribute validator keys across nodes with:

```bash
./scripts/deployment/multi_node_orchestration.sh balance
```

This:
- Redistributes validator keys evenly across nodes
- Updates validator clients
- Maintains consistent validator operations during rebalancing

### Triggering Manual Failover

Trigger a manual failover with:

```bash
./scripts/deployment/multi_node_orchestration.sh failover
```

This:
- Transitions the primary role to a healthy backup node
- Updates load balancer configuration
- Ensures continuous validator operations

### Coordinating Reset Across All Nodes

Coordinate an Ephemery reset across all nodes with:

```bash
./scripts/deployment/multi_node_orchestration.sh reset
```

This:
- Stops all validators in a coordinated manner
- Clears data directories across all nodes
- Restarts clients in the correct order
- Ensures validators resume operation with the new genesis

### Running Health Checks

Run a comprehensive health check across all nodes with:

```bash
./scripts/deployment/multi_node_orchestration.sh health
```

This:
- Checks all nodes for health issues
- Updates load balancer configuration based on results
- Attempts automatic recovery where possible
- Generates a detailed health report

### Cleaning Up the Deployment

Clean up the entire deployment with:

```bash
./scripts/deployment/multi_node_orchestration.sh cleanup
```

This:
- Stops all services
- Removes all containers
- Deletes all data directories

## Configuration

### Inventory File

The multi-node inventory file defines:

- **Node roles and groups**: How nodes are organized
- **Client combinations**: Which clients run on each node
- **Validator distribution**: How validators are distributed
- **Load balancer configuration**: How traffic is distributed
- **Monitoring setup**: How nodes are monitored

Example inventory structure:

```yaml
ephemery:
  children:
    geth_lighthouse_group1:
      hosts:
        ephemery-node1:
          ansible_host: 10.0.0.101
          el: geth
          cl: lighthouse
          node_role: primary

    nethermind_teku_group2:
      hosts:
        ephemery-node2:
          ansible_host: 10.0.0.102
          el: nethermind
          cl: teku
          node_role: secondary

validators:
  children:
    distributed_validators:
      hosts:
        ephemery-node1:
          validator_enabled: true
          validator_start_index: 0
          validator_count: 10
        ephemery-node2:
          validator_enabled: true
          validator_start_index: 10
          validator_count: 10
```

### Load Balancer Configuration

The load balancer can be configured with:

- **Backend selection**: Which nodes are included in the load balancer
- **Health check parameters**: How node health is determined
- **Load distribution algorithm**: How traffic is distributed
- **Failover behavior**: How failover is performed

### Validator Distribution

Validator distribution can be configured with:

- **Key assignment**: How validator keys are assigned to nodes
- **Redundancy level**: How many nodes can validate the same key
- **Rebalancing thresholds**: When validators are redistributed

## Best Practices

### Deployment Recommendations

For optimal performance and reliability:

1. **Use diverse client combinations** across nodes to minimize correlated failures
2. **Deploy at least 3 nodes** for proper redundancy and failover
3. **Use SSD storage** for all nodes to ensure fast synchronization
4. **Enable automatic failover** for production deployments
5. **Use a dedicated load balancer node** for high-traffic deployments

### Monitoring Recommendations

For effective monitoring:

1. **Set up alerting** for critical health check failures
2. **Monitor validator performance** across all nodes
3. **Track load balancer metrics** to identify bottlenecks
4. **Review health check logs** regularly
5. **Monitor resource usage** on all nodes

### Scaling Recommendations

When scaling the cluster:

1. **Add nodes incrementally** to avoid overloading the network
2. **Rebalance validators** after scaling
3. **Verify health** of all nodes after scaling
4. **Test failover** after significant changes

## Troubleshooting

### Common Issues

#### Load Balancer Connection Failures

- **Symptom**: Clients cannot connect to the load balancer
- **Possible Causes**: Firewall issues, load balancer not running
- **Solution**: Verify load balancer status, check firewall rules

#### Node Health Check Failures

- **Symptom**: Nodes are marked as unhealthy
- **Possible Causes**: Client issues, resource constraints
- **Solution**: Check node logs, verify resource availability

#### Validator Key Distribution Issues

- **Symptom**: Validators not operating correctly
- **Possible Causes**: Key distribution issues, client configuration
- **Solution**: Verify key distribution, check validator client configuration

#### Failover Issues

- **Symptom**: Automatic failover not working
- **Possible Causes**: Health check configuration, load balancer issues
- **Solution**: Check health check configuration, verify load balancer settings

## Future Enhancements

Planned enhancements include:

1. **Geographic Distribution**: Distribute nodes across multiple regions
2. **Advanced Redundancy**: Run redundant validators across nodes
3. **Dynamic Scaling**: Automatically scale based on load
4. **Self-Healing**: Automatically recover from more complex failures
5. **Performance Optimization**: Advanced load balancing algorithms

## Reference

### Command Reference

| Command | Description |
|---------|-------------|
| `deploy` | Deploy a multi-node Ephemery cluster |
| `status` | Show status of the multi-node cluster |
| `scale` | Scale the cluster up or down |
| `balance` | Rebalance validator keys across nodes |
| `failover` | Trigger manual failover to backup nodes |
| `reset` | Coordinate reset across all nodes |
| `health` | Run health checks across all nodes |
| `cleanup` | Clean up the multi-node deployment |

### Option Reference

| Option | Description | Default |
|--------|-------------|---------|
| `--inventory` | Specify custom inventory file | `inventory.yaml` |
| `--nodes` | Number of nodes to deploy | `3` |
| `--prefix` | Prefix for node names | `ephemery-node` |
| `--load-balancer` | Type of load balancer (nginx, haproxy) | `nginx` |
| `--distributed` | Enable distributed validator keys | `false` |
| `--monitoring` | Enable monitoring (true/false) | `true` |
| `--sync-type` | Sync type (checkpoint, genesis) | `checkpoint` |
| `--failover` | Enable automatic failover (true/false) | `true` |
| `--config` | Config directory | `./config/multi_node` |

## Limitations

Current limitations include:

1. **No Shared Validator Keys**: Each validator key can only be active on one node at a time
2. **Manual Recovery**: Some failure scenarios require manual intervention
3. **Reset Coordination**: Reset coordination requires careful timing
4. **Client Compatibility**: Not all client combinations have been extensively tested

## Conclusion

The Multi-Node Orchestration system provides a comprehensive solution for deploying and managing Ephemery validator clusters with improved reliability, scalability, and performance. By distributing validators across multiple nodes and implementing automatic failover, it significantly enhances the resilience of Ephemery validator operations. 