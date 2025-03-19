# Ephemery System Architecture

This document provides an overview of the Ephemery system architecture and the relationships between components.

## System Overview

Ephemery is an Ethereum test network that resets itself periodically, providing a fresh testing environment. The system consists of several components working together to provide a robust testing infrastructure.

```
+-------------------+        +--------------------+        +--------------------+
|                   |        |                    |        |                    |
|  Execution Client | <----> | Consensus Client  | <----> |  Validator Client  |
|     (Geth)        |        |   (Lighthouse)    |        |    (Lighthouse)    |
|                   |        |                    |        |                    |
+-------------------+        +--------------------+        +--------------------+
         ^                            ^                            ^
         |                            |                            |
         v                            v                            v
+-----------------------------------------------------------+     |
|                                                           |     |
|                    Monitoring Stack                       | <---+
|       (Prometheus, Grafana, Node Exporter)               |
|                                                           |
+-----------------------------------------------------------+
         ^
         |
         v
+-----------------------------------------------------------+
|                                                           |
|                     Ansible Automation                    |
|       (Playbooks, Roles, Inventory, Configuration)        |
|                                                           |
+-----------------------------------------------------------+
         ^
         |
         v
+-----------------------------------------------------------+
|                                                           |
|                    Testing Framework                      |
|     (Test Scripts, Fixtures, Mock Framework, CI/CD)       |
|                                                           |
+-----------------------------------------------------------+
```

## Component Relationships

### Client Interaction Flow

```
+-------------+          +-------------+          +-------------+
|             |  Engine  |             |  Sync    |             |
|   Geth      | <------> | Lighthouse  | <------> |  Validators |
| (Execution) |   API    | (Consensus) |  API     |             |
|             |          |             |          |             |
+-------------+          +-------------+          +-------------+
      ^                        ^                        ^
      |                        |                        |
      |                        |                        |
      v                        v                        v
+----------------------------------------------------------+
|                                                          |
|                      JWT Secret                          |
|                                                          |
+----------------------------------------------------------+
      ^                        ^                        ^
      |                        |                        |
      |                        |                        |
      v                        v                        v
+----------------------------------------------------------+
|                                                          |
|                  Docker Network                          |
|                                                          |
+----------------------------------------------------------+
```

### Testing Framework Structure

```
+---------------------+
|                     |
|     run_tests.sh    |
|                     |
+---------------------+
          |
          |
          v
+---------------------+    +---------------------+
|                     |    |                     |
| lint_shell_scripts.sh|<-->|   ci_check.sh      |
|                     |    |                     |
+---------------------+    +---------------------+
          |                          |
          |                          |
          v                          v
+---------------------+    +---------------------+
|                     |    |                     |
|    test_mock.sh     |<-->|   test_config.sh    |
|                     |    |                     |
+---------------------+    +---------------------+
          |                          |
          |                          |
          v                          v
+----------------------------------------------------------+
|                                                          |
|                    Test Fixtures                         |
|                                                          |
+----------------------------------------------------------+
          |                          |
          |                          |
          v                          v
+---------------------+    +---------------------+
|                     |    |                     |
|   Unit Tests        |    |  Integration Tests  |
|                     |    |                     |
+---------------------+    +---------------------+
```

### Continuous Integration Flow

```
+----------------+    +----------------+    +----------------+
|                |    |                |    |                |
|  Pull Request  | -> | GitHub Actions | -> |  Lint Check   |
|                |    |                |    |                |
+----------------+    +----------------+    +----------------+
                                               |
                                               v
+----------------+    +----------------+    +----------------+
|                |    |                |    |                |
| Version Bump   | <- |    Deploy      | <- |   Run Tests   |
|                |    |                |    |                |
+----------------+    +----------------+    +----------------+
        |
        v
+----------------+
|                |
| Create Release |
|                |
+----------------+
```

## Directory Structure

The repository is organized into a logical structure to separate concerns and make navigation easier:

```
ansible-ephemery/
├── README.md                   # Main project documentation
├── config/                     # Configuration files
│   ├── ansible/                # Ansible specific configuration
│   ├── clients/                # Client configuration
│   └── testing/                # Testing configuration
├── docs/                       # Detailed documentation
│   ├── development/            # Development guides
│   ├── testing/                # Testing guides
│   └── usage/                  # Usage guides
├── scripts/                    # Scripts directory
│   ├── core/                   # Core functionality scripts
│   ├── deployment/             # Deployment scripts
│   ├── lib/                    # Shared libraries
│   ├── maintenance/            # Maintenance scripts
│   ├── monitoring/             # Monitoring scripts
│   ├── testing/                # Testing scripts
│   └── utilities/              # Utility scripts
└── ansible/                    # Ansible playbooks and roles
    ├── playbooks/              # Main playbooks
    ├── roles/                  # Ansible roles
    └── inventories/            # Inventory files
```

## Component Descriptions

### Execution Client (Geth)

The execution client handles the execution layer of the Ethereum protocol. In Ephemery, we use Geth as the execution client.

### Consensus Client (Lighthouse)

The consensus client handles the consensus layer (formerly known as Eth2) of the Ethereum protocol. In Ephemery, we use Lighthouse as the consensus client.

### Validator Client

The validator client is responsible for participating in the Ethereum consensus mechanism. In Ephemery, validators are used to finalize blocks and maintain the chain.

### Monitoring Stack

The monitoring stack consists of Prometheus, Grafana, and Node Exporter for collecting metrics, visualizing data, and monitoring the health of the system.

### Ansible Automation

Ansible is used for automated deployment and configuration management. It provides a consistent way to set up and manage the Ephemery infrastructure.

### Testing Framework

The testing framework provides tools for testing the Ephemery components both in isolation and together. It includes mock frameworks for testing without real dependencies and CI/CD integration for automated testing.

## Interaction Protocols

### Engine API

The Engine API is used for communication between the execution client and consensus client. It allows the consensus client to send payload to the execution client for processing.

### Sync API

The Sync API is used by validators to stay in sync with the consensus client. It provides information about the current state of the chain.

### JWT Authentication

JSON Web Tokens (JWT) are used for secure authentication between the execution and consensus clients. A shared JWT secret is generated during setup and used by both clients. 