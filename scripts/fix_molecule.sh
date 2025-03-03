#!/bin/bash
# Fix file extensions in molecule directory
echo "Renaming .yaml files to .yml in molecule directory..."

# Rename all YAML files (excluding .j2 templates)
find molecule -type f -name "*.yaml" ! -name "*.j2" | while read file; do
  new_file="${file%.yaml}.yml"
  if [ ! -f "$new_file" ]; then
    echo "Renaming $file → $new_file"
    mv "$file" "$new_file"
  else
    echo "Warning: Cannot rename $file because $new_file already exists"
  fi
done

# Rename template files
find molecule -type f -name "*.yaml.j2" | while read file; do
  new_file="${file%.yaml.j2}.yml.j2"
  if [ ! -f "$new_file" ]; then
    echo "Renaming $file → $new_file"
    mv "$file" "$new_file"
  else
    echo "Warning: Cannot rename $file because $new_file already exists"
  fi
done

# Update references within files
echo -e "\nUpdating references within files..."
for file in $(find molecule -type f -name "*.yml"); do
  echo "Checking $file"
  # Use perl instead of sed for better cross-platform compatibility
  perl -i -pe 's/(verify|converge|prepare|molecule|cleanup)\.yaml/\1.yml/g' "$file"
done

echo -e "\nDone! Try running 'molecule test' now."
