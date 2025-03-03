#!/usr/bin/env bash

# A script to test if Ansible collections can be loaded properly

set -e

# Create a temporary playbook
TEMP_DIR=$(mktemp -d)
TEMP_PLAYBOOK="$TEMP_DIR/test-collections.yaml"

cat > "$TEMP_PLAYBOOK" << 'EOF'
---
- name: Test Collection Loading
  hosts: localhost
  connection: local
  gather_facts: false
  tasks:
    - name: Test community.docker module
      community.docker.docker_container:
        name: test-container
        image: ubuntu:latest
        state: absent
      check_mode: true
      when: false
      register: docker_test

    - name: Test ansible.posix module
      ansible.posix.firewalld:
        port: 80/tcp
        permanent: false
        state: disabled
      check_mode: true
      when: false
      register: firewalld_test
      
    - name: Test community.general module
      community.general.ufw:
        port: 22
        rule: allow
      check_mode: true
      when: false
      register: ufw_test
        
    - name: Print results
      ansible.builtin.debug:
        msg: "All collection modules loaded successfully"
EOF

# Run the playbook with --syntax-check to test collection loading
echo "Testing collection loading..."
ansible-playbook "$TEMP_PLAYBOOK" --syntax-check

# Clean up
rm -rf "$TEMP_DIR"

echo "✅ All collections loaded successfully!" 