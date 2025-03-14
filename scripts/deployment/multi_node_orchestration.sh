#!/usr/bin/env bash
#
# Multi-Node Orchestration for Ephemery
# 
# This script provides functionality for deploying and managing multiple Ephemery nodes
# with load balancing and distributed genesis validator support.
#
# Features:
# - Deploy multiple nodes with a single command
# - Configure load balancing between nodes
# - Distribute genesis validator keys across nodes
# - Monitor health across node clusters
# - Coordinate automatic resets across the cluster
#

# Color definitions
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Default values
INVENTORY_FILE="inventory.yaml"
CONFIG_DIR="./config/multi_node"
LOAD_BALANCER_TYPE="nginx" # Options: nginx, haproxy
DISTRIBUTED_VALIDATORS=false
NUMBER_OF_NODES=3
NODE_PREFIX="ephemery-node"
ENABLE_MONITORING=true
SYNC_TYPE="checkpoint" # Options: checkpoint, genesis
AUTOMATIC_FAILOVER=true
HEALTH_CHECK_INTERVAL=60
LOG_DIR="./logs/multi_node"

# Function to show usage
show_usage() {
    echo -e "${BLUE}Ephemery Multi-Node Orchestration Tool${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo ""
    echo "Commands:"
    echo "  deploy              Deploy a multi-node Ephemery cluster"
    echo "  status              Show status of the multi-node cluster"
    echo "  scale               Scale the cluster up or down"
    echo "  balance             Rebalance validator keys across nodes"
    echo "  failover            Trigger manual failover to backup nodes"
    echo "  reset               Coordinate reset across all nodes"
    echo "  health              Run health checks across all nodes"
    echo "  cleanup             Clean up the multi-node deployment"
    echo ""
    echo "Options:"
    echo "  -i, --inventory     Specify custom inventory file (default: inventory.yaml)"
    echo "  -n, --nodes         Number of nodes to deploy (default: 3)"
    echo "  -p, --prefix        Prefix for node names (default: ephemery-node)"
    echo "  -l, --load-balancer Type of load balancer to use (nginx, haproxy)"
    echo "  -d, --distributed   Enable distributed validator keys"
    echo "  -m, --monitoring    Enable monitoring (true/false)"
    echo "  -s, --sync-type     Sync type (checkpoint, genesis)"
    echo "  -f, --failover      Enable automatic failover (true/false)"
    echo "  -c, --config        Config directory"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy -n 5 -l nginx -d  # Deploy 5 nodes with nginx load balancer and distributed validators"
    echo "  $0 status                   # Show status of all nodes in the cluster"
    echo "  $0 scale --nodes 7          # Scale the cluster to 7 nodes"
    echo ""
}

