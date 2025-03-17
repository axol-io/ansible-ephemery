#!/bin/bash
#
# This script analyzes and optimizes Ansible collections directories
# 
# It performs several operations:
# 1. Analyzes existing Ansible collections and their structure
# 2. Compares collections across different directories if multiple exist
# 3. Suggests optimization strategies to reduce storage space
# 4. Creates an implementation script that can be run to apply the optimizations
#
# Expected storage savings: ~20MB by removing tests, docs, and examples
#

set -e

# Print header
echo "====================================================="
echo "       Analyzing Ansible Collections                  "
echo "====================================================="

# Define collections directories
COLLECTIONS_DIR="collections/ansible_collections"
ANSIBLE_COLLECTIONS_DIR=".ansible/collections"

# Create output directory
OUTPUT_DIR="ansible_collections_analysis_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"
echo "Created output directory: $OUTPUT_DIR"

# Function to analyze a collection directory
# Parameters:
#   $1: Directory to analyze
#   $2: Output file path
analyze_collection_dir() {
    local dir="$1"
    local output_file="$2"
    
    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist"
        return 1
    fi
    
    echo "Analyzing collections in $dir..."
    
    # Create file
    cat > "$output_file" << EOF
# Ansible Collections Analysis: $dir
Generated on $(date)

This report analyzes the Ansible collections in $dir.

## Overview

EOF
    
    # Count collections and namespaces
    local namespace_count=$(find "$dir" -maxdepth 1 -type d | wc -l)
    namespace_count=$((namespace_count - 1))  # Subtract 1 for the parent directory
    
    local collection_count=$(find "$dir" -mindepth 2 -maxdepth 2 -type d | wc -l)
    
    echo "- **Namespaces**: $namespace_count" >> "$output_file"
    echo "- **Collections**: $collection_count" >> "$output_file"
    echo "" >> "$output_file"
    
    # List all collections
    echo "## Collections by Namespace" >> "$output_file"
    echo "" >> "$output_file"
    
    # Find namespaces
    for namespace in $(find "$dir" -maxdepth 1 -type d -not -path "$dir" | sort); do
        namespace_name=$(basename "$namespace")
        echo "### $namespace_name" >> "$output_file"
        echo "" >> "$output_file"
        
        # List collections in namespace
        for collection in $(find "$namespace" -maxdepth 1 -type d -not -path "$namespace" | sort); do
            collection_name=$(basename "$collection")
            collection_size=$(du -sh "$collection" | awk '{print $1}')
            
            echo "- **$collection_name** ($collection_size)" >> "$output_file"
            
            # Check for galaxy.yml to get version
            if [ -f "$collection/galaxy.yml" ]; then
                version=$(grep -E "^version:" "$collection/galaxy.yml" | awk '{print $2}' | tr -d "'\"")
                echo "  - Version: $version" >> "$output_file"
            fi
            
            # Count number of roles and plugins
            roles_count=$(find "$collection/roles" -maxdepth 1 -type d 2>/dev/null | wc -l)
            roles_count=$((roles_count - 1 > 0 ? roles_count - 1 : 0))
            
            plugins_count=$(find "$collection/plugins" -type f -name "*.py" 2>/dev/null | wc -l)
            
            echo "  - Roles: $roles_count" >> "$output_file"
            echo "  - Plugins: $plugins_count" >> "$output_file"
        done
        
        echo "" >> "$output_file"
    done
    
    # Calculate total size
    local total_size=$(du -sh "$dir" | awk '{print $1}')
    echo "## Size Analysis" >> "$output_file"
    echo "" >> "$output_file"
    echo "- **Total Size**: $total_size" >> "$output_file"
    echo "" >> "$output_file"
    
    # List largest collections
    echo "### Largest Collections" >> "$output_file"
    echo "" >> "$output_file"
    echo "| Namespace | Collection | Size |" >> "$output_file"
    echo "|-----------|------------|------|" >> "$output_file"
    
    find "$dir" -mindepth 2 -maxdepth 2 -type d | sort | while read -r collection; do
        namespace=$(basename "$(dirname "$collection")")
        collection_name=$(basename "$collection")
        collection_size=$(du -sh "$collection" | awk '{print $1}')
        
        echo "| $namespace | $collection_name | $collection_size |" >> "$output_file"
    done | sort -k3 -h -r | head -10 >> "$output_file"
    
    echo "" >> "$output_file"
    
    echo "Analysis completed for $dir"
    echo "Report saved to $output_file"
}

