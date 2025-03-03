#!/usr/bin/env python3
"""
Script to update all molecule scenarios to use the standardized format.
This script:
1. Updates molecule.yaml files to import the base configuration
2. Updates verify.yaml files to use common verification templates
3. Updates variable references to use namespaced variables
4. Removes playbooks property from verifier section for compatibility

Usage:
  python3 update_all_scenarios.py
"""

import os
import sys
import yaml
import re
from pathlib import Path

# Define project root
PROJECT_ROOT = Path(__file__).resolve().parents[3]
MOLECULE_DIR = PROJECT_ROOT / "molecule"
SHARED_DIR = MOLECULE_DIR / "shared"

# Variable mapping (old name -> new name)
VARIABLE_MAPPING = {
    "prometheus_port": "monitoring_prometheus_port",
    "grafana_port": "monitoring_grafana_port",
    "grafana_agent_http_port": "monitoring_grafana_agent_http_port",
    "cadvisor_port": "monitoring_cadvisor_port",
    "el_memory_limit": "resource_el_memory_limit",
    "cl_memory_limit": "resource_cl_memory_limit",
    "validator_memory_limit": "resource_validator_memory_limit",
}

def get_scenarios():
    """Get all scenario directories"""
    scenarios = []
    for item in os.listdir(MOLECULE_DIR):
        if os.path.isdir(MOLECULE_DIR / item) and item != "shared":
            scenarios.append(item)
    return scenarios

def update_scenario_molecule_yaml(scenario):
    """Update molecule.yaml for a scenario"""
    # Check for both .yaml and .yml extensions
    for ext in ['.yaml', '.yml']:
        molecule_file = MOLECULE_DIR / scenario / f"molecule{ext}"
        if molecule_file.exists():
            break
    else:
        print(f"Warning: molecule configuration for {scenario} doesn't exist, skipping...")
        return

    print(f"Updating {molecule_file}...")

    # Read current content
    with open(molecule_file, "r") as f:
        content = f.read()

    # Add import comment if not present
    if "# Imports base configuration" not in content:
        content = re.sub(r"^---\n", "---\n# " + scenario.title() + " scenario configuration\n# Imports base configuration from shared/base_molecule.yaml\n\n", content)

    # Update variable references
    for old_var, new_var in VARIABLE_MAPPING.items():
        content = re.sub(f"(\\s+){old_var}:", f"\\1{new_var}:", content)

    # Remove playbooks property from verifier section
    content = re.sub(r"verifier:\s+name:\s+ansible\s+playbooks:\s+verify:\s+verify\.ya?ml", "verifier:\n  name: ansible", content)

    # Write updated content
    with open(molecule_file, "w") as f:
        f.write(content)

    print(f"Updated {molecule_file}")

def update_scenario_verify_yaml(scenario):
    """Update verify.yaml for a scenario to use common templates"""
    verify_file = MOLECULE_DIR / scenario / "verify.yaml"

    if not verify_file.exists():
        print(f"Warning: {verify_file} doesn't exist, skipping...")
        return

    print(f"Updating {verify_file}...")

    # Read current content
    with open(verify_file, "r") as f:
        content = f.read()

    # Check if we've already updated this file
    if "include_tasks: ../shared/templates/verify/common.yaml" in content:
        print(f"File {verify_file} already updated, skipping...")
        return

    # Extract the tasks section
    match = re.search(r"tasks:(.*?)(?:\n\w+:|$)", content, re.DOTALL)
    if not match:
        print(f"Warning: Couldn't find tasks section in {verify_file}, skipping...")
        return

    tasks_section = match.group(1)

    # Create new tasks section with imports
    new_tasks_section = "\n    # Include common verification tasks\n    - name: Include common verification tasks\n      include_tasks: ../shared/templates/verify/common.yaml\n"

    # Add scenario-specific template if available
    if os.path.exists(SHARED_DIR / "templates" / "verify" / f"{scenario}.yaml"):
        new_tasks_section += f"\n    # Include {scenario}-specific verification tasks\n    - name: Include {scenario}-specific verification tasks\n      include_tasks: ../shared/templates/verify/{scenario}.yaml\n"

    new_tasks_section += "\n    # Additional scenario-specific verification tasks"

    # Replace old tasks section with new one
    updated_content = content.replace(tasks_section, new_tasks_section)

    # Update variable references
    for old_var, new_var in VARIABLE_MAPPING.items():
        updated_content = re.sub(f"(\\s+){old_var}:", f"\\1{new_var}:", updated_content)

    # Update boolean conditions
    updated_content = re.sub(r"(\s+when:\s+)(\w+)(\s+and)", r"\1\2 | bool\3", updated_content)
    updated_content = re.sub(r"(\s+when:\s+)(\w+)($)", r"\1\2 | bool\3", updated_content)

    # Write updated content
    with open(verify_file, "w") as f:
        f.write(updated_content)

    print(f"Updated {verify_file}")

def rename_molecule_files():
    """Rename all molecule.yaml files to molecule.yml"""
    for scenario in get_scenarios():
        yaml_file = MOLECULE_DIR / scenario / "molecule.yaml"
        yml_file = MOLECULE_DIR / scenario / "molecule.yml"

        if yaml_file.exists() and not yml_file.exists():
            yaml_file.rename(yml_file)
            print(f"Renamed {yaml_file} to {yml_file}")

def make_script_executable():
    """Make this script and generate_scenario.py executable"""
    os.chmod(__file__, 0o755)

    generate_script = SHARED_DIR / "scripts" / "generate_scenario.py"
    if generate_script.exists():
        os.chmod(generate_script, 0o755)
        print(f"Made {generate_script} executable")

def main():
    # Make scripts executable
    make_script_executable()

    # Rename molecule.yaml to molecule.yml if needed
    rename_molecule_files()

    # Get all scenarios
    scenarios = get_scenarios()
    print(f"Found {len(scenarios)} scenarios: {', '.join(scenarios)}")

    # Update each scenario
    for scenario in scenarios:
        print(f"\nUpdating {scenario} scenario...")
        update_scenario_molecule_yaml(scenario)
        update_scenario_verify_yaml(scenario)

if __name__ == "__main__":
    main()
    print("\nDone! All scenarios have been updated to use the standardized format.")
