#!/bin/bash
#
# Script to normalize task file names using hyphens instead of underscores

echo "Normalizing task file names..."

# Find other task files with underscores
find tasks -type f -name "*_*.yaml" | while read file; do
  # Get new name with hyphens instead of underscores
  new_file=$(echo "$file" | sed 's/_/-/g')

  echo "Renaming $file to $new_file"
  mv "$file" "$new_file"

  # Update references in main.yaml
  if [ -f "main.yaml" ]; then
    base_file=$(basename "$file")
    base_new_file=$(basename "$new_file")
    echo "Updating references from $base_file to $base_new_file in main.yaml"
    sed -i '' "s/$base_file/$base_new_file/g" "main.yaml"
  fi
done

# Check client directories for underscore filenames
find tasks/clients -type f -name "*_*.yaml" | while read file; do
  # Get new name with hyphens instead of underscores
  new_file=$(echo "$file" | sed 's/_/-/g')

  echo "Renaming $file to $new_file"
  mv "$file" "$new_file"
done

# Update directory names if they use underscores
find tasks/clients -type d -name "*_*" | while read dir; do
  # Get new name with hyphens instead of underscores
  new_dir=$(echo "$dir" | sed 's/_/-/g')

  echo "Renaming directory $dir to $new_dir"
  mv "$dir" "$new_dir"

  # Update references in ephemery.yaml
  if [ -f "tasks/ephemery.yaml" ]; then
    base_dir=$(basename "$dir")
    base_new_dir=$(basename "$new_dir")
    echo "Updating references from $base_dir to $base_new_dir in tasks/ephemery.yaml"
    sed -i '' "s/$base_dir/$base_new_dir/g" "tasks/ephemery.yaml"
  fi
done

echo "Task name normalization complete!"
