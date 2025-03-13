# Ephemery Production Deployment: Findings and Next Steps

## Executive Summary

We've completed an initial production deployment attempt of our Ephemery node. The setup was partially successful, establishing the infrastructure and deploying containers, but encountered several issues preventing fully operational status. This document outlines our findings, challenges, and recommended next steps.

## Deployment Findings

### Successful Components

1. **Infrastructure Deployment**
   - Successfully deployed base infrastructure using Ansible
   - Created all required directories and file structures
   - Proper JWT secret generation and configuration
   - Validator client configuration completed

2. **Automation Setup**
   - Ephemery retention script deployed for automated reset detection
   - Cron job configured for periodic checks

### Identified Issues

1. **Client Container Failures**
   - **Lighthouse Client**: Error `invalid value 'ephemery' for '--network <network>'` indicates the client doesn't recognize Ephemery as a valid network
   - **Geth Client**: Failures in startup with `invalid command: "geth"` errors
   - Containers continually restart due to these configuration issues

2. **Monitoring System**
   - Prometheus and Grafana containers repeatedly restarting
   - Missing configuration for datasources (template file not found)

3. **Network Configuration**
   - Special Ephemery network configuration not properly initialized
   - Checkpoint sync working but not with correct genesis data

## Root Cause Analysis

1. **Client Compatibility**
   - Standard Lighthouse client doesn't support Ephemery network directly
   - Need properly configured Ephemery-specific clients
   - Special wrapper scripts from pk910/ephemery-* images not executing correctly

2. **Network Genesis**
   - Despite using ephemery-specific images, genesis configuration needs proper setup
   - Log shows: "found stored ephemery genesis (iteration ephemery-143)"

3. **Deployment Process**
   - The unified deployment script encountered issues extracting configuration from inventory
   - Direct Ansible playbook execution more successful but still incomplete

## Next Steps

### Immediate Actions

1. **Fix Client Container Configuration**
   ```yaml
   # Update client images configuration in inventory
   client_images:
     geth: 'pk910/ephemery-geth:v1.15.3'   # Use specific version tags
     lighthouse: 'pk910/ephemery-lighthouse:v5.3.0'
     validator: 'pk910/ephemery-lighthouse:v5.3.0'
   ```

2. **Network Directory Setup**
   ```bash
   # Create Ephemery testnet config directory
   ssh root@103.214.23.174 "mkdir -p /opt/ephemery/config/ephemery_network"

   # Download latest Ephemery network configuration
   ssh root@103.214.23.174 "cd /opt/ephemery/config/ephemery_network && \
     wget https://ephemery.dev/ephemery-143/testnet-all.tar.gz && \
     tar -xzf testnet-all.tar.gz"
   ```

3. **Fix Container Parameters**
   - Update container run parameters to correctly reference testnet directory:
   ```yaml
   # For Lighthouse
   cl_extra_opts: "--testnet-dir=/opt/ephemery/config/ephemery_network --target-peers=100 --execution-timeout-multiplier=5 --allow-insecure-genesis-sync --genesis-backfill --disable-backfill-rate-limiting"
   ```

4. **Fix Checkpoint Sync**
   ```bash
   # Run checkpoint sync fix script
   ./scripts/fix_checkpoint_sync.sh --inventory production-inventory.yaml
   ```

### Medium-term Improvements

1. **Monitoring Enhancement**
   - Fix Prometheus and Grafana integration with proper templates
   - Implement Ephemery-specific dashboards with network reset tracking

2. **Validation Process**
   - Create comprehensive validation script to verify all components
   - Add health check monitoring for container restart detection

3. **Documentation Updates**
   - Create Ephemery-specific deployment guide
   - Document common issues and resolutions

### Long-term Recommendations

1. **Ephemery Network Production Template**
   - Create standardized template specifically for Ephemery production deployments
   - Include pre-validated configurations for all components

2. **Auto-recovery System**
   - Implement enhanced monitoring with auto-recovery for failed components
   - Build automatic genesis detection and network reset handling

3. **Update Core Deployment Scripts**
   - Fix extraction of host and user from inventory file in unified deployment script
   - Create simpler production deployment path with fewer dependencies

## Implementation Timeline

| Action Item | Priority | Estimated Time | Dependencies |
|-------------|----------|----------------|--------------|
| Fix client container configuration | High | 1 day | None |
| Network directory setup | High | 0.5 days | None |
| Fix container parameters | High | 0.5 days | Network setup |
| Fix checkpoint sync | High | 1 day | Container config |
| Monitoring enhancement | Medium | 2 days | Working containers |
| Validation process | Medium | 2 days | Working deployment |
| Documentation updates | Medium | 3 days | All fixes implemented |
| Production template | Low | 5 days | Documentation |
| Auto-recovery system | Low | 7 days | Working monitoring |
| Update core scripts | Medium | 3 days | None |

## Technical Documentation

### Production Server Overview

- **Server IP**: 103.214.23.174
- **Base Directory**: /opt/ephemery
- **Client Configuration**:
  - Execution Layer: Geth
  - Consensus Layer: Lighthouse
  - Validator: Lighthouse validator

### Container Status and Troubleshooting

The deployed containers are currently in a restart loop due to configuration issues:

```
CONTAINER ID   IMAGE                              STATUS                    NAMES
3dc768ba227d   sigp/lighthouse:v5.3.0             Restarting (2) 48s ago   ephemery-validator-lighthouse
e1f74e602f3d   pk910/ephemery-lighthouse:latest   Restarting (1) 52s ago   ephemery-lighthouse
4d3b9c34c007   pk910/ephemery-geth:latest         Restarting (1) 58s ago   ephemery-geth
```

