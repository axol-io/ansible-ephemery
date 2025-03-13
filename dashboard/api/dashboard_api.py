#!/usr/bin/env python3
# dashboard_api.py - API endpoints for the Ephemery Sync Dashboard

import json
import logging
import os
import subprocess
import sys

from flask import Flask, Response, jsonify, request, send_from_directory
from flask_cors import CORS

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("/var/log/ephemery/dashboard_api.log"),
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger("dashboard_api")


# Load configuration from environment or config file
def load_config():
    config = {}
    config_path = os.environ.get(
        "EPHEMERY_CONFIG_PATH", "/opt/ephemery/config/ephemery_paths.conf"
    )

    if os.path.exists(config_path):
        logger.info(f"Loading configuration from {config_path}")
        with open(config_path, "r") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    # Remove quotes if present
                    value = value.strip("\"'")
                    # Expand variables in the value
                    if "$" in value:
                        for k, v in config.items():
                            value = value.replace(f"${{{k}}}", v)
                    config[key] = value
        logger.info(f"Loaded configuration: {config}")
    else:
        logger.warning(
            f"Configuration file {config_path} not found, using environment variables"
        )

    # Set defaults from environment or use defaults
    config["EPHEMERY_BASE_DIR"] = os.environ.get(
        "EPHEMERY_BASE_DIR", config.get("EPHEMERY_BASE_DIR", "/opt/ephemery")
    )
    config["EPHEMERY_SCRIPTS_DIR"] = os.environ.get(
        "EPHEMERY_SCRIPTS_DIR",
        config.get(
            "EPHEMERY_SCRIPTS_DIR", os.path.join(config["EPHEMERY_BASE_DIR"], "scripts")
        ),
    )
    config["EPHEMERY_DATA_DIR"] = os.environ.get(
        "EPHEMERY_DATA_DIR",
        config.get(
            "EPHEMERY_DATA_DIR", os.path.join(config["EPHEMERY_BASE_DIR"], "data")
        ),
    )

    return config


# Load configuration
config = load_config()

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Configuration
SCRIPTS_DIR = config["EPHEMERY_SCRIPTS_DIR"]
DATA_DIR = config["EPHEMERY_DATA_DIR"]


# Utility functions
def run_command(command, timeout=60):
    """Run a shell command and return the result"""
    try:
        logger.info(f"Running command: {command}")
        result = subprocess.run(
            command, shell=True, capture_output=True, text=True, timeout=timeout
        )
        if result.returncode != 0:
            logger.error(
                f"Command failed with code {result.returncode}: {result.stderr}"
            )
            return {"success": False, "error": result.stderr}
        return {"success": True, "output": result.stdout}
    except subprocess.TimeoutExpired:
        logger.error(f"Command timed out after {timeout} seconds: {command}")
        return {"success": False, "error": f"Command timed out after {timeout} seconds"}
    except Exception as e:
        logger.error(f"Error running command: {e}")
        return {"success": False, "error": str(e)}


# API Routes
@app.route("/api/status", methods=["GET"])
def get_status():
    """Get current sync status for both clients"""
    lighthouse_status = run_command("curl -s http://localhost:5052/eth/v1/node/syncing")
    geth_status = run_command(
        'curl -s -X POST -H \'Content-Type: application/json\' --data \'{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}\' http://localhost:8545'
    )

    if lighthouse_status["success"] and geth_status["success"]:
        try:
            lighthouse_data = json.loads(lighthouse_status["output"])
            geth_data = json.loads(geth_status["output"])
            return jsonify(
                {"success": True, "lighthouse": lighthouse_data, "geth": geth_data}
            )
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing client response: {e}")
            return jsonify({"success": False, "error": "Error parsing client response"})
    else:
        return jsonify({"success": False, "error": "Error fetching client status"})


@app.route("/api/restart/lighthouse", methods=["POST"])
def restart_lighthouse():
    """Restart the Lighthouse client"""
    logger.info("Restarting Lighthouse client")
    result = run_command("docker restart ephemery-lighthouse")
    return jsonify(result)


@app.route("/api/check-sync-urls", methods=["GET"])
def check_sync_urls():
    """Check available checkpoint sync URLs"""
    logger.info("Checking checkpoint sync URLs")
    script_path = os.path.join(SCRIPTS_DIR, "check_sync_urls.sh")

    # Create the script if it doesn't exist
    if not os.path.exists(script_path):
        with open(script_path, "w") as f:
            f.write(
                """#!/bin/bash
# check_sync_urls.sh - Test various checkpoint sync URLs for accessibility

# List of URLs to test
URLS=(
  "https://checkpoint-sync.holesky.ethpandaops.io"
  "https://beaconstate-holesky.chainsafe.io"
  "https://checkpoint-sync.ephemery.dev"
  "https://checkpoint.ephemery.eth.limo"
  "https://checkpoint-sync.ephemery.ethpandaops.io"
)

echo "Testing checkpoint sync URLs..."
echo "================================"

for url in "${URLS[@]}"; do
  echo -n "Testing $url: "
  response=$(curl -s -o /dev/null -w "%{http_code}" "$url/eth/v1/beacon/states/finalized" -m 10)

  if [ "$response" = "200" ]; then
    echo "OK (200)"
  else
    echo "FAILED ($response)"
  fi
done

echo "================================"
echo "Test completed. Use the URL marked as OK in your configuration."
"""
            )
        os.chmod(script_path, 0o755)

    result = run_command(script_path)
    return jsonify(result)


@app.route("/api/run-fix-script", methods=["POST"])
def run_fix_script():
    """Run the fix_checkpoint_sync.sh script"""
    logger.info("Running fix_checkpoint_sync.sh script")
    script_path = os.path.join(SCRIPTS_DIR, "fix_checkpoint_sync.sh")

    if not os.path.exists(script_path):
        return jsonify({"success": False, "error": f"Script not found: {script_path}"})

    # This might take longer than the default timeout
    result = run_command(f"{script_path}", timeout=300)
    return jsonify(result)


@app.route("/api/history", methods=["GET"])
def get_history():
    """Get historical sync data with optional filtering"""
    try:
        # Get query parameters
        days = request.args.get("days", default=0, type=int)

        # Load history data
        history_file = os.path.join(DATA_DIR, "sync_history.json")
        if not os.path.exists(history_file):
            return (
                jsonify({"success": False, "error": "No history data available"}),
                404,
            )

        with open(history_file, "r") as f:
            history_data = json.load(f)

        # Filter by days if specified
        if days > 0:
            from datetime import datetime, timedelta

            cutoff_date = datetime.now() - timedelta(days=days)
            cutoff_str = cutoff_date.isoformat()
            filtered_data = [
                entry for entry in history_data if entry["timestamp"] >= cutoff_str
            ]
            return jsonify(filtered_data)

        # Return all data if no filtering
        return jsonify(history_data)

    except Exception as e:
        logger.error(f"Error retrieving history data: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500


# Main entry point
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
