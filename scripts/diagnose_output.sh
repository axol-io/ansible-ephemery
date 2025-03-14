#!/bin/bash

# diagnose_output.sh
# A script to diagnose and fix common Ansible output issues
# Usage: ./scripts/diagnose_output.sh

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}Ephemery Ansible Output Diagnostics${NC}"
echo "This script will help diagnose and fix common Ansible output issues."
echo ""

# Check if ansible.cfg exists
if [ ! -f "ansible.cfg" ]; then
  echo -e "${RED}Error: ansible.cfg not found in the current directory${NC}"
  echo "Please run this script from the root of the Ephemery project."
  exit 1
fi

# Check current callback plugin
current_callback=$(grep "stdout_callback" ansible.cfg | awk -F "=" '{print $2}' | tr -d ' ')
echo -e "${BLUE}Current stdout callback:${NC} $current_callback"

# Check if our scripts exist
filter_script_exists=false
if [ -f "scripts/filter_ansible_output.sh" ]; then
  filter_script_exists=true
  echo -e "${GREEN}✓ Filter script found${NC}"
else
  echo -e "${RED}✗ Filter script not found${NC}"
fi

run_script_exists=false
if [ -f "scripts/run_ansible.sh" ]; then
  run_script_exists=true
  echo -e "${GREEN}✓ Run script found${NC}"
else
  echo -e "${RED}✗ Run script not found${NC}"
fi

monitor_script_exists=false
if [ -f "scripts/monitor_logs.sh" ]; then
  monitor_script_exists=true
  echo -e "${GREEN}✓ Monitor logs script found${NC}"
else
  echo -e "${RED}✗ Monitor logs script not found${NC}"
fi

# Check if scripts are executable
if [ "$filter_script_exists" = true ] && [ ! -x "scripts/filter_ansible_output.sh" ]; then
  echo -e "${YELLOW}! Filter script is not executable${NC}"
  echo "  Run: chmod +x scripts/filter_ansible_output.sh"
fi

if [ "$run_script_exists" = true ] && [ ! -x "scripts/run_ansible.sh" ]; then
  echo -e "${YELLOW}! Run script is not executable${NC}"
  echo "  Run: chmod +x scripts/run_ansible.sh"
fi

if [ "$monitor_script_exists" = true ] && [ ! -x "scripts/monitor_logs.sh" ]; then
  echo -e "${YELLOW}! Monitor logs script is not executable${NC}"
  echo "  Run: chmod +x scripts/monitor_logs.sh"
fi

# Check logs directory
logs_dir="${EPHEMERY_LOGS_DIR:-/tmp/ephemery-test/logs}"
if [ -d "$logs_dir" ]; then
  echo -e "${GREEN}✓ Logs directory found:${NC} $logs_dir"
  log_count=$(find "$logs_dir" -type f -name "*.log" 2>/dev/null | wc -l)
  echo "  $log_count log files found"
else
  echo -e "${YELLOW}! Logs directory not found:${NC} $logs_dir"
  echo "  This is normal if you haven't run Ephemery yet."
fi

# Check terminal color support
if [ -t 1 ]; then
  colors=$(tput colors 2>/dev/null)
  if [ -n "$colors" ] && [ "$colors" -ge 8 ]; then
    echo -e "${GREEN}✓ Terminal supports colors${NC}"
  else
    echo -e "${YELLOW}! Terminal may not support colors${NC}"
    echo "  This may affect the display of colored output."
  fi
else
  echo -e "${YELLOW}! Not running in a terminal${NC}"
  echo "  Color output may not display correctly."
fi

echo ""
echo -e "${BOLD}Recommendations:${NC}"

# Recommend callback plugin
echo -e "${BLUE}Callback Plugin:${NC}"
case "$current_callback" in
  minimal)
    echo "  Current: minimal (concise output, good for most cases)"
    echo "  Other options:"
    echo "    - yaml: structured output, good for debugging"
    echo "    - json: machine-readable output"
    echo "    - unixy: human-readable output with progress bars"
    ;;
  yaml)
    echo "  Current: yaml (structured output, good for debugging)"
    echo "  Consider switching to 'minimal' for less verbose output:"
    echo "    Edit ansible.cfg and set stdout_callback = minimal"
    ;;
  json)
    echo "  Current: json (machine-readable output)"
    echo "  Consider switching to 'minimal' for human-readable output:"
    echo "    Edit ansible.cfg and set stdout_callback = minimal"
    ;;
  *)
    echo "  Current: $current_callback"
    echo "  Consider trying 'minimal' for concise output:"
    echo "    Edit ansible.cfg and set stdout_callback = minimal"
    ;;
esac

# Recommend output management approach
echo -e "${BLUE}Output Management:${NC}"
if [ "$filter_script_exists" = true ] && [ "$run_script_exists" = true ]; then
  echo "  Use the wrapper script for most cases:"
  echo "    ./scripts/run_ansible.sh playbooks/your_playbook.yaml -f -l"
  echo "  For detailed debugging:"
  echo "    ./scripts/run_ansible.sh playbooks/your_playbook.yaml -vvv -l"
  echo "  For minimal output:"
  echo "    ./scripts/run_ansible.sh playbooks/your_playbook.yaml -s"
elif [ "$filter_script_exists" = true ]; then
  echo "  Use the filter script to reduce output:"
  echo "    ansible-playbook playbooks/your_playbook.yaml | ./scripts/filter_ansible_output.sh"
else
  echo "  Basic output management:"
  echo "    ansible-playbook playbooks/your_playbook.yaml | grep -E 'TASK|PLAY|fatal|failed='"
fi

# Recommend log monitoring approach
echo -e "${BLUE}Log Monitoring:${NC}"
if [ "$monitor_script_exists" = true ]; then
  echo "  Use the monitor script to view logs:"
  echo "    ./scripts/monitor_logs.sh -c geth"
  echo "    ./scripts/monitor_logs.sh -c lighthouse"
  echo "    ./scripts/monitor_logs.sh -c validator"
else
  echo "  Basic log monitoring:"
  echo "    tail -f $logs_dir/geth.log"
  echo "    tail -f $logs_dir/lighthouse.log"
  echo "    tail -f $logs_dir/validator.log"
fi

echo ""
echo -e "${BOLD}For more information:${NC}"
echo "  See docs/managing_ansible_output.md for detailed guidance" 