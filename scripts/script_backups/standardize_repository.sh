#!/bin/bash
# Version: 1.0.0
#
# Master script to standardize the repository structure and naming conventions
# This script runs all the standardization scripts in the correct order

echo "====================== ANSIBLE EPHEMERY REPOSITORY STANDARDIZATION ======================"
echo "This script will run all standardization scripts in the correct order."
echo "Make sure you have committed or backed up your changes before running this script."
echo "======================================================================================="
echo

# Make all scripts executable
echo "Making all scripts executable..."
chmod +x *.sh
echo

# Step 1: Prune redundant files
echo "Step 1: Pruning redundant files..."
./prune_redundant_files.sh
echo

# Step 2: Standardize YAML extensions
echo "Step 2: Standardizing YAML extensions..."
./standardize_yaml_extensions.sh
echo

# Step 3: Standardize Molecule extensions
echo "Step 3: Standardizing Molecule extensions..."
./standardize_molecule_extensions.sh
echo

# Step 4: Normalize task names
echo "Step 4: Normalizing task names..."
./normalize_task_names.sh
echo

# Step 5: Set up directory structure
echo "Step 5: Setting up recommended directory structure..."
./repository_structure.sh
echo

echo "======================================================================================="
echo "Repository standardization complete!"
echo "Please verify the changes and commit them if they look good."
echo "======================================================================================="
