#!/bin/bash
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Version: 1.0.0
#
# Script to standardize molecule file extensions to .yaml

echo "Standardizing molecule file extensions to .yaml..."

# Find molecule.yml files and rename them
find molecule -type f -name "molecule.yml" | while read file; do
  new_file="${file%.yml}.yaml"
  echo "Renaming ${file} to ${new_file}"
  mv "${file}" "${new_file}"

  # Update references in the file
  sed -i '' 's/\.yml/\.yaml/g' "${new_file}"
done

# Find other .yml files in molecule directory
find molecule -type f -name "*.yml" ! -name "molecule.yml" | while read file; do
  new_file="${file%.yml}.yaml"
  echo "Renaming ${file} to ${new_file}"
  mv "${file}" "${new_file}"

  # Update references in parent directory's molecule.yaml
  parent_dir=$(dirname "${file}")
  if [ -f "${parent_dir}/molecule.yaml" ]; then
    echo "Updating references in ${parent_dir}/molecule.yaml"
    filename=$(basename "${file}")
    new_filename=$(basename "${new_file}")
    sed -i '' "s/${filename}/${new_filename}/g" "${parent_dir}/molecule.yaml"
  fi
done

# Update references in molecule scripts
find molecule -type f -name "*.sh" | while read file; do
  if grep -q "\.yml" "${file}"; then
    echo "Updating references in ${file}"
    sed -i '' 's/\.yml/\.yaml/g' "${file}"
  fi
done

# Update references in template files
find molecule -type f -name "*.template" | while read file; do
  if grep -q "\.yml" "${file}"; then
    echo "Updating references in ${file}"
    sed -i '' 's/\.yml/\.yaml/g' "${file}"
  fi
done

echo "Molecule directory standardization complete!"
