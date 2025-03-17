#!/bin/bash
# Version: 1.0.0
# Script to fix YAML file extensions
# Convert .yml to .yaml except in the molecule/ directory

set -e

# Find all .yml files outside the molecule directory
YML_FILES=$(find . -name "*.yml" | grep -v "molecule/")

if [ -z "${YML_FILES}" ]; then
  echo "No .yml files found outside the molecule directory."
  exit 0
fi

echo "Converting the following files from .yml to .yaml:"
echo "${YML_FILES}"
echo ""

# Ask for confirmation
read -p "Proceed with conversion? (y/n) " -n 1 -r
echo
if [[ ! ${REPLY} =~ ^[Yy]$ ]]; then
  echo "Operation cancelled."
  exit 1
fi

# Convert each file
for file in ${YML_FILES}; do
  new_file="${file%.yml}.yaml"
  echo "Converting ${file} to ${new_file}"
  git mv "${file}" "${new_file}"
done

echo "Conversion complete. Please check your git status."
