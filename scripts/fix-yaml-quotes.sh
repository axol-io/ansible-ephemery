#!/bin/bash
# Script to fix YAML string quoting issues in Ansible files
# This script will replace double quotes with single quotes for string values

set -e

echo "Fixing YAML string quoting issues..."

# Find all yaml/yml files excluding hidden directories
YAML_FILES=$(find . -name "*.yaml" -o -name "*.yml" | grep -v "^\./\." | grep -v "node_modules")

for file in $YAML_FILES; do
  echo "Processing $file"
  
  # Replace double quotes with single quotes, but be careful with:
  # - Jinja2 expressions like {{ var }}
  # - YAML block indicators like ">"
  # - Raw tags {% raw %} {% endraw %}
  
  # Make a backup
  cp "$file" "${file}.bak"
  
  # Ensure all strings are properly quoted with single quotes
  sed -i.tmp -E '
    # Skip lines with raw tags
    /{% raw %}|{% endraw %}/b
    
    # Skip lines with multiline indicators
    /: [>|]/b
    
    # Replace double-quoted strings with single-quoted strings
    # but preserve Jinja2 variables
    s/: "([^"{}]*)"/: '\''\\1'\''/g
    
    # For strings with Jinja2 expressions, keep double quotes
    # but flag them for manual review
    s/: "([^"]*{{[^"]*}}[^"]*)"/: "\\1" # REVIEW: contains Jinja2 expression/g
    
    # Also handle redundantly quoted strings
    s/: '\''([^'\''{}]*)'\'''/: '\''\\1'\''/g
  ' "$file"
  
  # Remove temporary files
  rm -f "${file}.tmp"
done

echo "Quoting fixes complete. Please review changes manually!"