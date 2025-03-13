#!/usr/bin/env python3
"""
Validator Metrics API for Ephemery
==================================
A RESTful API that exposes validator performance metrics to the dashboard.
"""

import datetime
import json
import logging
import os
import subprocess
import time
from pathlib import Path

import requests
from flask import Flask, Response, jsonify, request, send_from_directory
from flask_cors import CORS

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("/var/log/ephemery/validator_api.log"),
        logging.StreamHandler(),
    ],
)

logger = logging.getLogger("validator-metrics-api")


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
    config["EPHEMERY_METRICS_DIR"] = os.environ.get(
        "EPHEMERY_METRICS_DIR",
        config.get(
            "EPHEMERY_METRICS_DIR",
            os.path.join(config["EPHEMERY_BASE_DIR"], "data/metrics"),
        ),
    )
    config["EPHEMERY_SCRIPTS_DIR"] = os.environ.get(
        "EPHEMERY_SCRIPTS_DIR",
        config.get(
            "EPHEMERY_SCRIPTS_DIR", os.path.join(config["EPHEMERY_BASE_DIR"], "scripts")
        ),
    )

    return config


# Load configuration
config = load_config()

# Configuration
BASE_DIR = config["EPHEMERY_BASE_DIR"]
METRICS_DIR = config["EPHEMERY_METRICS_DIR"]
SCRIPT_DIR = config["EPHEMERY_SCRIPTS_DIR"]

# Ensure metrics directory exists
os.makedirs(METRICS_DIR, exist_ok=True)

# Create Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Metrics cache to reduce filesystem reads
metrics_cache = {
    "last_updated": None,
    "data": None,
    "cache_time": 60,  # Cache time in seconds
}

# Default beacon and validator endpoints
BEACON_ENDPOINT = os.environ.get("BEACON_NODE_ENDPOINT", "http://localhost:5052")
VALIDATOR_ENDPOINT = os.environ.get("VALIDATOR_ENDPOINT", "http://localhost:5062")


def run_performance_check():
    """Run the performance check script and return the output."""
    logger.info("Running validator performance check...")

    try:
        script_path = os.path.join(
            SCRIPT_DIR, "monitoring/advanced_validator_monitoring.sh"
        )

        if not os.path.exists(script_path):
            logger.error(f"Performance script not found at {script_path}")
            return {"error": "Performance script not found"}, 500

        # Run the script with --check option
        result = subprocess.run(
            [script_path, "--check", "--verbose"],
            capture_output=True,
            text=True,
            check=False,
        )

        if result.returncode != 0:
            logger.error(f"Performance check failed: {result.stderr}")
            return {"error": f"Performance check failed: {result.stderr}"}, 500

        logger.info("Performance check completed successfully")
        return {"success": True, "output": result.stdout}, 200

    except Exception as e:
        logger.exception("Error running performance check")
        return {"error": str(e)}, 500


def get_validator_metrics():
    """Get validator metrics from cache or fetch fresh data."""
    now = time.time()

    # Check if we have a valid cache
    if (
        metrics_cache["last_updated"]
        and metrics_cache["data"]
        and now - metrics_cache["last_updated"] < metrics_cache["cache_time"]
    ):
        logger.debug("Returning cached metrics")
        return metrics_cache["data"]

    logger.info("Fetching fresh validator metrics")

    # Define metrics file path
    metrics_file = os.path.join(METRICS_DIR, "validator_metrics.json")

    # Check if metrics file exists
    if not os.path.exists(metrics_file):
        logger.warning(f"Metrics file not found at {metrics_file}")

        # Try to run the validator monitoring script to generate metrics
        try:
            run_performance_check()
        except Exception as e:
            logger.exception("Failed to generate metrics")
            return None

        # Check if the file was created
        if not os.path.exists(metrics_file):
            logger.error("Failed to create metrics file")
            return None

    # Read metrics from file
    try:
        with open(metrics_file, "r") as f:
            metrics = json.load(f)

        # Update the cache
        metrics_cache["data"] = metrics
        metrics_cache["last_updated"] = now

        return metrics
    except Exception as e:
        logger.exception(f"Error reading metrics file: {e}")
        return None


