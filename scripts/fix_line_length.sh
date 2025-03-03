#!/bin/bash
#
# Script to fix line length issues in defaults/main.yaml
# This script will break up long lines that exceed 80 characters

set -e

echo "Fixing line length issues in defaults/main.yaml..."

# Make a backup
cp defaults/main.yaml defaults/main.yaml.bak

# Fix specific long lines in defaults/main.yaml
sed -i '' 's/ephemery_docker_memory_limit: "{{ (ansible_memory_mb.real.total \* 0.90) | round | int }}M"/ephemery_docker_memory_limit: |-\
  "{{ (ansible_memory_mb.real.total * 0.90) | round | int }}M"/' defaults/main.yaml

sed -i '' 's/el_memory_limit: "{{ ((ansible_memory_mb.real.total \* 0.90 \* el_memory_percentage) | round | int) }}M"/el_memory_limit: |-\
  "{{ ((ansible_memory_mb.real.total * 0.90 * el_memory_percentage) | round | int) }}M"/' defaults/main.yaml

sed -i '' 's/cl_memory_limit: "{{ ((ansible_memory_mb.real.total \* 0.90 \* cl_memory_percentage) | round | int) }}M"/cl_memory_limit: |-\
  "{{ ((ansible_memory_mb.real.total * 0.90 * cl_memory_percentage) | round | int) }}M"/' defaults/main.yaml

sed -i '' 's/validator_memory_limit: "{{ ((ansible_memory_mb.real.total \* 0.90 \* validator_memory_percentage) | round | int) }}M"/validator_memory_limit: |-\
  "{{ ((ansible_memory_mb.real.total * 0.90 * validator_memory_percentage) | round | int) }}M"/' defaults/main.yaml

echo "Line length fixes applied. Original file backed up to defaults/main.yaml.bak"
echo "You may need to manually review and fix other files with line length issues."
