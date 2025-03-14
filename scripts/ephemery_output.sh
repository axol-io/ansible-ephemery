#!/bin/bash

# ephemery_output.sh
# A unified launcher script for all Ephemery output management tools
# Usage: ./scripts/ephemery_output.sh [command] [options]

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Ensure all scripts are executable
chmod +x "$SCRIPT_DIR/filter_ansible_output.sh" 2>/dev/null
chmod +x "$SCRIPT_DIR/run_ansible.sh" 2>/dev/null
chmod +x "$SCRIPT_DIR/monitor_logs.sh" 2>/dev/null
chmod +x "$SCRIPT_DIR/diagnose_output.sh" 2>/dev/null
chmod +x "$SCRIPT_DIR/ephemery_dashboard.sh" 2>/dev/null
chmod +x "$SCRIPT_DIR/analyze_ansible_output.sh" 2>/dev/null

# Display help
show_help() {
  echo -e "${BOLD}Ephemery Output Management Toolkit${NC}"
  echo "A unified interface for all Ephemery output management tools"
  echo ""
  echo "Usage: $0 [command] [options]"
  echo ""
  echo "Commands:"
  echo "  run <playbook> [options]   Run an Ansible playbook with output management"
  echo "  filter                     Filter Ansible output (from stdin)"
  echo "  monitor [options]          Monitor Ephemery logs in real-time"
  echo "  dashboard [options]        Show the Ephemery dashboard"
  echo "  analyze [file]             Analyze Ansible output"
  echo "  diagnose                   Diagnose and fix common output issues"
  echo "  help                       Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 run playbooks/deploy_ephemery_retention.yaml -f -l"
  echo "  ansible-playbook playbook.yml | $0 filter"
  echo "  $0 monitor -c geth"
  echo "  $0 dashboard -v status"
  echo "  $0 analyze logs/ansible-output.log"
  echo "  $0 diagnose"
  echo ""
  echo "For command-specific help, use: $0 <command> --help"
}

# No arguments provided, show help
if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

# Parse command
COMMAND="$1"
shift

case "$COMMAND" in
  run)
    if [ $# -eq 0 ] || [ "$1" == "--help" ]; then
      echo -e "${BOLD}Ephemery Output Management Toolkit - Run Command${NC}"
      echo "Run an Ansible playbook with output management"
      echo ""
      echo "Usage: $0 run <playbook> [options]"
      echo ""
      echo "Options:"
      echo "  -f, --filter        Filter output to show only important information"
      echo "  -l, --log           Log output to file (in logs directory)"
      echo "  -v, --verbose       Increase verbosity (single level)"
      echo "  -vv, --more-verbose Increase verbosity (two levels)"
      echo "  -vvv, --debug       Maximum verbosity for debugging"
      echo "  -s, --summary-only  Show only the play recap summary"
      echo "  -q, --quiet         Suppress all output except errors"
      echo "  -c, --callback      Specify callback plugin (minimal, yaml, json, unixy, dense)"
      echo "  -e, --extra-args    Pass additional arguments to ansible-playbook"
      echo ""
      echo "Examples:"
      echo "  $0 run playbooks/deploy_ephemery_retention.yaml -f -l"
      echo "  $0 run playbooks/deploy_validator_management.yaml -s"
      exit 0
    fi
    
    exec "$SCRIPT_DIR/run_ansible.sh" "$@"
    ;;
    
  filter)
    if [ "$1" == "--help" ]; then
      echo -e "${BOLD}Ephemery Output Management Toolkit - Filter Command${NC}"
      echo "Filter Ansible output to show only important information"
      echo ""
      echo "Usage: ansible-playbook playbook.yml | $0 filter"
      echo "   or: $0 run <playbook> | $0 filter"
      echo ""
      echo "The filter script highlights important information and filters out noise."
      echo "It colorizes tasks, plays, errors, warnings, and Ephemery-specific patterns."
      exit 0
    fi
    
    exec "$SCRIPT_DIR/filter_ansible_output.sh"
    ;;
    
  monitor)
    if [ $# -eq 0 ] || [ "$1" == "--help" ]; then
      echo -e "${BOLD}Ephemery Output Management Toolkit - Monitor Command${NC}"
      echo "Monitor Ephemery logs in real-time"
      echo ""
      echo "Usage: $0 monitor [options]"
      echo ""
      echo "Options:"
      echo "  -d, --dir DIR       Specify logs directory"
      echo "  -f, --filter REGEX  Filter logs by regex pattern"
      echo "  -n, --no-follow     Don't follow logs (just show and exit)"
      echo "  -l, --lines LINES   Number of lines to show (default: 20)"
      echo "  -c, --client CLIENT Monitor specific client (geth, lighthouse, validator)"
      echo ""
      echo "Examples:"
      echo "  $0 monitor -c geth"
      echo "  $0 monitor -c lighthouse -f \"ERROR|WARN\""
      exit 0
    fi
    
    exec "$SCRIPT_DIR/monitor_logs.sh" "$@"
    ;;
    
  dashboard)
    if [ "$1" == "--help" ]; then
      echo -e "${BOLD}Ephemery Output Management Toolkit - Dashboard Command${NC}"
      echo "Show the Ephemery dashboard"
      echo ""
      echo "Usage: $0 dashboard [options]"
      echo ""
      echo "Options:"
      echo "  -d, --data-dir DIR    Specify data directory"
      echo "  -l, --log-dir DIR     Specify logs directory"
      echo "  -r, --refresh SECONDS Refresh rate in seconds (default: 5)"
      echo "  -v, --view MODE       View mode: summary, logs, status (default: summary)"
      echo "  -c, --client CLIENT   Client to focus on: geth, lighthouse, validator"
      echo ""
      echo "Examples:"
      echo "  $0 dashboard"
      echo "  $0 dashboard -v logs -c geth"
      echo "  $0 dashboard -v status"
      exit 0
    fi
    
    exec "$SCRIPT_DIR/ephemery_dashboard.sh" "$@"
    ;;
    
  analyze)
    if [ $# -eq 0 ] || [ "$1" == "--help" ]; then
      echo -e "${BOLD}Ephemery Output Management Toolkit - Analyze Command${NC}"
      echo "Analyze Ansible output for performance and error patterns"
      echo ""
      echo "Usage: $0 analyze [file]"
      echo "   or: cat ansible_output.log | $0 analyze"
      echo ""
      echo "Examples:"
      echo "  $0 analyze logs/ansible-output.log"
      echo "  $0 run playbooks/deploy_ephemery_retention.yaml | $0 analyze"
      exit 0
    fi
    
    exec "$SCRIPT_DIR/analyze_ansible_output.sh" "$@"
    ;;
    
  diagnose)
    if [ "$1" == "--help" ]; then
      echo -e "${BOLD}Ephemery Output Management Toolkit - Diagnose Command${NC}"
      echo "Diagnose and fix common output issues"
      echo ""
      echo "Usage: $0 diagnose"
      echo ""
      echo "The diagnose command checks for:"
      echo "  - Current callback plugin configuration"
      echo "  - Existence and permissions of output management scripts"
      echo "  - Logs directory and available log files"
      echo "  - Terminal color support"
      echo "  - And provides recommendations based on the current configuration"
      exit 0
    fi
    
    exec "$SCRIPT_DIR/diagnose_output.sh" "$@"
    ;;
    
  help)
    show_help
    ;;
    
  *)
    echo -e "${RED}Error: Unknown command '$COMMAND'${NC}"
    echo "Use '$0 help' for usage information"
    exit 1
    ;;
esac 