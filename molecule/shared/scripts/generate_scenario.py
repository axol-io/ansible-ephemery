#!/usr/bin/env python3
"""
Script to generate molecule scenario configurations.
This helps ensure consistency across testing scenarios.

Usage:
  python3 generate_scenario.py --name validator --node-name ethereum-validator
"""

import argparse
import os
import sys
from pathlib import Path

import jinja2
import yaml

# Define project root
PROJECT_ROOT = Path(__file__).resolve().parents[3]
MOLECULE_DIR = PROJECT_ROOT / "molecule"
SHARED_DIR = MOLECULE_DIR / "shared"
TEMPLATES_DIR = SHARED_DIR / "templates"


def parse_args():
    parser = argparse.ArgumentParser(description="Generate molecule scenario config")
    parser.add_argument("--name", required=True, help="Scenario name")
    parser.add_argument("--node-name", default="ethereum-node", help="Node name")
    parser.add_argument("--vars", default="{}", help="Custom variables as JSON string")
    parser.add_argument(
        "--output-dir", help="Output directory, defaults to molecule/{name}"
    )
    return parser.parse_args()


def generate_scenario(scenario_name, node_name, custom_vars, output_dir=None):
    # Set up template environment
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(TEMPLATES_DIR))
    template = env.get_template("scenario_molecule.yml.j2")

    # Render template
    rendered = template.render(
        scenario_name=scenario_name, node_name=node_name, custom_vars=custom_vars
    )

    # Create output directory if it doesn't exist
    if not output_dir:
        output_dir = MOLECULE_DIR / scenario_name
    os.makedirs(output_dir, exist_ok=True)

    # Write output file
    output_file = output_dir / "molecule.yml"
    with open(output_file, "w") as f:
        f.write(rendered)

    print(f"Generated scenario configuration: {output_file}")

    # Create minimal converge.yaml if it doesn't exist
    converge_file = output_dir / "converge.yml"
    if not converge_file.exists():
        with open(converge_file, "w") as f:
            f.write(
                """---
- name: Converge
  hosts: all
  become: true
  tasks:
    - name: "Include ansible-ephemery role"
      include_role:
        name: "ansible-ephemery"
"""
            )
        print(f"Generated converge playbook: {converge_file}")

    # Create minimal verify.yaml if it doesn't exist
    verify_file = output_dir / "verify.yml"
    if not verify_file.exists():
        with open(verify_file, "w") as f:
            f.write(
                """---
- name: Verify
  hosts: all
  become: true
  tasks:
    - name: Gather service facts
      service_facts:

    - name: Check that required Docker containers are running
      shell: docker ps --format '{% raw %}{{.Names}}{% endraw %}'
      register: docker_containers
      changed_when: false
"""
            )
        print(f"Generated verify playbook: {verify_file}")


if __name__ == "__main__":
    args = parse_args()

    # Parse custom vars
    import json

    try:
        custom_vars_dict = json.loads(args.vars)
    except json.JSONDecodeError:
        print(f"Error: Custom variables must be valid JSON. Got: {args.vars}")
        sys.exit(1)

    output_dir = args.output_dir
    if output_dir:
        output_dir = Path(output_dir)
    else:
        output_dir = MOLECULE_DIR / args.name

    generate_scenario(args.name, args.node_name, custom_vars_dict, output_dir)
