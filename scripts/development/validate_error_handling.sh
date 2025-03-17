#!/bin/bash
# Version: 1.0.0
# validate_error_handling.sh - Validate error handling across all scripts
# This script checks for proper error handling in bash scripts

# Exit on error
set -e

# Define base directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

# Source core utilities if available
if [ -f "${PROJECT_ROOT}/scripts/core/common.sh" ]; then
  source "${PROJECT_ROOT}/scripts/core/common.sh"
fi

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPORT_FILE="${PROJECT_ROOT}/error_handling_report_$(date +%Y%m%d-%H%M%S).md"
EXCLUDE_DIRS=(".git" ".github" "node_modules" "venv")
SCRIPT_EXTENSIONS=("sh" "bash")

# Error handling patterns to check for
ERROR_HANDLING_PATTERNS=(
  "set -e"                  # Exit on error
  "set -o pipefail"         # Exit on pipe failure
  "trap.*ERR"               # ERR trap handler
  "if \[ .* \]; then"       # Conditional checks
  "function.*\(\)"          # Function definitions
  "return [1-9]"            # Non-zero return codes
  "exit [1-9]"              # Non-zero exit codes
  "error_handling"          # Custom error handling
  "error\(\)"               # Error function
  "setup_error_handling"    # Error handling setup
)

# Function to check if a file should be excluded
should_exclude() {
  local file_path=$1
  
  # Check excluded directories
  for dir in "${EXCLUDE_DIRS[@]}"; do
    if [[ "${file_path}" == *"/${dir}/"* ]]; then
      return 0  # Should exclude
    fi
  done
  
  return 1  # Should not exclude
}

# Function to check if a file is a shell script
is_shell_script() {
  local file_path=$1
  
  # Check by extension
  for ext in "${SCRIPT_EXTENSIONS[@]}"; do
    if [[ "${file_path}" == *".${ext}" ]]; then
      return 0  # Is a shell script by extension
    fi
  done
  
  # Check by shebang
  if head -n 1 "${file_path}" 2>/dev/null | grep -q "#!/.*sh"; then
    return 0  # Is a shell script by shebang
  fi
  
  return 1  # Not a shell script
}

