# Testing Guide for Ephemery Scripts

This document provides instructions for testing the Ephemery scripts, particularly the new wrapper scripts that have been implemented to standardize script usage.

## Prerequisites

Before testing, ensure you have:

1. A working Ephemery environment
2. Ansible installed
3. Access to the server where Ephemery is deployed

## Testing the Validator Management Wrapper Script

The validator management wrapper script (`manage-validator.sh`) provides a unified interface for managing validator operations.

### Deployment Test

1. Deploy the validator management wrapper script:

```bash
ansible-playbook playbooks/deploy_validator_management.yaml -i inventory.yaml
```

2. Verify the script was created:

```bash
ls -la /opt/ephemery/scripts/manage-validator.sh
```

3. Verify the symbolic link was created:

```bash
ls -la /usr/local/bin/ephemery-validator
```

### Functionality Tests

Test each command of the wrapper script:

1. Test the help command:

```bash
ephemery-validator help
```

2. Test the keys command:

```bash
ephemery-validator keys --help
ephemery-validator keys list
```

3. Test the monitor command:

```bash
ephemery-validator monitor --help
ephemery-validator monitor status
```

4. Test the test command:

```bash
ephemery-validator test --help
ephemery-validator test config
```

## Testing the Retention Wrapper Script

The retention wrapper script (`manage-retention.sh`) provides a unified interface for managing Ephemery network resets.

### Deployment Test

1. Deploy the retention wrapper script:

```bash
ansible-playbook playbooks/deploy_ephemery_retention.yaml -i inventory.yaml
```

2. Verify the script was created:

```bash
ls -la /opt/ephemery/scripts/manage-retention.sh
```

3. Verify the symbolic link was created:

```bash
ls -la /usr/local/bin/ephemery-retention
```

### Functionality Tests

Test each command of the wrapper script:

1. Test the help command:

```bash
ephemery-retention help
```

2. Test the check command:

```bash
ephemery-retention check
```

3. Test the status command:

```bash
ephemery-retention status
```

4. Test the reset command (use with caution in production):

```bash
# In a test environment only
ephemery-retention reset --dry-run
```

## Testing Standardized Paths

The scripts now use standardized paths defined in the `ephemery_paths.conf` file. Verify that this file exists and contains the correct paths:

```bash
cat /opt/ephemery/config/ephemery_paths.conf
```

## Testing Documentation

1. Verify that the documentation in `docs/SCRIPT_MANAGEMENT.md` accurately describes the wrapper scripts and their usage.

2. Verify that the documentation includes information about standardized paths.

3. Verify that the documentation includes best practices for using wrapper scripts.

## Testing CI/CD Pipeline

The CI/CD pipeline has been updated to test the wrapper scripts. You can manually trigger the pipeline to verify that the tests pass:

```bash
# From the repository root
git push origin main
```

## Reporting Issues

If you encounter any issues during testing, please report them by:

1. Creating a GitHub issue with detailed steps to reproduce
2. Including any error messages or logs
3. Describing the expected behavior

## Next Steps After Testing

After successful testing:

1. Update any documentation that references the old scripts to use the wrapper scripts instead
2. Train users on the new wrapper scripts
3. Consider deprecating direct usage of the individual scripts in favor of the wrapper scripts
