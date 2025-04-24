# Development Setup

This guide will help you set up a development environment for working on the Ephemery Node project.

## Prerequisites

You will need the following tools installed on your system:

- Python 3.8 or higher
- pip (Python package manager)
- Ansible 2.10 or higher
- Git
- Docker and Docker Compose (for testing)

## Setting Up Your Development Environment

### 1. Clone the Repository

```bash
# Clone the repository
git clone https://github.com/hydepwns/ansible-ephemery.git
cd ansible-ephemery
```

### 2. Set Up a Python Virtual Environment (Recommended)

Using a virtual environment keeps your project dependencies isolated:

```bash
# Create a virtual environment
python -m venv venv

# Activate the virtual environment
# On Linux/macOS
source venv/bin/activate
# On Windows
venv\Scripts\activate
```

### 3. Install Dependencies

```bash
# Install Python package dependencies
pip install -r requirements.txt -r requirements-dev.txt

# Install Ansible collections
ansible-galaxy collection install -r requirements.yaml
```

### 4. Set Up Pre-commit Hooks

We use pre-commit hooks to ensure code quality:

```bash
# Install pre-commit
pip install pre-commit

# Set up the git hooks
pre-commit install
```

### 5. Configure Testing Environment

For testing your changes, you'll need to have Docker installed and running:

```bash
# Verify Docker is working
docker run hello-world
```

## Development Workflow

1. **Create a Feature Branch**

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Your Changes**

   Follow the coding standards and best practices outlined in our [Contributing Guide](./CONTRIBUTING.md).

3. **Test Your Changes**

   ```bash
   # Run Molecule tests for specific scenarios
   molecule test -s default

   # Or run a quick demo test
   molecule/shared/scripts/demo_scenario.sh --execution geth --consensus lighthouse
   ```

4. **Lint Your Code**

   ```bash
   # Run Ansible linter
   ansible-lint

   # Run YAML linter
   yamllint .
   ```

5. **Commit Your Changes**

   ```bash
   git add .
   git commit -m "Add feature X"
   ```

   Note: Pre-commit hooks will run automatically to check your code.

6. **Push Your Changes**

   ```bash
   git push origin feature/your-feature-name
   ```

7. **Create a Pull Request**

   Go to the GitHub repository and create a pull request from your branch.

## Local Testing

### Running a Local Ephemery Node

You can use the demo script to quickly test your changes with a local Ephemery node:

```bash
./run-ephemery-demo.sh
```

### Testing with Different Client Combinations

To test different Ethereum client combinations:

```bash
# Specify execution and consensus clients
./scripts/local/run_local_node.sh --execution geth --consensus prysm
```

### Testing Ansible Playbooks Locally

```bash
# Create a local inventory file if you haven't already
cp test-inventory.yaml local-inventory.yaml

# Edit the local inventory to your needs
nano local-inventory.yaml

# Run the playbook against your local inventory
ansible-playbook -i local-inventory.yaml ephemery.yaml
```

## Debugging Tips

### Ansible Debugging

Add the `-v`, `-vv`, or `-vvv` flag to increase Ansible's verbosity:

```bash
ansible-playbook -i inventory.yaml ephemery.yaml -vv
```

### Docker Container Debugging

```bash
# List running containers
docker ps

# View container logs
docker logs ephemery-geth
docker logs ephemery-lighthouse

# Access a container's shell
docker exec -it ephemery-geth /bin/sh
```

## IDE Integration

### Visual Studio Code

We recommend the following extensions for VS Code:

- YAML (RedHat)
- Ansible (RedHat)
- Python (Microsoft)
- Docker (Microsoft)

### Configuring VS Code for Ansible Development

Add this to your VS Code settings.json:

```json
{
  "ansible.ansible.path": "ansible",
  "ansible.validation.lint.enabled": true,
  "ansible.validation.lint.path": "ansible-lint",
  "yaml.customTags": [
    "!vault"
  ]
}
```

## Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Molecule Documentation](https://molecule.readthedocs.io/)
- [Docker Documentation](https://docs.docker.com/)
- [Ethereum Client Documentation](https://ethereum.org/en/developers/docs/nodes-and-clients/)

## Next Steps

Now that you have your development environment set up, check out:

- [Contributing Guidelines](./CONTRIBUTING.md)
- [Testing Guide](./TESTING_GUIDE.md)
- [Architecture Overview](../ARCHITECTURE/ARCHITECTURE.md)
