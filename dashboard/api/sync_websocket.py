#!/usr/bin/env python3
# sync_websocket.py - WebSocket server for real-time sync status updates

import asyncio
import json
import logging
import os
import signal
import subprocess
import sys
import time
from datetime import datetime

import websockets

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler("/var/log/ephemery/sync_websocket.log"),
        logging.StreamHandler(sys.stdout),
    ],
)
logger = logging.getLogger("sync_websocket")


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
    config["EPHEMERY_DATA_DIR"] = os.environ.get(
        "EPHEMERY_DATA_DIR",
        config.get(
            "EPHEMERY_DATA_DIR", os.path.join(config["EPHEMERY_BASE_DIR"], "data")
        ),
    )
    config["LIGHTHOUSE_API_ENDPOINT"] = os.environ.get(
        "LIGHTHOUSE_API_ENDPOINT",
        config.get("LIGHTHOUSE_API_ENDPOINT", "http://localhost:5052"),
    )
    config["GETH_API_ENDPOINT"] = os.environ.get(
        "GETH_API_ENDPOINT", config.get("GETH_API_ENDPOINT", "http://localhost:8545")
    )

    return config


# Load configuration
config = load_config()

# Configuration
DATA_DIR = config["EPHEMERY_DATA_DIR"]
LIGHTHOUSE_API = config["LIGHTHOUSE_API_ENDPOINT"]
GETH_API = config["GETH_API_ENDPOINT"]
UPDATE_INTERVAL = 5  # seconds
HISTORY_FILE = os.path.join(DATA_DIR, "sync_history.json")
MAX_HISTORY_ENTRIES = 1000  # Maximum number of entries to keep in history

# Global state
connected_clients = set()
current_sync_status = {"lighthouse": None, "geth": None, "timestamp": None}
running = True


# Signal handling for graceful shutdown
def handle_shutdown(signum, frame):
    global running
    logger.info(f"Received signal {signum}. Shutting down...")
    running = False


signal.signal(signal.SIGINT, handle_shutdown)
signal.signal(signal.SIGTERM, handle_shutdown)


# Utility functions
async def run_command(command):
    """Run a shell command asynchronously and return the result"""
    process = await asyncio.create_subprocess_shell(
        command, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE
    )
    stdout, stderr = await process.communicate()

    if process.returncode != 0:
        logger.error(
            f"Command failed with code {process.returncode}: {stderr.decode()}"
        )
        return None

    return stdout.decode()


async def get_lighthouse_status():
    """Get Lighthouse sync status"""
    try:
        result = await run_command(f"curl -s {LIGHTHOUSE_API}/eth/v1/node/syncing")
        if result:
            return json.loads(result)
        return None
    except Exception as e:
        logger.error(f"Error getting Lighthouse status: {e}")
        return None


async def get_geth_status():
    """Get Geth sync status"""
    try:
        result = await run_command(
            f"curl -s -X POST -H 'Content-Type: application/json' "
            f'--data \'{{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}}\' '
            f"{GETH_API}"
        )
        if result:
            return json.loads(result)
        return None
    except Exception as e:
        logger.error(f"Error getting Geth status: {e}")
        return None


async def update_sync_status():
    """Fetch and update the current sync status"""
    global current_sync_status

    lighthouse_status = await get_lighthouse_status()
    geth_status = await get_geth_status()

    current_sync_status = {
        "lighthouse": lighthouse_status,
        "geth": geth_status,
        "timestamp": datetime.now().isoformat(),
    }

    # Save to history file
    await save_to_history(current_sync_status)

    return current_sync_status


async def save_to_history(status):
    """Save current status to history file"""
    try:
        history = []

        # Load existing history if available
        if os.path.exists(HISTORY_FILE):
            with open(HISTORY_FILE, "r") as f:
                history = json.load(f)

        # Add new entry
        history.append(status)

        # Limit history size
        if len(history) > MAX_HISTORY_ENTRIES:
            history = history[-MAX_HISTORY_ENTRIES:]

        # Save history
        with open(HISTORY_FILE, "w") as f:
            json.dump(history, f)

    except Exception as e:
        logger.error(f"Error saving to history: {e}")


async def status_updater():
    """Background task to periodically update sync status"""
    while running:
        try:
            status = await update_sync_status()

            # Broadcast to all connected clients
            if connected_clients:
                websocket_message = json.dumps(status)
                await asyncio.gather(
                    *[client.send(websocket_message) for client in connected_clients]
                )

            # Wait for next update
            await asyncio.sleep(UPDATE_INTERVAL)

        except Exception as e:
            logger.error(f"Error in status updater: {e}")
            await asyncio.sleep(UPDATE_INTERVAL)


async def handle_client(websocket, path):
    """Handle a client WebSocket connection"""
    try:
        # Register client
        connected_clients.add(websocket)
        logger.info(f"New client connected. Total clients: {len(connected_clients)}")

        # Send initial status
        if current_sync_status["lighthouse"] is not None:
            await websocket.send(json.dumps(current_sync_status))

        # Keep connection alive and handle messages
        async for message in websocket:
            # Process any client messages (e.g., filtering requests)
            try:
                data = json.loads(message)
                if "action" in data:
                    if data["action"] == "get_history":
                        # Handle history request
                        days = data.get("days", 1)
                        await handle_history_request(websocket, days)
            except json.JSONDecodeError:
                logger.warning(f"Received invalid JSON: {message}")

    except websockets.exceptions.ConnectionClosed:
        logger.info("Client disconnected normally")
    except Exception as e:
        logger.error(f"Error handling client: {e}")
    finally:
        # Unregister client
        connected_clients.remove(websocket)
        logger.info(f"Client disconnected. Remaining clients: {len(connected_clients)}")


async def handle_history_request(websocket, days=1):
    """Handle a request for historical data"""
    try:
        if os.path.exists(HISTORY_FILE):
            with open(HISTORY_FILE, "r") as f:
                history = json.load(f)

            # Filter by days if needed
            # This is a simplified filtering - in production you would use proper datetime filtering
            history_response = {
                "action": "history_data",
                "data": history[
                    -min(days * 24 * 60 // UPDATE_INTERVAL, len(history)) :
                ],
            }

            await websocket.send(json.dumps(history_response))
    except Exception as e:
        logger.error(f"Error handling history request: {e}")
        error_response = {
            "action": "error",
            "message": f"Error retrieving history: {str(e)}",
        }
        await websocket.send(json.dumps(error_response))


async def main():
    """Main entry point"""
    # Initial status update
    await update_sync_status()

    # Start background updater task
    updater_task = asyncio.create_task(status_updater())

    # Start WebSocket server
    async with websockets.serve(handle_client, "0.0.0.0", 5001):
        logger.info("WebSocket server started on port 5001")
        # Run forever (or until interrupted)
        while running:
            await asyncio.sleep(1)

    # Cancel updater task when shutting down
    updater_task.cancel()
    try:
        await updater_task
    except asyncio.CancelledError:
        logger.info("Updater task cancelled")


if __name__ == "__main__":
    asyncio.run(main())
