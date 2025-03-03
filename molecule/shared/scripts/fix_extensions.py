#!/usr/bin/env python3
"""
Script to fix file extensions in the molecule directory:
1. Rename all .yaml files to .yml
2. Update references within files to use .yml extension

Usage:
  python3 fix_extensions.py
"""

import os
import re
from pathlib import Path

# Define project root
PROJECT_ROOT = Path(__file__).resolve().parents[3]
MOLECULE_DIR = PROJECT_ROOT / "molecule"

def fix_yaml_extensions():
    """Rename all .yaml files to .yml"""
    yaml_files = []
    for root, dirs, files in os.walk(MOLECULE_DIR):
        for file in files:
            if file.endswith('.yaml'):
                yaml_path = Path(root) / file
                yml_path = yaml_path.with_suffix('.yml')
                yaml_files.append((yaml_path, yml_path))

    # Rename files
    for yaml_path, yml_path in yaml_files:
        if not yml_path.exists():
            print(f"Renaming {yaml_path} → {yml_path}")
            yaml_path.rename(yml_path)
        else:
            print(f"Warning: Cannot rename {yaml_path} because {yml_path} already exists")

def update_file_references():
    """Update references to .yaml files within all molecule files"""
    yml_files = []
    for root, dirs, files in os.walk(MOLECULE_DIR):
        for file in files:
            if file.endswith('.yml'):
                yml_files.append(Path(root) / file)

    for file_path in yml_files:
        print(f"Checking references in {file_path}")

        # Read file content
        with open(file_path, 'r') as f:
            content = f.read()

        # Replace .yaml references with .yml
        original_content = content
        content = re.sub(r'(verify|converge|prepare|molecule|cleanup)\.yaml', r'\1.yml', content)

        # Only write if content changed
        if content != original_content:
            print(f"  Updating references in {file_path}")
            with open(file_path, 'w') as f:
                f.write(content)

def main():
    print("Fixing file extensions in molecule directory...")
    fix_yaml_extensions()
    print("\nUpdating file references...")
    update_file_references()
    print("\nDone!")

if __name__ == "__main__":
    main()