# Function to parse command line arguments
parse_args() {
    COMMAND=""
    
    # Parse command
    if [[ $# -gt 0 ]]; then
        COMMAND="$1"
        shift
    fi
    
    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -i|--inventory)
                INVENTORY_FILE="$2"
                shift 2
                ;;
            -n|--nodes)
                NUMBER_OF_NODES="$2"
                shift 2
                ;;
            -p|--prefix)
                NODE_PREFIX="$2"
                shift 2
                ;;
            -l|--load-balancer)
                LOAD_BALANCER_TYPE="$2"
                shift 2
                ;;
            -d|--distributed)
                DISTRIBUTED_VALIDATORS=true
                shift
                ;;
            -m|--monitoring)
                ENABLE_MONITORING="$2"
                shift 2
                ;;
            -s|--sync-type)
                SYNC_TYPE="$2"
                shift 2
                ;;
            -f|--failover)
                AUTOMATIC_FAILOVER="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo -e "${RED}Error: Unknown option $1${NC}"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate command
    if [[ -z "$COMMAND" ]]; then
        echo -e "${RED}Error: No command specified${NC}"
        show_usage
        exit 1
    fi
    
    # Validate options
    if [[ ! "$NUMBER_OF_NODES" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: Number of nodes must be a positive integer${NC}"
        exit 1
    fi
    
    if [[ "$LOAD_BALANCER_TYPE" != "nginx" && "$LOAD_BALANCER_TYPE" != "haproxy" ]]; then
        echo -e "${RED}Error: Load balancer type must be 'nginx' or 'haproxy'${NC}"
        exit 1
    fi
    
    if [[ "$SYNC_TYPE" != "checkpoint" && "$SYNC_TYPE" != "genesis" ]]; then
        echo -e "${RED}Error: Sync type must be 'checkpoint' or 'genesis'${NC}"
        exit 1
    fi
}

# Function to create multi-node inventory
create_multi_node_inventory() {
    echo -e "${BLUE}Creating multi-node inventory file...${NC}"
    
    # Create directory for inventory if it doesn't exist
    mkdir -p "$(dirname "$INVENTORY_FILE")"
    
    # Create basic structure
    cat > "$INVENTORY_FILE" << EOF
---
# Multi-node Ephemery inventory
# Generated by multi_node_orchestration.sh

# Group nodes by client combinations
ephemery:
  children:
EOF

    # Add node groups
    for ((i=1; i<=$NUMBER_OF_NODES; i++)); do
        # Alternate client combinations for better diversity
        # We'll use different combinations based on node number
        case $((i % 4)) in
            0)
                EL="erigon"
                CL="lighthouse"
                ;;
            1)
                EL="geth"
                CL="teku"
                ;;
            2)
                EL="nethermind"
                CL="prysm"
                ;;
            3)
                EL="besu"
                CL="lodestar"
                ;;
        esac

        NODE_NAME="${NODE_PREFIX}$i"
        NODE_IP="10.0.0.$((100 + i))" # Example IP, would be replaced in real deployment
        
        cat >> "$INVENTORY_FILE" << EOF
    ${EL}_${CL}_group${i}:
      hosts:
        ${NODE_NAME}:
          ansible_host: ${NODE_IP}
          el: ${EL}
          cl: ${CL}
          use_checkpoint_sync: $([ "$SYNC_TYPE" == "checkpoint" ] && echo "true" || echo "false")
          node_role: $([ $i -eq 1 ] && echo "primary" || echo "secondary")
          node_index: ${i}
          node_group: "multi_node_cluster"

EOF
    done

    # Add load balancer configuration
    cat >> "$INVENTORY_FILE" << EOF
    load_balancer:
      hosts:
        ${NODE_PREFIX}-lb:
          ansible_host: 10.0.0.99
          lb_type: ${LOAD_BALANCER_TYPE}
          backend_nodes: [$(for ((i=1; i<=$NUMBER_OF_NODES; i++)); do echo -n "\"${NODE_PREFIX}$i\""; [ $i -lt $NUMBER_OF_NODES ] && echo -n ", "; done)]
          lb_http_port: 8545
          lb_ws_port: 8546
          lb_consensus_port: 5052

EOF

    # Add validator configuration if distributed
    if [ "$DISTRIBUTED_VALIDATORS" = true ]; then
        cat >> "$INVENTORY_FILE" << EOF
# Validator configuration
validators:
  children:
    distributed_validators:
      hosts:
EOF
        # Distribute validators across nodes
        for ((i=1; i<=$NUMBER_OF_NODES; i++)); do
            NODE_NAME="${NODE_PREFIX}$i"
            cat >> "$INVENTORY_FILE" << EOF
        ${NODE_NAME}:
          validator_enabled: true
          validator_start_index: $((($i-1) * 10))
          validator_count: 10
EOF
        done
    fi

    # Add monitoring configuration
    cat >> "$INVENTORY_FILE" << EOF
# Monitoring configuration
monitoring:
  hosts:
    ${NODE_PREFIX}-monitor:
      ansible_host: 10.0.0.100
      monitoring_enabled: ${ENABLE_MONITORING}
      prometheus_enabled: true
      grafana_enabled: true
      monitored_nodes: [$(for ((i=1; i<=$NUMBER_OF_NODES; i++)); do echo -n "\"${NODE_PREFIX}$i\""; [ $i -lt $NUMBER_OF_NODES ] && echo -n ", "; done)]

# General variables for all hosts
all:
  vars:
    ansible_user: ubuntu
    ansible_become: true
    multi_node_deployment: true
    automatic_failover: ${AUTOMATIC_FAILOVER}
    health_check_interval: ${HEALTH_CHECK_INTERVAL}
    load_balancer_host: "${NODE_PREFIX}-lb"
    monitoring_host: "${NODE_PREFIX}-monitor"
    ephemery_network: true
    docker_installed: true
EOF

    echo -e "${GREEN}Inventory file created at ${INVENTORY_FILE}${NC}"
}

