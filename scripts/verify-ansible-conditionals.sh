#!/bin/bash
# verify-ansible-conditionals.sh
# Checks for common conditional issues in Ansible YAML files

set -e

echo "Checking for common Ansible conditional issues..."

# Check for unquoted strings in ansible_facts.services conditionals
UNQUOTED_SERVICES=$(grep -r "when:.*[a-zA-Z][a-zA-Z0-9_]*\.service in ansible_facts\.services" --include="*.yml" --include="*.yaml" molecule/ || true)
if [ -n "$UNQUOTED_SERVICES" ]; then
    echo "ERROR: Found unquoted service references in conditionals:"
    echo "$UNQUOTED_SERVICES"
    echo "Fix by adding quotes: \"'service.name' in ansible_facts.services\""
    exit 1
fi

# Check for missing is defined checks before using ansible_facts.services
MISSING_DEFINED=$(grep -r "when:.*'.*\.service' in ansible_facts\.services" --include="*.yml" --include="*.yaml" molecule/ | grep -v "ansible_facts\.services is defined" || true)
if [ -n "$MISSING_DEFINED" ]; then
    echo "WARNING: Found ansible_facts.services checks without 'is defined' guard:"
    echo "$MISSING_DEFINED"
    echo "Consider adding: \"ansible_facts.services is defined and '...' in ansible_facts.services\""
fi

# Check for missing quotes in default() filters
MISSING_QUOTES=$(grep -r "default(" --include="*.yml" --include="*.yaml" molecule/ | grep -v "default(\"" | grep -v "default('" || true)
if [ -n "$MISSING_QUOTES" ]; then
    echo "WARNING: Found default() filters without quotes:"
    echo "$MISSING_QUOTES"
    echo "Fix by adding quotes: default(\"/path/to/file\")"
fi

echo "Ansible conditional check completed."
exit 0
