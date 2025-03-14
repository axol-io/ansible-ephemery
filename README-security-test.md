# Security Test

This file is just to test our pre-commit hook for security scanning.

## Patterns That Should Be Excluded (Not Flagged)

- Valid configuration: password variable
- Valid configuration: API token configuration
- Valid configuration: SSH key path
- Valid path: validator_keys_dir
- Valid path: jwt_secret_path
- Valid configuration: validator_keystore_password

## Patterns That Should Be Caught (Actual Secrets)

- Actual secret: password: supersecret123
- Actual token: api_token: 4a1d476f2e0b4c3a9876
- Actual key: private_key: -----BEGIN PRIVATE KEY----

These patterns above should be caught by the pre-commit hook as they might be real secrets. 