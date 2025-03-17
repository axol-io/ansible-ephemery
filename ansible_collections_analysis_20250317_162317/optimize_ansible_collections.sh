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