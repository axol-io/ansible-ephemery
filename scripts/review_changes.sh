#!/bin/bash
#
# Script to help review changes made by the standardization scripts

echo "Reviewing changes made by standardization scripts..."

# Check if git is available
if ! command -v git &> /dev/null; then
    echo "Error: git is not installed. Please install git to review changes."
    exit 1
fi

# Check if this is a git repository
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: Not a git repository. Please run this script from the root of your git repository."
    exit 1
fi

# Function to check for specific types of changes
check_changes() {
    local pattern=$1
    local description=$2

    echo "Checking for $description..."
    git diff --name-only | grep -E "$pattern" | while read file; do
        echo "  - $file"
    done
}

# Check for renamed files
echo "Checking for renamed files..."
git status -s | grep "^R" | while read change; do
    echo "  $change"
done

# Check for specific types of changes
check_changes "\.ya?ml$" "YAML file changes"
check_changes "tasks/" "Task file changes"
check_changes "molecule/" "Molecule file changes"
check_changes "\.sh$" "Script file changes"
check_changes "README\.md" "README changes"
check_changes "docs/" "Documentation changes"

# Summarize changes by type
echo ""
echo "Summary of changes by type:"
echo "  YAML files renamed/modified: $(git diff --name-only | grep -E "\.ya?ml$" | wc -l | tr -d ' ')"
echo "  Task files renamed/modified: $(git diff --name-only | grep -E "tasks/" | wc -l | tr -d ' ')"
echo "  Molecule files renamed/modified: $(git diff --name-only | grep -E "molecule/" | wc -l | tr -d ' ')"
echo "  Scripts renamed/modified: $(git diff --name-only | grep -E "\.sh$" | wc -l | tr -d ' ')"
echo "  Documentation files renamed/modified: $(git diff --name-only | grep -E "README\.md|docs/" | wc -l | tr -d ' ')"
echo ""

# Check for important files that might be accidentally removed
important_files=("main.yaml" "requirements.yaml" "requirements.txt" "requirements-dev.txt")
for file in "${important_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "WARNING: Important file $file is missing. This may be intentional if renamed to .yaml, but please verify."
    fi
done

echo ""
echo "For a detailed review of the changes to a specific file, use:"
echo "  git diff <filename>"
echo ""
echo "To review all changes with context:"
echo "  git diff"
echo ""
echo "Review complete. Verify the changes before committing."