**Key Error Analysis**:
- Lighthouse error: `invalid value 'ephemery' for '--network <network>'`
- Geth error: `invalid command: "geth"`

### Modified Workflow for Production Deployment

1. Create properly structured inventory file (completed)
2. Deploy base infrastructure with main playbook:
   ```bash
   ansible-playbook -i production-inventory.yaml ansible/playbooks/main.yaml
   ```
3. Fix network configuration with latest genesis:
   ```bash
   ./scripts/fix_checkpoint_sync.sh --inventory production-inventory.yaml
   ```
4. Deploy validator client:
   ```bash
   ansible-playbook -i production-inventory.yaml ansible/playbooks/validator.yaml
   ```
5. Setup retention script (manually):
   ```bash
   scp scripts/ephemery_retention.sh root@SERVER:/opt/ephemery/scripts/
   ssh root@SERVER "chmod +x /opt/ephemery/scripts/ephemery_retention.sh && \
     (crontab -l 2>/dev/null; echo '*/5 * * * * /opt/ephemery/scripts/ephemery_retention.sh >> /opt/ephemery/logs/retention.log 2>&1') | crontab -"
   ```

## Known Issues

| Issue | Impact | Workaround | Permanent Fix |
|-------|--------|------------|---------------|
| Standard Lighthouse client doesn't support Ephemery | Client restarts | Use pk910/ephemery-lighthouse image with proper testnet directory | Create dedicated Ephemery client package |
| Unified deployment script extraction failure | Script exits with error | Use direct Ansible playbook execution | Fix script to properly parse inventory |
| Monitoring template missing | Monitoring system fails | Manual template creation | Include templates in package |
| Container restart loop | Service unavailable | Manual container configuration | Fix deployment playbooks |

This documentation will be updated as we implement fixes and gather more information about the production deployment process.

## Recent Deployment Fixes (March 2025)

### Resolved Issues

1. **JWT Authentication Failure**
   - **Problem**: Lighthouse container was unable to authenticate with Geth using JWT token, showing `ERRO Failed jwt authorization error: InvalidToken` errors
   - **Root Cause**: Container name resolution issues between Lighthouse and Geth containers
   - **Solution**: Reconfigured Lighthouse container to use Geth's IP address directly instead of container name

   ```bash
   # Get Geth IP address
   GETH_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ephemery-geth)

   # Recreate Lighthouse container with Geth IP
   docker run -d --name ephemery-lighthouse \
       --network ephemery-net \
       --restart unless-stopped \
       -v /root/ephemery/data/lighthouse:/ethdata \
       -v /root/ephemery/jwt.hex:/config/jwt-secret \
       -p 5052:5052 -p 9000:9000 -p 9000:9000/udp -p 8008:8008 \
       pk910/ephemery-lighthouse:latest \
       lighthouse beacon \
       --datadir /ethdata \
       --testnet-dir /ephemery_config \
       --execution-jwt /config/jwt-secret \
       --execution-endpoint http://$GETH_IP:8551 \
       --http --http-address 0.0.0.0 --http-port 5052 \
       --target-peers=100 \
       --execution-timeout-multiplier=5 \
       --allow-insecure-genesis-sync \
       --genesis-backfill \
       --disable-backfill-rate-limiting \
       --disable-deposit-contract-sync
   ```

2. **Monitoring Stack Failures**
   - **Problem**: Prometheus and Grafana containers were continuously restarting
   - **Root Cause**: YAML syntax error in Prometheus configuration file
   - **Solution**: Created a valid Prometheus configuration file and recreated the containers

   ```bash
   # Create proper Prometheus configuration
   cat > /root/ephemery/config/prometheus/prometheus.yml << EOF
   global:
     scrape_interval: 15s
     evaluation_interval: 15s

   scrape_configs:
     - job_name: 'prometheus'
       static_configs:
         - targets: ['localhost:9090']

     - job_name: 'node_exporter'
       static_configs:
         - targets: ['node-exporter:9100']

     - job_name: 'geth'
       metrics_path: /debug/metrics/prometheus
       static_configs:
         - targets: ['ephemery-geth:6060']

     - job_name: 'lighthouse'
       static_configs:
         - targets: ['ephemery-lighthouse:5054']
   EOF

   # Recreate Prometheus container
   docker run -d --name prometheus --network host \
       -v /root/ephemery/config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml \
       prom/prometheus:v2.47.2

   # Recreate Grafana container
   docker run -d --name grafana --network host \
       -e GF_SECURITY_ADMIN_USER=admin \
       -e GF_SECURITY_ADMIN_PASSWORD=ephemery \
       -e GF_AUTH_ANONYMOUS_ENABLED=true \
       -e GF_USERS_ALLOW_SIGN_UP=false \
       -e GF_SERVER_HTTP_PORT=3000 \
       grafana/grafana:latest
   ```

### Current Status

The Ephemery node is now fully operational with both Geth and Lighthouse containers running properly. The monitoring stack is also functioning correctly.

- **Geth**: Running and accepting connections
- **Lighthouse**: Successfully connecting to Geth and syncing with the network
- **Monitoring**: Prometheus and Grafana are operational

### Recommendations for Future Deployments

1. **Container Networking**:
   - Use a dedicated Docker network for Ethereum clients
   - Consider using IP addresses instead of container names for critical connections
   - Implement network connectivity tests in deployment scripts

2. **Monitoring Configuration**:
   - Include pre-configured Prometheus and Grafana configurations in the deployment
   - Add validation steps for monitoring configuration files
   - Implement automatic dashboard provisioning

3. **Troubleshooting Tools**:
   - Deploy the `troubleshoot_ephemery.sh` script to all production servers
   - Add comprehensive logging for all deployment steps
   - Implement automated health checks for early detection of issues