# Function to deploy the multi-node cluster
deploy_multi_node_cluster() {
    echo -e "${BLUE}Deploying multi-node Ephemery cluster...${NC}"
    
    # Create the inventory file
    create_multi_node_inventory
    
    # Create config directory
    mkdir -p "$CONFIG_DIR"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Deploy nodes using ansible
    echo -e "${YELLOW}Deploying ${NUMBER_OF_NODES} Ephemery nodes...${NC}"
    ansible-playbook -i "$INVENTORY_FILE" ephemery.yaml
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Multi-node deployment completed successfully!${NC}"
        echo -e "${YELLOW}Configuring load balancer...${NC}"
        
        # Deploy load balancer
        ansible-playbook -i "$INVENTORY_FILE" -l "${NODE_PREFIX}-lb" load_balancer.yaml
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Load balancer configured successfully!${NC}"
        else
            echo -e "${RED}Failed to configure load balancer${NC}"
            exit 1
        fi
        
        # Deploy monitoring if enabled
        if [ "$ENABLE_MONITORING" = true ]; then
            echo -e "${YELLOW}Setting up monitoring...${NC}"
            ansible-playbook -i "$INVENTORY_FILE" -l "${NODE_PREFIX}-monitor" monitoring.yaml
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Monitoring configured successfully!${NC}"
            else
                echo -e "${RED}Failed to configure monitoring${NC}"
                exit 1
            fi
        fi
        
        # If distributed validators are enabled, set up validator coordination
        if [ "$DISTRIBUTED_VALIDATORS" = true ]; then
            echo -e "${YELLOW}Setting up distributed validators...${NC}"
            ansible-playbook -i "$INVENTORY_FILE" -l "validators" validator_distribution.yaml
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}Distributed validators configured successfully!${NC}"
            else
                echo -e "${RED}Failed to configure distributed validators${NC}"
                exit 1
            fi
        fi
        
        # Configure health checks and automatic failover
        echo -e "${YELLOW}Setting up health checks and failover...${NC}"
        ansible-playbook -i "$INVENTORY_FILE" health_failover.yaml
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Health checks and failover configured successfully!${NC}"
        else
            echo -e "${RED}Failed to configure health checks and failover${NC}"
            exit 1
        fi
        
        # Show summary
        echo -e "\n${BLUE}Multi-node Ephemery Cluster Summary:${NC}"
        echo -e "Number of nodes: ${NUMBER_OF_NODES}"
        echo -e "Load balancer: ${LOAD_BALANCER_TYPE}"
        echo -e "Distributed validators: $([ "$DISTRIBUTED_VALIDATORS" = true ] && echo "Enabled" || echo "Disabled")"
        echo -e "Monitoring: $([ "$ENABLE_MONITORING" = true ] && echo "Enabled" || echo "Disabled")"
        echo -e "Sync type: ${SYNC_TYPE}"
        echo -e "Automatic failover: $([ "$AUTOMATIC_FAILOVER" = true ] && echo "Enabled" || echo "Disabled")"
        echo -e "\nTo check status: $0 status"
    else
        echo -e "${RED}Failed to deploy multi-node cluster${NC}"
        exit 1
    fi
}

# Function to check status of the multi-node cluster
check_cluster_status() {
    echo -e "${BLUE}Checking status of multi-node Ephemery cluster...${NC}"
    
    # Run ansible ad-hoc command to check status
    ansible -i "$INVENTORY_FILE" all -m shell -a "docker ps | grep ephemery"
    
    # Check load balancer status
    echo -e "\n${YELLOW}Load Balancer Status:${NC}"
    ansible -i "$INVENTORY_FILE" "${NODE_PREFIX}-lb" -m shell -a "systemctl status ${LOAD_BALANCER_TYPE} | grep Active"
    
    # Check monitoring status if enabled
    if [ "$ENABLE_MONITORING" = true ]; then
        echo -e "\n${YELLOW}Monitoring Status:${NC}"
        ansible -i "$INVENTORY_FILE" "${NODE_PREFIX}-monitor" -m shell -a "docker ps | grep -E 'prometheus|grafana'"
    fi
    
    # Show validator status if distributed
    if [ "$DISTRIBUTED_VALIDATORS" = true ]; then
        echo -e "\n${YELLOW}Validator Status:${NC}"
        ansible -i "$INVENTORY_FILE" validators -m shell -a "docker ps | grep validator"
    fi
}

