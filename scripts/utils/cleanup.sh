#!/bin/bash

# Utility script to clean up Ephemery resources
set -e

echo "Ephemery Cleanup Utility"
echo "========================"
echo "This script will stop and remove Ephemery containers and optionally delete data"

# Function to display help
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -d, --data               Also remove data directories"
    echo "  -h, --help               Display this help message"
    echo
    echo "Examples:"
    echo "  $0                       # Stop containers only"
    echo "  $0 --data                # Stop containers and remove data"
}

# Parse command line options
REMOVE_DATA=false

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d|--data)
            REMOVE_DATA=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Stop and remove containers
echo "Stopping and removing Ephemery containers..."
docker stop ephemery-geth ephemery-lighthouse ephemery-validator-lighthouse 2>/dev/null || true
docker rm -f ephemery-geth ephemery-lighthouse ephemery-validator-lighthouse 2>/dev/null || true

echo "Containers removed successfully"

# Remove data if requested
if [ "$REMOVE_DATA" = true ]; then
    echo "Removing Ephemery data directories..."

    # Determine base directories
    DEFAULT_DIR="$HOME/ephemery-demo"
    LOCAL_DIR="$HOME/ephemery-local"

    # Ask for confirmation
    read -p "This will delete all data in $DEFAULT_DIR and $LOCAL_DIR. Continue? (y/N): " CONFIRM
    if [[ $CONFIRM == [yY] ]]; then
        rm -rf "$DEFAULT_DIR" 2>/dev/null || true
        rm -rf "$LOCAL_DIR" 2>/dev/null || true
        echo "Data directories removed successfully"
    else
        echo "Data removal cancelled"
    fi
fi

echo "Cleanup complete"