def get_validator_history():
    """Get historical validator metrics."""
    history_file = os.path.join(METRICS_DIR, "history/validator_history.json")

    if not os.path.exists(history_file):
        logger.warning(f"History file not found at {history_file}")
        # Return empty history
        return []

    try:
        with open(history_file, "r") as f:
            history = json.load(f)
        return history
    except Exception as e:
        logger.exception(f"Error reading history file: {e}")
        return []


def get_validator_alerts():
    """Get validator alerts."""
    alerts_dir = os.path.join(METRICS_DIR, "alerts")
    alerts = []

    if not os.path.exists(alerts_dir):
        logger.warning(f"Alerts directory not found at {alerts_dir}")
        return alerts

    try:
        # List all alert files, sorted by most recent first
        alert_files = sorted(Path(alerts_dir).glob("alert_*.json"), reverse=True)

        # Only read the 10 most recent alerts
        for file_path in list(alert_files)[:10]:
            with open(file_path, "r") as f:
                alert = json.load(f)
                alerts.append(alert)

        return alerts
    except Exception as e:
        logger.exception(f"Error reading alerts: {e}")
        return []


def fetch_beacon_data():
    """Fetch data directly from the beacon node API."""
    try:
        # Get validator statuses from the beacon node
        response = requests.get(
            f"{BEACON_ENDPOINT}/eth/v1/beacon/states/head/validators", timeout=5
        )

        if response.status_code != 200:
            logger.error(f"Failed to fetch validator data: {response.status_code}")
            return None

        return response.json()
    except Exception as e:
        logger.exception(f"Error fetching beacon data: {e}")
        return None


def fetch_lighthouse_validator_data():
    """Fetch validator metrics from Lighthouse validator client."""
    try:
        response = requests.get(f"{VALIDATOR_ENDPOINT}/lighthouse/validators", timeout=5)

        if response.status_code != 200:
            logger.error(f"Failed to fetch validator data: {response.status_code}")
            return None

        return response.json()
    except Exception as e:
        logger.exception(f"Error fetching validator data: {e}")
        return None


@app.route("/api/metrics", methods=["GET"])
def api_metrics():
    """API endpoint to get current validator metrics."""
    metrics = get_validator_metrics()
    if metrics is None:
        return jsonify({"error": "Failed to retrieve metrics"}), 500
    return jsonify(metrics)


@app.route("/api/history", methods=["GET"])
def api_history():
    """API endpoint to get historical validator metrics."""
    history = get_validator_history()
    return jsonify(history)


@app.route("/api/alerts", methods=["GET"])
def api_alerts():
    """API endpoint to get validator alerts."""
    alerts = get_validator_alerts()
    return jsonify(alerts)


@app.route("/api/run_check", methods=["POST"])
def api_run_check():
    """API endpoint to trigger a validator performance check."""
    result, status_code = run_performance_check()
    return jsonify(result), status_code


@app.route("/api/validators/live", methods=["GET"])
def api_validators_live():
    """API endpoint to get live validator data from the beacon node."""
    # Try different sources in order of preference
    data = fetch_lighthouse_validator_data()
    if data is not None:
        return jsonify(data)

    data = fetch_beacon_data()
    if data is not None:
        return jsonify(data)

    return (
        jsonify({"error": "Failed to retrieve validator data from any source"}),
        500,
    )


@app.route("/api/status", methods=["GET"])
def api_status():
    """API endpoint to get the status of the validator metrics API."""
    status = {
        "timestamp": datetime.datetime.now().isoformat(),
        "api_version": "1.0.0",
        "beacon_node_endpoint": BEACON_ENDPOINT,
        "validator_endpoint": VALIDATOR_ENDPOINT,
        "metrics_dir": METRICS_DIR,
        "script_dir": SCRIPT_DIR,
        "metrics_cache_age": (
            time.time() - metrics_cache["last_updated"]
            if metrics_cache["last_updated"]
            else None
        ),
    }
    return jsonify(status)


@app.route("/")
def index():
    """Serve the index page."""
    return jsonify(
        {"message": "Validator Metrics API", "version": "1.0.0", "status": "running"}
    )


@app.route("/health")
def health():
    """Health check endpoint."""
    return jsonify({"status": "healthy"})


if __name__ == "__main__":
    # Set host to 0.0.0.0 to make the server externally visible
    port = int(os.environ.get("PORT", 5000))
    debug = os.environ.get("DEBUG", "false").lower() == "true"
    app.run(host="0.0.0.0", port=port, debug=debug)
