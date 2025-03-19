#!/bin/bash
#
# This script standardizes documentation files and reduces duplication
#

set -e

# Print header
echo "====================================================="
echo "     Standardizing Documentation Files                "
echo "====================================================="

# Define documentation file pairs to check (potentially duplicated docs)
declare -A DOC_PAIRS=(
  ["docs/dev/SECURITY.md"]="SECURITY.md"
)

# Define directories to audit for README.md files
README_DIRS=(
  "scripts"
  "scripts/lib"
  "scripts/utilities"
  "scripts/core"
  "scripts/validator"
  "scripts/monitoring"
  "scripts/deployment"
  "scripts/testing"
  "ansible"
  "playbooks"
  "dashboard"
)

BACKUP_DIR="documentation_backup_$(date +%Y%m%d_%H%M%S)"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Function to standardize documentation files
standardize_documentation() {
  echo "Checking for duplicate documentation files..."

  for source in "${!DOC_PAIRS[@]}"; do
    target="${DOC_PAIRS[$source]}"

    # Check if both files exist
    if [ -f "$source" ] && [ -f "$target" ]; then
      # Backup both files
      cp "$source" "$BACKUP_DIR/$(basename "$source")"
      cp "$target" "$BACKUP_DIR/$(basename "$target")"

      echo "Comparing $source and $target..."

      # Check if files are identical
      if diff -q "$source" "$target" >/dev/null; then
        echo "Files are identical, will replace $source with a link to $target"
        rm "$source"

        # Create directory if it doesn't exist
        source_dir=$(dirname "$source")
        if [ ! -d "$source_dir" ]; then
          mkdir -p "$source_dir"
        fi

        # Create a markdown link file
        cat >"$source" <<EOF
# ${target%.*}

This documentation has been moved to the root directory.

Please see: [${target}](../../${target})
EOF
        echo "Created link file at $source pointing to $target"
      else
        # Files differ, create a comparison report
        DIFF_FILE="$BACKUP_DIR/diff_$(basename "$source").txt"
        echo "Files differ, creating comparison report at $DIFF_FILE"

        echo "# Comparison between $source and $target" >"$DIFF_FILE"
        echo "# Generated on $(date)" >>"$DIFF_FILE"
        echo "" >>"$DIFF_FILE"

        # Show file contents
        echo "## $source content:" >>"$DIFF_FILE"
        echo '```markdown' >>"$DIFF_FILE"
        cat "$source" >>"$DIFF_FILE"
        echo '```' >>"$DIFF_FILE"
        echo "" >>"$DIFF_FILE"

        echo "## $target content:" >>"$DIFF_FILE"
        echo '```markdown' >>"$DIFF_FILE"
        cat "$target" >>"$DIFF_FILE"
        echo '```' >>"$DIFF_FILE"
        echo "" >>"$DIFF_FILE"

        # Show diff
        echo "## Diff:" >>"$DIFF_FILE"
        echo '```diff' >>"$DIFF_FILE"
        diff -u "$source" "$target" >>"$DIFF_FILE" 2>/dev/null || true
        echo '```' >>"$DIFF_FILE"

        # Ask user what to do
        echo "Files differ. Please review the comparison report at $DIFF_FILE"
        echo "Options:"
        echo "1. Keep $target (replace $source with link)"
        echo "2. Keep $source (replace $target)"
        echo "3. Merge files (combine content from both)"
        echo "4. Skip (do nothing)"

        read -p "Choose option (1-4): " OPTION
        case "$OPTION" in
          1)
            rm "$source"
            # Create a markdown link file
            cat >"$source" <<EOF
# ${target%.*}

This documentation has been moved to the root directory.

Please see: [${target}](../../${target})
EOF
            echo "Created link file at $source pointing to $target"
            ;;
          2)
            cp "$source" "$target"
            rm "$source"
            # Create a markdown link file
            cat >"$source" <<EOF
# ${target%.*}

This documentation has been moved to the root directory.

