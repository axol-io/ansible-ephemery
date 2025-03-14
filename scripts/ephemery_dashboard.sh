#!/bin/bash

# ephemery_dashboard.sh
# A terminal-based dashboard for monitoring Ephemery status and logs
# Usage: ./scripts/ephemery_dashboard.sh

# Check dependencies
if ! command -v tput &> /dev/null; then
  echo "Error: tput is required but not installed. Please install ncurses."
  exit 1
fi

# Default values
LOG_DIR="${EPHEMERY_LOGS_DIR:-/tmp/ephemery-test/logs}"
DATA_DIR="${EPHEMERY_DATA_DIR:-/tmp/ephemery-test/data}"
REFRESH_RATE=5
VIEW_MODE="summary"
SELECTED_CLIENT=""

# Colors and formatting
HEADER_BG=$(tput setab 4)
HEADER_FG=$(tput setaf 7)
NORMAL=$(tput sgr0)
BOLD=$(tput bold)
GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--data-dir)
      DATA_DIR="$2"
      shift 2
      ;;
    -l|--log-dir)
      LOG_DIR="$2"
      shift 2
      ;;
    -r|--refresh)
      REFRESH_RATE="$2"
      shift 2
      ;;
    -v|--view)
      VIEW_MODE="$2"
      shift 2
      ;;
    -c|--client)
      SELECTED_CLIENT="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -d, --data-dir DIR    Specify data directory (default: $DATA_DIR)"
      echo "  -l, --log-dir DIR     Specify logs directory (default: $LOG_DIR)"
      echo "  -r, --refresh SECONDS Refresh rate in seconds (default: 5)"
      echo "  -v, --view MODE       View mode: summary, logs, status (default: summary)"
      echo "  -c, --client CLIENT   Client to focus on: geth, lighthouse, validator"
      echo "  -h, --help            Show this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use -h or --help for usage information"
      exit 1
      ;;
  esac
done

# Get terminal dimensions
get_terminal_size() {
  TERM_COLS=$(tput cols)
  TERM_ROWS=$(tput lines)
}

# Clear screen and move cursor to top-left
clear_screen() {
  tput clear
  tput cup 0 0
}

# Draw a header
draw_header() {
  local header_text="$1"
  local width=$2
  printf "%s%s%s%s%s\n" "$HEADER_BG" "$HEADER_FG" "$BOLD" "$(printf "%-${width}s" " $header_text")" "$NORMAL"
}

# Draw a divider
draw_divider() {
  local width=$1
  local char=${2:-"-"}
  printf "%s\n" "$(printf "%${width}s" | tr " " "$char")"
}

# Format timestamp
format_timestamp() {
  local timestamp=$1
  date -r "$timestamp" "+%Y-%m-%d %H:%M:%S"
}

# Check if a service is running
is_service_running() {
  local service=$1
  if [ -f "$DATA_DIR/$service.pid" ]; then
    local pid=$(cat "$DATA_DIR/$service.pid")
    if ps -p "$pid" > /dev/null; then
      return 0
    fi
  fi
  return 1
}

# Get service status
get_service_status() {
  local service=$1
  if is_service_running "$service"; then
    echo -e "${GREEN}Running${NORMAL}"
  else
    echo -e "${RED}Stopped${NORMAL}"
  fi
}

# Get log file last modified time
get_log_last_modified() {
  local log_file=$1
  if [ -f "$log_file" ]; then
    local timestamp=$(stat -f "%m" "$log_file")
    format_timestamp "$timestamp"
  else
    echo "N/A"
  fi
}

# Get last logs for a service
get_last_logs() {
  local service=$1
  local lines=${2:-5}
  local log_file="$LOG_DIR/$service.log"
  
  if [ -f "$log_file" ]; then
    tail -n "$lines" "$log_file"
  else
    echo "No log file found for $service"
  fi
}

# Get error logs for a service
get_error_logs() {
  local service=$1
  local lines=${2:-5}
  local log_file="$LOG_DIR/$service.log"
  
  if [ -f "$log_file" ]; then
    grep -i "error\|warn\|fatal" "$log_file" | tail -n "$lines"
  else
    echo "No log file found for $service"
  fi
}

# Get sync status for a service
get_sync_status() {
  local service=$1
  local log_file="$LOG_DIR/$service.log"
  
  if [ -f "$log_file" ]; then
    local latest_sync=$(grep -i "sync" "$log_file" | tail -n 1)
    if [ -n "$latest_sync" ]; then
      echo "$latest_sync"
    else
      echo "No sync information found"
    fi
  else
    echo "No log file found for $service"
  fi
}

# Display summary view
display_summary() {
  get_terminal_size
  clear_screen
  
  draw_header "Ephemery Dashboard - Summary View" $TERM_COLS
  echo "Refresh interval: ${REFRESH_RATE}s | Press Ctrl+C to exit"
  draw_divider $TERM_COLS
  
  # Display services status
  printf "%-15s %-12s %-30s\n" "Service" "Status" "Last Log Update"
  draw_divider $TERM_COLS "-"
  
  for service in geth lighthouse validator; do
    local status=$(get_service_status "$service")
    local last_update=$(get_log_last_modified "$LOG_DIR/$service.log")
    printf "%-15s %-12s %-30s\n" "$service" "$status" "$last_update"
  done
  
  draw_divider $TERM_COLS
  
  # Display latest logs
  echo "Latest Logs:"
  draw_divider $TERM_COLS "-"
  
  for service in geth lighthouse validator; do
    echo -e "${BOLD}${service}:${NORMAL}"
    get_last_logs "$service" 3 | while read -r line; do
      # Colorize log lines
      if echo "$line" | grep -q -i "error\|fatal"; then
        echo -e "${RED}$line${NORMAL}"
      elif echo "$line" | grep -q -i "warn"; then
        echo -e "${YELLOW}$line${NORMAL}"
      elif echo "$line" | grep -q -i "sync\|syncing"; then
        echo -e "${CYAN}$line${NORMAL}"
      else
        echo "$line"
      fi
    done
    echo ""
  done
  
  draw_divider $TERM_COLS
  echo "Sync Status:"
  for service in geth lighthouse; do
    echo -e "${BOLD}${service}:${NORMAL} $(get_sync_status "$service")"
  done
}

