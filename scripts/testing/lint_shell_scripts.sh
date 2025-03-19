#!/usr/bin/env bash
# Version: 1.1.0
#
# Script Name: lint_shell_scripts.sh
# Description: Lints shell scripts using shellharden
# Author: Ephemery Team
# Created: 2025-03-21
# Last Modified: 2025-03-22
#
# This script uses shellharden to lint and optionally correct shell scripts in the project.

set -euo pipefail

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/testing/.shellhardenrc"

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Process command-line arguments
AUTO_FIX=false
CHECK_ONLY=false
VERBOSE=false
SPECIFIC_PATH=""

print_usage() {
  echo "Usage: $0 [options] [path]"
  echo "Options:"
  echo "  --fix            Auto-fix shell script issues"
  echo "  --check          Only check scripts, don't make changes (exit with error if issues found)"
  echo "  --verbose        Show detailed output"
  echo "  --help           Show this help message"
  echo "  path             Path to a specific script or directory to check"
  echo
  echo "If no path is specified, all shell scripts in the project will be checked."
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --fix)
      AUTO_FIX=true
      shift
      ;;
    --check)
      CHECK_ONLY=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      print_usage
      exit 1
      ;;
    *)
      if [[ -z "${SPECIFIC_PATH}" ]]; then
        SPECIFIC_PATH="$1"
      else
        echo "Error: More than one path specified"
        print_usage
        exit 1
      fi
      shift
      ;;
  esac
done

