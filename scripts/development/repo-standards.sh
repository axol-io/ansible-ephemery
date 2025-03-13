#!/bin/bash
# repo-standards.sh - Consolidated script for repository standardization
# Combines functionality from:
# - repository_structure.sh
# - normalize_task_names.sh
# - standardize_repository.sh
# - standardize_molecule_extensions.sh

set -e

# Print main usage information
function usage {
  echo "Usage: $0 <command> [options]"
  echo
  echo "Commands:"
  echo "  structure            Generate or verify repository structure documentation"
  echo "  normalize-tasks      Normalize task names to follow standards"
  echo "  standardize-molecule Standardize Molecule directory extensions"
  echo "  standardize-all      Run all standardization tasks"
  echo "  help                 Show this help message"
  echo
  echo "Options vary by command. Use '$0 <command> --help' for command-specific help."
}

# Print structure command usage
function usage_structure {
  echo "Usage: $0 structure [options]"
  echo
  echo "Generate or verify repository structure documentation."
  echo
  echo "Options:"
  echo "  --verify        Check if documentation matches actual structure"
  echo "  --update        Update structure documentation in REPOSITORY_STRUCTURE.md"
  echo "  --output FILE   Write structure to specified file (default: REPOSITORY_STRUCTURE.md)"
  echo "  --help          Show this help message"
}

# Print normalize-tasks command usage
function usage_normalize_tasks {
  echo "Usage: $0 normalize-tasks [options]"
  echo
  echo "Normalize task names to follow standards."
  echo
  echo "Options:"
  echo "  --dry-run       Show what would be changed without making changes"
  echo "  --force         Apply changes without confirmation"
  echo "  --help          Show this help message"
}

# Print standardize-molecule command usage
function usage_standardize_molecule {
  echo "Usage: $0 standardize-molecule [options]"
  echo
  echo "Standardize Molecule directory extensions (use .yml in molecule/)."
  echo
  echo "Options:"
  echo "  --dry-run       Show what would be changed without making changes"
  echo "  --help          Show this help message"
}

# Function to generate/verify repository structure
function manage_structure {
  local mode="generate"
  local output_file="docs/REPOSITORY_STRUCTURE.md"

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verify)
        mode="verify"
        shift
        ;;
      --update)
        mode="update"
        shift
        ;;
      --output)
        output_file="$2"
        shift 2
        ;;
      --help)
        usage_structure
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage_structure
        exit 1
        ;;
    esac
  done

  echo "Processing repository structure..."

  # Create temporary file for structure
  local temp_file
  temp_file=$(mktemp)

  # Generate repository structure
  echo "# Ansible Ephemery Repository Structure" > "$temp_file"
  echo "" >> "$temp_file"
  echo "This document outlines the organization of the Ansible Ephemery repository." >> "$temp_file"
  echo "" >> "$temp_file"
  echo "## Directory Structure" >> "$temp_file"
  echo "" >> "$temp_file"
  echo "\`\`\`bash" >> "$temp_file"

  # Generate directory tree
  find . -type f -o -type d | grep -v '.git/' | grep -v 'venv/' | grep -v '.pytest_cache/' | sort | while read -r line; do
    # Skip current directory
    if [ "$line" == "." ]; then
      continue
    fi

    # Remove leading ./
    line="${line#./}"

    # Skip hidden files unless they're important config files
    if [[ "$line" =~ ^\. && ! "$line" =~ ^\.ansible-lint && ! "$line" =~ ^\.yamllint && ! "$line" =~ ^\.pre-commit-config.yaml ]]; then
      continue
    fi

    # Calculate depth for indentation
    depth=$(echo "$line" | tr -cd '/' | wc -c)
    indent=$(printf '%*s' $((depth * 4)) '')

    # Get base name
    base_name=$(basename "$line")

    # Determine if it's a file or directory
    if [ -f "$line" ]; then
      # For files, add a short description
      case "$base_name" in
        *.yaml|*.yml)
          echo "$indent$base_name  # YAML configuration" >> "$temp_file"
          ;;
        *.md)
          echo "$indent$base_name  # Documentation" >> "$temp_file"
          ;;
        *.sh)
          echo "$indent$base_name  # Utility script" >> "$temp_file"
          ;;
        requirements.txt)
          echo "$indent$base_name  # Python dependencies" >> "$temp_file"
          ;;
        *)
          echo "$indent$base_name" >> "$temp_file"
          ;;
      esac
    else
      # It's a directory, add a trailing slash
      if [ "$depth" -eq 0 ]; then
        echo "$indent$base_name/  # Root directory" >> "$temp_file"
      else
        case "$base_name" in
          tasks)
            echo "$indent$base_name/  # Ansible tasks" >> "$temp_file"
            ;;
          templates)
            echo "$indent$base_name/  # Jinja2 templates" >> "$temp_file"
            ;;
          vars)
            echo "$indent$base_name/  # Variable definitions" >> "$temp_file"
            ;;
          molecule)
            echo "$indent$base_name/  # Testing framework" >> "$temp_file"
            ;;
          scripts)
            echo "$indent$base_name/  # Utility scripts" >> "$temp_file"
            ;;
          docs)
            echo "$indent$base_name/  # Documentation" >> "$temp_file"
            ;;
          files)
            echo "$indent$base_name/  # Static files" >> "$temp_file"
            ;;
          *)
            echo "$indent$base_name/" >> "$temp_file"
            ;;
        esac
      fi
    fi
  done

  echo "\`\`\`" >> "$temp_file"

  # Add additional sections
  echo "" >> "$temp_file"
  echo "## File Naming Convention" >> "$temp_file"
  echo "" >> "$temp_file"
  echo "- YAML files use \`.yaml\` extension (not \`.yml\`) except in molecule directory" >> "$temp_file"
  echo "- Files use lowercase with hyphens for multi-word names" >> "$temp_file"
  echo "- Task files named by function" >> "$temp_file"
  echo "" >> "$temp_file"
  echo "## Variable Organization" >> "$temp_file"
  echo "" >> "$temp_file"
  echo "Variables precedence (lowest to highest):" >> "$temp_file"
  echo "" >> "$temp_file"
  echo "1. \`defaults/main.yaml\` - Default values" >> "$temp_file"
  echo "2. \`vars/main.yaml\` - Common variables" >> "$temp_file"
  echo "3. \`group_vars/all.yaml\` - All-hosts variables" >> "$temp_file"
  echo "4. \`group_vars/<group>.yaml\` - Group-specific variables" >> "$temp_file"
  echo "5. \`host_vars/<host>.yaml\` - Host-specific variables" >> "$temp_file"
  echo "6. Command line \`-e\` variables - Runtime overrides" >> "$temp_file"

  # Process based on mode
  if [ "$mode" == "generate" ]; then
    cat "$temp_file"
    echo ""
    echo "To save this to a file, use:"
    echo "  $0 structure --output filename.md"
  elif [ "$mode" == "update" ]; then
    echo "Updating $output_file..."
    cp "$temp_file" "$output_file"
    echo "Repository structure documentation updated."
  elif [ "$mode" == "verify" ]; then
    if [ ! -f "$output_file" ]; then
      echo "Error: Structure file $output_file does not exist."
      exit 1
    fi

    echo "Verifying repository structure against $output_file..."
    if diff -q "$temp_file" "$output_file" > /dev/null; then
      echo "✓ Structure documentation is up to date."
    else
      echo "✗ Structure documentation is outdated."
      echo ""
      echo "Differences:"
      diff -u "$output_file" "$temp_file"
      echo ""
      echo "To update the documentation, run:"
      echo "  $0 structure --update"
      exit 1
    fi
  fi

  # Clean up
  rm -f "$temp_file"
}