# Function to scale the cluster
scale_cluster() {
    echo -e "${BLUE}Scaling multi-node Ephemery cluster to ${NUMBER_OF_NODES} nodes...${NC}"
    
    # Get current number of nodes
    CURRENT_NODES=$(grep -c "ansible_host:" "$INVENTORY_FILE")
    
    if [ "$NUMBER_OF_NODES" -gt "$CURRENT_NODES" ]; then
        echo -e "${YELLOW}Adding $((NUMBER_OF_NODES - CURRENT_NODES)) nodes to the cluster...${NC}"
        # Re-create inventory with more nodes
        create_multi_node_inventory
        
        # Deploy only the new nodes
        for ((i=CURRENT_NODES+1; i<=$NUMBER_OF_NODES; i++)); do
            NODE_NAME="${NODE_PREFIX}$i"
            echo -e "${YELLOW}Deploying ${NODE_NAME}...${NC}"
            ansible-playbook -i "$INVENTORY_FILE" -l "$NODE_NAME" ephemery.yaml
        done
        
        # Update load balancer configuration
        echo -e "${YELLOW}Updating load balancer configuration...${NC}"
        ansible-playbook -i "$INVENTORY_FILE" -l "${NODE_PREFIX}-lb" load_balancer.yaml
        
        # Update monitoring if enabled
        if [ "$ENABLE_MONITORING" = true ]; then
            echo -e "${YELLOW}Updating monitoring configuration...${NC}"
            ansible-playbook -i "$INVENTORY_FILE" -l "${NODE_PREFIX}-monitor" monitoring.yaml
        fi
        
        echo -e "${GREEN}Cluster successfully scaled up to ${NUMBER_OF_NODES} nodes${NC}"
    elif [ "$NUMBER_OF_NODES" -lt "$CURRENT_NODES" ]; then
        echo -e "${YELLOW}Removing $((CURRENT_NODES - NUMBER_OF_NODES)) nodes from the cluster...${NC}"
        
        # Stop services on nodes to be removed
        for ((i=NUMBER_OF_NODES+1; i<=$CURRENT_NODES; i++)); do
            NODE_NAME="${NODE_PREFIX}$i"
            echo -e "${YELLOW}Stopping services on ${NODE_NAME}...${NC}"
            ansible -i "$INVENTORY_FILE" "$NODE_NAME" -m shell -a "docker stop $(docker ps -q --filter name=ephemery)"
        done
        
        # Re-create inventory with fewer nodes
        create_multi_node_inventory
        
        # Update load balancer configuration
        echo -e "${YELLOW}Updating load balancer configuration...${NC}"
        ansible-playbook -i "$INVENTORY_FILE" -l "${NODE_PREFIX}-lb" load_balancer.yaml
        
        # Update monitoring if enabled
        if [ "$ENABLE_MONITORING" = true ]; then
            echo -e "${YELLOW}Updating monitoring configuration...${NC}"
            ansible-playbook -i "$INVENTORY_FILE" -l "${NODE_PREFIX}-monitor" monitoring.yaml
        fi
        
        echo -e "${GREEN}Cluster successfully scaled down to ${NUMBER_OF_NODES} nodes${NC}"
    else
        echo -e "${YELLOW}Cluster already has ${NUMBER_OF_NODES} nodes, no scaling needed${NC}"
    fi
}

# Function to rebalance validator keys
rebalance_validator_keys() {
    echo -e "${BLUE}Rebalancing validator keys across nodes...${NC}"
    
    if [ "$DISTRIBUTED_VALIDATORS" = true ]; then
        # Deploy validator distribution playbook
        ansible-playbook -i "$INVENTORY_FILE" -l "validators" validator_rebalance.yaml
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Validator keys rebalanced successfully!${NC}"
        else
            echo -e "${RED}Failed to rebalance validator keys${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Distributed validators not enabled in configuration${NC}"
        exit 1
    fi
}

# Function to trigger manual failover
trigger_failover() {
    echo -e "${BLUE}Triggering manual failover...${NC}"
    
    if [ "$AUTOMATIC_FAILOVER" = true ]; then
        # Get current primary node
        PRIMARY_NODE=$(grep "node_role: primary" "$INVENTORY_FILE" | awk '{print $1}' | sed 's/://')
        
        echo -e "${YELLOW}Current primary node is ${PRIMARY_NODE}${NC}"
        echo -e "${YELLOW}Triggering failover to backup node...${NC}"
        
        # Run the failover playbook
        ansible-playbook -i "$INVENTORY_FILE" manual_failover.yaml
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Failover completed successfully!${NC}"
            echo -e "${YELLOW}New primary node is now set in the inventory${NC}"
        else
            echo -e "${RED}Failed to trigger failover${NC}"
            exit 1
        fi
    else
        echo -e "${RED}Automatic failover not enabled in configuration${NC}"
        exit 1
    fi
}

