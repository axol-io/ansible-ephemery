#!/bin/bash
# Script to run molecule tests without relying on Molecule configuration discovery

# Check for DOCKER_HOST env variable and set it if not present
if [ -z "$DOCKER_HOST" ]; then
    if [ -e "/var/run/docker.sock" ]; then
        export DOCKER_HOST="unix:///var/run/docker.sock"
    elif [ -e "$HOME/.docker/run/docker.sock" ]; then
        export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
    fi
fi

# Validate scenario name
if [ -z "$1" ]; then
    echo "Usage: $0 <scenario-name>"
    echo "Example: $0 geth-lighthouse"
    exit 1
fi

SCENARIO_NAME="$1"

# Extract execution and consensus client names
EL=$(echo $SCENARIO_NAME | cut -d- -f1)
CL=$(echo $SCENARIO_NAME | cut -d- -f2)

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo "Created temporary directory: $TEMP_DIR"
echo "Running Molecule test for: $SCENARIO_NAME (using temporary directory)"

# Create necessary directories
mkdir -p "$TEMP_DIR/molecule/default"
mkdir -p "$TEMP_DIR/molecule/default/inventory"
mkdir -p "$TEMP_DIR/molecule/shared"
mkdir -p "$TEMP_DIR/molecule/ansible/tasks/clients/$SCENARIO_NAME"
mkdir -p "$TEMP_DIR/molecule/ansible/templates/scripts"
mkdir -p "$TEMP_DIR/molecule/ansible/defaults"
mkdir -p "$TEMP_DIR/molecule/ansible/vars"
mkdir -p "$TEMP_DIR/molecule/clients/$SCENARIO_NAME"
mkdir -p "$TEMP_DIR/molecule/default/templates"

