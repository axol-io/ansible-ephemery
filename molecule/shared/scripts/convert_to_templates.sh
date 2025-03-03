#!/bin/bash

# Script to convert existing Molecule scenarios to use the new templates
set -e

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOLECULE_DIR="$(cd "$SCRIPT_DIR/../../" && pwd)"
SHARED_DIR="$MOLECULE_DIR/shared"
TEMPLATES_DIR="$SHARED_DIR/templates"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to log progress
log() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to log success
success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to log warning
warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to log error
error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to convert a scenario
convert_scenario() {
  local scenario_dir="$1"
  local scenario_name
  scenario_name=$(basename "$scenario_dir")

  # Skip if it's shared or doesn't exist
  if [[ "$scenario_name" == "shared" ]] || [[ ! -d "$scenario_dir" ]]; then
    return
  fi

  log "Converting scenario: $scenario_name"

  # Backup existing files
  if [[ -f "$scenario_dir/molecule.yml" ]]; then
    cp "$scenario_dir/molecule.yml" "$scenario_dir/molecule.yml.bak"
  fi
  if [[ -f "$scenario_dir/converge.yml" ]]; then
    cp "$scenario_dir/converge.yml" "$scenario_dir/converge.yml.bak"
  fi
  if [[ -f "$scenario_dir/verify.yml" ]]; then
    cp "$scenario_dir/verify.yml" "$scenario_dir/verify.yml.bak"
  fi
  if [[ -f "$scenario_dir/prepare.yml" ]]; then
    cp "$scenario_dir/prepare.yml" "$scenario_dir/prepare.yml.bak"
  fi

  # Extract scenario-specific values for templating
  local el_client="geth"  # Default value
  local cl_client="lighthouse"  # Default value

  # Try to extract client information from scenario name if it's in clients directory
  if [[ "$scenario_dir" == *"clients/"* ]]; then
    local client_scenario_name
    client_scenario_name=$(basename "$scenario_dir")
    if [[ "$client_scenario_name" == *"-"* ]]; then
      el_client=$(echo "$client_scenario_name" | cut -d'-' -f1)
      cl_client=$(echo "$client_scenario_name" | cut -d'-' -f2)
    fi
  else
    # Try to extract from existing molecule.yml
    if [[ -f "$scenario_dir/molecule.yml" ]]; then
      if grep -q "el_client:" "$scenario_dir/molecule.yml"; then
        el_client=$(grep "el_client:" "$scenario_dir/molecule.yml" | awk '{print $2}' | tr -d '"')
      fi
      if grep -q "cl_client:" "$scenario_dir/molecule.yml"; then
        cl_client=$(grep "cl_client:" "$scenario_dir/molecule.yml" | awk '{print $2}' | tr -d '"')
      fi
    fi
  fi

  # Generate new files from templates
  log "Generating molecule.yml from template"
  python3 -c "
import os
import jinja2

template_file = '$TEMPLATES_DIR/scenario_molecule.yml.j2'
output_file = '$scenario_dir/molecule.yml'
scenario_name = '$scenario_name'
el_client = '$el_client'
cl_client = '$cl_client'

with open(template_file, 'r') as f:
    template_content = f.read()

template = jinja2.Template(template_content)
rendered = template.render(
    scenario_name=scenario_name,
    el_client=el_client,
    cl_client=cl_client,
)

with open(output_file, 'w') as f:
    f.write(rendered)
"

  log "Generating converge.yml from template"
  python3 -c "
import os
import jinja2

template_file = '$TEMPLATES_DIR/converge.yml.j2'
output_file = '$scenario_dir/converge.yml'
scenario_name = '$scenario_name'
el_client = '$el_client'
cl_client = '$cl_client'

with open(template_file, 'r') as f:
    template_content = f.read()

template = jinja2.Template(template_content)
rendered = template.render(
    scenario_name=scenario_name,
    el_client=el_client,
    cl_client=cl_client,
)

with open(output_file, 'w') as f:
    f.write(rendered)
"

  log "Generating verify.yml from template"
  python3 -c "
import os
import jinja2

template_file = '$TEMPLATES_DIR/verify.yml.j2'
output_file = '$scenario_dir/verify.yml'
scenario_name = '$scenario_name'
el_client = '$el_client'
cl_client = '$cl_client'

with open(template_file, 'r') as f:
    template_content = f.read()

template = jinja2.Template(template_content)
rendered = template.render(
    scenario_name=scenario_name,
    el_client=el_client,
    cl_client=cl_client,
)

with open(output_file, 'w') as f:
    f.write(rendered)
"

  log "Generating prepare.yml from template"
  python3 -c "
import os
import jinja2

template_file = '$TEMPLATES_DIR/prepare.yml.j2'
output_file = '$scenario_dir/prepare.yml'
scenario_name = '$scenario_name'
el_client = '$el_client'
cl_client = '$cl_client'

with open(template_file, 'r') as f:
    template_content = f.read()

template = jinja2.Template(template_content)
rendered = template.render(
    scenario_name=scenario_name,
    el_client=el_client,
    cl_client=cl_client,
)

with open(output_file, 'w') as f:
    f.write(rendered)
"

  success "Converted scenario: $scenario_name"
}

# Main execution
log "Starting scenario conversion..."

# Process specific scenario if provided
if [[ $# -gt 0 ]]; then
  SCENARIO="$1"
  SCENARIO_DIR="$MOLECULE_DIR/$SCENARIO"

  if [[ ! -d "$SCENARIO_DIR" ]]; then
    error "Scenario directory not found: $SCENARIO"
    exit 1
  fi

  convert_scenario "$SCENARIO_DIR"
else
  # Process all scenarios (excluding shared)
  for dir in "$MOLECULE_DIR"/*/ ; do
    convert_scenario "$dir"
  done

  # Process client scenarios
  if [[ -d "$MOLECULE_DIR/clients" ]]; then
    for dir in "$MOLECULE_DIR/clients"/*/ ; do
      convert_scenario "$dir"
    done
  fi
fi

log "Creating backup of top-level cleanup.yml"
if [[ -f "$MOLECULE_DIR/cleanup.yml" ]]; then
  cp "$MOLECULE_DIR/cleanup.yml" "$MOLECULE_DIR/cleanup.yml.bak"
fi

success "All scenarios converted! Backups of original files created with .bak extension."
log "You can now run './run-tests.sh default' to test the new setup."
