# ansible-ephemery Documentation

This directory contains comprehensive documentation for setting up, configuring, and maintaining optimized Ephemery Ethereum testnet nodes using Ansible.

## 📚 Documentation Guide

### 🚀 Getting Started

| Guide | Description | Use When |
|-------|-------------|----------|
| [Getting Started](GETTING_STARTED.md) | Step-by-step setup for beginners | You're new to the project or Ansible |
| [Requirements](REQUIREMENTS.md) | Software and hardware prerequisites | Checking if your system meets requirements |
| [Ephemery Specific](EPHEMERY_SPECIFIC.md) | **Essential guide to Ephemery-specific configurations and optimizations** | **Starting your Ephemery deployment** |

### 💻 Configuration & Setup

| Guide | Description | Use When |
|-------|-------------|----------|
| [Variable Structure](VARIABLE_STRUCTURE.md) | All configuration options explained | You need to customize your deployment |
| [Validator Setup](VALIDATOR_README.md) | Complete guide to running validators | Setting up validator nodes |
| [Monitoring](MONITORING.md) | Setting up metrics and dashboards | You want visibility into node performance |
| [Security](SECURITY.md) | Security best practices and settings | Hardening your node deployment |

### 🛠️ Optimization & Troubleshooting

| Guide | Description | Use When |
|-------|-------------|----------|
| [Client Optimization](CLIENT_OPTIMIZATION.md) | **Optimizing Geth & Lighthouse for faster sync** | **Improving sync speed (critical for Ephemery)** |
| [Troubleshooting](TROUBLESHOOTING.md) | **Common issues and solutions, including network resets** | **Something isn't working as expected** |
| [Direct Deployment Script](../scripts/local/run-ephemery-local.sh) | **Alternative deployment method with optimizations** | **Quick deployment or testing** |

### 🧰 Development & Contributing

| Guide | Description | Use When |
|-------|-------------|----------|
| [Repository Structure](REPOSITORY_STRUCTURE.md) | Codebase organization | You want to understand the repository layout |
| [Coding Standards](CODING_STANDARDS.md) | Code style guidelines | Contributing code to the project |
| [Linting](LINTING.md) | Code quality tools | Setting up your development environment |
| [Testing](TESTING.md) | Test framework and methodologies | Writing or running tests |
| [Contributing](CONTRIBUTING.md) | How to contribute to the project | You want to help improve the project |
| [CI/CD](CI_CD.md) | Continuous integration workflow | Understanding the automated testing process |

### 📂 Advanced Topics

| Guide | Description | Use When |
|-------|-------------|----------|
| [Script Management](SCRIPT_MANAGEMENT.md) | Management script documentation | Working with utility scripts |
| [Resource Management](VARIABLE_STRUCTURE.md#resource-management) | Managing system resources | Optimizing for limited hardware |
| [Variable Management](VARIABLE_MANAGEMENT.md) | **Avoiding templating errors in Ansible** | **Troubleshooting variable resolution issues** |

## 🚀 Key Optimizations

Our recent improvements focus on:

1. **Optimized Genesis Sync**: Significantly faster synchronization with specialized parameters
2. **Improved Client Configuration**: Tuned settings for both Geth and Lighthouse
3. **Direct Deployment Script**: Alternative to Ansible for rapid deployment
4. **Network Reset Handling**: Clear procedures for handling Ephemery's daily resets
5. **Troubleshooting Guidance**: Expanded documentation for common issues

## 📝 Documentation Conventions

- All documentation uses Markdown format
- Code examples use syntax highlighting where appropriate
- Command examples use actual commands you can copy and paste
- Configuration examples use YAML format

## 🔗 Quick Links

- [Main README](../README.md) - Project overview
- [GitHub Issues](https://github.com/hydepwns/ansible-ephemery/issues) - Report bugs or request features