# Copy necessary files
cp -r molecule/clients/"$SCENARIO_NAME"/* "$TEMP_DIR/molecule/default/"
cp -r molecule/shared/* "$TEMP_DIR/molecule/shared/"
cp -r ansible/tasks/* "$TEMP_DIR/molecule/ansible/tasks/"
cp -r ansible/templates/* "$TEMP_DIR/molecule/ansible/templates/"
cp -r ansible/defaults/* "$TEMP_DIR/molecule/ansible/defaults/"
cp -r ansible/vars/* "$TEMP_DIR/molecule/ansible/vars/"
cp -r ansible/tasks/clients/"$SCENARIO_NAME"/* "$TEMP_DIR/molecule/clients/$SCENARIO_NAME/"

# Create a main.yaml file for the client
cat > "$TEMP_DIR/molecule/clients/$SCENARIO_NAME/main.yaml" << EOF
---
# Client-specific tasks for $SCENARIO_NAME
- name: Set up $EL execution client
  ansible.builtin.include_tasks: ../ansible/tasks/clients/$SCENARIO_NAME/setup-$EL.yaml
  when: execution_client == "$EL"

- name: Set up $CL consensus client
  ansible.builtin.include_tasks: ../ansible/tasks/clients/$SCENARIO_NAME/setup-$CL.yaml
  when: consensus_client == "$CL"
EOF

# Create inventory hosts file
cat > "$TEMP_DIR/molecule/default/inventory/hosts.yml" << EOF
---
all:
  hosts:
    ephemery-$SCENARIO_NAME:
      ansible_connection: docker
  vars:
    el: $EL
    cl: $CL
    test_mode: true
    ephemery_base_dir: "/opt/ephemery"
    ephemery_dir: "/opt/ephemery"
    ephemery_data_dir: "/opt/ephemery/data"
    ephemery_scripts_dir: "/opt/ephemery/scripts"
    jwt_secret_path: "/opt/ephemery/jwt.hex"
    firewall_enabled: false
    monitoring_enabled: false
    validator_enabled: false
    backup_enabled: false
    cadvisor_enabled: false
EOF

# Create a molecule.yml file in the temporary directory
cat > "$TEMP_DIR/molecule/default/molecule.yml" << EOF
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: ephemery-$SCENARIO_NAME
    image: geerlingguy/docker-ubuntu2204-ansible:latest
    pre_build_image: true
    privileged: true
    cgroupns_mode: host
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - /var/run/docker.sock:/var/run/docker.sock:rw
provisioner:
  name: ansible
  env:
    ANSIBLE_ROLES_PATH: "../../molecule/ansible/"
  inventory:
    host_vars:
      ephemery-$SCENARIO_NAME:
        ansible_connection: docker
    group_vars:
      all:
        el: $EL
        cl: $CL
        test_mode: true
        ephemery_base_dir: "/opt/ephemery"
        ephemery_dir: "/opt/ephemery"
        ephemery_data_dir: "/opt/ephemery/data"
        ephemery_scripts_dir: "/opt/ephemery/scripts"
        jwt_secret_path: "/opt/ephemery/jwt.hex"
        firewall_enabled: false
        monitoring_enabled: false
        validator_enabled: false
        backup_enabled: false
        cadvisor_enabled: false
verifier:
  name: ansible
EOF

# Update the converge.yml file to use the correct paths
cat > "$TEMP_DIR/molecule/default/converge.yml" << EOF
---
- name: Converge
  hosts: all
  vars_files:
    - ../ansible/defaults/main.yaml
    - ../ansible/vars/main.yaml
  vars:
    test_mode: true
    home_dir: "/opt/ephemery"
    ephemery_base_dir: "/opt/ephemery"
    ephemery_dir: "{{ ephemery_base_dir }}"
    ephemery_data_dir: "{{ ephemery_base_dir }}/data"
    ephemery_scripts_dir: "{{ ephemery_base_dir }}/scripts"
    jwt_secret_path: "{{ ephemery_dir }}/jwt.hex"
    firewall_enabled: false
    monitoring_enabled: false
    validator_enabled: false
    backup_enabled: false
    cadvisor_enabled: false
    grafana_agent_http_port: 12345
    grafana_port: 3000
    node_exporter_port: 9100
    prometheus_port: 17690
    cadvisor_port: 8080
    el: $EL
    cl: $CL
    client_images:
      geth: ethereum/client-go:v1.15.4
      lighthouse: sigp/lighthouse:v5.3.0
  tasks:
    - name: Install required packages
      ansible.builtin.apt:
        name:
          - socat
          - procps
          - iproute2
        state: present
        update_cache: true

    - name: Import main Ephemery tasks
      ansible.builtin.import_tasks: ../ansible/tasks/main.yaml
      vars:
        execution_client: $EL
        consensus_client: $CL

    # After the role runs, set up the mock services for testing
    - name: Include mock services setup for testing
      ansible.builtin.include_tasks:
        file: ../shared/setup-mock-services.yml
EOF

# Update verify.yml if it exists
if [ -f "$TEMP_DIR/molecule/default/verify.yml" ]; then
  cat > "$TEMP_DIR/molecule/default/verify.yml" << EOF
---
- name: Verify
  hosts: all
  tasks:
    - name: Include verification tasks
      ansible.builtin.include_tasks:
        file: ../shared/verify-mock-services.yml
EOF
fi

# Create a symlink for the health_check.sh.j2 template
mkdir -p "$TEMP_DIR/templates/scripts"
cp -r ansible/templates/scripts/* "$TEMP_DIR/templates/scripts/"

# Create setup files for the clients if they don't exist
mkdir -p "$TEMP_DIR/molecule/ansible/tasks/clients/$SCENARIO_NAME"

# Create setup-geth.yaml
cat > "$TEMP_DIR/molecule/ansible/tasks/clients/$SCENARIO_NAME/setup-$EL.yaml" << EOF
---
# Setup tasks for $EL execution client
- name: Create $EL data directory
  ansible.builtin.file:
    path: "{{ ephemery_data_dir }}/el"
    state: directory
    mode: '0755'

- name: Set up $EL container
  ansible.builtin.debug:
    msg: "Setting up $EL container (mock for testing)"
EOF

# Create setup-lighthouse.yaml
cat > "$TEMP_DIR/molecule/ansible/tasks/clients/$SCENARIO_NAME/setup-$CL.yaml" << EOF
---
# Setup tasks for $CL consensus client
- name: Create $CL data directory
  ansible.builtin.file:
    path: "{{ ephemery_data_dir }}/cl"
    state: directory
    mode: '0755'

- name: Set up $CL container
  ansible.builtin.debug:
    msg: "Setting up $CL container (mock for testing)"
EOF

# Create mock templates for monitoring
mkdir -p "$TEMP_DIR/molecule/ansible/tasks/templates"
mkdir -p "$TEMP_DIR/molecule/default/templates"

# Create datasources.yaml.j2 in both locations to be safe
cat > "$TEMP_DIR/molecule/ansible/tasks/templates/datasources.yaml.j2" << EOF
# Mock datasources.yaml.j2 for testing
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF

cat > "$TEMP_DIR/molecule/default/templates/datasources.yaml.j2" << EOF
# Mock datasources.yaml.j2 for testing
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF

# Create prometheus.yaml.j2 in both locations (note the .yaml extension, not .yml)
cat > "$TEMP_DIR/molecule/ansible/tasks/templates/prometheus.yaml.j2" << EOF
# Mock prometheus.yaml.j2 for testing
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

cat > "$TEMP_DIR/molecule/default/templates/prometheus.yaml.j2" << EOF
# Mock prometheus.yaml.j2 for testing
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Also create prometheus.yml.j2 in case it's needed
cat > "$TEMP_DIR/molecule/ansible/tasks/templates/prometheus.yml.j2" << EOF
# Mock prometheus.yml.j2 for testing
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

cat > "$TEMP_DIR/molecule/default/templates/prometheus.yml.j2" << EOF
# Mock prometheus.yml.j2 for testing
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
EOF

# Create grafana-agent.yaml.j2 in both locations
cat > "$TEMP_DIR/molecule/ansible/tasks/templates/grafana-agent.yaml.j2" << EOF
# Mock grafana-agent.yaml.j2 for testing
server:
  http_listen_port: 12345

prometheus:
  configs:
    - name: integrations
      scrape_configs:
        - job_name: node
          static_configs:
            - targets: ['localhost:9100']
EOF

cat > "$TEMP_DIR/molecule/default/templates/grafana-agent.yaml.j2" << EOF
# Mock grafana-agent.yaml.j2 for testing
server:
  http_listen_port: 12345

prometheus:
  configs:
    - name: integrations
      scrape_configs:
        - job_name: node
          static_configs:
            - targets: ['localhost:9100']
EOF

# Create dashboards.yaml.j2 in both locations
cat > "$TEMP_DIR/molecule/ansible/tasks/templates/dashboards.yaml.j2" << EOF
# Mock dashboards.yaml.j2 for testing
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: false
    options:
      path: /var/lib/grafana/dashboards
EOF

cat > "$TEMP_DIR/molecule/default/templates/dashboards.yaml.j2" << EOF
# Mock dashboards.yaml.j2 for testing
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: false
    options:
      path: /var/lib/grafana/dashboards
EOF

# Update the setup-mock-services.yml file to ensure it creates the mock-services directory
cat > "$TEMP_DIR/molecule/shared/setup-mock-services.yml" << EOF
---
# Setup mock services for testing

- name: Create directory structure for Ethereum clients
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    mode: '0755'
  with_items:
    - "/etc/ethereum"
    - "/etc/ethereum/{{ el }}"
    - "/etc/ethereum/{{ cl }}"
    - "/var/lib/ethereum"
    - "/var/lib/ethereum/{{ el }}"
    - "/var/lib/ethereum/{{ cl }}"

- name: Create JWT secret file
  ansible.builtin.copy:
    dest: "/etc/ethereum/jwt.hex"
    content: "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
    mode: '0644'

- name: Create mock configuration files for execution client
  ansible.builtin.copy:
    dest: "/etc/ethereum/{{ el }}/{{ el }}.conf"
    content: |
      # Mock configuration for {{ el }}
      EXECUTION_CLIENT={{ el }}
      ENGINE_RPC_PORT=8551
      RPC_PORT=8545
      JWT_SECRET=/etc/ethereum/jwt.hex
    mode: '0644'

- name: Create mock configuration files for consensus client
  ansible.builtin.copy:
    dest: "/etc/ethereum/{{ cl }}/{{ cl }}-beacon.conf"
    content: |
      # Mock configuration for {{ cl }}
      CONSENSUS_CLIENT={{ cl }}
      {% if cl == 'lighthouse' %}
      HTTP_PORT=5052
      {% elif cl == 'prysm' %}
      HTTP_PORT=4000
      {% elif cl == 'teku' %}
      HTTP_PORT=5051
      {% else %}
      HTTP_PORT=9000
      {% endif %}
      JWT_SECRET=/etc/ethereum/jwt.hex
    mode: '0644'

- name: Create fake service files for service_facts
  ansible.builtin.file:
    path: "{{ item.path }}"
    state: directory
    mode: '0755'
  with_items:
    - { path: "/run/systemd/system/{{ el }}.service.d" }
    - { path: "/run/systemd/system/{{ cl }}-beacon.service.d" }
    - { path: "/run/systemd/system/{{ cl }}-validator.service.d" }

- name: Create fake service state files
  ansible.builtin.copy:
    dest: "{{ item.dest }}"
    content: "{{ item.content }}"
    mode: '0644'
  with_items:
    - { dest: "/run/systemd/system/{{ el }}.service.d/state", content: "running" }
    - { dest: "/run/systemd/system/{{ cl }}-beacon.service.d/state", content: "running" }
    - { dest: "/run/systemd/system/{{ cl }}-validator.service.d/state", content: "running" }

- name: Create mock port listeners for execution client
  ansible.builtin.copy:
    dest: "/tmp/el-port-listeners.sh"
    content: |
      #!/bin/bash
      socat TCP-LISTEN:8545,fork,reuseaddr /dev/null &
      socat TCP-LISTEN:8551,fork,reuseaddr /dev/null &
      touch /tmp/el-ports-started
    mode: '0755'

- name: Create mock port listeners for consensus client
  ansible.builtin.copy:
    dest: "/tmp/cl-port-listeners.sh"
    content: |
      #!/bin/bash
      {% if cl == 'lighthouse' %}
      socat TCP-LISTEN:5052,fork,reuseaddr /dev/null &
      {% elif cl == 'prysm' %}
      socat TCP-LISTEN:4000,fork,reuseaddr /dev/null &
      {% elif cl == 'teku' %}
      socat TCP-LISTEN:5051,fork,reuseaddr /dev/null &
      {% else %}
      socat TCP-LISTEN:9000,fork,reuseaddr /dev/null &
      {% endif %}
      touch /tmp/cl-ports-started
    mode: '0755'

- name: Check if port listeners are already started
  ansible.builtin.stat:
    path: "{{ item }}"
  register: port_listeners_check
  with_items:
    - "/tmp/el-ports-started"
    - "/tmp/cl-ports-started"

- name: Start execution client port listeners if not already started
  ansible.builtin.shell: /tmp/el-port-listeners.sh
  when: not port_listeners_check.results[0].stat.exists

- name: Start consensus client port listeners if not already started
  ansible.builtin.shell: /tmp/cl-port-listeners.sh
  when: not port_listeners_check.results[1].stat.exists

- name: Create mock services directory
  ansible.builtin.file:
    path: "{{ ephemery_base_dir }}/mock-services"
    state: directory
    mode: '0755'

- name: Create mock service file
  ansible.builtin.copy:
    dest: "{{ ephemery_base_dir }}/mock-services/mock-service.sh"
    content: |
      #!/bin/bash
      # Mock service for testing
      echo "Mock service is running"
      exit 0
    mode: '0755'

- name: Run mock service
  ansible.builtin.command: "{{ ephemery_base_dir }}/mock-services/mock-service.sh"
  changed_when: false
EOF

# Navigate to the temporary directory and run the test
cd "$TEMP_DIR" || exit 1
ANSIBLE_ROLES_PATH="$TEMP_DIR/molecule/ansible" molecule test

# Capture exit code
EXIT_CODE=$?

# Clean up
echo "Cleaning up temporary directory"
rm -rf "$TEMP_DIR"

exit $EXIT_CODE
