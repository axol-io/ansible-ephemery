#!/bin/bash
# analyze_verify_files.sh - Analyze verify.yaml files to identify duplication

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
MOLECULE_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
REPORT_FILE="$MOLECULE_DIR/verify_analysis_report.txt"

echo "Analyzing verify.yaml files for possible consolidation..."
echo "Report will be saved to: $REPORT_FILE"

# Start with a fresh report
echo "Molecule Verify.yaml Consolidation Report" > "$REPORT_FILE"
echo "=======================================" >> "$REPORT_FILE"
echo "Generated on: $(date)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Create a temporary directory for task extraction
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Find all verify.yaml files
find "$MOLECULE_DIR" -type f -name "verify.yaml" | sort | while read -r file; do
  # Skip empty files and the shared directory
  if [[ ! -s "$file" ]] || [[ "$file" == *"/shared/"* ]]; then
    continue
  fi

  scenario_dir=$(dirname "$file")
  scenario_name=$(basename "$scenario_dir")
  scenario_type=$(basename "$(dirname "$scenario_dir")")

  # Extract task names to compare
  grep -A 1 "name:" "$file" | grep -v "\-\-" > "$TEMP_DIR/${scenario_type}_${scenario_name}_tasks.txt"

  echo "Analyzing: $file" >> "$REPORT_FILE"
  echo "---------------------------------------------------------" >> "$REPORT_FILE"

  # Count lines and tasks
  line_count=$(wc -l < "$file")
  task_count=$(grep -c "- name:" "$file" || echo "0")
  echo "Line count: $line_count" >> "$REPORT_FILE"
  echo "Task count: $task_count" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
done

# Identify similar verify.yaml files based on task names
echo "Similarity Analysis" >> "$REPORT_FILE"
echo "===================" >> "$REPORT_FILE"

# Group by scenario type
for type_dir in "$MOLECULE_DIR"/*/ ; do
  type_name=$(basename "$type_dir")

  # Skip shared and types with no verify.yaml files
  if [[ "$type_name" == "shared" ]] || ! find "$type_dir" -name "verify.yaml" -type f | grep -q .; then
    continue
  fi

  echo "" >> "$REPORT_FILE"
  echo "Scenario Type: $type_name" >> "$REPORT_FILE"
  echo "---------------------" >> "$REPORT_FILE"

  # Compare task files within the same type
  task_files=$(find "$TEMP_DIR" -name "${type_name}_*_tasks.txt")
  if [ -z "$task_files" ]; then
    echo "No verify.yaml files found for this type." >> "$REPORT_FILE"
    continue
  fi

  # For each task file, compare with others of the same type
  for task_file in $task_files; do
    base_name=$(basename "$task_file" | sed "s/${type_name}_//" | sed "s/_tasks.txt//")
    echo "Scenario: $base_name" >> "$REPORT_FILE"

    for compare_file in $task_files; do
      compare_name=$(basename "$compare_file" | sed "s/${type_name}_//" | sed "s/_tasks.txt//")

      # Skip comparing with itself
      if [ "$task_file" = "$compare_file" ]; then
        continue
      fi

      # Compare task files
      common_tasks=$(comm -12 <(sort "$task_file") <(sort "$compare_file") | wc -l)
      total_tasks=$(cat "$task_file" | wc -l)

      if [ "$total_tasks" -gt 0 ]; then
        similarity=$((common_tasks * 100 / total_tasks))

        if [ "$similarity" -gt 50 ]; then
          echo "  - $similarity% similar to $compare_name" >> "$REPORT_FILE"
        fi
      fi
    done

    echo "" >> "$REPORT_FILE"
  done
done

echo "" >> "$REPORT_FILE"
echo "Recommendations" >> "$REPORT_FILE"
echo "==============" >> "$REPORT_FILE"
echo "Based on the similarity analysis:" >> "$REPORT_FILE"
echo "1. Create shared/verify_templates for each scenario type (clients, monitoring, etc.)" >> "$REPORT_FILE"
echo "2. Extract common tests into these template files" >> "$REPORT_FILE"
echo "3. Allow individual scenarios to import the template and add specific tests" >> "$REPORT_FILE"
echo "4. Consider parameterizing tests that differ only in variable values" >> "$REPORT_FILE"

echo "Analysis complete. Report saved to: $REPORT_FILE"
echo "Review the report and manually consolidate verify.yaml files as recommended."
