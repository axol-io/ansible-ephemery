# Managing Ansible Output in Ephemery

This guide provides tips and tools for managing and troubleshooting Ansible output in the Ephemery project.

## Using the Unified Output Management Toolkit

We've created a unified launcher script that provides access to all output management tools:

```bash
# Show help
./scripts/ephemery_output.sh help

# Run a playbook with output management
./scripts/ephemery_output.sh run playbooks/deploy_ephemery_retention.yaml -f -l

# Filter Ansible output
ansible-playbook playbooks/deploy_ephemery_retention.yaml | ./scripts/ephemery_output.sh filter

# Monitor logs
./scripts/ephemery_output.sh monitor -c geth

# Launch the dashboard
./scripts/ephemery_output.sh dashboard

# Analyze Ansible output
./scripts/ephemery_output.sh analyze logs/ansible-output.log

# Diagnose output issues
./scripts/ephemery_output.sh diagnose
```

For command-specific help, use `./scripts/ephemery_output.sh <command> --help`.

## Using the Output Filter Script

We've created a script to filter Ansible output to show only the most important information:

```bash
# Run an Ansible playbook and filter the output
ansible-playbook playbooks/deploy_ephemery_retention.yaml | ./scripts/filter_ansible_output.sh
```

The filter script includes Ephemery-specific patterns to highlight important information related to Geth, Lighthouse, validators, and container operations.

## Using the Ansible Wrapper Script

The `run_ansible.sh` script provides several options for managing Ansible output:

```bash
# Basic usage
./scripts/run_ansible.sh playbooks/deploy_ephemery_retention.yaml

# Filter output to show only important information
./scripts/run_ansible.sh playbooks/deploy_ephemery_retention.yaml -f

# Log output to a file
./scripts/run_ansible.sh playbooks/deploy_ephemery_retention.yaml -l

# Both filter output and log to a file
./scripts/run_ansible.sh playbooks/deploy_ephemery_retention.yaml -f -l

# Increase verbosity
./scripts/run_ansible.sh playbooks/deploy_ephemery_retention.yaml -v

# Show only the play recap summary
./scripts/run_ansible.sh playbooks/deploy_ephemery_retention.yaml -s

# Suppress all output except errors
./scripts/run_ansible.sh playbooks/deploy_ephemery_retention.yaml -q

# Use a different callback plugin
./scripts/run_ansible.sh playbooks/deploy_ephemery_retention.yaml -c yaml

# Pass extra arguments to ansible-playbook
./scripts/run_ansible.sh playbooks/deploy_ephemery_retention.yaml -e "--tags=geth,lighthouse"
```

## Monitoring Ephemery Logs

The `monitor_logs.sh` script allows you to monitor Ephemery logs in real-time:

```bash
# List available log files
./scripts/monitor_logs.sh

# Monitor Geth logs
./scripts/monitor_logs.sh -c geth

# Monitor Lighthouse logs
./scripts/monitor_logs.sh -c lighthouse

# Monitor validator logs
./scripts/monitor_logs.sh -c validator

# Filter logs by pattern
./scripts/monitor_logs.sh -c geth -f "ERROR|WARN"

# Show only the last 50 lines
./scripts/monitor_logs.sh -c lighthouse -l 50

# Don't follow logs (just show and exit)
./scripts/monitor_logs.sh -c validator -n

# Specify a custom logs directory
./scripts/monitor_logs.sh -d /path/to/logs
```

## Using the Ephemery Dashboard

The `ephemery_dashboard.sh` script provides a terminal-based dashboard for monitoring Ephemery status and logs:

```bash
# Basic usage (summary view)
./scripts/ephemery_dashboard.sh

# Show detailed logs view for a specific client
./scripts/ephemery_dashboard.sh -v logs -c geth

# Show detailed status view
./scripts/ephemery_dashboard.sh -v status

# Change refresh rate to 10 seconds
./scripts/ephemery_dashboard.sh -r 10

# Specify custom data and log directories
./scripts/ephemery_dashboard.sh -d /path/to/data -l /path/to/logs
```

### Dashboard Views

The dashboard provides three different views:

1. **Summary View** (default): Shows a high-level overview of all services, including status, recent logs, and sync status.
2. **Logs View**: Shows detailed logs for a specific client.
3. **Status View**: Shows detailed status information for all services, including process info, memory usage, and error counts.

## Analyzing Ansible Output

The `analyze_ansible_output.sh` script helps you analyze Ansible output for performance and error patterns:

```bash
# Analyze a log file
./scripts/analyze_ansible_output.sh logs/ansible-output.log

# Analyze output from a running playbook
./scripts/run_ansible.sh playbooks/deploy_ephemery_retention.yaml -l | ./scripts/analyze_ansible_output.sh
```

The analysis includes:

- Summary of tasks, errors, warnings, and changed tasks
- Play recap with colorized output
- Top 10 longest-running tasks
- Detailed error and warning messages
- Suggestions for improvement based on common patterns

