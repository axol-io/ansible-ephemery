#!/bin/bash

# Script to validate inventory files before deployment

# Check if input file was provided
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <inventory_file> [--type local|remote]"
    echo "Validates an inventory file for local or remote deployment"
    exit 1
fi

INVENTORY_FILE="$1"
INVENTORY_TYPE=""

# Parse parameters
if [ "$#" -ge 3 ] && [ "$2" == "--type" ]; then
    INVENTORY_TYPE="$3"
fi

# Verify file exists
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "Error: Inventory file not found: $INVENTORY_FILE"
    exit 1
fi

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to check YAML syntax
check_yaml_syntax() {
    # Check if yamllint is available
    if command_exists yamllint; then
        if ! yamllint -d "{extends: relaxed, rules: {line-length: disable}}" "$INVENTORY_FILE" > /dev/null 2>&1; then
            echo "Error: YAML syntax validation failed"
            yamllint -d "{extends: relaxed, rules: {line-length: disable}}" "$INVENTORY_FILE"
            return 1
        fi
    else
        # If yamllint is not available, use simple syntax check
        if command_exists python3; then
            if ! python3 -c "import yaml; yaml.safe_load(open('$INVENTORY_FILE', 'r'))" 2>/dev/null; then
                echo "Error: YAML syntax validation failed (using Python)"
                python3 -c "import yaml; yaml.safe_load(open('$INVENTORY_FILE', 'r'))"
                return 1
            fi
        else
            echo "Warning: Neither yamllint nor python3 is available. Skipping YAML syntax validation."
        fi
    fi

    return 0
}

# Check YAML syntax
echo "Checking YAML syntax..."
if ! check_yaml_syntax; then
    exit 1
fi

# Determine inventory type if not specified
if [ -z "$INVENTORY_TYPE" ]; then
    if grep -q "local:" "$INVENTORY_FILE"; then
        INVENTORY_TYPE="local"
        echo "Detected inventory type: local"
    elif grep -q "hosts:" "$INVENTORY_FILE"; then
        INVENTORY_TYPE="remote"
        echo "Detected inventory type: remote"
    else
        echo "Error: Could not determine inventory type. Please specify with --type option."
        exit 1
    fi
fi

# Function to validate local inventory
validate_local_inventory() {
    local errors=0

    echo "Validating local inventory..."

    # Check if yq is available
    if command_exists yq; then
        # Check required fields
        if [ -z "$(yq '.local.base_dir // ""' "$INVENTORY_FILE")" ]; then
            echo "Error: Missing required field 'local.base_dir'"
            errors=$((errors+1))
        fi

        if [ -z "$(yq '.local.data_dir // ""' "$INVENTORY_FILE")" ]; then
            echo "Error: Missing required field 'local.data_dir'"
            errors=$((errors+1))
        fi

        if [ -z "$(yq '.local.logs_dir // ""' "$INVENTORY_FILE")" ]; then
            echo "Error: Missing required field 'local.logs_dir'"
            errors=$((errors+1))
        fi

        # Check geth configuration
        if [ -z "$(yq '.local.geth.image // ""' "$INVENTORY_FILE")" ]; then
            echo "Error: Missing required field 'local.geth.image'"
            errors=$((errors+1))
        fi

        # Check lighthouse configuration
        if [ -z "$(yq '.local.lighthouse.image // ""' "$INVENTORY_FILE")" ]; then
            echo "Error: Missing required field 'local.lighthouse.image'"
            errors=$((errors+1))
        fi
    else
        echo "Warning: 'yq' command not found. Using fallback method with grep (less reliable)"

        # Check required fields using grep
        if ! grep -q "base_dir:" "$INVENTORY_FILE"; then
            echo "Error: Missing required field 'local.base_dir'"
            errors=$((errors+1))
        fi

        if ! grep -q "data_dir:" "$INVENTORY_FILE"; then
            echo "Error: Missing required field 'local.data_dir'"
            errors=$((errors+1))
        fi

        if ! grep -q "logs_dir:" "$INVENTORY_FILE"; then
            echo "Error: Missing required field 'local.logs_dir'"
            errors=$((errors+1))
        fi

        # Check if geth and lighthouse sections exist
        if ! grep -q "geth:" "$INVENTORY_FILE"; then
            echo "Error: Missing 'geth' section"
            errors=$((errors+1))
        fi

        if ! grep -q "lighthouse:" "$INVENTORY_FILE"; then
            echo "Error: Missing 'lighthouse' section"
            errors=$((errors+1))
        fi
    fi

    return $errors
}

# Function to validate remote inventory
validate_remote_inventory() {
    local errors=0

    echo "Validating remote inventory..."

    # Check if yq is available
    if command_exists yq; then
        # Check remote host configuration
        if [ -z "$(yq '.hosts[0].host // ""' "$INVENTORY_FILE")" ]; then
            echo "Error: Missing required field 'hosts[0].host'"
            errors=$((errors+1))
        fi

        if [ -z "$(yq '.hosts[0].user // ""' "$INVENTORY_FILE")" ]; then
            echo "Error: Missing required field 'hosts[0].user'"
            errors=$((errors+1))
        fi

        # Check remote configuration
        if [ -z "$(yq '.remote.base_dir // ""' "$INVENTORY_FILE")" ]; then
            echo "Error: Missing required field 'remote.base_dir'"
            errors=$((errors+1))
        fi

        if [ -z "$(yq '.remote.data_dir // ""' "$INVENTORY_FILE")" ]; then
            echo "Error: Missing required field 'remote.data_dir'"
            errors=$((errors+1))
        fi

        if [ -z "$(yq '.remote.logs_dir // ""' "$INVENTORY_FILE")" ]; then
            echo "Error: Missing required field 'remote.logs_dir'"
            errors=$((errors+1))
        fi
    else
        echo "Warning: 'yq' command not found. Using fallback method with grep (less reliable)"

        # Check remote host configuration
        if ! grep -q "host:" "$INVENTORY_FILE"; then
            echo "Error: Missing required field 'hosts[0].host'"
            errors=$((errors+1))
        fi

        if ! grep -q "user:" "$INVENTORY_FILE"; then
            echo "Error: Missing required field 'hosts[0].user'"
            errors=$((errors+1))
        fi

        # Check if remote section exists
        if ! grep -q "remote:" "$INVENTORY_FILE"; then
            echo "Error: Missing 'remote' section"
            errors=$((errors+1))
        fi
    fi

    return $errors
}

# Validate inventory based on type
errors=0
if [ "$INVENTORY_TYPE" = "local" ]; then
    validate_local_inventory
    errors=$?
elif [ "$INVENTORY_TYPE" = "remote" ]; then
    validate_remote_inventory
    errors=$?
else
    echo "Error: Unknown inventory type: $INVENTORY_TYPE"
    exit 1
fi

# Summary
if [ $errors -eq 0 ]; then
    echo "Validation successful: No errors found in $INVENTORY_TYPE inventory"
    exit 0
else
    echo "Validation failed: Found $errors error(s) in $INVENTORY_TYPE inventory"
    exit 1
fi
