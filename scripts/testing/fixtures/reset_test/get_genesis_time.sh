#!/usr/bin/env bash
# Version: 1.0.0
#
# Script Name: get_genesis_time.sh
# Description: Gets the genesis time from the genesis file
# Author: Ephemery Team
# Created: 2025-03-17
# Last Modified: 2025-03-17
# Get the absolute path to the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Source the common library
source "${PROJECT_ROOT}/scripts/lib/common.sh"

get_genesis_time() {
  cat "/Users/droo/Documents/CODE/ansible-ephemery/scripts/testing/fixtures/reset_test/genesis_time.txt"
}
