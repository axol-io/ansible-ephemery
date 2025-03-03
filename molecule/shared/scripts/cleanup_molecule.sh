#!/bin/bash
# cleanup_molecule.sh - Remove redundant files after reorganization

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
MOLECULE_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"

echo "Cleaning up redundant files in the molecule directory..."

# 1. Remove top-level cleanup.yaml if it exists
if [ -f "$MOLECULE_DIR/cleanup.yaml" ]; then
  echo "Removing top-level cleanup.yaml (now in shared/cleanup.yaml)"
  rm -f "$MOLECULE_DIR/cleanup.yaml"
fi

# 2. Remove empty files from client scenarios
echo "Removing empty verify.yaml and converge.yaml files from client directories..."
find "$MOLECULE_DIR/clients/" -type f -name "verify.yaml" -size 0 -delete
find "$MOLECULE_DIR/clients/" -type f -name "converge.yaml" -size 0 -delete

# 3. Check for duplicate converge.yaml files that can be simplified
echo "Identifying duplicate converge.yaml files..."
for dir in "$MOLECULE_DIR"/*/ ; do
  if [ -f "$dir/converge.yaml" ] && [ "$(basename "$dir")" != "shared" ] && [ "$(basename "$dir")" != "default" ]; then
    # Count lines in converge.yaml
    LINES=$(wc -l < "$dir/converge.yaml")

    # If it's a standard simple converge.yaml, suggest using shared template
    if [ "$LINES" -lt 15 ]; then
      echo "Consider simplifying: $dir/converge.yaml (${LINES} lines)"
    fi
  fi
done

echo ""
echo "Manual steps needed:"
echo "1. Review scenario-specific molecule.yaml files and simplify by inheriting from base_molecule.yaml"
echo "2. Consolidate duplicate verify.yaml files with similar tests"
echo "3. Move test-specific variables from molecule.yaml files to host_vars files"
echo ""
echo "Cleanup complete. Remember to test all scenarios after making changes!"
