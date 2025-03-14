#!/bin/bash

# filter_ansible_output.sh
# A script to filter and format Ansible output to make it more manageable
# Usage: ansible-playbook playbook.yml | ./scripts/filter_ansible_output.sh

# Set colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Process input line by line
while IFS= read -r line; do
    # Filter out lines containing these patterns
    if echo "$line" | grep -q "TASK \["; then
        echo -e "${BLUE}$line${NC}"
    elif echo "$line" | grep -q "PLAY \["; then
        echo -e "${GREEN}${BOLD}$line${NC}"
    elif echo "$line" | grep -q "PLAY RECAP"; then
        echo -e "${GREEN}${BOLD}$line${NC}"
    elif echo "$line" | grep -q "fatal:"; then
        echo -e "${RED}${BOLD}$line${NC}"
    elif echo "$line" | grep -q "failed="; then
        echo -e "${RED}$line${NC}"
    elif echo "$line" | grep -q "ok="; then
        echo -e "${GREEN}$line${NC}"
    elif echo "$line" | grep -q "changed="; then
        echo -e "${YELLOW}$line${NC}"
    elif echo "$line" | grep -q "ERROR"; then
        echo -e "${RED}${BOLD}$line${NC}"
    elif echo "$line" | grep -q "WARNING"; then
        echo -e "${YELLOW}${BOLD}$line${NC}"
    # Ephemery-specific patterns
    elif echo "$line" | grep -q -E "geth|lighthouse|validator|ephemery"; then
        echo -e "${CYAN}$line${NC}"
    elif echo "$line" | grep -q -E "Starting container|Container .* started"; then
        echo -e "${MAGENTA}$line${NC}"
    elif echo "$line" | grep -q -E "Pulling image|Image .* pulled"; then
        echo -e "${MAGENTA}$line${NC}"
    elif echo "$line" | grep -q -E "Syncing|Sync"; then
        echo -e "${CYAN}$line${NC}"
    fi
done

echo -e "${GREEN}Filtered output complete. Only showing PLAY, TASK, errors, warnings, and summary lines.${NC}" 