# Load configuration file
load_config() {
  if [[ -f "${CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
    echo -e "${BLUE}Using configuration from ${CONFIG_FILE}${NC}"
  else
    echo -e "${YELLOW}Configuration file not found: ${CONFIG_FILE}${NC}"
    echo -e "${YELLOW}Using default settings${NC}"
    
    # Default settings
    exclude_dirs=(".git" ".vscode" "node_modules" "venv")
    exclude_files=("*.md" "*.txt" "*.log")
    enforce_quotes=true
    replace_backticks=true
    check_unquoted_vars=true
    check_shebang=true
    replace_echo=true
    check_common_issues=true
    exit_code_warning=1
    exit_code_error=2
  fi
}

# Function to check if shellharden is installed
check_shellharden() {
  if ! command -v shellharden &> /dev/null; then
    echo -e "${YELLOW}shellharden is not installed.${NC}"
    return 1
  fi
  return 0
}

# Function to install shellharden
install_shellharden() {
  echo -e "${BLUE}Installing shellharden...${NC}"
  
  # Check if cargo is installed
  if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: cargo is not installed. Please install Rust and Cargo first:${NC}"
    echo "  https://www.rust-lang.org/tools/install"
    echo
    echo "Or install shellharden manually:"
    echo "  https://github.com/anordal/shellharden"
    exit 1
  fi
  
  # Install shellharden using cargo
  cargo install shellharden
  
  # Verify installation
  if ! command -v shellharden &> /dev/null; then
    echo -e "${RED}Failed to install shellharden.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}shellharden installed successfully.${NC}"
}

# Function to build find exclude arguments
build_exclude_args() {
  local exclude_args=()
  
  for dir in "${exclude_dirs[@]}"; do
    exclude_args+=("-not" "-path" "*/${dir}/*")
  done
  
  for file in "${exclude_files[@]}"; do
    exclude_args+=("-not" "-name" "${file}")
  done
  
  echo "${exclude_args[@]}"
}

# Find all shell scripts in the repository
find_shell_scripts() {
  local search_path="${1:-$PROJECT_ROOT}"
  local exclude_args
  mapfile -t exclude_args < <(build_exclude_args)
  
  if [[ -f "$search_path" ]]; then
    # If the path is a file, check if it's a shell script
    if file "$search_path" | grep -q "shell script"; then
      echo "$search_path"
    fi
  else
    # Find all shell scripts in the directory, excluding specified paths
    find "$search_path" -type f \( -name "*.sh" -o -name "*.bash" \) "${exclude_args[@]}" | sort
  fi
}

# Extract line number from shellharden output
extract_line_number() {
  local line="$1"
  if [[ "$line" =~ :[0-9]+:[0-9]+: ]]; then
    echo "$line" | sed -E 's/.*:([0-9]+):[0-9]+:.*/\1/'
  else
    echo ""
  fi
}

# Display context around an issue
display_context() {
  local file="$1"
  local line_number="$2"
  local context_lines=3
  
  # Calculate start and end lines for context
  local start_line=$((line_number - context_lines))
  local end_line=$((line_number + context_lines))
  
  # Ensure start_line is not negative
  if [[ $start_line -lt 1 ]]; then
    start_line=1
  fi
  
  # Get total lines in the file
  local total_lines
  total_lines=$(wc -l < "$file")
  
  # Ensure end_line doesn't exceed file length
  if [[ $end_line -gt $total_lines ]]; then
    end_line=$total_lines
  fi
  
  # Display context
  echo -e "${CYAN}Context (lines ${start_line}-${end_line}):${NC}"
  sed -n "${start_line},${end_line}p" "$file" | nl -v "$start_line" -w4 -s "  " | 
  while read -r context_line; do
    if [[ $context_line =~ ^[[:space:]]*$line_number[[:space:]] ]]; then
      echo -e "${RED}$context_line${NC}"
    else
      echo "$context_line"
    fi
  done
  echo
}

# Lint a single shell script
lint_script() {
  local script="$1"
  local issues_found=0
  
  if [[ "${VERBOSE}" == "true" ]]; then
    echo -e "${BLUE}Checking ${script}...${NC}"
  fi
  
  # Build shellharden arguments based on config
  local shellharden_args=()
  
  if [[ "${enforce_quotes}" == "true" ]]; then
    shellharden_args+=("--syntax")
  fi
  
  if [[ "${replace_backticks}" == "true" ]]; then
    shellharden_args+=("--replace-backticks")
  fi
  
  if [[ "${AUTO_FIX}" == "true" ]]; then
    # Auto-fix mode: apply changes
    shellharden_args+=("--replace")
    
    if [[ "${VERBOSE}" == "true" ]]; then
      shellharden "${shellharden_args[@]}" "$script"
    else
      shellharden "${shellharden_args[@]}" "$script" > /dev/null
    fi
    echo -e "${GREEN}✓ Fixed${NC} ${script}"
  else
    # Check-only mode: report issues
    local output
    output=$(shellharden "${shellharden_args[@]}" "$script" 2>&1 || true)
    
    if echo "$output" | grep -q "would change"; then
      issues_found=1
      echo -e "${RED}✗ Issues found${NC} in ${script}"
      
      if [[ "${VERBOSE}" == "true" ]]; then
        # Parse and display each issue with line number and context
        echo "$output" | grep -E ":[0-9]+:[0-9]+:" | while read -r issue; do
          echo -e "${RED}$issue${NC}"
          
          # Extract line number and display context
          local line_number
          line_number=$(extract_line_number "$issue")
          if [[ -n "$line_number" ]]; then
            display_context "$script" "$line_number"
          fi
        done
      fi
    else
      if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${GREEN}✓ No issues found${NC} in ${script}"
      fi
    fi
  fi
  
  return $issues_found
}

# Main function
main() {
  # Load configuration
  load_config
  
  # Check if shellharden is installed
  if ! check_shellharden; then
    install_shellharden
  fi
  
  echo -e "${BLUE}Shell script linting using shellharden${NC}"
  echo
  
  local search_path="${SPECIFIC_PATH:-$PROJECT_ROOT}"
  local scripts
  scripts=$(find_shell_scripts "$search_path")
  
  if [[ -z "$scripts" ]]; then
    echo -e "${YELLOW}No shell scripts found in ${search_path}.${NC}"
    exit 0
  fi
  
  local total_scripts=0
  local issues_found=0
  
  echo -e "${BLUE}Checking shell scripts...${NC}"
  echo
  
  while IFS= read -r script; do
    total_scripts=$((total_scripts + 1))
    if ! lint_script "$script"; then
      issues_found=$((issues_found + 1))
    fi
  done <<< "$scripts"
  
  echo
  echo -e "${BLUE}Summary:${NC}"
  echo "Total scripts checked: $total_scripts"
  
  if [[ "${AUTO_FIX}" == "true" ]]; then
    echo -e "${GREEN}All scripts processed.${NC}"
    exit 0
  else
    if [[ $issues_found -eq 0 ]]; then
      echo -e "${GREEN}No issues found! All scripts passed.${NC}"
      exit 0
    else
      echo -e "${RED}Issues found in $issues_found scripts.${NC}"
      
      if [[ "${CHECK_ONLY}" == "true" ]]; then
        echo "To fix these issues, run: $0 --fix"
        exit "${exit_code_error:-2}"
      else
        echo "To fix these issues, run: $0 --fix"
        exit 0
      fi
    fi
  fi
}

# Run main function
main 