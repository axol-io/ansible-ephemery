# Security Considerations

This document outlines security best practices for Ephemery node deployments.

## Security Principles

| Area | Recommendation |
|------|----------------|
| **Secrets Management** | Use Ansible Vault for all sensitive data |
| **Network Security** | Restrict service access with proper firewall rules |
| **Container Security** | Use pinned versions, limit capabilities, enforce resource limits |
| **Host Security** | Maintain updated base OS, use SSH keys, disable password auth |
| **Monitoring** | Configure alerts for suspicious activities |

## Sensitive Data Handling

- **JWT Secrets**: Stored in `host_vars/secrets.yaml` and encrypted with Ansible Vault
- **API Credentials**: Never stored in plaintext, always use Vault
- **Private Keys**: Maintain strict file permissions (0600) for any key files

### Using Ansible Vault

We strongly recommend using Ansible Vault to encrypt all sensitive information. Here are examples of how to use it:

#### Encrypting an Entire File

```bash
# Create and encrypt a new file
ansible-vault create host_vars/secrets.yaml

# Encrypt an existing file
ansible-vault encrypt host_vars/secrets.yaml

# Edit an encrypted file
ansible-vault edit host_vars/secrets.yaml

# View an encrypted file
ansible-vault view host_vars/secrets.yaml
```

#### Encrypting Individual Variables

You can encrypt individual variables using `ansible-vault encrypt_string`:

```bash
# Basic usage
ansible-vault encrypt_string 'secret_value' --name 'variable_name'

# Example for JWT secret
ansible-vault encrypt_string '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef' --name 'jwtsecret'

# Example for Grafana password
ansible-vault encrypt_string 'secure_grafana_password' --name 'grafana_admin_password'
```

Example output and usage in your host_vars file:

```yaml
# In your host_vars/<hostname>.yaml or secrets.yaml
jwtsecret: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          34623636336132323333373435363338366565323832623236303561366333393833303139303731
          6238303563643133383930613735303134363038393638320a333835393832386663303465653537
          36373834333430623866646136363336626165633134646433623139393931393364623762663533
          3633623735393334350a636237636461373636643735313466393738663131376166633365643366
          32323430323438383732383162623866343463323234323539363939646564626438
```

#### Running Playbooks with Encrypted Variables

```bash
# Prompt for password
ansible-playbook -i inventory.yaml main.yaml --ask-vault-pass

# Use a password file (store this securely!)
ansible-playbook -i inventory.yaml main.yaml --vault-password-file ~/.vault_pass
```

## ⚠️ WARNING: Remove Example Secrets Before Production

**IMPORTANT**: Before deploying to a production environment, ensure you:

1. Remove ALL example files containing placeholder secrets (`*.example` files)
2. Replace all example passwords, tokens, and keys with properly encrypted values
3. Verify that your .gitignore excludes all files containing sensitive information
4. Conduct a security audit to ensure no secrets are exposed in your configuration

Failure to remove example secrets could result in security vulnerabilities in your deployment.

## Network Security Configuration

| Port | Service | Access Control |
|------|---------|----------------|
| 22 | SSH | Restricted to admin IPs |
| 30303 | Execution P2P | Public |
| 9000 | Consensus P2P | Public |
| 8545 | Execution API | Restricted to specific IPs |
| 5052 | Consensus API | Restricted to specific IPs |

## Container Security

- **Image Versions**: Pinned to specific versions (never use `latest` tag)
- **Resource Limits**: CPU and memory limits enforced for all containers
- **User Namespaces**: Containers run as non-root users where possible
- **Read-only Filesystem**: Applied where applicable

## Monitoring Security Events

- Configure monitoring stack to alert on:
  - Failed login attempts
  - Unusual network traffic patterns
  - Resource exhaustion
  - Container restarts

## Security Updates

- Review and apply security updates regularly
- Follow the Ethereum client security announcements
- Test updates in staging environment before production deployment

## Security Checklist

- [ ] Secrets encrypted with Ansible Vault
- [ ] Firewall rules properly configured
- [ ] Container resource limits set
- [ ] SSH using key authentication only
- [ ] Monitoring alerts configured
- [ ] Regular security updates scheduled