# Display logs view
display_logs() {
  get_terminal_size
  clear_screen
  
  local service=${SELECTED_CLIENT:-geth}
  draw_header "Ephemery Dashboard - Logs View ($service)" $TERM_COLS
  echo "Refresh interval: ${REFRESH_RATE}s | Press Ctrl+C to exit"
  draw_divider $TERM_COLS
  
  local log_file="$LOG_DIR/$service.log"
  if [ -f "$log_file" ]; then
    local max_lines=$(($TERM_ROWS - 6))
    echo -e "${BOLD}Latest logs from $service:${NORMAL}"
    get_last_logs "$service" $max_lines | while read -r line; do
      # Colorize log lines
      if echo "$line" | grep -q -i "error\|fatal"; then
        echo -e "${RED}$line${NORMAL}"
      elif echo "$line" | grep -q -i "warn"; then
        echo -e "${YELLOW}$line${NORMAL}"
      elif echo "$line" | grep -q -i "sync\|syncing"; then
        echo -e "${CYAN}$line${NORMAL}"
      else
        echo "$line"
      fi
    done
  else
    echo "No log file found for $service"
  fi
}

# Display status view
display_status() {
  get_terminal_size
  clear_screen
  
  draw_header "Ephemery Dashboard - Status View" $TERM_COLS
  echo "Refresh interval: ${REFRESH_RATE}s | Press Ctrl+C to exit"
  draw_divider $TERM_COLS
  
  # Check data directory
  if [ -d "$DATA_DIR" ]; then
    echo -e "${GREEN}✓${NORMAL} Data directory: $DATA_DIR"
    local data_size=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)
    echo "   Size: $data_size"
  else
    echo -e "${RED}✗${NORMAL} Data directory not found: $DATA_DIR"
  fi
  
  # Check logs directory
  if [ -d "$LOG_DIR" ]; then
    echo -e "${GREEN}✓${NORMAL} Logs directory: $LOG_DIR"
    local log_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1)
    echo "   Size: $log_size"
    local log_count=$(find "$LOG_DIR" -type f -name "*.log" 2>/dev/null | wc -l)
    echo "   Log files: $log_count"
  else
    echo -e "${RED}✗${NORMAL} Logs directory not found: $LOG_DIR"
  fi
  
  draw_divider $TERM_COLS
  
  # Display services status with more details
  echo "Services Status:"
  draw_divider $TERM_COLS "-"
  
  for service in geth lighthouse validator; do
    echo -e "${BOLD}${service}:${NORMAL}"
    if is_service_running "$service"; then
      local pid=$(cat "$DATA_DIR/$service.pid" 2>/dev/null)
      local uptime=""
      local memory=""
      local cpu=""
      
      if [ -n "$pid" ]; then
        # Get process info
        if ps -p "$pid" > /dev/null; then
          uptime=$(ps -p "$pid" -o etime= 2>/dev/null)
          memory=$(ps -p "$pid" -o rss= 2>/dev/null)
          memory=$((memory / 1024)) # Convert to MB
          cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null)
          
          echo -e "   ${GREEN}Running${NORMAL} (PID: $pid)"
          echo "   Uptime: $uptime"
          echo "   Memory: ${memory}MB"
          echo "   CPU: ${cpu}%"
        else
          echo -e "   ${RED}Not running${NORMAL} (PID file exists but process not found)"
        fi
      else
        echo -e "   ${RED}Not running${NORMAL} (No PID file)"
      fi
    else
      echo -e "   ${RED}Not running${NORMAL}"
    fi
    
    # Check log file
    local log_file="$LOG_DIR/$service.log"
    if [ -f "$log_file" ]; then
      local log_size=$(du -h "$log_file" 2>/dev/null | cut -f1)
      local last_modified=$(get_log_last_modified "$log_file")
      echo "   Log: $log_file"
      echo "   Log size: $log_size"
      echo "   Last update: $last_modified"
      
      # Show error count
      local error_count=$(grep -i "error" "$log_file" 2>/dev/null | wc -l)
      local warn_count=$(grep -i "warn" "$log_file" 2>/dev/null | wc -l)
      echo "   Errors: $error_count, Warnings: $warn_count"
    else
      echo "   Log not found: $log_file"
    fi
    
    echo ""
  done
  
  draw_divider $TERM_COLS
  echo "System Status:"
  # Display system load and memory
  if command -v top &> /dev/null; then
    local load=$(uptime | awk -F'[a-z]:' '{ print $2}' | tr -d ',')
    echo "Load average:$load"
    
    # Memory info
    local mem_info=$(top -l 1 -s 0 | grep PhysMem)
    echo "Memory: $mem_info"
  fi
}

# Main dashboard loop
main() {
  trap 'tput cnorm; exit 0' INT TERM EXIT
  tput civis # Hide cursor
  
  while true; do
    case "$VIEW_MODE" in
      summary)
        display_summary
        ;;
      logs)
        display_logs
        ;;
      status)
        display_status
        ;;
      *)
        display_summary
        ;;
    esac
    
    sleep "$REFRESH_RATE"
  done
}

# Start the dashboard
main 