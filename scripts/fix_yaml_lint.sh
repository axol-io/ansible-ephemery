#!/bin/bash
#
# Script to fix common YAML linting issues
# - Adds missing document start markers
# - Normalizes truthy values to 'true' and 'false'
# - Fixes indentation

set -e

echo "Fixing YAML linting issues..."

# Find YAML files (excluding .git directory)
yaml_files=$(find . -type f \( -name "*.yaml" -o -name "*.yml" \) -not -path "*/\.git/*")

# Add document start marker if missing
for file in $yaml_files; do
  # Skip files in .git directory
  if [[ "$file" == *".git"* ]]; then
    continue
  fi
  
  # Check if file starts with --- and add if missing
  if ! grep -q "^---" "$file"; then
    echo "Adding document start marker to $file"
    sed -i '' '1s/^/---\n/' "$file"
  fi
done

# Fix truthy values
for file in $yaml_files; do
  # Skip files in .git directory
  if [[ "$file" == *".git"* ]]; then
    continue
  fi
  
  echo "Normalizing truthy values in $file"
  # Replace yes/Yes/YES with true
  sed -i '' 's/: yes$/: true/g' "$file"
  sed -i '' 's/: Yes$/: true/g' "$file"
  sed -i '' 's/: YES$/: true/g' "$file"
  
  # Replace no/No/NO with false
  sed -i '' 's/: no$/: false/g' "$file"
  sed -i '' 's/: No$/: false/g' "$file"
  sed -i '' 's/: NO$/: false/g' "$file"
done

# Fix trailing whitespace
for file in $yaml_files; do
  # Skip files in .git directory
  if [[ "$file" == *".git"* ]]; then
    continue
  fi
  
  echo "Removing trailing whitespace in $file"
  sed -i '' 's/[[:space:]]*$//' "$file"
done

echo "YAML linting fixes completed!"
echo "Note: This script addresses common issues but manual review may still be needed."
echo "For line length issues, consider breaking long lines manually." 