# Function to normalize task names
function normalize_task_names {
  local dry_run=0
  local force=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=1
        shift
        ;;
      --force)
        force=1
        shift
        ;;
      --help)
        usage_normalize_tasks
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage_normalize_tasks
        exit 1
        ;;
    esac
  done

  echo "Normalizing task names..."

  # Find all task files
  yaml_files=$(find . -path "./tasks/*.yaml" -o -path "./tasks/*.yml" -o -path "./handlers/*.yaml" -o -path "./handlers/*.yml")

  # Track stats
  local modified_files=0
  local total_files=0
  local total_tasks=0
  local modified_tasks=0

  for file in $yaml_files; do
    total_files=$((total_files + 1))
    local file_modified=0
    local temp_file
    temp_file=$(mktemp)
    local line_num=0
    local task_line_num=0
    local task_name=""

    # Process file line by line
    while IFS= read -r line; do
      line_num=$((line_num + 1))

      # Check if we're entering a task
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]name: ]]; then
        task_line_num=$line_num
        task_name=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]name:[[:space:]]*(.*)/\1/')

        # Check if task name matches convention
        if ! [[ "$task_name" =~ ^[A-Z][a-z]+:[[:space:]][A-Z0-9] ]]; then
          # Task name doesn't match convention, normalize it
          local action
          action=$(echo "$task_name" | awk -F ':' '{print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
          local description
          description=$(echo "$task_name" | awk -F ':' '{$1=""; print $0}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

          # If no colon, treat whole thing as description and guess action
          if [ -z "$description" ]; then
            description=$action
            if [[ "$file" =~ handlers ]]; then
              action="Handle"
            elif [[ "$task_name" =~ ^[Ii]nstall ]]; then
              action="Install"
            elif [[ "$task_name" =~ ^[Cc]onfigure ]]; then
              action="Configure"
            elif [[ "$task_name" =~ ^[Ss]etup ]]; then
              action="Setup"
            elif [[ "$task_name" =~ ^[Cc]reate ]]; then
              action="Create"
            elif [[ "$task_name" =~ ^[Rr]emove ]]; then
              action="Remove"
            elif [[ "$task_name" =~ ^[Cc]heck ]]; then
              action="Check"
            else
              action="Execute"
            fi
          fi

          # Capitalize first letter of action
          action=$(echo "$action" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')

          # Capitalize first letter of description
          description=$(echo "$description" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')

          # New normalized task name
          local new_task_name="$action: $description"

          if [ "$dry_run" -eq 1 ]; then
            echo "File: $file, Line: $task_line_num"
            echo "  Original: $task_name"
            echo "  Normalized: $new_task_name"
          else
            # Replace task name
            line=$(echo "$line" | sed -E "s/^([[:space:]]*-[[:space:]]name:[[:space:]]*).*$/\1\"$new_task_name\"/")
            file_modified=1
            modified_tasks=$((modified_tasks + 1))
          fi
        fi

        total_tasks=$((total_tasks + 1))
      else
        true  # No-op to prevent empty else clause
      fi

      # Write line to temp file
      echo "$line" >> "$temp_file"
    done < "$file"

    # Update file if modified
    if [ "$file_modified" -eq 1 ]; then
      if [ "$force" -eq 1 ] || [ "$dry_run" -eq 1 ]; then
        if [ "$dry_run" -eq 0 ]; then
          cp "$temp_file" "$file"
          echo "Updated: $file"
        fi
        modified_files=$((modified_files + 1))
      else
        read -p "Update $file? [y/N]: " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
          cp "$temp_file" "$file"
          echo "Updated: $file"
          modified_files=$((modified_files + 1))
        else
          echo "Skipped: $file"
        fi
      fi
    fi

    # Clean up
    rm -f "$temp_file"
  done

  # Print summary
  echo ""
  echo "Task Normalization Summary:"
  echo "------------------------"
  echo "Files processed: $total_files"
  echo "Tasks processed: $total_tasks"
  if [ "$dry_run" -eq 1 ]; then
    echo "Tasks that would be modified: $modified_tasks"
    echo "Files that would be modified: $modified_files"
    echo ""
    echo "To apply these changes, run:"
    echo "  $0 normalize-tasks"
  else
    echo "Tasks modified: $modified_tasks"
    echo "Files modified: $modified_files"
  fi
}

# Function to standardize Molecule extensions
function standardize_molecule_extensions {
  local dry_run=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=1
        shift
        ;;
      --help)
        usage_standardize_molecule
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage_standardize_molecule
        exit 1
        ;;
    esac
  done

  echo "Standardizing Molecule directory extensions..."

  # Check if molecule directory exists
  if [ ! -d "molecule" ]; then
    echo "Error: molecule directory not found."
    exit 1
  fi

  # Track stats
  local renamed_files=0
  local total_files=0

  # Find .yaml files in molecule directory
  while IFS= read -r file; do
    total_files=$((total_files + 1))
    new_file="${file%.yaml}.yml"

    if [ "$dry_run" -eq 1 ]; then
      echo "Would rename: $file -> $new_file"
    else
      mv "$file" "$new_file"
      echo "Renamed: $file -> $new_file"
    fi

    renamed_files=$((renamed_files + 1))
  done < <(find molecule -name "*.yaml" -type f)

  # Print summary
  echo ""
  echo "Molecule Extension Standardization Summary:"
  echo "----------------------------------------"
  echo "Files found: $total_files"
  if [ "$dry_run" -eq 1 ]; then
    echo "Files that would be renamed: $renamed_files"
    echo ""
    echo "To apply these changes, run:"
    echo "  $0 standardize-molecule"
  else
    echo "Files renamed: $renamed_files"
  fi
}

# Function to run all standardization tasks
function standardize_all {
  local dry_run=0

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        dry_run=1
        shift
        ;;
      --help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  echo "Running all standardization tasks..."
  echo ""

  # Run structure check/update
  manage_structure --verify

  # Add some spacing
  echo ""
  echo "========================================"
  echo ""

  # Run task normalization
  if [ "$dry_run" -eq 1 ]; then
    normalize_task_names --dry-run
  else
    normalize_task_names --force
  fi

  # Add some spacing
  echo ""
  echo "========================================"
  echo ""

  # Run molecule extension standardization
  if [ "$dry_run" -eq 1 ]; then
    standardize_molecule_extensions --dry-run
  else
    standardize_molecule_extensions
  fi

  echo ""
  echo "All standardization tasks completed."
}

# Main command processing
if [ $# -eq 0 ]; then
  usage
  exit 1
fi

COMMAND="$1"
shift

case "$COMMAND" in
  structure)
    manage_structure "$@"
    ;;

  normalize-tasks)
    normalize_task_names "$@"
    ;;

  standardize-molecule)
    standardize_molecule_extensions "$@"
    ;;

  standardize-all)
    standardize_all "$@"
    ;;

  help)
    usage
    exit 0
    ;;

  *)
    echo "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