Please see: [${target}](../../${target})
EOF
            echo "Replaced $target with $source and created link file"
            ;;
          3)
            # Create merged file
            MERGED_FILE="$target.merged.md"

            echo "# ${target%.*} (Combined)" >"$MERGED_FILE"
            echo "" >>"$MERGED_FILE"
            echo "This document combines content from multiple sources." >>"$MERGED_FILE"
            echo "" >>"$MERGED_FILE"

            echo "## Content from $target" >>"$MERGED_FILE"
            echo "" >>"$MERGED_FILE"
            tail -n +2 "$target" >>"$MERGED_FILE" # Skip first line (title)

            echo "" >>"$MERGED_FILE"
            echo "## Additional Content from $source" >>"$MERGED_FILE"
            echo "" >>"$MERGED_FILE"
            tail -n +2 "$source" >>"$MERGED_FILE" # Skip first line (title)

            mv "$MERGED_FILE" "$target"
            rm "$source"

            # Create a markdown link file
            cat >"$source" <<EOF
# ${target%.*}

This documentation has been moved to the root directory.

Please see: [${target}](../../${target})
EOF
            echo "Created merged file at $target and link file at $source"
            ;;
          *)
            echo "Skipping $source and $target"
            ;;
        esac
      fi
    elif [ -f "$source" ]; then
      # Only source exists
      cp "$source" "$BACKUP_DIR/$(basename "$source")"

      echo "Only $source exists, moving to standard location $target"

      # Create directory if it doesn't exist
      target_dir=$(dirname "$target")
      if [ ! -d "$target_dir" ]; then
        mkdir -p "$target_dir"
      fi

      cp "$source" "$target"
      rm "$source"

      # Create a markdown link file
      cat >"$source" <<EOF
# ${target%.*}

This documentation has been moved to the root directory.

Please see: [${target}](../../${target})
EOF
      echo "Moved $source to $target and created link file"
    elif [ -f "$target" ]; then
      # Only target exists
      echo "Only $target exists, standard location is already used"
    else
      echo "Neither $source nor $target exist, skipping"
    fi
  done
}

# Function to standardize READMEs in subdirectories
standardize_readmes() {
  echo "Standardizing README files in subdirectories..."

  for dir in "${README_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
      echo "Directory $dir does not exist, skipping"
      continue
    fi

    readme_file="$dir/README.md"

    # If no README exists, create a basic one
    if [ ! -f "$readme_file" ]; then
      echo "No README found in $dir, creating a basic one"

      dir_name=$(basename "$dir")

      cat >"$readme_file" <<EOF
# $dir_name

This directory contains files for the Ephemery Node system.

## Contents

$(find "$dir" -maxdepth 1 -type f | sort | while read -r file; do
        filename=$(basename "$file")
        if [[ "$filename" == *.sh ]]; then
          description=$(grep -m 1 "# Description:" "$file" | sed 's/# Description: //g' || echo "Shell script")
        elif [[ "$filename" == *.yml || "$filename" == *.yaml ]]; then
          description="YAML configuration file"
        elif [[ "$filename" == *.py ]]; then
          description="Python script"
        else
          description="File"
        fi
        echo "- **$filename**: $description"
      done)

## Usage

Please refer to individual files for specific usage instructions.
EOF
      echo "Created README file for $dir"
    else
      # README exists, check if it needs to be updated
      cp "$readme_file" "$BACKUP_DIR/$(basename "$dir")_README.md"
      echo "Backed up existing README for $dir"

      # Update README if it doesn't have a contents section
      if ! grep -q "## Contents" "$readme_file"; then
        echo "Updating README in $dir to include contents section"

        # Preserve existing content
        README_CONTENT=$(cat "$readme_file")

        # Create new README with contents section
        dir_name=$(basename "$dir")

        cat >"$readme_file" <<EOF
# $dir_name

$(echo "$README_CONTENT" | tail -n +2)

## Contents

$(find "$dir" -maxdepth 1 -type f -not -name "README.md" | sort | while read -r file; do
          filename=$(basename "$file")
          if [[ "$filename" == *.sh ]]; then
            description=$(grep -m 1 "# Description:" "$file" | sed 's/# Description: //g' || echo "Shell script")
          elif [[ "$filename" == *.yml || "$filename" == *.yaml ]]; then
            description="YAML configuration file"
          elif [[ "$filename" == *.py ]]; then
            description="Python script"
          else
            description="File"
          fi
          echo "- **$filename**: $description"
        done)
EOF
        echo "Updated README file for $dir with contents section"
      fi
    fi
  done
}

