#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Obol SquadStaking Integration Module for Ephemery Dashboard

This module provides integration with Obol's distributed validator technology (DVT)
for the Ephemery dashboard, including metrics collection, analysis, and visualization.
"""

import datetime
import json
import logging
import os
import time

import numpy as np
import pandas as pd
import requests
from apscheduler.schedulers.background import BackgroundScheduler
from flask import Blueprint, current_app, jsonify, render_template, request

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger(__name__)

# Create Blueprint
obol_bp = Blueprint("obol", __name__, url_prefix="/obol")

# Constants
DEFAULT_HISTORY_DAYS = 7
DEFAULT_REFRESH_INTERVAL = 300  # 5 minutes
DATA_DIR = os.environ.get("EPHEMERY_DATA_DIR", "/opt/ephemery/data")
OBOL_DATA_DIR = os.path.join(DATA_DIR, "obol")
METRICS_DATA_DIR = os.path.join(DATA_DIR, "metrics")

# Ensure directories exist
os.makedirs(OBOL_DATA_DIR, exist_ok=True)
os.makedirs(METRICS_DATA_DIR, exist_ok=True)


class ObolMetricsCollector:
    """Class to collect and analyze Obol SquadStaking metrics"""

    def __init__(self):
        self.charon_metrics_endpoint = "http://localhost:3620/metrics"
        self.validator_metrics_endpoint = "http://localhost:5064/metrics"
        self.beacon_api_endpoint = "http://localhost:5052"
        self.metrics_history_file = os.path.join(
            METRICS_DATA_DIR, "obol_metrics_history.json"
        )
        self.metrics_history = self._load_metrics_history()

    def _load_metrics_history(self):
        """Load metrics history from file"""
        if os.path.exists(self.metrics_history_file):
            try:
                with open(self.metrics_history_file, "r") as f:
                    return json.load(f)
            except (json.JSONDecodeError, IOError) as e:
                logger.error(f"Error loading metrics history: {e}")
                return {"charon": [], "validator": []}
        return {"charon": [], "validator": []}

    def _save_metrics_history(self):
        """Save metrics history to file"""
        try:
            with open(self.metrics_history_file, "w") as f:
                json.dump(self.metrics_history, f)
        except IOError as e:
            logger.error(f"Error saving metrics history: {e}")

    def fetch_prometheus_metrics(self, endpoint):
        """Fetch metrics from Prometheus endpoint"""
        try:
            response = requests.get(endpoint, timeout=10)
            response.raise_for_status()
            return response.text
        except requests.RequestException as e:
            logger.error(f"Error fetching metrics from {endpoint}: {e}")
            return None

    def parse_prometheus_metrics(self, metrics_text):
        """Parse Prometheus metrics format into a dictionary"""
        if not metrics_text:
            return {}

        metrics = {}
        current_metric = None

        for line in metrics_text.split("\n"):
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            if "{" in line:
                # This is a metric with labels
                metric_name = line.split("{")[0]
                labels_str = line.split("{")[1].split("}")[0]
                value_str = line.split("}")[1].strip()

                # Parse labels
                labels = {}
                for label_pair in labels_str.split(","):
                    if "=" in label_pair:
                        key, value = label_pair.split("=", 1)
                        labels[key.strip()] = value.strip().strip('"')

                # Parse value
                try:
                    value = float(value_str)
                except ValueError:
                    continue

                # Store in metrics dictionary
                if metric_name not in metrics:
                    metrics[metric_name] = []

                metrics[metric_name].append({"labels": labels, "value": value})
            else:
                # This is a simple metric without labels
                parts = line.split()
                if len(parts) >= 2:
                    metric_name = parts[0]
                    try:
                        value = float(parts[1])
                        metrics[metric_name] = [{"labels": {}, "value": value}]
                    except ValueError:
                        continue

        return metrics

    def collect_metrics(self):
        """Collect metrics from Charon and validator nodes"""
        timestamp = datetime.datetime.now().isoformat()

        # Fetch Charon metrics
        charon_metrics_text = self.fetch_prometheus_metrics(
            self.charon_metrics_endpoint
        )
        charon_metrics = self.parse_prometheus_metrics(charon_metrics_text)

        # Fetch validator metrics
        validator_metrics_text = self.fetch_prometheus_metrics(
            self.validator_metrics_endpoint
        )
        validator_metrics = self.parse_prometheus_metrics(validator_metrics_text)

        # Store metrics with timestamp
        if charon_metrics:
            self.metrics_history["charon"].append(
                {"timestamp": timestamp, "metrics": charon_metrics}
            )

            # Keep only last 30 days of data
            if (
                len(self.metrics_history["charon"]) > 8640
            ):  # 30 days at 5-minute intervals
                self.metrics_history["charon"] = self.metrics_history["charon"][-8640:]

        if validator_metrics:
            self.metrics_history["validator"].append(
                {"timestamp": timestamp, "metrics": validator_metrics}
            )

            # Keep only last 30 days of data
            if (
                len(self.metrics_history["validator"]) > 8640
            ):  # 30 days at 5-minute intervals
                self.metrics_history["validator"] = self.metrics_history["validator"][
                    -8640:
                ]

        # Save updated history
        self._save_metrics_history()

        return {
            "timestamp": timestamp,
            "charon": charon_metrics,
            "validator": validator_metrics,
        }

    def get_latest_metrics(self):
        """Get the latest collected metrics"""
        if not self.metrics_history["charon"] or not self.metrics_history["validator"]:
            return self.collect_metrics()

        return {
            "timestamp": self.metrics_history["charon"][-1]["timestamp"],
            "charon": self.metrics_history["charon"][-1]["metrics"],
            "validator": self.metrics_history["validator"][-1]["metrics"],
        }

    def get_metrics_history(self, days=DEFAULT_HISTORY_DAYS):
        """Get metrics history for the specified number of days"""
        cutoff_time = (
            datetime.datetime.now() - datetime.timedelta(days=days)
        ).isoformat()

        charon_history = [
            entry
            for entry in self.metrics_history["charon"]
            if entry["timestamp"] >= cutoff_time
        ]

        validator_history = [
            entry
            for entry in self.metrics_history["validator"]
            if entry["timestamp"] >= cutoff_time
        ]

        return {"charon": charon_history, "validator": validator_history}

    def calculate_consensus_rate(self):
        """Calculate consensus rate from metrics history"""
        if not self.metrics_history["charon"]:
            return 0.0

        # Look for consensus metrics in the latest data
        latest_metrics = self.metrics_history["charon"][-1]["metrics"]

        # Extract consensus success and failure counts
        consensus_success = 0
        consensus_total = 0

        if "charon_consensus_count" in latest_metrics:
            for item in latest_metrics["charon_consensus_count"]:
                if item["labels"].get("result") == "success":
                    consensus_success += item["value"]
                consensus_total += item["value"]

        if consensus_total == 0:
            return 0.0

        return (consensus_success / consensus_total) * 100

    def calculate_duty_performance(self):
        """Calculate duty performance metrics"""
        if not self.metrics_history["validator"]:
            return {
                "attestation_effectiveness": 0.0,
                "missed_attestations": 0,
                "missed_blocks": 0,
            }

        # Look for duty metrics in the latest data
        latest_metrics = self.metrics_history["validator"][-1]["metrics"]

        # Extract attestation and block metrics
        attestation_effectiveness = 0.0
        missed_attestations = 0
        missed_blocks = 0

        # Process attestation metrics
        if "validator_effectiveness" in latest_metrics:
            for item in latest_metrics["validator_effectiveness"]:
                attestation_effectiveness = item["value"] * 100

        if "validator_missed_attestations" in latest_metrics:
            for item in latest_metrics["validator_missed_attestations"]:
                missed_attestations += int(item["value"])

        if "validator_missed_blocks" in latest_metrics:
            for item in latest_metrics["validator_missed_blocks"]:
                missed_blocks += int(item["value"])

        return {
            "attestation_effectiveness": attestation_effectiveness,
            "missed_attestations": missed_attestations,
            "missed_blocks": missed_blocks,
        }

    def calculate_performance_trend(self, days=DEFAULT_HISTORY_DAYS):
        """Calculate performance trend over time"""
        history = self.get_metrics_history(days)

        if not history["validator"]:
            return {"attestation_trend": "stable", "consensus_trend": "stable"}

        # Extract attestation effectiveness over time
        attestation_values = []
        timestamps = []

        for entry in history["validator"]:
            metrics = entry["metrics"]
            if "validator_effectiveness" in metrics:
                for item in metrics["validator_effectiveness"]:
                    attestation_values.append(item["value"] * 100)
                    timestamps.append(entry["timestamp"])

        # Extract consensus rate over time
        consensus_values = []
        consensus_timestamps = []

        for entry in history["charon"]:
            metrics = entry["metrics"]
            consensus_success = 0
            consensus_total = 0

            if "charon_consensus_count" in metrics:
                for item in metrics["charon_consensus_count"]:
                    if item["labels"].get("result") == "success":
                        consensus_success += item["value"]
                    consensus_total += item["value"]

                if consensus_total > 0:
                    consensus_values.append((consensus_success / consensus_total) * 100)
                    consensus_timestamps.append(entry["timestamp"])

        # Calculate trends
        attestation_trend = "stable"
        if len(attestation_values) >= 2:
            if attestation_values[-1] > attestation_values[0] * 1.05:
                attestation_trend = "improving"
            elif attestation_values[-1] < attestation_values[0] * 0.95:
                attestation_trend = "declining"

        consensus_trend = "stable"
        if len(consensus_values) >= 2:
            if consensus_values[-1] > consensus_values[0] * 1.05:
                consensus_trend = "improving"
            elif consensus_values[-1] < consensus_values[0] * 0.95:
                consensus_trend = "declining"

        return {
            "attestation_trend": attestation_trend,
            "consensus_trend": consensus_trend,
            "attestation_values": attestation_values,
            "attestation_timestamps": timestamps,
            "consensus_values": consensus_values,
            "consensus_timestamps": consensus_timestamps,
        }

    def get_comprehensive_analysis(self):
        """Get comprehensive analysis of Obol SquadStaking performance"""
        # Collect latest metrics if needed
        latest_metrics = self.get_latest_metrics()

        # Calculate consensus rate
        consensus_rate = self.calculate_consensus_rate()

        # Calculate duty performance
        duty_performance = self.calculate_duty_performance()

        # Calculate performance trend
        performance_trend = self.calculate_performance_trend()

        # Calculate overall health score (0-100)
        attestation_score = duty_performance["attestation_effectiveness"]
        consensus_score = consensus_rate
        missed_penalty = (duty_performance["missed_attestations"] * 2) + (
            duty_performance["missed_blocks"] * 10
        )
        health_score = max(
            0, min(100, (attestation_score + consensus_score) / 2 - missed_penalty)
        )

        return {
            "timestamp": latest_metrics["timestamp"],
            "consensus_rate": consensus_rate,
            "duty_performance": duty_performance,
            "performance_trend": performance_trend,
            "health_score": health_score,
        }


# Create metrics collector instance
metrics_collector = ObolMetricsCollector()

# Schedule metrics collection
scheduler = BackgroundScheduler()
scheduler.add_job(
    metrics_collector.collect_metrics,
    "interval",
    seconds=DEFAULT_REFRESH_INTERVAL,
    id="obol_metrics_collection",
)


@obol_bp.route("/")
def index():
    """Render Obol SquadStaking dashboard"""
    return render_template("obol_dashboard.html")


@obol_bp.route("/api/metrics")
def get_metrics():
    """API endpoint to get latest metrics"""
    return jsonify(metrics_collector.get_latest_metrics())


@obol_bp.route("/api/analysis")
def get_analysis():
    """API endpoint to get comprehensive analysis"""
    return jsonify(metrics_collector.get_comprehensive_analysis())


@obol_bp.route("/api/history")
def get_history():
    """API endpoint to get metrics history"""
    days = request.args.get("days", DEFAULT_HISTORY_DAYS, type=int)
    return jsonify(metrics_collector.get_metrics_history(days))


@obol_bp.route("/api/refresh", methods=["POST"])
def refresh_metrics():
    """API endpoint to manually refresh metrics"""
    metrics = metrics_collector.collect_metrics()
    return jsonify({"status": "success", "metrics": metrics})


def register_obol_blueprint(app):
    """Register the Obol blueprint with the Flask app"""
    app.register_blueprint(obol_bp)

    # Start the scheduler if it's not already running
    if not scheduler.running:
        scheduler.start()

    # Register shutdown function to stop scheduler when app stops
    @app.teardown_appcontext
    def shutdown_scheduler(exception=None):
        if scheduler.running:
            scheduler.shutdown()