# Function to compare collections directories
# Parameters:
#   $1: First directory to compare
#   $2: Second directory to compare
#   $3: Output file path
compare_collections() {
    local dir1="$1"
    local dir2="$2"
    local output_file="$3"
    
    if [ ! -d "$dir1" ] || [ ! -d "$dir2" ]; then
        echo "One or both directories do not exist"
        if [ ! -d "$dir1" ]; then
            echo "$dir1 does not exist"
        fi
        if [ ! -d "$dir2" ]; then
            echo "$dir2 does not exist"
        fi
        return 1
    fi
    
    echo "Comparing collections in $dir1 and $dir2..."
    
    # Create file
    cat > "$output_file" << EOF
# Ansible Collections Comparison
Generated on $(date)

This report compares the Ansible collections in:
- $dir1
- $dir2

## Collections Comparison

EOF
    
    # Create lists of collections
    local collections1=$(find "$dir1" -mindepth 2 -maxdepth 2 -type d | sort)
    local collections2=$(find "$dir2" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort)
    
    # Create temp files
    local temp_file1=$(mktemp)
    local temp_file2=$(mktemp)
    
    # Process collections into namespace.collection format
    if [ -n "$collections1" ]; then
        echo "$collections1" | while read -r collection; do
            namespace=$(basename "$(dirname "$collection")")
            collection_name=$(basename "$collection")
            echo "$namespace.$collection_name"
        done > "$temp_file1"
    else
        touch "$temp_file1"
    fi
    
    if [ -n "$collections2" ]; then
        echo "$collections2" | while read -r collection; do
            namespace=$(basename "$(dirname "$collection")")
            collection_name=$(basename "$collection")
            echo "$namespace.$collection_name"
        done > "$temp_file2"
    else
        touch "$temp_file2"
    fi
    
    # Find unique collections in dir1
    echo "### Collections unique to $dir1" >> "$output_file"
    echo "" >> "$output_file"
    comm -23 "$temp_file1" "$temp_file2" | while read -r collection; do
        echo "- $collection" >> "$output_file"
    done
    echo "" >> "$output_file"
    
    # Find unique collections in dir2
    echo "### Collections unique to $dir2" >> "$output_file"
    echo "" >> "$output_file"
    comm -13 "$temp_file1" "$temp_file2" | while read -r collection; do
        echo "- $collection" >> "$output_file"
    done
    echo "" >> "$output_file"
    
    # Find common collections
    echo "### Collections common to both directories" >> "$output_file"
    echo "" >> "$output_file"
    comm -12 "$temp_file1" "$temp_file2" | while read -r collection; do
        echo "- $collection" >> "$output_file"
    done
    echo "" >> "$output_file"
    
    # Clean up temp files
    rm -f "$temp_file1" "$temp_file2"
    
    echo "Comparison completed"
    echo "Report saved to $output_file"
}

