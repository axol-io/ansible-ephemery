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
   ls -la /var/run/docker.sock # varies based on your OS / Docker install.
   ls -la /Users/<username>/.docker/run/docker.sock
   ls -la /Users/<username>/Library/Containers/com.docker.docker/Data/docker-cli.sock
   ```

3. **Update molecule.yml file**:

   ```yaml
   driver:
     name: docker
     options:
       docker_host: "unix:///path/to/your/docker.sock"
   ```

4. **Use the helper script**:

   ```bash
   ./run-molecule.sh test # automatically configures the correct Docker context and socket path.
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
   docker context use desktop-linux  # For macOS
   # OR
   docker context use default  # For standard setups
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

### Problem: Docker Contexts on macOS

macOS has multiple Docker contexts and the default may not work with Molecule.

1. **Use the desktop-linux context**:

   ```bash
   docker context use desktop-linux
   ```

2. **Update the Docker host path**:

   ```bash
   export DOCKER_HOST=unix:///Users/<username>/.docker/run/docker.sock
   ```

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

2. **Ensure proper cgroup mounting**:

   ```yaml
   platforms:
     - name: ethereum-node
       volumes:
         - /sys/fs/cgroup:/sys/fs/cgroup:rw
       cgroupns_mode: host
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
