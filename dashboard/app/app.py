#!/usr/bin/env python3
# app.py - Main Flask application for Ephemery checkpoint sync dashboard

import datetime
import json
import logging
import os
import time

import requests
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from flask import Flask, jsonify, render_template, request

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Configuration
LIGHTHOUSE_API = os.environ.get(
    "LIGHTHOUSE_API_URL", "http://host.docker.internal:5052"
)
GETH_API = os.environ.get("GETH_API_URL", "http://host.docker.internal:8545")
DATA_DIR = os.environ.get("DATA_DIR", "/app/data")

# Ensure data directory exists
os.makedirs(DATA_DIR, exist_ok=True)
SYNC_HISTORY_FILE = os.path.join(DATA_DIR, "sync_history.json")

# Initialize sync history if it doesn't exist
if not os.path.exists(SYNC_HISTORY_FILE):
    with open(SYNC_HISTORY_FILE, "w") as f:
        json.dump([], f)


def get_lighthouse_status():
    """Get Lighthouse sync status from API"""
    try:
        response = requests.get(f"{LIGHTHOUSE_API}/eth/v1/node/syncing", timeout=5)
        if response.status_code == 200:
            return response.json()
        else:
            logger.error(f"Failed to get Lighthouse status: {response.status_code}")
            return {
                "data": {
                    "is_syncing": None,
                    "head_slot": "Unknown",
                    "sync_distance": "Unknown",
                }
            }
    except Exception as e:
        logger.error(f"Error getting Lighthouse status: {str(e)}")
        return {
            "data": {
                "is_syncing": None,
                "head_slot": "Unknown",
                "sync_distance": "Unknown",
            }
        }


def get_geth_status():
    """Get Geth sync status from API"""
    try:
        payload = {"jsonrpc": "2.0", "method": "eth_syncing", "params": [], "id": 1}
        response = requests.post(GETH_API, json=payload, timeout=5)
        if response.status_code == 200:
            result = response.json().get("result", False)
            if isinstance(result, dict):
                return {
                    "is_syncing": True,
                    "current_block": int(result.get("currentBlock", "0x0"), 16),
                    "highest_block": int(result.get("highestBlock", "0x0"), 16),
                    "starting_block": int(result.get("startingBlock", "0x0"), 16),
                }
            elif result is False:
                # Not syncing, get the current block number
                block_response = requests.post(
                    GETH_API,
                    json={
                        "jsonrpc": "2.0",
                        "method": "eth_blockNumber",
                        "params": [],
                        "id": 1,
                    },
                    timeout=5,
                )
                if block_response.status_code == 200:
                    current_block = int(block_response.json().get("result", "0x0"), 16)
                    return {
                        "is_syncing": False,
                        "current_block": current_block,
                        "highest_block": current_block,
                        "starting_block": 0,
                    }
        return {
            "is_syncing": None,
            "current_block": "Unknown",
            "highest_block": "Unknown",
            "starting_block": "Unknown",
        }
    except Exception as e:
        logger.error(f"Error getting Geth status: {str(e)}")
        return {
            "is_syncing": None,
            "current_block": "Unknown",
            "highest_block": "Unknown",
            "starting_block": "Unknown",
        }


def update_sync_history():
    """Update sync history with current status"""
    try:
        lighthouse_status = get_lighthouse_status()
        geth_status = get_geth_status()

        timestamp = datetime.datetime.now().isoformat()

        # Load existing history
        with open(SYNC_HISTORY_FILE, "r") as f:
            history = json.load(f)

        # Add new entry
        history.append(
            {
                "timestamp": timestamp,
                "lighthouse": lighthouse_status.get("data", {}),
                "geth": geth_status,
            }
        )

        # Keep only last 1000 entries to prevent file from growing too large
        if len(history) > 1000:
            history = history[-1000:]

        # Save updated history
        with open(SYNC_HISTORY_FILE, "w") as f:
            json.dump(history, f)

        logger.info(f"Updated sync history at {timestamp}")
    except Exception as e:
        logger.error(f"Error updating sync history: {str(e)}")


