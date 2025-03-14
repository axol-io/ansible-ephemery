#!/bin/bash

# analyze_ansible_output.sh
# A utility to parse and analyze Ansible output for performance and error patterns
# Usage: cat ansible_output.log | ./scripts/analyze_ansible_output.sh
#   or:  ./scripts/analyze_ansible_output.sh ansible_output.log

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check if a file was provided as an argument
if [ $# -gt 0 ]; then
  if [ ! -f "$1" ]; then
    echo "Error: File '$1' not found"
    exit 1
  fi
  INPUT_FILE="$1"
else
  # Check if we're getting input from stdin
  if [ -t 0 ]; then
    echo "Error: No input provided"
    echo "Usage: cat ansible_output.log | $0"
    echo "   or: $0 ansible_output.log"
    exit 1
  fi
  INPUT_FILE="-" # Use stdin
fi

# Temporary files
TASK_TIMES=$(mktemp)
ERROR_FILE=$(mktemp)
WARNING_FILE=$(mktemp)
CHANGED_FILE=$(mktemp)
RECAP_FILE=$(mktemp)

# Clean up temporary files on exit
trap 'rm -f "$TASK_TIMES" "$ERROR_FILE" "$WARNING_FILE" "$CHANGED_FILE" "$RECAP_FILE"' EXIT

echo -e "${BOLD}Ansible Output Analysis${NC}"
echo "Analyzing Ansible output..."

# Extract task times, errors, warnings, and changed tasks
START_TIME=""
CURRENT_TASK=""

# Process the input, line by line
cat "$INPUT_FILE" | while IFS= read -r line; do
  # Extract task name and start time
  if echo "$line" | grep -q "TASK \["; then
    CURRENT_TASK=$(echo "$line" | sed -E 's/TASK \[(.*)\] \*+/\1/')
    START_TIME=$(date +%s%3N) # Milliseconds since epoch
  
  # Extract task completion and calculate time
  elif echo "$line" | grep -q "ok: \[" && [ -n "$CURRENT_TASK" ] && [ -n "$START_TIME" ]; then
    END_TIME=$(date +%s%3N)
    DURATION=$((END_TIME - START_TIME))
    echo "$DURATION $CURRENT_TASK" >> "$TASK_TIMES"
    CURRENT_TASK=""
    START_TIME=""
  
  # Extract changed tasks
  elif echo "$line" | grep -q "changed: \["; then
    echo "$line" >> "$CHANGED_FILE"
  
  # Extract errors
  elif echo "$line" | grep -q -i "fatal\|error\|failed"; then
    echo "$line" >> "$ERROR_FILE"
  
  # Extract warnings
  elif echo "$line" | grep -q -i "warn\|deprecation"; then
    echo "$line" >> "$WARNING_FILE"
  
  # Extract play recap
  elif echo "$line" | grep -q "PLAY RECAP"; then
    # Capture the recap and the next few lines
    echo "$line" >> "$RECAP_FILE"
    for i in {1..10}; do
      read -r recap_line
      echo "$recap_line" >> "$RECAP_FILE"
      # Stop if we've reached the end of the recap
      if [ -z "$recap_line" ]; then
        break
      fi
    done
  fi
done

# Calculate statistics
TOTAL_TASKS=$(wc -l < "$TASK_TIMES")
if [ "$TOTAL_TASKS" -gt 0 ]; then
  # Sort tasks by duration (longest first)
  sort -nr "$TASK_TIMES" -o "$TASK_TIMES"
  
  # Get top 10 longest tasks
  TOP_TASKS=$(head -n 10 "$TASK_TIMES")
  
  # Calculate average task time
  TOTAL_TIME=$(awk '{sum += $1} END {print sum}' "$TASK_TIMES")
  AVG_TIME=$((TOTAL_TIME / TOTAL_TASKS))
  
  # Calculate total execution time
  TOTAL_EXEC_TIME=$((TOTAL_TIME / 1000)) # Convert to seconds
fi

# Count errors and warnings
ERROR_COUNT=$(wc -l < "$ERROR_FILE")
WARNING_COUNT=$(wc -l < "$WARNING_FILE")
CHANGED_COUNT=$(wc -l < "$CHANGED_FILE")

# Display results
echo ""
echo -e "${BOLD}Summary:${NC}"
echo -e "Total tasks: ${BLUE}$TOTAL_TASKS${NC}"
if [ "$TOTAL_TASKS" -gt 0 ]; then
  echo -e "Average task time: ${BLUE}$AVG_TIME ms${NC}"
  echo -e "Total execution time: ${BLUE}$TOTAL_EXEC_TIME seconds${NC}"
fi
echo -e "Errors: ${RED}$ERROR_COUNT${NC}"
echo -e "Warnings: ${YELLOW}$WARNING_COUNT${NC}"
echo -e "Changed tasks: ${CYAN}$CHANGED_COUNT${NC}"

# Display play recap
echo ""
echo -e "${BOLD}Play Recap:${NC}"
if [ -s "$RECAP_FILE" ]; then
  cat "$RECAP_FILE" | while IFS= read -r line; do
    if echo "$line" | grep -q "failed=0"; then
      echo -e "${GREEN}$line${NC}"
    elif echo "$line" | grep -q "failed=[1-9]"; then
      echo -e "${RED}$line${NC}"
    else
      echo "$line"
    fi
  done
else
  echo "No play recap found in the output"
fi

# Display top 10 longest tasks
if [ "$TOTAL_TASKS" -gt 0 ]; then
  echo ""
  echo -e "${BOLD}Top 10 Longest Tasks:${NC}"
  echo "$TOP_TASKS" | while read -r time task; do
    echo -e "${BLUE}$(printf "%6d" "$time") ms${NC}: $task"
  done
fi

# Display errors
if [ "$ERROR_COUNT" -gt 0 ]; then
  echo ""
  echo -e "${BOLD}${RED}Errors:${NC}"
  cat "$ERROR_FILE" | head -n 20 | while IFS= read -r line; do
    echo -e "${RED}$line${NC}"
  done
  
  if [ "$ERROR_COUNT" -gt 20 ]; then
    echo -e "${YELLOW}... and $((ERROR_COUNT - 20)) more errors${NC}"
  fi
fi

# Display warnings
if [ "$WARNING_COUNT" -gt 0 ]; then
  echo ""
  echo -e "${BOLD}${YELLOW}Warnings:${NC}"
  cat "$WARNING_FILE" | head -n 10 | while IFS= read -r line; do
    echo -e "${YELLOW}$line${NC}"
  done
  
  if [ "$WARNING_COUNT" -gt 10 ]; then
    echo -e "${YELLOW}... and $((WARNING_COUNT - 10)) more warnings${NC}"
  fi
fi

# Check for common patterns and suggest improvements
echo ""
echo -e "${BOLD}Suggestions:${NC}"

# Check for many changed tasks
if [ "$CHANGED_COUNT" -gt 20 ]; then
  echo -e "${YELLOW}• High number of changed tasks ($CHANGED_COUNT). Consider using --check mode first to review changes.${NC}"
fi

# Check for many errors
if [ "$ERROR_COUNT" -gt 5 ]; then
  echo -e "${RED}• High number of errors ($ERROR_COUNT). Review error messages and fix issues.${NC}"
fi

# Check for long-running tasks
LONG_TASK_COUNT=$(awk '$1 > 5000 {count++} END {print count}' "$TASK_TIMES")
if [ "$LONG_TASK_COUNT" -gt 5 ]; then
  echo -e "${YELLOW}• $LONG_TASK_COUNT tasks took more than 5 seconds. Consider optimizing these tasks or using async mode.${NC}"
fi

# Check for common Ephemery-specific issues
if grep -q "connection timed out" "$ERROR_FILE"; then
  echo -e "${RED}• Connection timeouts detected. Check network connectivity and firewall settings.${NC}"
fi

if grep -q "container .* not found" "$ERROR_FILE"; then
  echo -e "${RED}• Container not found errors detected. Ensure Docker is running and containers are properly configured.${NC}"
fi

if grep -q "permission denied" "$ERROR_FILE"; then
  echo -e "${RED}• Permission denied errors detected. Check file permissions and user privileges.${NC}"
fi

if grep -q "No space left on device" "$ERROR_FILE"; then
  echo -e "${RED}• No space left on device errors detected. Free up disk space or increase storage allocation.${NC}"
fi

# Output final message
echo ""
echo -e "${BOLD}Analysis complete.${NC}"
echo "For more detailed analysis, consider using the Ansible callback plugins or filtering the original output."
echo "Use ./scripts/run_ansible.sh with appropriate options for better output management." 