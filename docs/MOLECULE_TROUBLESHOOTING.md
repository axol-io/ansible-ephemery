# Molecule Testing Troubleshooting Guide

This document provides solutions for common issues encountered when running Molecule tests for the ansible-ephemery project.

## Docker Connection Issues

### Problem: Cannot connect to Docker daemon

Error message:

```bash
docker.errors.DockerException: Error while fetching server API version: ('Connection aborted.', FileNotFoundError(2, 'No such file or directory'))
```

1. **Verify Docker is running**:

   ```bash
   docker ps # If this fails, start Docker Desktop or the Docker daemon.
   ```

2. **Check Docker socket path**:

   ```bash
   ls -la /var/run/docker.sock # Linux
   ls -la /Users/<username>/.docker/run/docker.sock # macOS with Docker Desktop
   ls -la /Users/<username>/.orbstack/run/docker.sock # macOS with OrbStack
   ```

3. **Check Docker contexts**:

   ```bash
   # List available contexts
   docker context ls

   # Use the correct context for your environment
   docker context use desktop-linux  # For Docker Desktop on macOS
   docker context use orbstack       # For OrbStack on macOS
   docker context use default        # For standard Linux setups

   # Inspect the context to find the Docker socket path
   docker context inspect desktop-linux
   ```

4. **Update molecule.yml file**:

   ```yaml
   driver:
     name: docker
     docker_host: "unix:///path/to/your/docker.sock"
   platforms:
     - name: instance-name
       volumes:
         - /sys/fs/cgroup:/sys/fs/cgroup:rw
         - "/path/to/your/docker.sock:/var/run/docker.sock:rw"
   ```

5. **Use environment variables**:

   ```bash
   export DOCKER_HOST=unix:///path/to/your/docker.sock
   molecule test -s your-scenario
   ```

6. **Use the helper script**:

   ```bash
   ./scripts/run-molecule-tests-macos.sh your-scenario # automatically configures the correct Docker context and socket path.
   ```

## Docker Context Issues

### Problem: Wrong Docker context is active

Error message:

```bash
Warning: DOCKER_HOST environment variable overrides the active context.
```

1. **List available contexts**:

   ```bash
   docker context ls
   ```

2. **Switch to a working context**:

   ```bash
   docker context use desktop-linux  # For macOS with Docker Desktop
   docker context use orbstack       # For macOS with OrbStack
   docker context use default        # For standard setups
   ```

3. **Create a new context if needed**:

   ```bash
   docker context create molecule --docker "host=unix:///path/to/docker.sock"
   docker context use molecule
   ```

## Docker in Docker (DinD) Issues

### Problem: Container can't access Docker

Error message:

```bash
Error starting container: failed to create task for container: failed to create shim task
```

1. **Ensure proper volume mounting**:

   ```yaml
   platforms:
     - name: ethereum-node
       volumes:
         - /sys/fs/cgroup:/sys/fs/cgroup:rw
         - /path/to/docker.sock:/var/run/docker.sock
   ```

2. **Set the privileged flag**:

   ```yaml
   platforms:
     - name: ethereum-node
       privileged: true
   ```

3. **Check Docker socket permissions**:

   ```bash
   sudo chmod 666 /var/run/docker.sock  # Linux only
   ```

## macOS-Specific Issues

### Problem: Docker socket path varies on macOS

Different Docker implementations on macOS use different socket paths:

1. **Docker Desktop socket paths**:
   - `/Users/<username>/.docker/run/docker.sock` (most common)
   - `/var/run/docker.sock` (via symlink)

2. **OrbStack socket path**:
   - `/Users/<username>/.orbstack/run/docker.sock`

3. **Determine correct socket path**:

   ```bash
   # Check context and socket path
   docker context ls
   docker context inspect <context-name> | grep "Host"

   # Check if sockets exist
   ls -la /Users/<username>/.docker/run/docker.sock
   ls -la /Users/<username>/.orbstack/run/docker.sock
   ```

4. **Update molecule.yml configuration**:

   ```yaml
   driver:
     name: docker
     docker_host: "unix:///Users/<username>/.docker/run/docker.sock"
   platforms:
     - name: instance-name
       volumes:
         - /sys/fs/cgroup:/sys/fs/cgroup:rw
         - "/Users/<username>/.docker/run/docker.sock:/var/run/docker.sock:rw"
   ```

### Problem: Docker Desktop in Eco Mode

Docker Desktop's Eco Mode pauses the Docker engine when not in use, which can cause connection issues.

1. **Disable Eco Mode**:
   - Open Docker Desktop
   - Go to Settings/Preferences
   - Disable "Use Eco mode" in the General settings

2. **Or wake Docker before testing**:

   ```bash
   docker ps  # Run a simple command to wake Docker
   sleep 5    # Wait for Docker to fully wake up
   molecule test
   ```