# Function to suggest optimizations for collections
# Parameters:
#   $1: Output file path
suggest_optimizations() {
    local output_file="$1"
    
    echo "Generating optimization suggestions..."
    
    # Create file
    cat > "$output_file" << EOF
# Ansible Collections Optimization Suggestions
Generated on $(date)

This report provides suggestions for optimizing the Ansible collections.

## Recommendations

EOF
    
    # Check if both directories exist
    if [ -d "$COLLECTIONS_DIR" ] && [ -d "$ANSIBLE_COLLECTIONS_DIR" ]; then
        echo "### Multiple Collection Directories" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Observation**: Two collection directories were found:" >> "$output_file"
        echo "- $COLLECTIONS_DIR" >> "$output_file"
        echo "- $ANSIBLE_COLLECTIONS_DIR" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Recommendation**: Standardize on a single collection directory, preferably $COLLECTIONS_DIR, as it is more explicitly named and appears to be the main collection location." >> "$output_file"
        echo "" >> "$output_file"
        echo "**Implementation**:" >> "$output_file"
        echo "1. Move any unique collections from $ANSIBLE_COLLECTIONS_DIR to $COLLECTIONS_DIR" >> "$output_file"
        echo "2. Update ansible.cfg to specify collections_paths = ./collections" >> "$output_file"
        echo "3. Remove the $ANSIBLE_COLLECTIONS_DIR directory" >> "$output_file"
        echo "" >> "$output_file"
    elif [ -d "$COLLECTIONS_DIR" ]; then
        echo "### Collection Directory" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Observation**: Only one collection directory was found: $COLLECTIONS_DIR" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Recommendation**: This is already optimal. Ensure ansible.cfg properly references this directory." >> "$output_file"
        echo "" >> "$output_file"
    elif [ -d "$ANSIBLE_COLLECTIONS_DIR" ]; then
        echo "### Collection Directory" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Observation**: Only one collection directory was found: $ANSIBLE_COLLECTIONS_DIR" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Recommendation**: Consider renaming to $COLLECTIONS_DIR for better organization and clarity." >> "$output_file"
        echo "" >> "$output_file"
    else
        echo "### No Collection Directories" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Observation**: No collection directories were found." >> "$output_file"
        echo "" >> "$output_file"
        echo "**Recommendation**: If Ansible collections are needed, create $COLLECTIONS_DIR directory." >> "$output_file"
        echo "" >> "$output_file"
    fi
    
    # Check ansible.cfg
    if [ -f "ansible.cfg" ]; then
        collections_path=$(grep -E "^collections_paths\s*=" ansible.cfg)
        if [ -z "$collections_path" ]; then
            echo "### Missing Collections Path in ansible.cfg" >> "$output_file"
            echo "" >> "$output_file"
            echo "**Observation**: ansible.cfg does not specify a collections_paths setting." >> "$output_file"
            echo "" >> "$output_file"
            echo "**Recommendation**: Add the following to ansible.cfg:" >> "$output_file"
            echo '```ini' >> "$output_file"
            echo "collections_paths = ./collections" >> "$output_file"
            echo '```' >> "$output_file"
            echo "" >> "$output_file"
        else
            echo "### Collections Path in ansible.cfg" >> "$output_file"
            echo "" >> "$output_file"
            echo "**Observation**: ansible.cfg specifies: $collections_path" >> "$output_file"
            echo "" >> "$output_file"
            
            if [[ "$collections_path" == *"./collections"* ]]; then
                echo "**Recommendation**: This is already optimal." >> "$output_file"
            else
                echo "**Recommendation**: Consider updating to use the standard path:" >> "$output_file"
                echo '```ini' >> "$output_file"
                echo "collections_paths = ./collections" >> "$output_file"
                echo '```' >> "$output_file"
            fi
            echo "" >> "$output_file"
        fi
    else
        echo "### No ansible.cfg Found" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Observation**: No ansible.cfg file was found." >> "$output_file"
        echo "" >> "$output_file"
        echo "**Recommendation**: Create an ansible.cfg file with proper collections_paths setting:" >> "$output_file"
        echo '```ini' >> "$output_file"
        echo "[defaults]" >> "$output_file"
        echo "collections_paths = ./collections" >> "$output_file"
        echo '```' >> "$output_file"
        echo "" >> "$output_file"
    fi
    
    # Analyze collection content if the main directory exists
    if [ -d "$COLLECTIONS_DIR" ]; then
        total_size=$(du -sh "$COLLECTIONS_DIR" | awk '{print $1}')
        
        echo "### Collection Size Optimization" >> "$output_file"
        echo "" >> "$output_file"
        echo "**Observation**: The collections directory ($COLLECTIONS_DIR) uses $total_size of disk space." >> "$output_file"
        echo "" >> "$output_file"
        echo "**Recommendations** for reducing size:" >> "$output_file"
        echo "" >> "$output_file"
        echo "1. **Remove development files**: Delete tests, documentation, and examples from collections:" >> "$output_file"
        echo '   ```bash' >> "$output_file"
        echo "   find $COLLECTIONS_DIR -type d -name 'tests' -o -name 'docs' -o -name 'examples' | xargs rm -rf" >> "$output_file"
        echo '   ```' >> "$output_file"
        echo "" >> "$output_file"
        echo "2. **Remove unused collections**: Based on your playbooks, identify and remove unused collections." >> "$output_file"
        echo "" >> "$output_file"
        echo "3. **Use requirements.yml**: Instead of committing collections to the repository, consider using a requirements.yml file to manage collections:" >> "$output_file"
        echo '   ```yaml' >> "$output_file"
        echo "   collections:" >> "$output_file"
        echo "     - name: community.general" >> "$output_file"
        echo "     - name: ansible.posix" >> "$output_file"
        echo '   ```' >> "$output_file"
        echo "   And install with: ansible-galaxy collection install -r requirements.yml" >> "$output_file"
        echo "" >> "$output_file"
    fi
    
    echo "Suggestions generated"
    echo "Report saved to $output_file"
}

