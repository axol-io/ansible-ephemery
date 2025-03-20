# Secure Development Guide for Ephemery Ansible

This guide provides best practices for securing your development environment when working with the Ephemery Ansible repository.

## Setting Up a Secure Local Environment

### 1. Use Environment Variables

Instead of hardcoding paths or credentials in configuration files, use environment variables:

```bash
# Example setup script
export EPHEMERY_BASE_DIR="$HOME/ephemery"
export EPHEMERY_DATA_DIR="$EPHEMERY_BASE_DIR/data"
export EPHEMERY_LOGS_DIR="$EPHEMERY_BASE_DIR/logs"
export EPHEMERY_SECRETS_DIR="$EPHEMERY_BASE_DIR/secrets"
export EPHEMERY_SCRIPTS_DIR="$EPHEMERY_BASE_DIR/scripts"
export EPHEMERY_BACKUP_DIR="$EPHEMERY_BASE_DIR/backups"
export JWT_SECRET_PATH="$EPHEMERY_BASE_DIR/jwt.hex"
export DOCKER_HOST="unix:///var/run/docker.sock"  # Adjust as needed
```

Consider using a tool like `direnv` to automatically load these variables in your project directory.

### 2. Creating Your Inventory Files

Always start with our example inventory files and never commit your actual inventory files:

```bash
# For local testing
cp inventories/local-inventory.yaml.example inventories/my-local-inventory.yaml

# For production deployments
cp inventory.yaml.example inventory.yaml
```

### 3. Managing Validator Keys

Validator keys are sensitive and should be properly secured:

- Store validator keys outside of the repository
- Use strong passwords
- Never commit validator keys or passwords to git
- Consider using environment variables or Ansible Vault for key passwords

```bash
# Example of using ansible-vault to encrypt sensitive files
ansible-vault encrypt files/passwords/validators.txt
```

### 4. JWT Secret Management

JWT secrets should always be securely generated and never committed to the repository:

```yaml
# Secure configuration example
jwt_secret_secure_generation: true
```

### 5. SSH Keys

When configuring SSH access in your inventory:

- Use SSH keys with strong security (Ed25519 or RSA with 4096+ bits)
- Do not store private keys in the repository
- Consider using SSH agent forwarding for deployment
- Keep your SSH keys passphrase protected

### 6. Preventing Secrets from Being Committed

We've included a comprehensive `.gitignore` file to prevent accidental commits of sensitive information. However, be vigilant and consider using git hooks for additional protection:

```bash
# Example pre-commit hook to check for potential secrets
#!/bin/bash

if git diff --cached | grep -E '(password|secret|token|key).*[A-Za-z0-9]{8,}' > /dev/null; then
    echo "WARNING: Possible secrets detected in commit."
    echo "Please review your changes for secrets before committing."
    exit 1
fi
```

### 7. Auditing Your Local Configuration

Before pushing changes, audit your local configuration for hardcoded paths and sensitive information:

```bash
# Check for hardcoded paths
grep -r "/Users/" --include="*.yml" --include="*.yaml" .
grep -r "/home/" --include="*.yml" --include="*.yaml" .

# Check for sensitive terms
grep -r "password\|secret\|token\|key" --include="*.yml" --include="*.yaml" .
```

## Secure Deployment Practices

### 1. Using Ansible Vault for Sensitive Data

For production deployments, encrypt sensitive information:

```bash
# Create an encrypted variable file
ansible-vault create group_vars/all/vault.yml

# Edit an existing encrypted file
ansible-vault edit group_vars/all/vault.yml

# Run playbooks with vault password
ansible-playbook -i inventory.yaml playbook.yaml --ask-vault-pass
```

### 2. Least Privilege Principle

When deploying:

- Use dedicated service accounts with minimal permissions
- Avoid using root accounts except when absolutely necessary
- Implement proper firewall rules to restrict access to services

### 3. Monitoring and Logging

Enable comprehensive logging and monitoring:

```yaml
# Example logging configuration
monitoring_enabled: true
log_retention_days: 30
```

### 4. Regular Security Updates

Keep your systems up to date:

```yaml
# Example configuration for automatic upgrades
security_updates_enabled: true
```

## Best Practices for Contributing

When contributing to this repository:

1. **Never commit sensitive information** - double-check all commits
2. **Use templates** - Start with our example files for your configurations
3. **Parameterize paths** - Use environment variables or Ansible variables for paths
4. **Template usernames** - Use `{{ ansible_user }}` or environment variables instead of hardcoded usernames
5. **Review changes** - Run `git diff` before committing to check for sensitive information
6. **Use pull requests** - Allow others to review your code for security issues

By following these guidelines, we can maintain a secure and reliable Ephemery deployment environment.
