# Security Test

This file contains test patterns to verify our pre-commit hook.

## Patterns that should be excluded (not flagged)

```yaml
# Variable references - should be ignored
password: {{ password_var }}
token: {{ api_token }}
secret: {{ lookup('env', 'SECRET') }}

# Configuration references - should be ignored
password: admin
admin_password: "admin"
grafana_admin_password: "admin"
key: pre-commit
private_key_path: /path/to/keys
ssh_key_file: /etc/ssh/id_rsa.pub
api_token_config: token_name
jwt_secret_path: /secrets/jwt.hex

# Template variables - should be ignored
password: "{{ credentials.password }}"
token: "{{ api.token }}"
```

## Patterns that should be caught (actual secrets)

```yaml
# Real secrets - should be caught by the hook
password: supersecret123!
api_token: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ
private_key: -----BEGIN RSA PRIVATE KEY-----\nMIIEogIBAAKCAQEA7bq98wTPWJQS/8FkVKAfhI7+xV+NzTQ1tM3+KzOjZaLJ+5Z6\n54f5jH3254==\n-----END RSA PRIVATE KEY-----
``` 