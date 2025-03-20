# Ephemery Scripts Technical Reference

This document provides detailed technical documentation for the Ephemery scripts, explaining each function and configuration element.

## Table of Contents

1. [Ephemery Retention Script](#ephemery-retention-script)
   - [Configuration Variables](#configuration-variables)
   - [Client Management Functions](#client-management-functions)
   - [Data Management Functions](#data-management-functions)
   - [Genesis Management Functions](#genesis-management-functions)
   - [Main Control Flow](#main-control-flow)
2. [Cron Setup Script](#cron-setup-script)
3. [Deployment Script](#deployment-script)
4. [Ansible Playbook](#ansible-playbook)

## Ephemery Retention Script

The `ephemery_retention.sh` script is the core component that manages the Ephemery testnet node's lifecycle, handling automatic resets and updates.

### Configuration Variables

| Variable | Description |
|----------|-------------|
| `HOME_DIR` | Base directory for all Ephemery files, default is `/root/ephemery` |
| `DATA_DIR` | Directory for client data storage, default is `$HOME_DIR/data` |
| `CONFIG_DIR` | Directory for configuration files, default is `$HOME_DIR/config` |
| `LOG_DIR` | Directory for log files, default is `$HOME_DIR/logs` |
| `GENESIS_REPO` | GitHub repository for genesis files, default is `ephemery-testnet/ephemery-genesis` |
| `CL_PORT` | Port for the consensus layer API, default is `5052` |

### Client Management Functions

#### `start_clients()`

**Purpose**: Starts the Docker containers for the execution and consensus clients.

**Details**:

- Starts the execution layer client (Geth) first
- Waits 10 seconds to allow Geth to initialize
- Starts the consensus layer client (Lighthouse)
- Contains commented code to start a validator client if needed

**Usage Example**:

```bash
start_clients
```

#### `stop_clients()`

**Purpose**: Stops all Docker containers for the Ethereum clients.

**Details**:

- Stops both execution and consensus layer clients
- Uses `|| true` to prevent script failure if containers are already stopped
- Contains commented code to stop a validator client if needed

**Usage Example**:

```bash
stop_clients
```

### Data Management Functions

#### `clear_datadirs()`

**Purpose**: Clears client data directories while preserving critical files.

**Details**:

- Preserves the Geth node key to maintain network identity
- Completely clears beacon node data
- Removes slashing protection database if it exists
- Creates necessary directories if they don't exist

**Process**:

1. Checks if a nodekey exists and preserves it
2. Removes all Geth data
3. Recreates directories and restores the nodekey
4. Clears the beacon node data directory
5. Removes slashing protection database if present

**Usage Example**:

```bash
clear_datadirs
```

### Genesis Management Functions

#### `setup_genesis()`

**Purpose**: Initializes the execution client with the new genesis configuration.

**Details**:

- Uses Docker to run the initialization command
- Mounts the data and config directories as volumes
- Initializes Geth with the genesis.json file

**Usage Example**:

```bash
setup_genesis
```

#### `get_github_release()`

**Purpose**: Retrieves the latest release tag from a GitHub repository.

**Details**:

- Uses GitHub API to fetch release information
- Parses the response to extract the tag name
- Returns the tag name as a string

**Parameters**:

- `$1`: The GitHub repository path (e.g., `ephemery-testnet/ephemery-genesis`)

**Returns**: The latest release tag name

**Usage Example**:

```bash
latest_release=$(get_github_release "ephemery-testnet/ephemery-genesis")
```

#### `download_genesis_release()`

**Purpose**: Downloads and extracts the latest genesis configuration files.

**Details**:

- Creates the configuration directory if it doesn't exist
- Clears existing configuration files
- Downloads the release tarball from GitHub
- Extracts the files to the config directory
- Creates a retention.vars file with key information

**Parameters**:

- `$1`: The release tag to download

**Usage Example**:

```bash
download_genesis_release "v1.2.3"
```

#### `reset_testnet()`

**Purpose**: Performs a complete reset of the testnet node to a new genesis state.

**Details**:

- Orchestrates the entire reset process
- Manages the sequence of operations to ensure a clean reset

**Process**:

1. Stops all client containers
2. Clears data directories while preserving important files
3. Downloads the new genesis files
4. Initializes the execution client with the new genesis
5. Starts all client containers

**Parameters**:

- `$1`: The release tag to reset to

**Usage Example**:

```bash
reset_testnet "v1.2.3"
```

#### `check_testnet()`

**Purpose**: Checks if the testnet needs to be reset based on genesis time.

**Details**:

- Retrieves the genesis time from the running beacon node
- Handles error cases when the beacon node is unreachable
- Calculates the reset time based on the genesis time
- Checks for new releases and initiates a reset if needed

**Process**:

1. Gets the current time and beacon node genesis time
2. Calculates when the next reset should occur
3. If unable to get genesis time, attempts recovery or forces a reset
4. If reset time is reached, checks for a new release
5. If a new release is found, initiates a reset

**Usage Example**:

```bash
check_testnet
```

### Main Control Flow

#### `main()`

**Purpose**: Controls the overall script execution flow.

**Details**:

- Serves as the entry point for the script
- Decides whether to perform an initial setup or check for updates

**Process**:

1. Checks if a genesis file exists
2. If no genesis file is found, performs an initial setup
3. Otherwise, checks if the testnet needs to be reset

**Usage Example**:

```bash
main
```

## Cron Setup Script

The `setup_ephemery_cron.sh` script automates the creation of a cron job for running the retention script regularly.

### Key Functions

#### Script Validation

**Purpose**: Validates that the retention script exists and is executable.

**Details**:

- Checks if the script exists at the expected path
- Makes the script executable if needed
- Provides clear error messages if script is missing

#### Cron Job Management

**Purpose**: Creates or updates the cron job for the retention script.

**Details**:

- Checks if a cron job already exists for the script
- Removes existing entries to avoid duplication
- Adds a new cron job to run every 5 minutes
- Redirects output to a log file

#### Initial Run

**Purpose**: Runs the retention script immediately after setup.

**Details**:

- Executes the script for immediate validation
- Displays the output of the first run
- Helps identify any immediate issues

## Deployment Script

The `deploy_ephemery_retention.sh` script simplifies the deployment process using Ansible.

### Key Functions

#### Environment Validation

**Purpose**: Validates that the script is run from the correct directory.

**Details**:

- Checks for the presence of the inventory file
- Verifies that the playbook exists
- Provides clear error messages if validation fails

#### Playbook Execution

**Purpose**: Runs the Ansible playbook to deploy the retention script.

**Details**:

- Executes the Ansible playbook with verbose output
- Captures the playbook's exit code
- Displays appropriate success or failure messages

#### User Guidance

**Purpose**: Provides clear guidance to the user after deployment.

**Details**:

- Shows how to view logs
- Explains how to monitor sync status
- Provides commands for troubleshooting

## Ansible Playbook

The `deploy_ephemery_retention.yml` playbook automates the deployment of the retention script across multiple servers.

### Key Tasks

#### Directory Setup

**Purpose**: Ensures necessary directories exist on the target server.

**Details**:

- Creates the script, config, data, and log directories
- Sets appropriate permissions

#### Script Deployment

**Purpose**: Copies the retention script to the target server.

**Details**:

- Copies the script with executable permissions
- Updates paths in the script to match the target environment

#### Environment Validation

**Purpose**: Validates that the target environment meets requirements.

**Details**:

- Checks if Docker is installed
- Verifies if required containers exist
- Tests if necessary ports are accessible

#### Cron Setup

**Purpose**: Sets up the cron job on the target server.

**Details**:

- Creates a cron job to run every 5 minutes
- Redirects output to a log file for monitoring

#### Initial Execution

**Purpose**: Performs an initial run of the retention script.

**Details**:

- Executes the script for immediate validation
- Captures and displays the output
- Marks the task as changed only if a reset was performed