# Routes
@app.route("/")
def index():
    """Main dashboard page"""
    return render_template("index.html")


@app.route("/api/status")
def status():
    """API endpoint for current status"""
    lighthouse_status = get_lighthouse_status()
    geth_status = get_geth_status()

    return jsonify(
        {
            "lighthouse": lighthouse_status.get("data", {}),
            "geth": geth_status,
            "timestamp": datetime.datetime.now().isoformat(),
        }
    )


@app.route("/api/history")
def history():
    """API endpoint for sync history"""
    try:
        # Optional parameters for filtering
        limit = request.args.get("limit", 100, type=int)

        with open(SYNC_HISTORY_FILE, "r") as f:
            full_history = json.load(f)

        # Return the most recent entries
        return jsonify(full_history[-limit:])
    except Exception as e:
        logger.error(f"Error retrieving sync history: {str(e)}")
        return jsonify([])


@app.route("/api/metrics")
def metrics():
    """Metrics endpoint for Prometheus scraping"""
    try:
        # Get the latest status
        lighthouse_status = get_lighthouse_status()
        geth_status = get_geth_status()

        # Build metrics output
        lines = []

        # Lighthouse metrics
        lines.append("# HELP lighthouse_syncing Whether lighthouse is syncing")
        lines.append("# TYPE lighthouse_syncing gauge")
        if lighthouse_status.get("data", {}).get("is_syncing") is not None:
            lines.append(
                f"lighthouse_syncing {1 if lighthouse_status.get('data', {}).get('is_syncing') else 0}"
            )
        else:
            lines.append("lighthouse_syncing 0")

        lines.append("# HELP lighthouse_head_slot Current head slot")
        lines.append("# TYPE lighthouse_head_slot gauge")
        head_slot = lighthouse_status.get("data", {}).get("head_slot")
        if head_slot and head_slot != "Unknown":
            lines.append(f"lighthouse_head_slot {head_slot}")
        else:
            lines.append("lighthouse_head_slot 0")

        lines.append("# HELP lighthouse_sync_distance Current sync distance")
        lines.append("# TYPE lighthouse_sync_distance gauge")
        sync_distance = lighthouse_status.get("data", {}).get("sync_distance")
        if sync_distance and sync_distance != "Unknown":
            lines.append(f"lighthouse_sync_distance {sync_distance}")
        else:
            lines.append("lighthouse_sync_distance 0")

        # Geth metrics
        lines.append("# HELP geth_syncing Whether geth is syncing")
        lines.append("# TYPE geth_syncing gauge")
        if geth_status.get("is_syncing") is not None:
            lines.append(f"geth_syncing {1 if geth_status.get('is_syncing') else 0}")
        else:
            lines.append("geth_syncing 0")

        lines.append("# HELP geth_current_block Current block number")
        lines.append("# TYPE geth_current_block gauge")
        current_block = geth_status.get("current_block")
        if current_block and current_block != "Unknown":
            lines.append(f"geth_current_block {current_block}")
        else:
            lines.append("geth_current_block 0")

        lines.append("# HELP geth_highest_block Highest known block number")
        lines.append("# TYPE geth_highest_block gauge")
        highest_block = geth_status.get("highest_block")
        if highest_block and highest_block != "Unknown":
            lines.append(f"geth_highest_block {highest_block}")
        else:
            lines.append("geth_highest_block 0")

        return "\n".join(lines), 200, {"Content-Type": "text/plain"}
    except Exception as e:
        logger.error(f"Error generating metrics: {str(e)}")
        return "# Error generating metrics", 500, {"Content-Type": "text/plain"}


# Initialize scheduler
scheduler = BackgroundScheduler()
scheduler.add_job(
    func=update_sync_history,
    trigger=IntervalTrigger(minutes=5),
    id="update_sync_history",
    name="Update sync history every 5 minutes",
    replace_existing=True,
)

# Start the scheduler
scheduler.start()

if __name__ == "__main__":
    # Update sync history on startup
    update_sync_history()

    # Start the Flask app
    app.run(host="0.0.0.0", port=8080, debug=True)