# Function to check error handling in a file
check_error_handling() {
  local file_path=$1
  local error_handling_score=0
  local max_score=${#ERROR_HANDLING_PATTERNS[@]}
  local found_patterns=()
  
  # Check for each error handling pattern
  for pattern in "${ERROR_HANDLING_PATTERNS[@]}"; do
    if grep -q "${pattern}" "${file_path}"; then
      error_handling_score=$((error_handling_score + 1))
      found_patterns+=("${pattern}")
    fi
  done
  
  # Calculate percentage score
  local percentage=$((error_handling_score * 100 / max_score))
  
  # Return result as score,percentage,found_patterns
  echo "${error_handling_score},${percentage},${found_patterns[*]}"
}

# Function to generate recommendations for improving error handling
generate_recommendations() {
  local file_path=$1
  local found_patterns=$2
  local recommendations=()
  
  # Check for basic error handling
  if ! echo "${found_patterns}" | grep -q "set -e"; then
    recommendations+=("Add \`set -e\` at the beginning of the script to exit on error")
  fi
  
  if ! echo "${found_patterns}" | grep -q "set -o pipefail"; then
    recommendations+=("Add \`set -o pipefail\` to catch errors in piped commands")
  fi
  
  # Check for error trapping
  if ! echo "${found_patterns}" | grep -q "trap.*ERR"; then
    recommendations+=("Add error trap handler: \`trap 'handle_error \$?' ERR\`")
  fi
  
  # Check for function return codes
  if echo "${found_patterns}" | grep -q "function.*\(\)" && ! echo "${found_patterns}" | grep -q "return [1-9]"; then
    recommendations+=("Ensure functions return appropriate error codes (non-zero) on failure")
  fi
  
  # Check for common error handling framework
  if ! echo "${found_patterns}" | grep -q "setup_error_handling"; then
    recommendations+=("Use the project's common error handling framework by sourcing core utilities and calling \`setup_error_handling\`")
  fi
  
  # Check for conditional handling of command output
  local conditional_count=$(grep -c "if \[ .* \]; then" "${file_path}")
  local command_count=$(grep -c "\$(" "${file_path}")
  
  if ((command_count > 0)) && ((conditional_count == 0)); then
    recommendations+=("Add error checking for command substitutions using conditionals")
  fi
  
  # Return the recommendations as a comma-separated list
  echo "${recommendations[*]}"
}

# Function to find and check all shell scripts
find_and_check_scripts() {
  echo -e "${BLUE}Finding and checking shell scripts for error handling...${NC}"
  
  # Create report header
  {
    echo "# Error Handling Validation Report"
    echo ""
    echo "Report generated on: $(date)"
    echo ""
    echo "## Summary"
    echo ""
    echo "| Score | Category |"
    echo "|-------|----------|"
    echo "| 90-100% | Excellent |"
    echo "| 70-89% | Good |"
    echo "| 50-69% | Adequate |"
    echo "| 30-49% | Needs Improvement |"
    echo "| 0-29% | Poor |"
    echo ""
    echo "## Detailed Results"
    echo ""
  } > "${REPORT_FILE}"
  
  local scripts_found=0
  local excellent_count=0
  local good_count=0
  local adequate_count=0
  local needs_improvement_count=0
  local poor_count=0
  
  # Find all files with shell script extensions or shebangs
  while IFS= read -r -d '' file; do
    if should_exclude "${file}"; then
      continue
    fi
    
    if is_shell_script "${file}"; then
      local relative_path="${file#${PROJECT_ROOT}/}"
      scripts_found=$((scripts_found + 1))
      
      echo -e "${BLUE}Checking script: ${relative_path}${NC}"
      
      # Check error handling
      local check_result=$(check_error_handling "${file}")
      local score=$(echo "${check_result}" | cut -d ',' -f1)
      local percentage=$(echo "${check_result}" | cut -d ',' -f2)
      local found_patterns=$(echo "${check_result}" | cut -d ',' -f3-)
      
      # Generate recommendations
      local recommendations=$(generate_recommendations "${file}" "${found_patterns}")
      
      # Determine result category
      local category=""
      if ((percentage >= 90)); then
        category="Excellent"
        excellent_count=$((excellent_count + 1))
        echo -e "${GREEN}${relative_path}: ${percentage}% - ${category}${NC}"
      elif ((percentage >= 70)); then
        category="Good"
        good_count=$((good_count + 1))
        echo -e "${GREEN}${relative_path}: ${percentage}% - ${category}${NC}"
      elif ((percentage >= 50)); then
        category="Adequate"
        adequate_count=$((adequate_count + 1))
        echo -e "${YELLOW}${relative_path}: ${percentage}% - ${category}${NC}"
      elif ((percentage >= 30)); then
        category="Needs Improvement"
        needs_improvement_count=$((needs_improvement_count + 1))
        echo -e "${RED}${relative_path}: ${percentage}% - ${category}${NC}"
      else
        category="Poor"
        poor_count=$((poor_count + 1))
        echo -e "${RED}${relative_path}: ${percentage}% - ${category}${NC}"
      fi
      
      # Add to report
      {
        echo "### ${relative_path}"
        echo ""
        echo "- **Score**: ${percentage}%"
        echo "- **Category**: ${category}"
        echo "- **Error Handling Patterns Found**: ${score}/${#ERROR_HANDLING_PATTERNS[@]}"
        echo ""
        
        if [ -n "${recommendations}" ]; then
          echo "#### Recommendations"
          echo ""
          IFS=',' read -ra RECOMMENDATION_ARRAY <<< "${recommendations}"
          for rec in "${RECOMMENDATION_ARRAY[@]}"; do
            echo "- ${rec}"
          done
          echo ""
        fi
        
        echo "---"
        echo ""
      } >> "${REPORT_FILE}"
    fi
  done < <(find "${PROJECT_ROOT}" -type f -print0)
  
  # Generate summary statistics
  {
    echo "## Summary Statistics"
    echo ""
    echo "Total scripts analyzed: ${scripts_found}"
    echo ""
    echo "| Category | Count | Percentage |"
    echo "|----------|-------|------------|"
    echo "| Excellent | ${excellent_count} | $(( excellent_count * 100 / scripts_found ))% |"
    echo "| Good | ${good_count} | $(( good_count * 100 / scripts_found ))% |"
    echo "| Adequate | ${adequate_count} | $(( adequate_count * 100 / scripts_found ))% |"
    echo "| Needs Improvement | ${needs_improvement_count} | $(( needs_improvement_count * 100 / scripts_found ))% |"
    echo "| Poor | ${poor_count} | $(( poor_count * 100 / scripts_found ))% |"
  } >> "${REPORT_FILE}"
  
  echo -e "${GREEN}Analyzed ${scripts_found} shell scripts.${NC}"
  echo -e "${GREEN}Report saved to: ${REPORT_FILE}${NC}"
}

# Main function
main() {
  echo -e "${BLUE}Error Handling Validation${NC}"
  echo -e "${BLUE}=========================${NC}"
  
  find_and_check_scripts
  
  echo -e "${GREEN}Validation complete.${NC}"
}

# Run main function
main "$@" 