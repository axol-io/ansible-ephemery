# Unified Deployment System for Ephemery

This document provides detailed information about the unified deployment system for Ephemery nodes.

## Overview

The unified deployment system simplifies the process of deploying and configuring Ephemery nodes. It provides a consistent interface for both local and remote deployments, with guided configuration options and automated verification.

## Components

The unified deployment system consists of three main components:

1. **Main Deployment Script** (`scripts/deploy-ephemery.sh`)
   - Serves as the primary entry point for all deployments
   - Handles command-line arguments and configuration options
   - Orchestrates the deployment process

2. **Guided Configuration Tool** (`scripts/utils/guided_config.sh`)
   - Provides an interactive configuration workflow
   - Helps users create customized inventory files
   - Validates configuration options

3. **Deployment Verification Tool** (`scripts/utils/verify_deployment.sh`)
   - Verifies that deployments are successful
   - Checks container status, API connectivity, and other components
   - Provides detailed feedback on verification results

## Usage

### Basic Deployment

The simplest way to deploy an Ephemery node is to use the main deployment script:

```bash
./scripts/deploy-ephemery.sh
```

This will start an interactive process that guides you through selecting a deployment type (local or remote) and configuring the deployment options.

### Command-Line Options

The main deployment script supports various command-line options:

```bash
Usage: ./scripts/deploy-ephemery.sh [options]

Options:
  -h, --help                  Show this help message
  -t, --type TYPE             Deployment type (local|remote)
  -i, --inventory FILE        Use custom inventory file
  -H, --host HOST             Remote host (for remote deployment)
  -u, --user USER             Remote user (for remote deployment)
  -p, --port PORT             SSH port (default: 22)
  -r, --retention             Setup Ephemery retention system
  -v, --validator             Enable validator support
  -m, --monitoring            Enable sync monitoring
  -d, --dashboard             Enable web dashboard
  --skip-verify               Skip deployment verification
  -y, --yes                   Skip all prompts, use defaults
```

### Deployment Types

#### Local Deployment

For deploying an Ephemery node on the local machine:

```bash
./scripts/deploy-ephemery.sh --type local
```

This will deploy the Ephemery node using Docker containers on the local machine.

#### Remote Deployment

For deploying an Ephemery node on a remote server:

```bash
./scripts/deploy-ephemery.sh --type remote --host your-server --user your-username
```

This will deploy the Ephemery node on the specified remote server using SSH.

### Using Custom Inventory Files

You can create and use custom inventory files for more advanced configurations:

```bash
# Create a custom inventory file
./scripts/utils/guided_config.sh --output my-inventory.yaml

# Deploy using the custom inventory file
./scripts/deploy-ephemery.sh --inventory my-inventory.yaml
```

### Non-Interactive Deployment

For automated or scripted deployments, you can use the `--yes` flag to skip all prompts and use default values:

```bash
./scripts/deploy-ephemery.sh --type local --yes
```

## Deployment Process

The unified deployment system follows these steps:

1. **Parse Arguments and Configuration**
   - Process command-line options
   - Set default values for unspecified options

2. **Select Deployment Type**
   - Determine whether to deploy locally or remotely
   - Collect remote server details if needed

3. **Check Prerequisites**
   - Verify that required tools and dependencies are available
   - Check connectivity to remote server if applicable

4. **Configure Deployment**
   - Set up feature flags and configuration options
   - Generate or validate inventory file

5. **Run Deployment**
   - Execute the appropriate deployment script
   - Set up containers and services

6. **Setup Retention (if enabled)**
   - Deploy Ephemery retention system
   - Configure cron job for automatic resets

7. **Verify Deployment**
   - Check container status
   - Verify API connectivity
   - Test feature functionality

8. **Display Final Information**
   - Show connection details
   - Provide monitoring instructions

## Verification Process

The verification process checks the following components:

- **Execution Client** (Geth)
  - Container status
  - API connectivity
  - Sync status

- **Consensus Client** (Lighthouse)
  - Container status
  - API connectivity
  - Sync status

- **Validator Client** (if enabled)
  - Container status
  - API connectivity

- **Retention System** (if enabled)
  - Script installation
  - Cron job configuration

- **Dashboard** (if enabled)
  - Web server status
  - API connectivity

## Advanced Configuration

### Inventory Files

Inventory files are YAML documents that define the configuration for an Ephemery deployment. They can be created manually or using the guided configuration tool.

Example inventory file:

```yaml
---
# Ephemery Inventory File

# Deployment type
deployment_type: local

# Directory paths
directories:
  base: /opt/ephemery
  data: /opt/ephemery/data
  logs: /opt/ephemery/logs

# Client configuration
clients:
  execution: geth
  consensus: lighthouse

geth:
  image: pk910/ephemery-geth:latest
  cache: 2048
  max_peers: 50

lighthouse:
  image: pk910/ephemery-lighthouse:latest
  target_peers: 30

# Feature flags
features:
  validator:
    enabled: false
  retention:
    enabled: true
  monitoring:
    enabled: true
    dashboard: false
```

### Remote Deployment Configuration

For remote deployments, additional configuration is required:

```yaml
# Remote connection details
remote:
  host: your-server-hostname
  user: your-username
  port: 22
```

### Validator Configuration

To enable validator support:

```yaml
# Validator configuration
features:
  validator:
    enabled: true
    expected_key_count: 1000

validator:
  image: sigp/lighthouse:latest
```

## Troubleshooting

### Deployment Failures

If deployment fails, check the following:

- Docker is installed and running (for local deployments)
- SSH connectivity is working (for remote deployments)
- Required ports are available (8545, 5052, etc.)
- Sufficient disk space and memory are available

### Verification Failures

If verification fails, the verification script will provide specific error messages. Common issues include:

- Containers not starting properly
- API endpoints not responding
- Network connectivity issues
- Configuration errors

### Manual Verification

You can run the verification script manually:

```bash
# For local deployments
./scripts/utils/verify_deployment.sh --type local

# For remote deployments
./scripts/utils/verify_deployment.sh --type remote --host your-server --user your-username
```

## Customizing the Deployment

### Modifying Default Values

The default values for the deployment can be modified by editing the following files:

- `scripts/deploy-ephemery.sh`: Main deployment script
- `scripts/utils/guided_config.sh`: Guided configuration tool

### Adding New Features

To add new features to the deployment system:

1. Update the command-line options in `deploy-ephemery.sh`
2. Add configuration options to `guided_config.sh`
3. Update the verification process in `verify_deployment.sh`
4. Update the documentation in `docs/UNIFIED_DEPLOYMENT.md`

## List of New Files and Changes

The unified deployment system consists of the following new files:

- `scripts/deploy-ephemery.sh` - Main deployment script
- `scripts/utils/guided_config.sh` - Guided configuration tool
- `scripts/utils/verify_deployment.sh` - Deployment verification tool
- `docs/UNIFIED_DEPLOYMENT.md` - Documentation for the unified deployment system

Updates to existing files:

- `README.md` - Added information about the unified deployment system
- `CHANGELOG.md` - Added unified deployment system to the list of completed features
- `docs/roadmaps/ROADMAP.md` - Updated roadmap to mark unified deployment system as completed

## Conclusion

The unified deployment system provides a simple, consistent, and reliable way to deploy Ephemery nodes. It handles the complexities of deployment and configuration, allowing users to focus on using Ephemery for testing and development.

For more information, see:

- [Ephemery Setup Guide](EPHEMERY_SETUP.md)
- [Ephemery Script Reference](EPHEMERY_SCRIPT_REFERENCE.md)
- [Ephemery-Specific Configuration](EPHEMERY_SPECIFIC.md)