# Function to create a script for implementing recommendations
# Parameters:
#   $1: Output file path for the implementation script
create_implementation_script() {
    local output_file="$1"
    
    echo "Creating implementation script..."
    
    # Create the shell script with EOF heredoc
    # This implementation script will:
    # 1. Back up existing collections
    # 2. Merge collections from different directories
    # 3. Update ansible.cfg settings
    # 4. Optimize collection size by removing unnecessary files
    # 5. Create a requirements.yml file for managing collections
    cat > "$output_file" << 'EOF'
#!/bin/bash
#
# Script to implement Ansible collections optimization
#

set -e

# Print header
echo "====================================================="
echo "     Implementing Ansible Collections Optimization    "
echo "====================================================="

# Define directories
COLLECTIONS_DIR="collections/ansible_collections"
ANSIBLE_COLLECTIONS_DIR=".ansible/collections"
BACKUP_DIR="ansible_collections_backup_$(date +%Y%m%d_%H%M%S)"

# Create backup directory
mkdir -p "$BACKUP_DIR"
echo "Created backup directory: $BACKUP_DIR"

# Function to backup collections
backup_collections() {
    echo "Creating backups of collections directories..."
    
    if [ -d "$COLLECTIONS_DIR" ]; then
        echo "Backing up $COLLECTIONS_DIR"
        mkdir -p "$BACKUP_DIR/$(dirname "$COLLECTIONS_DIR")"
        cp -r "$COLLECTIONS_DIR" "$BACKUP_DIR/$(dirname "$COLLECTIONS_DIR")/"
    fi
    
    if [ -d "$ANSIBLE_COLLECTIONS_DIR" ]; then
        echo "Backing up $ANSIBLE_COLLECTIONS_DIR"
        mkdir -p "$BACKUP_DIR/$(dirname "$ANSIBLE_COLLECTIONS_DIR")"
        cp -r "$ANSIBLE_COLLECTIONS_DIR" "$BACKUP_DIR/$(dirname "$ANSIBLE_COLLECTIONS_DIR")/"
    fi
    
    if [ -f "ansible.cfg" ]; then
        echo "Backing up ansible.cfg"
        cp ansible.cfg "$BACKUP_DIR/"
    fi
    
    echo "Backups created in $BACKUP_DIR"
}

# Function to merge collections directories
merge_collections() {
    echo "Checking if collections directories need to be merged..."
    
    # If both directories exist, merge them
    if [ -d "$COLLECTIONS_DIR" ] && [ -d "$ANSIBLE_COLLECTIONS_DIR" ]; then
        echo "Both collections directories exist, merging..."
        
        # Create target directory if it doesn't exist
        mkdir -p "$COLLECTIONS_DIR"
        
        # Find all namespaces in .ansible/collections
        for namespace_dir in "$ANSIBLE_COLLECTIONS_DIR"/*; do
            if [ -d "$namespace_dir" ]; then
                namespace=$(basename "$namespace_dir")
                echo "Processing namespace: $namespace"
                
                # Create namespace directory in collections if it doesn't exist
                mkdir -p "$COLLECTIONS_DIR/$namespace"
                
                # Copy each collection
                for collection_dir in "$namespace_dir"/*; do
                    if [ -d "$collection_dir" ]; then
                        collection=$(basename "$collection_dir")
                        echo "  Processing collection: $collection"
                        
                        # Check if collection already exists in target
                        if [ -d "$COLLECTIONS_DIR/$namespace/$collection" ]; then
                            echo "  Collection already exists in target, checking versions..."
                            
                            # Check versions if galaxy.yml exists in both
                            if [ -f "$collection_dir/galaxy.yml" ] && [ -f "$COLLECTIONS_DIR/$namespace/$collection/galaxy.yml" ]; then
                                version1=$(grep -E "^version:" "$collection_dir/galaxy.yml" | awk '{print $2}' | tr -d "'\"")
                                version2=$(grep -E "^version:" "$COLLECTIONS_DIR/$namespace/$collection/galaxy.yml" | awk '{print $2}' | tr -d "'\"")
                                
                                if [ -n "$version1" ] && [ -n "$version2" ]; then
                                    # Compare versions (basic string comparison, not semantic)
                                    if [[ "$version1" > "$version2" ]]; then
                                        echo "  Newer version found in .ansible/collections ($version1 > $version2), replacing..."
                                        rm -rf "$COLLECTIONS_DIR/$namespace/$collection"
                                        cp -r "$collection_dir" "$COLLECTIONS_DIR/$namespace/"
                                    else
                                        echo "  Keeping version in collections ($version2 >= $version1)"
                                    fi
                                else
                                    echo "  Could not determine versions, keeping version in collections"
                                fi
                            else
                                echo "  Could not determine versions (missing galaxy.yml), keeping version in collections"
                            fi
                        else
                            echo "  Collection doesn't exist in target, copying..."
                            cp -r "$collection_dir" "$COLLECTIONS_DIR/$namespace/"
                        fi
                    fi
                done
            fi
        done
        
        echo "Collections merged successfully"
    elif [ -d "$ANSIBLE_COLLECTIONS_DIR" ] && [ ! -d "$COLLECTIONS_DIR" ]; then
        echo "Only .ansible/collections exists, moving to collections/ansible_collections..."
        mkdir -p "$(dirname "$COLLECTIONS_DIR")"
        mv "$ANSIBLE_COLLECTIONS_DIR" "$COLLECTIONS_DIR"
        echo "Collections moved successfully"
    else
        echo "No merging needed (either collections directory doesn't exist or only collections/ansible_collections exists)"
    fi
}

# Function to update ansible.cfg
update_ansible_cfg() {
    echo "Checking if ansible.cfg needs to be updated..."
    
    if [ -f "ansible.cfg" ]; then
        # Check if collections_paths is set correctly
        if grep -q "^collections_paths\s*=\s*\./collections" ansible.cfg; then
            echo "ansible.cfg already has correct collections_paths setting"
        else
            # Check if collections_paths exists but with wrong value
            if grep -q "^collections_paths\s*=" ansible.cfg; then
                echo "Updating existing collections_paths setting in ansible.cfg"
                sed -i 's|^collections_paths\s*=.*|collections_paths = ./collections|' ansible.cfg
            else
                # Add collections_paths to [defaults] section
                echo "Adding collections_paths setting to ansible.cfg"
                if grep -q "\[defaults\]" ansible.cfg; then
                    # Add setting under [defaults]
                    sed -i '/\[defaults\]/a collections_paths = ./collections' ansible.cfg
                else
                    # Add [defaults] section and setting
                    echo -e "\n[defaults]\ncollections_paths = ./collections" >> ansible.cfg
                fi
            fi
            echo "ansible.cfg updated successfully"
        fi
    else
        echo "Creating new ansible.cfg file"
        cat > ansible.cfg << 'EOT'
[defaults]
collections_paths = ./collections
EOT
        echo "ansible.cfg created successfully"
    fi
}

# Function to optimize collections size
optimize_collections_size() {
    echo "Optimizing collections size..."
    
    if [ -d "$COLLECTIONS_DIR" ]; then
        echo "Removing development files (tests, docs, examples)..."
        
        # Create a list of directories to remove
        echo "Finding directories to clean up..."
        DIRS_TO_REMOVE=$(find "$COLLECTIONS_DIR" -type d \( -name 'tests' -o -name 'docs' -o -name 'examples' -o -name '.git' -o -name '.github' \))
        
        if [ -n "$DIRS_TO_REMOVE" ]; then
            echo "Found $(echo "$DIRS_TO_REMOVE" | wc -l) directories to remove"
            
            # Ask for confirmation
            echo "The following directories will be removed:"
            echo "$DIRS_TO_REMOVE"
            read -p "Do you want to proceed? (y/n): " CONFIRM
            
            if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
                echo "$DIRS_TO_REMOVE" | xargs rm -rf
                echo "Development files removed successfully"
            else
                echo "Skipping removal of development files"
            fi
        else
            echo "No development files found to remove"
        fi
    else
        echo "Collections directory doesn't exist, skipping optimization"
    fi
}

# Function to create requirements.yml
create_requirements_yml() {
    echo "Creating requirements.yml file..."
    
    if [ -d "$COLLECTIONS_DIR" ]; then
        REQUIREMENTS_FILE="requirements-collections.yml"
        
        # Check if file already exists
        if [ -f "$REQUIREMENTS_FILE" ]; then
            echo "Requirements file already exists: $REQUIREMENTS_FILE"
            read -p "Do you want to overwrite it? (y/n): " CONFIRM
            if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
                echo "Skipping creation of requirements file"
                return
            fi
        fi
        
        echo "Collecting installed collections..."
        
        # Create requirements file
        cat > "$REQUIREMENTS_FILE" << 'EOT'
---
collections:
EOT
        
        # Find all collections and add to file
        find "$COLLECTIONS_DIR" -mindepth 2 -maxdepth 2 -type d | sort | while read -r collection_dir; do
            namespace=$(basename "$(dirname "$collection_dir")")
            collection=$(basename "$collection_dir")
            
            # Try to get version if galaxy.yml exists
            if [ -f "$collection_dir/galaxy.yml" ]; then
                version=$(grep -E "^version:" "$collection_dir/galaxy.yml" | awk '{print $2}' | tr -d "'\"")
                if [ -n "$version" ]; then
                    echo "  - name: $namespace.$collection" >> "$REQUIREMENTS_FILE"
                    echo "    version: $version" >> "$REQUIREMENTS_FILE"
                else
                    echo "  - name: $namespace.$collection" >> "$REQUIREMENTS_FILE"
                fi
            else
                echo "  - name: $namespace.$collection" >> "$REQUIREMENTS_FILE"
            fi
        done
        
        echo "Requirements file created: $REQUIREMENTS_FILE"
        echo
        echo "To install collections from this file, run:"
        echo "  ansible-galaxy collection install -r $REQUIREMENTS_FILE"
    else
        echo "Collections directory doesn't exist, skipping creation of requirements file"
    fi
}

# Function to clean up
cleanup() {
    echo "Cleaning up..."
    
    # Check if .ansible directory is empty after moving collections
    if [ -d ".ansible" ]; then
        if [ ! -d "$ANSIBLE_COLLECTIONS_DIR" ] || [ -z "$(ls -A "$ANSIBLE_COLLECTIONS_DIR" 2>/dev/null)" ]; then
            # Check if .ansible is empty or only has empty subdirectories
            if [ -z "$(find .ansible -type f 2>/dev/null)" ]; then
                echo ".ansible directory is empty, removing..."
                rm -rf .ansible
                echo ".ansible directory removed"
            else
                echo ".ansible directory contains other files, keeping it"
            fi
        else
            echo ".ansible/collections still contains files, keeping it"
        fi
    fi
    
    echo "Cleanup completed"
}

# Main execution
echo "This script will optimize your Ansible collections."
echo "It will:"
echo "1. Create backups of your collections directories"
echo "2. Merge collections from .ansible/collections to collections/ansible_collections (if both exist)"
echo "3. Update ansible.cfg to use the standard collections path"
echo "4. Optionally remove development files to reduce size"
echo "5. Create a requirements.yml file for future use"
echo

read -p "Do you want to proceed? (y/n): " PROCEED
if [[ "$PROCEED" != "y" && "$PROCEED" != "Y" ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Run the functions
backup_collections
merge_collections
update_ansible_cfg
optimize_collections_size
create_requirements_yml
cleanup

echo
echo "Ansible collections optimization completed successfully."
echo "Backups are available in: $BACKUP_DIR"
EOF
    
    # Make script executable
    chmod +x "$output_file"
    
    echo "Implementation script created at $output_file"
}

# Run the analysis
if [ -d "$COLLECTIONS_DIR" ]; then
    analyze_collection_dir "$COLLECTIONS_DIR" "$OUTPUT_DIR/collections_analysis.md"
fi

if [ -d "$ANSIBLE_COLLECTIONS_DIR" ]; then
    analyze_collection_dir "$ANSIBLE_COLLECTIONS_DIR" "$OUTPUT_DIR/ansible_collections_analysis.md"
fi

if [ -d "$COLLECTIONS_DIR" ] && [ -d "$ANSIBLE_COLLECTIONS_DIR" ]; then
    compare_collections "$COLLECTIONS_DIR" "$ANSIBLE_COLLECTIONS_DIR" "$OUTPUT_DIR/collections_comparison.md"
fi

# Generate recommendations
suggest_optimizations "$OUTPUT_DIR/optimization_recommendations.md"

# Create implementation script
create_implementation_script "$OUTPUT_DIR/optimize_ansible_collections.sh"

echo 
echo "Ansible collections analysis complete."
echo "Reports and scripts saved to $OUTPUT_DIR"
echo
echo "Next steps:"
echo "1. Review the analysis reports in $OUTPUT_DIR"
echo "2. Check the optimization recommendations in $OUTPUT_DIR/optimization_recommendations.md"
echo "3. Run the implementation script at $OUTPUT_DIR/optimize_ansible_collections.sh to apply the recommendations" 