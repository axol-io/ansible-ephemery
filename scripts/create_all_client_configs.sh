#!/bin/bash
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
  el_cap="$(echo ${el:0:1} | tr '[:lower:]' '[:upper:]')${el:1}"
  cl_cap="$(echo ${cl:0:1} | tr '[:lower:]' '[:upper:]')${cl:1}"

  echo "Creating $dir"

  # Create directory if it doesn't exist
  mkdir -p "$dir"

  # Create main.yaml
  cat > "$dir/main.yaml" << 'EOF'
---
# Client-specific configuration for ELCAP (EL) and CLCAP (CL)

- name: Set client-specific variables
  ansible.builtin.set_fact:
    el_client_name: ELNAME
    cl_client_name: CLNAME
    el_client_image: '{{ client_images.ELNAME }}'
    cl_client_image: '{{ client_images.CLNAME }}'
    el_client_port: 8545
    cl_client_port: 5052
    el_p2p_port: 30303
    cl_p2p_port: 9000
    el_metrics_port: 6060
    cl_metrics_port: 5054

- name: Create client-specific directories
  ansible.builtin.file:
    path: '{{ item }}'
    state: directory
    mode: '0755'
    owner: '{{ ansible_user }}'
    group: '{{ ansible_user }}'
  loop:
    - '{{ ephemery_data_dir }}/{{ el_client_name }}'
    - '{{ ephemery_data_dir }}/{{ cl_client_name }}'

# Include client-specific tasks if they exist
- name: Include EL client-specific tasks
  ansible.builtin.include_tasks:
    file: 'el-{{ el_client_name }}.yaml'
  ignore_errors: yes

- name: Include CL client-specific tasks
  ansible.builtin.include_tasks:
    file: 'cl-{{ cl_client_name }}.yaml'
  ignore_errors: yes
EOF

  # Replace placeholders with actual values
  sed -i "" "s/ELCAP/${el_cap}/g" "$dir/main.yaml"
  sed -i "" "s/CLCAP/${cl_cap}/g" "$dir/main.yaml"
  sed -i "" "s/ELNAME/${el}/g" "$dir/main.yaml"
  sed -i "" "s/CLNAME/${cl}/g" "$dir/main.yaml"

  # Create el-client.yaml
  cat > "$dir/el-${el}.yaml" << 'EOF'
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
  sed -i "" "s/ELCAP/${el_cap}/g" "$dir/el-${el}.yaml"
  sed -i "" "s/ELNAME/${el}/g" "$dir/el-${el}.yaml"

  # Create cl-client.yaml
  cat > "$dir/cl-${cl}.yaml" << 'EOF'
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
  sed -i "" "s/CLCAP/${cl_cap}/g" "$dir/cl-${cl}.yaml"
  sed -i "" "s/CLNAME/${cl}/g" "$dir/cl-${cl}.yaml"
}

# Generate all client combinations
for el in $EL_CLIENTS; do
  for cl in $CL_CLIENTS; do
    # Check if the directory already exists and has all required files
    if [ -d "clients/${el}-${cl}" ] &&
       [ -f "clients/${el}-${cl}/main.yaml" ] &&
       [ -f "clients/${el}-${cl}/el-${el}.yaml" ] &&
       [ -f "clients/${el}-${cl}/cl-${cl}.yaml" ]; then
      echo "Skipping existing client config: ${el}-${cl}"
    else
      create_client_config "$el" "$cl"
    fi
  done
done

echo "All client configuration files have been created successfully."
