#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: generate_documentation.sh
# Description: Generates documentation for Ephemery shell scripts
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17

# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

# Setup error handling
setup_traps

# Default paths and settings
SCRIPTS_DIR="${PROJECT_ROOT}/scripts"
DOCS_DIR="${PROJECT_ROOT}/docs/scripts"
OUTPUT_FORMAT="markdown"
VERBOSE=false
INCLUDE_PRIVATE=false
TARGET_DIRS=()

# Print usage information
function print_usage() {
  log_info "Ephemery Script Documentation Generator"
  log_info ""
  log_info "This script generates documentation for shell scripts in the Ephemery project."
  log_info ""
  log_info "Usage:"
  log_info "  $0 [options] [directories...]"
  log_info ""
  log_info "Options:"
  log_info "  -o, --output-dir DIR   Set output directory (default: ${DOCS_DIR})"
  log_info "  -f, --format FORMAT    Set output format (markdown or json, default: markdown)"
  log_info "  -v, --verbose          Enable verbose output"
  log_info "  -p, --include-private  Include private scripts (prefixed with underscore)"
  log_info "  -h, --help             Show this help message"
  log_info ""
  log_info "Examples:"
  log_info "  $0                     # Document all scripts"
  log_info "  $0 scripts/core        # Document only scripts in core directory"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -h | --help)
      print_usage
      exit 0
      ;;
    -o | --output-dir)
      DOCS_DIR="$2"
      shift 2
      ;;
    -f | --format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    -v | --verbose)
      VERBOSE=true
      shift
      ;;
    -p | --include-private)
      INCLUDE_PRIVATE=true
      shift
      ;;
    -*)
      log_error "Unknown option: $1"
      print_usage
      exit 1
      ;;
    *)
      # Add directory to the list
      TARGET_DIRS+=("$1")
      shift
      ;;
  esac
done

# If no target directories specified, use the default scripts directory
if [[ ${#TARGET_DIRS[@]} -eq 0 ]]; then
  TARGET_DIRS=("${SCRIPTS_DIR}")
fi

# Validate output format
if [[ "${OUTPUT_FORMAT}" != "markdown" && "${OUTPUT_FORMAT}" != "json" ]]; then
  log_error "Invalid output format: ${OUTPUT_FORMAT}. Must be 'markdown' or 'json'."
  exit 1
fi

# Create output directory if it doesn't exist
mkdir -p "${DOCS_DIR}"

# Initialize index file
INDEX_FILE="${DOCS_DIR}/index.md"
log_info "Generating script documentation index at ${INDEX_FILE}"
cat >"${INDEX_FILE}" <<EOF
# Ephemery Script Documentation

Generated on $(date '+%Y-%m-%d %H:%M:%S')

This documentation provides details about the shell scripts in the Ephemery project.

## Script Categories
EOF

# Process each target directory
for dir in "${TARGET_DIRS[@]}"; do
  if [[ ! -d "${dir}" ]]; then
    log_warn "Directory not found: ${dir}"
    continue
  fi

  # Get relative path for category name
  rel_path="${dir#${PROJECT_ROOT}/}"
  category_name=$(basename "${dir}")
  category_name_clean=$(echo "${category_name}" | tr '-' ' ' | tr '_' ' ' | sed -e 's/\b\(.\)/\u\1/g')

  # Add category to index
  echo -e "\n### ${category_name_clean} Scripts\n" >>"${INDEX_FILE}"

  # Create category directory
  category_dir="${DOCS_DIR}/${category_name}"
  mkdir -p "${category_dir}"

  # Find all shell scripts in the directory
  log_info "Processing scripts in ${rel_path}"

  # Build find command based on inclusion settings
  if [[ "${INCLUDE_PRIVATE}" == "true" ]]; then
    find_cmd="find \"${dir}\" -type f -name \"*.sh\""
  else
    find_cmd="find \"${dir}\" -type f -name \"*.sh\" ! -name \"_*\""
  fi

  # Execute find command and process scripts
  script_count=0
  while read -r script; do
    # Skip if not a file
    if [[ ! -f "${script}" ]]; then
      continue
    fi

    # Get script name and create output file
    script_name=$(basename "${script}")
    script_base="${script_name%.sh}"
    doc_file="${category_dir}/${script_base}.md"

    # Extract metadata and generate documentation
    log_info "Generating documentation for ${script_name}"
    if [[ "${VERBOSE}" == "true" ]]; then
      log_info "  Output file: ${doc_file}"
    fi

    # Use common library function for extraction
    generate_script_docs "${script}" "${doc_file}" "${OUTPUT_FORMAT}"

    # Check if documentation was generated successfully
    if [[ $? -eq 0 && -f "${doc_file}" ]]; then
      # Extract description for index
      description=""
      if grep -q "Description:" "${script}"; then
        description=$(grep -E "^#[[:space:]]*Description:" "${script}" | sed -E 's/^#[[:space:]]*Description:[[:space:]]*(.*)/\1/')
      else
        description="No description available"
      fi

      # Add to index
      echo "- [${script_name}](${category_name}/${script_base}.md) - ${description}" >>"${INDEX_FILE}"
      script_count=$((script_count + 1))
    else
      log_warn "Failed to generate documentation for ${script_name}"
    fi
  done < <(eval "${find_cmd}")

  log_info "Processed ${script_count} scripts in ${rel_path}"
done

log_success "Documentation generation complete"
log_info "Generated documentation is available at ${DOCS_DIR}"