# Function to create a documentation index
create_documentation_index() {
  echo "Creating documentation index..."

  INDEX_FILE="docs/INDEX.md"

  # Backup existing index if it exists
  if [ -f "$INDEX_FILE" ]; then
    cp "$INDEX_FILE" "$BACKUP_DIR/INDEX.md"
  fi

  # Create index header
  cat >"$INDEX_FILE" <<EOF
# Ephemery Documentation Index

This is the central index for all Ephemery documentation.

## Core Documentation

$(find . -maxdepth 1 -name "*.md" -not -name "README.md" | sort | while read -r file; do
    filename=$(basename "$file")
    title=$(head -n 1 "$file" | sed 's/^# //g')
    echo "- [${title:-$filename}]($filename)"
  done)

## Directory-Specific Documentation

EOF

  # Add directory READMEs
  for dir in "${README_DIRS[@]}"; do
    if [ -f "$dir/README.md" ]; then
      dir_name=$(basename "$dir")
      dir_title=$(head -n 1 "$dir/README.md" | sed 's/^# //g')
      echo "- [${dir_title:-$dir_name}]($dir/README.md)" >>"$INDEX_FILE"
    fi
  done

  # Add other documentation files
  cat >>"$INDEX_FILE" <<EOF

## Developer Documentation

$(find docs/dev -name "*.md" 2>/dev/null | sort | while read -r file; do
    filename=$(basename "$file")
    title=$(head -n 1 "$file" | sed 's/^# //g')
    echo "- [${title:-$filename}]($file)"
  done)

## Usage Documentation

$(find docs/usage -name "*.md" 2>/dev/null | sort | while read -r file; do
    filename=$(basename "$file")
    title=$(head -n 1 "$file" | sed 's/^# //g')
    echo "- [${title:-$filename}]($file)"
  done)
EOF

  echo "Created documentation index at $INDEX_FILE"

  # Add link to index in main README if it exists
  if [ -f "README.md" ]; then
    if ! grep -q "docs/INDEX.md" "README.md"; then
      echo "Adding link to documentation index in README.md"

      # Create a temporary file
      TMP_README=$(mktemp)

      # Process the README
      awk '
            /^## Documentation/ {
                print $0;
                print "";
                print "For a comprehensive list of all documentation, see the [Documentation Index](docs/INDEX.md).";
                print "";
                doc_section = 1;
                next;
            }
            doc_section == 1 && /^##/ {
                doc_section = 0;
            }
            {
                print $0;
            }
            ' "README.md" >"$TMP_README"

      # If no Documentation section was found, add one
      if ! grep -q "^## Documentation" "$TMP_README"; then
        echo -e "\n## Documentation\n\nFor a comprehensive list of all documentation, see the [Documentation Index](docs/INDEX.md).\n" >>"$TMP_README"
      fi

      # Replace the original README
      cp "README.md" "$BACKUP_DIR/README.md"
      mv "$TMP_README" "README.md"
      echo "Updated README.md with link to documentation index"
    fi
  fi
}

# Run the functions
standardize_documentation
standardize_readmes
create_documentation_index

echo
echo "Documentation has been standardized."
echo "Backups saved to $BACKUP_DIR"
echo
echo "Next steps:"
echo "1. Review the updated documentation files"
echo "2. Check the documentation index at docs/INDEX.md"
echo "3. Verify that links between documentation files work correctly"
