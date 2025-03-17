#!/bin/bash
# Version: 1.0.0
# Fix ShellCheck SC2155 warnings by separating variable declarations and assignments

# Display help information
show_help() {
  echo "Usage: $0 [options] [file ...]"
  echo "Fix ShellCheck SC2155 warnings by separating variable declarations and assignments."
  echo ""
  echo "Options:"
  echo "  -h, --help        Show this help message"
  echo "  -r, --recursive   Process all shell scripts recursively from current directory"
  echo "  -d, --dry-run     Show what would be changed without actually modifying files"
  echo ""
  echo "Examples:"
  echo "  $0 script.sh                  # Fix SC2155 issues in a single file"
  echo "  $0 -r                         # Fix SC2155 issues in all shell scripts recursively"
  echo "  $0 -d script.sh               # Show what would be changed without modifying the file"
  echo ""
  echo "This script fixes the ShellCheck SC2155 warning by converting:"
  echo "  local var=\$(command)  -->  local var; var=\$(command)"
  echo "  export var=\$(command) -->  export var; var=\$(command)"
  echo "  declare var=\$(command) -->  declare var; var=\$(command)"
}

# Initialize variables
dry_run=false
recursive=false
files=()

# Parse command line arguments
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      show_help
      exit 0
      ;;
    -r | --recursive)
      recursive=true
      shift
      ;;
    -d | --dry-run)
      dry_run=true
      shift
      ;;
    *)
      files+=("$1")
      shift
      ;;
  esac
done

# Function to fix SC2155 issues in a single file
fix_sc2155() {
  local file="$1"
  local tmpfile
  local fixed=false

  # Make sure file exists and is a regular file
  if [ ! -f "$file" ]; then
    echo "Error: $file does not exist or is not a regular file"
    return 1
  fi

  # Check if the file is a shell script
  if ! grep -q '^#!/bin/\(ba\)\?sh' "$file"; then
    if ! [[ "$file" =~ \.(sh|bash)$ ]]; then
      echo "Warning: $file does not appear to be a shell script, skipping"
      return 0
    fi
  fi

  # Create a temporary file
  tmpfile=$(mktemp)

  # Process the file line by line
  while IFS= read -r line; do
    # Check for SC2155 pattern: declaration with assignment using $( )
    if [[ "$line" =~ ^[[:space:]]*(local|export|declare)[[:space:]]+([a-zA-Z0-9_]+)=\$\( ]]; then
      # Extract the declaration type, variable name, and assignment
      declare_type="${BASH_REMATCH[1]}"
      var_name="${BASH_REMATCH[2]}"

      # Extract the full line and replace with two lines
      new_line="${line/%$var_name=/$var_name;}"
      new_line="${new_line/$declare_type $var_name;/$declare_type $var_name; $var_name=}"

      if $dry_run; then
        echo "Would change in $file:"
        echo "- $line"
        echo "+ $new_line"
      else
        echo "$new_line" >>"$tmpfile"
        fixed=true
      fi
    else
      # No change needed, copy line as is
      if ! $dry_run; then
        echo "$line" >>"$tmpfile"
      fi
    fi
  done <"$file"

  # Replace the original file with the fixed version if changes were made
  if $fixed && ! $dry_run; then
    mv "$tmpfile" "$file"
    echo "Fixed SC2155 issues in $file"
  elif ! $dry_run; then
    rm "$tmpfile"
    echo "No SC2155 issues found in $file"
  fi
}

# If recursive mode is enabled, find all shell scripts in the current directory and subdirectories
if $recursive; then
  while IFS= read -r file; do
    files+=("$file")
  done < <(find . -type f \( -name "*.sh" -o -name "*.bash" \) -o -exec grep -l '^#!/bin/\(ba\)\?sh' {} \;)
fi

# If no files were specified and not in recursive mode, show help
if [ ${#files[@]} -eq 0 ] && ! $recursive; then
  echo "Error: No files specified"
  show_help
  exit 1
fi

# Process each file
for file in "${files[@]}"; do
  fix_sc2155 "$file"
done

echo "SC2155 fixing complete!"
