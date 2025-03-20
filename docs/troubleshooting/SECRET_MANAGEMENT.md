# Secret Management in Ansible-Ephemery

This document provides guidelines for managing secrets in the Ansible-Ephemery project.

## Sensitive Information

The following types of information should be considered sensitive and should never be stored in plain text:

- JWT secrets
- Telegram bot tokens
- Telegram chat IDs
- Grafana admin passwords
- API keys
- Any authentication credentials

## Using Ansible Vault

Ansible Vault should be used to encrypt all sensitive information. The following commands will help you manage secrets safely:

### Encrypting Strings

To encrypt a single string (such as a password or token):

```bash
ansible-vault encrypt_string --name 'telegram_bot_token' 'your_token_here'
```

Copy the output (including the `!vault` tag) into your host_vars file.

### Example of Encrypted Value

```yaml
telegram_bot_token: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  62313365396662343061393464336163383764373764613633653634306231386433626436623361
  6134333665353966363534333332666535333761666131620a663537646436643839616531643561
  63396265333966386166373632626539326166353965363262633030333630313338646335303630
  3438626666616437340a376134343865613232613836393831663939306439383463363461363436
  33616633666264363933643333383332623631616536303963366465366633366234
```

### Encrypting Files

For files containing multiple secrets:

```bash
ansible-vault encrypt path/to/secrets.yml
```

### Editing Encrypted Files

To edit an already encrypted file:

```bash
ansible-vault edit path/to/secrets.yml
```

### Viewing Encrypted Files

To view the content of an encrypted file:

```bash
ansible-vault view path/to/secrets.yml
```

## JWT Secret Standardization

For consistency across the project, JWT secrets should:

1. Use the filename `jwt.hex`
2. Be located at `{{ ephemery_base_dir }}/jwt.hex`
3. Be generated securely at runtime or encrypted with Ansible Vault

Example of a proper JWT secret configuration:

```yaml
# In your host_vars file
jwt_secret_path: "{{ ephemery_base_dir }}/jwt.hex"
jwt_secret_secure_generation: true
```

## Pre-commit Hook

A pre-commit hook is included to detect unencrypted secrets in the codebase. This helps prevent accidental commits of sensitive information.

To run the check manually:

```bash
./scripts/check-unencrypted-secrets.sh
```

## Best Practices

1. Never hardcode secrets in templates or playbooks
2. Use environment-specific vault files with different passwords
3. Store vault passwords securely (not in the repository)
4. For development environments, document the use of fake/example secrets
5. Review all PRs for potential secret leakage before merging

## Example Host Configuration

```yaml
---
# Host-specific variables
ephemery_base_dir: /opt/ephemery

# JWT Secret configuration
jwt_secret_path: "{{ ephemery_base_dir }}/jwt.hex"
jwt_secret_secure_generation: true

# Grafana configuration
grafana_admin_password: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  62313365396662343061393464336163383764373764613633653634306231386433626436623361
  6134333665353966363534333332666535333761666131620a663537646436643839616531643561
  63396265333966386166373632626539326166353965363262633030333630313338646335303630
  3438626666616437340a376134343865613232613836393831663939306439383463363461363436
  33616633666264363933643333383332623631616536303963366465366633366234

# Telegram configuration
telegram_bot_token: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  62313365396662343061393464336163383764373764613633653634306231386433626436623361
  6134333665353966363534333332666535333761666131620a663537646436643839616531643561
  63396265333966386166373632626539326166353965363262633030333630313338646335303630
  3438626666616437340a376134343865613232613836393831663939306439383463363461363436
  33616633666264363933643333383332623631616536303963366465366633366234
telegram_chat_id: !vault |
  $ANSIBLE_VAULT;1.1;AES256
  62313365396662343061393464336163383764373764613633653634306231386433626436623361
  6134333665353966363534333332666535333761666131620a663537646436643839616531643561
  63396265333966386166373632626539326166353965363262633030333630313338646335303630
  3438626666616437340a376134343865613232613836393831663939306439383463363461363436
  33616633666264363933643333383332623631616536303963366465366633366234
```
