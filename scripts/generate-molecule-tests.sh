#!/bin/bash
# Script to generate molecule tests for all client combinations

# Define execution and consensus clients
EXECUTION_CLIENTS=("geth" "reth" "erigon" "nethermind" "besu")
CONSENSUS_CLIENTS=("lighthouse" "prysm" "teku" "lodestar")

# Function to create molecule test for a client combination
create_molecule_test() {
    local el=$1
    local cl=$2
    local scenario="${el}-${cl}"
    local dir="molecule/clients/${scenario}"

    echo "Generating molecule test for ${scenario}..."

    # Create directory if it doesn't exist
    mkdir -p "${dir}"

    # Create molecule.yml
    cat > "${dir}/molecule.yml" << 'EOF'
---
dependency:
  name: galaxy
driver:
  name: docker
  docker_host: "unix:///var/run/docker.sock"
platforms:
  - name: ephemery-EXECUTION-CONSENSUS
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    pre_build_image: true
    privileged: true
    cgroupns_mode: host
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - "/var/run/docker.sock:/var/run/docker.sock:rw"
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        el: EXECUTION
        cl: CONSENSUS
verifier:
  name: ansible
EOF

    # Replace placeholder with actual client names
    sed -i.bak "s/EXECUTION/${el}/g; s/CONSENSUS/${cl}/g" "${dir}/molecule.yml"
    rm "${dir}/molecule.yml.bak" 2>/dev/null || true

    # Create converge.yml
    cat > "${dir}/converge.yml" << 'EOF'
---
- name: Converge
  hosts: all
  tasks:
    - name: Install required packages
      ansible.builtin.apt:
        name:
          - socat
          - procps
          - iproute2
        state: present
        update_cache: yes

    - name: Include ephemery role
      include_role:
        name: ../../..
      vars:
        execution_client: EXECUTION
        consensus_client: CONSENSUS

    # After the role runs, set up the mock services for testing
    - name: Include mock services setup for testing
      ansible.builtin.include_tasks:
        file: ../../shared/setup-mock-services.yml
EOF

    # Replace placeholder with actual client names
    sed -i.bak "s/EXECUTION/${el}/g; s/CONSENSUS/${cl}/g" "${dir}/converge.yml"
    rm "${dir}/converge.yml.bak" 2>/dev/null || true

    # Determine consensus client port
    local cl_port="9000"
    if [ "${cl}" == "lighthouse" ]; then
        cl_port="5052"
    elif [ "${cl}" == "prysm" ]; then
        cl_port="4000"
    elif [ "${cl}" == "teku" ]; then
        cl_port="5051"
    elif [ "${cl}" == "lodestar" ]; then
        cl_port="9000"
    fi

    # Create verify.yml
    cat > "${dir}/verify.yml" << 'EOF'
---
- name: Verify
  hosts: all
  vars:
    el: EXECUTION
    cl: CONSENSUS
  tasks:
    - name: Include mock services verification tasks
      ansible.builtin.include_tasks:
        file: ../../shared/verify-mock-services.yml
EOF

    # Replace placeholders with actual values
    sed -i.bak "s/EXECUTION/${el}/g; s/CONSENSUS/${cl}/g; s/CLPORT/${cl_port}/g" "${dir}/verify.yml"
    rm "${dir}/verify.yml.bak" 2>/dev/null || true

    echo "Generated molecule test for ${scenario}"
}

# Generate tests for all combinations
for el in "${EXECUTION_CLIENTS[@]}"; do
    for cl in "${CONSENSUS_CLIENTS[@]}"; do
        create_molecule_test "$el" "$cl"
    done
done

echo "All molecule tests generated successfully!"

# Update GitHub workflow matrix
echo "To update the GitHub workflow matrix, add the following scenarios to .github/workflows/molecule.yaml with the \"clients/\" prefix:"
for el in "${EXECUTION_CLIENTS[@]}"; do
    for cl in "${CONSENSUS_CLIENTS[@]}"; do
        echo "          - clients/${el}-${cl}"
    done
done
