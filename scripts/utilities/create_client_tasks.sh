#!/bin/bash
# Script to generate tasks for all client combinations in tasks/clients directory

# Define clients
EL_CLIENTS="geth besu nethermind reth erigon"
CL_CLIENTS="lighthouse teku prysm lodestar"

# Define client versions
GETH_VERSION="v1.15.3"
BESU_VERSION="23.10.0"
NETHERMIND_VERSION="v1.25.2"
RETH_VERSION="v0.1.0-alpha.11"
ERIGON_VERSION="v2.55.1"
LIGHTHOUSE_VERSION="v4.6.0"
TEKU_VERSION="24.1.0"
PRYSM_VERSION="v4.1.1"
LODESTAR_VERSION="v1.13.0"

# Create tasks for a given client combination
create_client_tasks() {
  el="$1"
  cl="$2"
  dir="tasks/clients/${el}-${cl}"

  # Capitalize first letter of client names for comments
  first_char=$(echo "$el" | cut -c1 | tr '[:lower:]' '[:upper:]')
  rest_chars=$(echo "$el" | cut -c2-)
  el_cap="${first_char}${rest_chars}"

  first_char=$(echo "$cl" | cut -c1 | tr '[:lower:]' '[:upper:]')
  rest_chars=$(echo "$cl" | cut -c2-)
  cl_cap="${first_char}${rest_chars}"

  # Get versions based on client
  el_version=""
  cl_version=""

  case "$el" in
    geth) el_version=$GETH_VERSION ;;
    besu) el_version=$BESU_VERSION ;;
    nethermind) el_version=$NETHERMIND_VERSION ;;
    reth) el_version=$RETH_VERSION ;;
    erigon) el_version=$ERIGON_VERSION ;;
  esac

  case "$cl" in
    lighthouse) cl_version=$LIGHTHOUSE_VERSION ;;
    teku) cl_version=$TEKU_VERSION ;;
    prysm) cl_version=$PRYSM_VERSION ;;
    lodestar) cl_version=$LODESTAR_VERSION ;;
  esac

  echo "Creating tasks for $dir (EL: $el v$el_version, CL: $cl v$cl_version)"

  # Create directory if it doesn't exist
  mkdir -p "$dir"

  # Create firewall.yaml based on client combination
  # Note: Different clients may have different port requirements
  cat > "$dir/firewall.yaml" << 'EOF'
---
# Firewall rules for ELCAP (execution client) and CLCAP (consensus client) combination
firewall_allowed_tcp_ports:
  - 22    # SSH
  - 80    # HTTP
  - 443   # HTTPS