### Solution: Use Our macOS Helper Script

We've created a dedicated script to handle all macOS-specific Docker issues:

```bash
# Run a specific scenario on macOS
./scripts/run-molecule-tests-macos.sh default

# Run client combination scenario on macOS
./scripts/run-molecule-tests-macos.sh geth-lighthouse
```

This script:

- Automatically detects the correct Docker socket path on macOS
- Updates the molecule.yml configuration with the correct path
- Sets the necessary environment variables
- Handles the different `sed` syntax in macOS
- Restores original configuration after testing

## Role Path Resolution Issues

### Problem: Role not found when using include_role

Error message:

```bash
ERROR! the role 'ansible-ephemery' was not found in /path/to/molecule/scenario/roles:/path/to/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles
```

**Solution**: Use relative paths to the project root in converge.yml:

```yaml
- name: Include ephemery role
  include_role:
    name: ../..  # Points to the project root which contains the role
```

## Ansible Conditional Issues

### Problem: Unquoted service names in conditionals

Error message:

```bash
The conditional check 'docker.service in ansible_facts.services' failed. The error was: error while evaluating conditional (docker.service in ansible_facts.services): 'docker' is undefined
```

**Solution**: Always use quotes for string literals in conditionals:

```yaml
# Incorrect
when: docker.service in ansible_facts.services

# Correct
when: "'docker.service' in ansible_facts.services"
```

### Problem: Missing existence checks for dictionary keys

Error message:

```bash
The error appears to be in '...': line XX, column 3, but may be elsewhere in the file depending on the exact syntax problem.
```

**Solution**: Always check if a dictionary exists before accessing its keys:

```yaml
# Incorrect
when: "'docker.service' in ansible_facts.services"

# Correct
when: ansible_facts.services is defined and "'docker.service' in ansible_facts.services"
```

### Problem: Unquoted default values

Error message:

```bash
The error appears to be in '...': line XX, column 3, but may be elsewhere in the file depending on the exact syntax problem.
```

**Solution**: Always quote string values in default() filters:

```yaml
# Incorrect
ephemery_base_dir | default(/home/ubuntu/ephemery)

# Correct
ephemery_base_dir | default("/home/ubuntu/ephemery")
```

### Solution: Use Our Verification Script

We've created a script to check for common Ansible conditional issues:

```bash
./scripts/verify-ansible-conditionals.sh
```

This script checks for:

- Unquoted service names in conditionals
- Missing existence checks for dictionary keys
- Unquoted default values

## Github Actions Issues

### Problem: systemd not available in container

Error message:

```bash
failed to create shim task: OCI runtime create failed: exec: "/lib/systemd/systemd": stat /lib/systemd/systemd: no such file or directory
```

1. **Use a systemd-enabled image**:

   ```yaml
   platforms:
     - name: ethereum-node
       image: geerlingguy/docker-ubuntu2204-ansible:latest
   ```

## Automating Configuration Updates

To simplify the process of updating all Molecule configuration files, we've provided an automated script:

### Using update-molecule-configs.sh

This script automatically updates all Molecule scenario configurations with the correct Docker settings for your environment:

```bash
# Make the script executable if needed
chmod +x update-molecule-configs.sh

# Run the script
./update-molecule-configs.sh
```

What the script does:

1. Detects your operating system (macOS or Linux)
2. Finds the appropriate Docker socket path
3. Updates all `molecule.yml` files with:
   - The correct Docker socket path
   - Proper cgroup mounts
   - cgroupns_mode (for macOS)
4. Creates backups of all original files (with .bak extension)

After running the script, you can use the provided `run-molecule.sh` script to run your tests:

```bash
./run-molecule.sh test
```

### Reverting Changes

If you need to revert to the original configurations:

```bash
# Find all backup files and restore them
find molecule -name "molecule.yml.bak" | while read -r FILE; do
    ORIG_FILE="${FILE%.bak}"
    mv "$FILE" "$ORIG_FILE"
    echo "Restored $ORIG_FILE"
done
```

## General Molecule Issues

### Problem: "Scenario config file has been modified" warning

Warning message:

```bash
WARNING  The scenario config file has been modified since the scenario was created.
```

1. **Reset the scenario**:

   ```bash
   molecule reset
   ```

2. **Or destroy and recreate**:

   ```bash
   molecule destroy
   molecule create
   ```

### Problem: Missing requirements file warning

Warning message:

```bash
WARNING  Skipping, missing the requirements file.
```

This is generally harmless. To eliminate it:

1. **Create a requirements file**:

   ```bash
   touch molecule/default/requirements.yml
   ```

2. **Or specify dependency name with empty requirements**:

   ```yaml
   dependency:
     name: galaxy
     options:
       requirements-file: molecule/requirements.yml
   ```
