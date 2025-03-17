#!/bin/bash
# Version: 1.0.0
# Consolidated script to generate all client combinations

# Define clients
EL_CLIENTS="geth besu nethermind reth erigon"
CL_CLIENTS="lighthouse teku prysm lodestar"

# Define client versions - maintain consistency with create_client_tasks.sh
export GETH_VERSION="v1.15.3"
export BESU_VERSION="23.10.0"
export NETHERMIND_VERSION="v1.25.2"
export RETH_VERSION="v0.1.0-alpha.11"
export ERIGON_VERSION="v2.55.1"
export LIGHTHOUSE_VERSION="v4.6.0"
export TEKU_VERSION="24.1.0"
export PRYSM_VERSION="v4.1.1"
export LODESTAR_VERSION="v1.13.0"

# Create client configuration files for all combinations
create_client_config() {
  local el=$1
  local cl=$2
  local dir="clients/${el}-${cl}"

  # Capitalize first letter of client names for comments
  el_cap="$(echo "${el:0:1}" | tr '[:lower:]' '[:upper:]')${el:1}"
  cl_cap="$(echo "${cl:0:1}" | tr '[:lower:]' '[:upper:]')${cl:1}"

  echo "Creating ${dir}"

  # Create directory if it doesn't exist
  mkdir -p "${dir}"

  # Create ephemery.yaml
  cat >"${dir}/ephemery.yaml" <<'EOF'
---
- name: Deploy Ephemery Test Environment for ELCAP (ELNAME) + CLCAP (CLNAME)
  hosts: all
  gather_facts: true
  become: true
  vars:
    el: ELNAME
    cl: CLNAME
    monitoring_enabled: true
    validator_enabled: false
    node_exporter_enabled: true
    cadvisor_enabled: true
    firewall_enabled: true
    setup_checks_enabled: true

  tasks:
    - name: Include validation tasks
      ansible.builtin.include_tasks: validation.yaml

    - name: Include environment setup tasks
      ansible.builtin.include_tasks: setup-env.yaml

    - name: Include JWT secret tasks
      ansible.builtin.include_tasks: jwt-secret.yaml

    - name: Include client specific tasks
      ansible.builtin.include_tasks: "clients/{{ el }}.yaml"

    - name: Include client specific tasks
      ansible.builtin.include_tasks: "clients/{{ cl }}.yaml"

    - name: Include validator tasks if enabled
      ansible.builtin.include_tasks: validator.yaml
      when: validator_enabled | bool

    - name: Include monitoring tasks if enabled
      ansible.builtin.include_tasks: monitoring.yaml
      when: monitoring_enabled | bool

    - name: Include firewall tasks if enabled
      ansible.builtin.include_tasks: firewall.yaml
      when: firewall_enabled | bool
EOF

  # Replace placeholders with actual values
  sed -i "" "s/ELCAP/${el_cap}/g" "${dir}/ephemery.yaml"
  sed -i "" "s/CLCAP/${cl_cap}/g" "${dir}/ephemery.yaml"
  sed -i "" "s/ELNAME/${el}/g" "${dir}/ephemery.yaml"
  sed -i "" "s/CLNAME/${cl}/g" "${dir}/ephemery.yaml"

  # Create el-client.yaml
  cat >"${dir}/el-${el}.yaml" <<'EOF'
---
# ELCAP-specific configuration tasks

- name: Set ELCAP-specific variables
  ansible.builtin.set_fact:
    ELNAME_data_dir: '{{ ephemery_data_dir }}/{{ el_client_name }}'
    ELNAME_network_id: 3151908
    ELNAME_http_port: '{{ el_client_port }}'
    ELNAME_p2p_port: '{{ el_p2p_port }}'
    ELNAME_metrics_port: '{{ el_metrics_port }}'
    ELNAME_authrpc_port: 8551

- name: Create ELCAP data directory
  ansible.builtin.file:
    path: '{{ ELNAME_data_dir }}'
    state: directory
    mode: '0755'
    owner: '{{ ansible_user }}'
    group: '{{ ansible_user }}'
EOF

  # Replace placeholders with actual values
  sed -i "" "s/ELCAP/${el_cap}/g" "${dir}/el-${el}.yaml"
  sed -i "" "s/ELNAME/${el}/g" "${dir}/el-${el}.yaml"

  # Create cl-client.yaml
  cat >"${dir}/cl-${cl}.yaml" <<'EOF'
---
# CLCAP-specific configuration tasks

- name: Set CLCAP-specific variables
  ansible.builtin.set_fact:
    CLNAME_data_dir: '{{ ephemery_data_dir }}/{{ cl_client_name }}'
    CLNAME_http_port: '{{ cl_client_port }}'
    CLNAME_p2p_port: '{{ cl_p2p_port }}'
    CLNAME_metrics_port: '{{ cl_metrics_port }}'

- name: Create CLCAP data directory
  ansible.builtin.file:
    path: '{{ CLNAME_data_dir }}'
    state: directory
    mode: '0755'
    owner: '{{ ansible_user }}'
    group: '{{ ansible_user }}'
EOF

  # Replace placeholders with actual values
  sed -i "" "s/CLCAP/${cl_cap}/g" "${dir}/cl-${cl}.yaml"
  sed -i "" "s/CLNAME/${cl}/g" "${dir}/cl-${cl}.yaml"
}

# Generate all client combinations
for el in ${EL_CLIENTS}; do
  for cl in ${CL_CLIENTS}; do
    # Check if the directory already exists and has all required files
    if [ -d "clients/${el}-${cl}" ] \
      && [ -f "clients/${el}-${cl}/ephemery.yaml" ] \
      && [ -f "clients/${el}-${cl}/el-${el}.yaml" ] \
      && [ -f "clients/${el}-${cl}/cl-${cl}.yaml" ]; then
      echo "Skipping existing client config: ${el}-${cl}"
    else
      create_client_config "${el}" "${cl}"
    fi
  done
done

echo "All client configuration files have been created successfully."