EOF

  # Add client-specific ports based on the client combination
  # EL client ports
  if [ "$el" = "geth" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 30303 # Geth P2P
  - 8551  # Geth Engine API
EOF
  elif [ "$el" = "besu" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 30303 # Besu P2P
  - 8551  # Besu Engine API
EOF
  elif [ "$el" = "nethermind" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 30303 # Nethermind P2P
  - 8551  # Nethermind Engine API
EOF
  elif [ "$el" = "reth" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 30303 # Reth P2P
  - 8551  # Reth Engine API
EOF
  elif [ "$el" = "erigon" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 30303 # Erigon P2P
  - 30304 # Erigon P2P
  - 8551  # Erigon Engine API
EOF
  fi

  # CL client ports
  if [ "$cl" = "lighthouse" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 9000  # Lighthouse P2P
  - 5052  # Lighthouse metrics
EOF
  elif [ "$cl" = "teku" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 9000  # Teku P2P
  - 8008  # Teku metrics
EOF
  elif [ "$cl" = "prysm" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 9001  # Prysm P2P
  - 9999  # Prysm metrics
  - 3500  # Prysm RPC
EOF
  elif [ "$cl" = "lodestar" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 9000  # Lodestar P2P
  - 5052  # Lodestar metrics
EOF
  fi

  # UDP ports section for firewall rules
  cat >> "$dir/firewall.yaml" << 'EOF'

firewall_allowed_udp_ports:
EOF

  # EL client UDP ports
  if [ "$el" = "geth" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 30303 # Geth P2P
EOF
  elif [ "$el" = "besu" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 30303 # Besu P2P
EOF
  elif [ "$el" = "nethermind" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 30303 # Nethermind P2P
EOF
  elif [ "$el" = "reth" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 30303 # Reth P2P
EOF
  elif [ "$el" = "erigon" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 30303 # Erigon P2P
  - 30304 # Erigon P2P
EOF
  fi

  # CL client UDP ports
  if [ "$cl" = "lighthouse" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 9000  # Lighthouse P2P
EOF
  elif [ "$cl" = "teku" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 9000  # Teku P2P
EOF
  elif [ "$cl" = "prysm" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 9001  # Prysm P2P
EOF
  elif [ "$cl" = "lodestar" ]; then
    cat >> "$dir/firewall.yaml" << 'EOF'
  - 9000  # Lodestar P2P
EOF
  fi

  # Replace placeholders with actual values in firewall.yaml
  sed -i "" "s/ELCAP/${el_cap}/g" "$dir/firewall.yaml"
  sed -i "" "s/CLCAP/${cl_cap}/g" "$dir/firewall.yaml"

  # Create molecule.yaml
  cat > "$dir/molecule.yaml" << 'EOF'
---
- name: Check if client combination is selected
  ansible.builtin.set_fact:
    client_skip: '{{ not (el == "ELNAME" and cl == "CLNAME") }}'

- name: 🌟 Ensure client directories exist
  ansible.builtin.file:
    path: '{{ item }}'
    state: directory
    mode: '0755'
    owner: '{{ ansible_user }}'
    group: '{{ ansible_user }}'
  loop:
    - '{{ ephemery_data_dir }}/el'
    - '{{ ephemery_data_dir }}/cl'
    - '{{ ephemery_logs_dir }}'
  when: not client_skip

- name: 🔑 Ensure JWT secret exists
  ansible.builtin.import_tasks:
    file: tasks/jwt-secret.yaml
  when: not client_skip
EOF

  # Add EL client specific container configuration
  if [ "$el" = "geth" ]; then
    cat >> "$dir/molecule.yaml" << EOF

- name: 🚀 Start Geth (Execution Client)
  community.docker.docker_container:
    name: '{{ network }}-geth'
    image: 'pk910/ephemery-geth:v1.15.3'
    state: started
    pull: true
    restart_policy: unless-stopped
    network_mode: host
    memory: '{{ el_memory_limit }}'
    volumes:
      - '{{ jwt_secret_path }}:/execution-auth.jwt:ro'
      - '{{ ephemery_data_dir }}/el:/data'
    command: >
      --datadir=/data
      --http
      --http.addr=0.0.0.0
      --http.api=engine,eth,web3,net
      --http.port=8545
      --http.vhosts=*
      --ws
      --ws.addr=0.0.0.0
      --ws.origins=*
      --ws.api=engine,eth,web3,net
      --ws.port=8546
      --metrics
      --metrics.addr=0.0.0.0
      --metrics.port=6060
      --authrpc.jwtsecret=/execution-auth.jwt
      --authrpc.addr=0.0.0.0
      --authrpc.port=8551
      --authrpc.vhosts=*
  when: not client_skip
EOF
  elif [ "$el" = "besu" ]; then
    cat >> "$dir/molecule.yaml" << EOF

- name: 🚀 Start Besu (Execution Client)
  community.docker.docker_container:
    name: '{{ network }}-besu'
    image: 'pk910/ephemery-besu:23.10.0'
    state: started
    pull: true
    restart_policy: unless-stopped
    network_mode: host
    memory: '{{ el_memory_limit }}'
    volumes:
      - '{{ jwt_secret_path }}:/execution-auth.jwt:ro'
      - '{{ ephemery_data_dir }}/el:/data'
    command: >
      --data-path=/data
      --rpc-http-enabled=true
      --rpc-http-host=0.0.0.0
      --rpc-http-port=8545
      --rpc-http-cors-origins="*"
      --rpc-ws-enabled=true
      --rpc-ws-host=0.0.0.0
      --rpc-ws-port=8546
      --host-allowlist="*"
      --engine-rpc-enabled=true
      --engine-host-allowlist="*"
      --engine-jwt-secret=/execution-auth.jwt
      --engine-rpc-port=8551
      --metrics-enabled=true
      --metrics-host=0.0.0.0
      --metrics-port=9545
  when: not client_skip
EOF
  elif [ "$el" = "nethermind" ]; then
    cat >> "$dir/molecule.yaml" << EOF

- name: 🚀 Start Nethermind (Execution Client)
  community.docker.docker_container:
    name: '{{ network }}-nethermind'
    image: 'pk910/ephemery-nethermind:v1.25.2'
    state: started
    pull: true
    restart_policy: unless-stopped
    network_mode: host
    memory: '{{ el_memory_limit }}'
    volumes:
      - '{{ jwt_secret_path }}:/execution-auth.jwt:ro'
      - '{{ ephemery_data_dir }}/el:/data'
    command: >
      --datadir=/data
      --Network.DiscoveryPort=30303
      --Network.P2PPort=30303
      --JsonRpc.Enabled=true
      --JsonRpc.Host=0.0.0.0
      --JsonRpc.Port=8545
      --JsonRpc.JwtSecretFile=/execution-auth.jwt
      --JsonRpc.EnabledModules=[Web3,Eth,Subscribe,Net,Trace]
      --Metrics.Enabled=true
      --Metrics.ExposePort=9091
  when: not client_skip
EOF
  elif [ "$el" = "reth" ]; then
    cat >> "$dir/molecule.yaml" << EOF

- name: 🚀 Start Reth (Execution Client)
  community.docker.docker_container:
    name: '{{ network }}-reth'
    image: 'pk910/ephemery-reth:v0.1.0-alpha.11'
    state: started
    pull: true
    restart_policy: unless-stopped
    network_mode: host
    memory: '{{ el_memory_limit }}'
    volumes:
      - '{{ jwt_secret_path }}:/execution-auth.jwt:ro'
      - '{{ ephemery_data_dir }}/el:/data'
    command: >
      --datadir=/data
      --http
      --http.addr=0.0.0.0
      --http.port=8545
      --http.api=eth,net,web3
      --ws
      --ws.addr=0.0.0.0
      --ws.port=8546
      --metrics=0.0.0.0:9001
      --authrpc.addr=0.0.0.0
      --authrpc.port=8551
      --authrpc.jwtsecret=/execution-auth.jwt
  when: not client_skip
EOF
  elif [ "$el" = "erigon" ]; then
    cat >> "$dir/molecule.yaml" << EOF

- name: 🚀 Start Erigon (Execution Client)
  community.docker.docker_container:
    name: '{{ network }}-erigon'
    image: 'pk910/ephemery-erigon:v2.55.1'
    state: started
    pull: true
    restart_policy: unless-stopped
    network_mode: host
    memory: '{{ el_memory_limit }}'
    volumes:
      - '{{ jwt_secret_path }}:/execution-auth.jwt:ro'
      - '{{ ephemery_data_dir }}/el:/data'
    command: >
      --datadir=/data
      --http
      --http.addr=0.0.0.0
      --http.port=8545
      --http.api=eth,erigon,web3,net,debug,trace,txpool
      --ws
      --private.api.addr=0.0.0.0:9090
      --metrics
      --metrics.addr=0.0.0.0
      --metrics.port=6060
      --authrpc.addr=0.0.0.0
      --authrpc.port=8551
      --authrpc.jwtsecret=/execution-auth.jwt
      --p2p.allowed-ports=30303,30304
  when: not client_skip
EOF
  fi

  # Add CL client specific container configuration
  if [ "$cl" = "lighthouse" ]; then
    cat >> "$dir/molecule.yaml" << EOF

- name: 🚀 Start Lighthouse (Consensus Client)
  community.docker.docker_container:
    name: '{{ network }}-lighthouse'
    image: 'pk910/ephemery-lighthouse:v4.6.0'
    state: started
    pull: true
    restart_policy: unless-stopped
    network_mode: host
    memory: '{{ cl_memory_limit }}'
    volumes:
      - '{{ jwt_secret_path }}:/execution-auth.jwt:ro'
      - '{{ ephemery_data_dir }}/cl:/data'
    command: >
      --datadir=/data
      --network=ephemery
      --execution-endpoint=http://127.0.0.1:8551
      --execution-jwt=/execution-auth.jwt
      --http
      --http-address=0.0.0.0
      --http-port=5052
      --metrics
      --metrics-address=0.0.0.0
      --metrics-port=5054
      --disable-deposit-contract-sync
  when: not client_skip
EOF
  elif [ "$cl" = "teku" ]; then
    cat >> "$dir/molecule.yaml" << EOF

- name: 🚀 Start Teku (Consensus Client)
  community.docker.docker_container:
    name: '{{ network }}-teku'
    image: 'pk910/ephemery-teku:24.1.0'
    state: started
    pull: true
    restart_policy: unless-stopped
    network_mode: host
    memory: '{{ cl_memory_limit }}'
    volumes:
      - '{{ jwt_secret_path }}:/execution-auth.jwt:ro'
      - '{{ ephemery_data_dir }}/cl:/data'
    command: >
      --data-path=/data
      --network=ephemery
      --logging=INFO
      --rest-api-enabled=true
      --rest-api-interface=0.0.0.0
      --rest-api-port=5052
      --metrics-enabled=true
      --metrics-interface=0.0.0.0
      --metrics-port=8008
      --ee-endpoint=http://127.0.0.1:8551
      --ee-jwt-secret-file=/execution-auth.jwt
  when: not client_skip
EOF
  elif [ "$cl" = "prysm" ]; then
    cat >> "$dir/molecule.yaml" << EOF

- name: 🚀 Start Prysm (Consensus Client)
  community.docker.docker_container:
    name: '{{ network }}-prysm'
    image: 'pk910/ephemery-prysm:v4.1.1'
    state: started
    pull: true
    restart_policy: unless-stopped
    network_mode: host
    memory: '{{ cl_memory_limit }}'
    volumes:
      - '{{ jwt_secret_path }}:/execution-auth.jwt:ro'
      - '{{ ephemery_data_dir }}/cl:/data'
    command: >
      --datadir=/data
      --ephemery-network
      --accept-terms-of-use
      --rpc-host=0.0.0.0
      --rpc-port=3500
      --grpc-gateway-host=0.0.0.0
      --grpc-gateway-port=3501
      --monitoring-host=0.0.0.0
      --monitoring-port=9999
      --p2p-tcp-port=9001
      --p2p-udp-port=9001
      --execution-endpoint=http://127.0.0.1:8551
      --jwt-secret=/execution-auth.jwt
      --disable-blst
  when: not client_skip
EOF
  elif [ "$cl" = "lodestar" ]; then
    cat >> "$dir/molecule.yaml" << EOF

- name: 🚀 Start Lodestar (Consensus Client)
  community.docker.docker_container:
    name: '{{ network }}-lodestar'
    image: 'pk910/ephemery-lodestar:v1.13.0'
    state: started
    pull: true
    restart_policy: unless-stopped
    network_mode: host
    memory: '{{ cl_memory_limit }}'
    volumes:
      - '{{ jwt_secret_path }}:/execution-auth.jwt:ro'
      - '{{ ephemery_data_dir }}/cl:/data'
    command: >
      beacon
      --dataDir=/data
      --ephemery-network
      --execution.urls=http://127.0.0.1:8551
      --jwt-secret=/execution-auth.jwt
      --rest.address=0.0.0.0
      --rest.port=5052
      --metrics.enabled=true
      --metrics.address=0.0.0.0
      --metrics.port=9000
  when: not client_skip
EOF
  fi

  # Replace placeholders with actual values in molecule.yaml
  sed -i "" "s/ELNAME/${el}/g" "$dir/molecule.yaml"
  sed -i "" "s/CLNAME/${cl}/g" "$dir/molecule.yaml"

  # Create empty converge.yaml and verify.yaml files if they don't exist
  touch "$dir/converge.yaml"
  if [ ! -s "$dir/converge.yaml" ]; then
    # Add document start marker to empty files
    echo "---" > "$dir/converge.yaml"
  fi

  touch "$dir/verify.yaml"
  if [ ! -s "$dir/verify.yaml" ]; then
    # Add document start marker to empty files
    echo "---" > "$dir/verify.yaml"
  fi
}

# Generate all client task combinations
for el in $EL_CLIENTS; do
  for cl in $CL_CLIENTS; do
    # Check if the directory already exists with all required files
    if [ -d "tasks/clients/${el}-${cl}" ] &&
       [ -f "tasks/clients/${el}-${cl}/firewall.yaml" ] &&
       [ -f "tasks/clients/${el}-${cl}/molecule.yaml" ] &&
       [ -f "tasks/clients/${el}-${cl}/converge.yaml" ] &&
       [ -f "tasks/clients/${el}-${cl}/verify.yaml" ] &&
       [ -s "tasks/clients/${el}-${cl}/firewall.yaml" ]; then
      echo "Skipping existing client tasks: ${el}-${cl}"
    else
      create_client_tasks "$el" "$cl"
    fi
  done
done

echo "All client task files have been created successfully."