# Function to coordinate reset across all nodes
coordinate_reset() {
    echo -e "${BLUE}Coordinating reset across all nodes...${NC}"
    
    # Stop all validators first
    if [ "$DISTRIBUTED_VALIDATORS" = true ]; then
        echo -e "${YELLOW}Stopping all validators...${NC}"
        ansible -i "$INVENTORY_FILE" validators -m shell -a "docker stop $(docker ps -q --filter name=validator)"
    fi
    
    # Stop consensus and execution clients on all nodes
    echo -e "${YELLOW}Stopping clients on all nodes...${NC}"
    ansible -i "$INVENTORY_FILE" ephemery -m shell -a "docker stop $(docker ps -q --filter name=ephemery)"
    
    # Clear data directories
    echo -e "${YELLOW}Clearing data directories...${NC}"
    ansible -i "$INVENTORY_FILE" ephemery -m shell -a "rm -rf /root/ephemery/data/*"
    
    # Start execution clients first
    echo -e "${YELLOW}Starting execution clients...${NC}"
    ansible -i "$INVENTORY_FILE" ephemery -m shell -a "docker start $(docker ps -a -q --filter name=geth --filter name=nethermind --filter name=besu --filter name=erigon)"
    
    # Wait for execution clients to initialize
    echo -e "${YELLOW}Waiting for execution clients to initialize (30 seconds)...${NC}"
    sleep 30
    
    # Start consensus clients
    echo -e "${YELLOW}Starting consensus clients...${NC}"
    ansible -i "$INVENTORY_FILE" ephemery -m shell -a "docker start $(docker ps -a -q --filter name=lighthouse --filter name=teku --filter name=prysm --filter name=lodestar)"
    
    # Wait for consensus clients to initialize
    echo -e "${YELLOW}Waiting for consensus clients to initialize (30 seconds)...${NC}"
    sleep 30
    
    # Start validators if distributed
    if [ "$DISTRIBUTED_VALIDATORS" = true ]; then
        echo -e "${YELLOW}Starting validators...${NC}"
        ansible -i "$INVENTORY_FILE" validators -m shell -a "docker start $(docker ps -a -q --filter name=validator)"
    fi
    
    echo -e "${GREEN}Reset coordinated successfully across all nodes!${NC}"
}

# Function to run health checks
run_health_checks() {
    echo -e "${BLUE}Running health checks across all nodes...${NC}"
    
    # Run the health check playbook
    ansible-playbook -i "$INVENTORY_FILE" health_check.yaml
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Health checks completed!${NC}"
    else
        echo -e "${RED}Health checks failed on one or more nodes${NC}"
    fi
}

# Function to clean up the deployment
cleanup_deployment() {
    echo -e "${BLUE}Cleaning up multi-node deployment...${NC}"
    
    echo -e "${YELLOW}This will stop all services and remove all data. Are you sure? (y/n)${NC}"
    read -r CONFIRM
    
    if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
        # Stop all containers
        echo -e "${YELLOW}Stopping all containers...${NC}"
        ansible -i "$INVENTORY_FILE" all -m shell -a "docker stop $(docker ps -q)" || true
        
        # Remove all containers
        echo -e "${YELLOW}Removing all containers...${NC}"
        ansible -i "$INVENTORY_FILE" all -m shell -a "docker rm $(docker ps -a -q)" || true
        
        # Remove data directories
        echo -e "${YELLOW}Removing data directories...${NC}"
        ansible -i "$INVENTORY_FILE" all -m shell -a "rm -rf /root/ephemery" || true
        
        echo -e "${GREEN}Cleanup completed!${NC}"
    else
        echo -e "${YELLOW}Cleanup cancelled${NC}"
    fi
}

# Main execution
parse_args "$@"

# Execute the appropriate command
case "$COMMAND" in
    deploy)
        deploy_multi_node_cluster
        ;;
    status)
        check_cluster_status
        ;;
    scale)
        scale_cluster
        ;;
    balance)
        rebalance_validator_keys
        ;;
    failover)
        trigger_failover
        ;;
    reset)
        coordinate_reset
        ;;
    health)
        run_health_checks
        ;;
    cleanup)
        cleanup_deployment
        ;;
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        show_usage
        exit 1
        ;;
esac

exit 0 