## Diagnosing Output Issues

The `diagnose_output.sh` script helps diagnose and fix common Ansible output issues:

```bash
# Run the diagnostic script
./scripts/diagnose_output.sh
```

The script checks for:

- Current callback plugin configuration
- Existence and permissions of output management scripts
- Logs directory and available log files
- Terminal color support
- And provides recommendations based on the current configuration

## Configuring Ansible Output

You can configure Ansible output by modifying the `ansible.cfg` file:

```ini
[defaults]
# Use a minimal output callback
stdout_callback = minimal

# Other options: yaml, json, unixy, dense
```

## Common Output Issues and Solutions

### Issue: Too much output

**Solution**: Use the filter script or wrapper script with the `-f` option.
```bash
./scripts/ephemery_output.sh run playbooks/your_playbook.yaml -f
```

### Issue: Need to save output for later analysis

**Solution**: Use the wrapper script with the `-l` option to log output to a file.
```bash
./scripts/ephemery_output.sh run playbooks/your_playbook.yaml -l
```

### Issue: Need more detailed output for debugging

**Solution**: Use the wrapper script with the `-v`, `-vv`, or `-vvv` options to increase verbosity.
```bash
./scripts/ephemery_output.sh run playbooks/your_playbook.yaml -vvv
```

### Issue: Only interested in the final summary

**Solution**: Use the wrapper script with the `-s` option to show only the play recap summary.
```bash
./scripts/ephemery_output.sh run playbooks/your_playbook.yaml -s
```

### Issue: Want to run in the background without output

**Solution**: Use the wrapper script with the `-q` option to suppress all output except errors.
```bash
./scripts/ephemery_output.sh run playbooks/your_playbook.yaml -q
```

### Issue: Need to monitor multiple services simultaneously

**Solution**: Use the Ephemery dashboard with the summary view:
```bash
./scripts/ephemery_output.sh dashboard
```

### Issue: Need to analyze performance and errors

**Solution**: Use the analysis script:
```bash
./scripts/ephemery_output.sh analyze logs/ansible-output.log
```

### Issue: Output is not colorized

**Solution**: Ensure your terminal supports ANSI colors and that Ansible's color settings are enabled.

### Issue: Need to search through output

**Solution**: Log output to a file and use tools like `grep`, `less`, or `awk` to search through it.

## Advanced Techniques

### Using `grep` to filter output

```bash
# Show only failed tasks
ansible-playbook playbook.yml | grep -A 5 "failed:"

# Show only changed tasks
ansible-playbook playbook.yml | grep -A 5 "changed:"
```

### Using `tee` to both display and log output

```bash
ansible-playbook playbook.yml | tee ansible-output.log
```

### Using `less` to view large log files

```bash
less -R ansible-output.log  # -R preserves color codes
```

### Creating a combined view with multiple tools

```bash
# Run a playbook, filter the output, log it, and analyze it
./scripts/ephemery_output.sh run playbooks/deploy_ephemery_retention.yaml -f -l | tee /dev/tty | ./scripts/ephemery_output.sh analyze
```

## Ephemery-Specific Output Management

For Ephemery-specific output, consider:

1. Adjusting log levels in your Ephemery configuration
2. Using the monitoring scripts with appropriate verbosity
3. Using the `monitor_logs.sh` script to monitor client logs in real-time
4. Using the `ephemery_dashboard.sh` script for a comprehensive view
5. Checking client-specific logs in the logs directory

## Troubleshooting Common Ephemery Output Issues

### Issue: Overwhelming container logs

**Solution**: Use the `monitor_logs.sh` script with filtering to focus on specific log patterns:

```bash
./scripts/ephemery_output.sh monitor -c geth -f "ERROR|WARN|FATAL"
```

### Issue: Need to monitor multiple logs simultaneously

**Solution**: Use the Ephemery dashboard:

```bash
./scripts/ephemery_output.sh dashboard
```

Or use multiple terminal windows/tabs, each running the `monitor_logs.sh` script for a different client:

```bash
# In terminal 1
./scripts/ephemery_output.sh monitor -c geth

# In terminal 2
./scripts/ephemery_output.sh monitor -c lighthouse

# In terminal 3
./scripts/ephemery_output.sh monitor -c validator
```

### Issue: Need to analyze historical logs

**Solution**: Use the `monitor_logs.sh` script with the `-n` option to view logs without following:

```bash
./scripts/ephemery_output.sh monitor -c geth -n -l 1000 > geth_history.log
```

### Issue: Performance bottlenecks in Ansible playbooks

**Solution**: Use the analysis script to identify long-running tasks:

```bash
./scripts/ephemery_output.sh analyze logs/ansible-output.log
```

### Issue: Need to diagnose system-level issues

**Solution**: Use the dashboard's status view:

```bash
./scripts/ephemery_output.sh dashboard -v status
```
