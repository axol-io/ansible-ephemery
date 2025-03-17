#!/usr/bin/env python3
"""
Profitability Calculator Module for Lido CSM
This module provides functionality to calculate and visualize validator profitability.
"""

import datetime
import json
import logging
import os
import time
from typing import Any, Dict, List, Optional, Tuple, Union

import numpy as np
import pandas as pd
import requests
from flask import Blueprint, current_app, jsonify, render_template, request

# Configure logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Create Blueprint
profitability_bp = Blueprint("profitability", __name__, url_prefix="/profitability")

# Constants
DEFAULT_ANALYSIS_PERIOD_DAYS = 90
DEFAULT_FORECAST_DAYS = 365
DEFAULT_ETH_PRICE = 3500  # Default ETH price in USD
PROFITABILITY_DATA_DIR = os.environ.get(
    "PROFITABILITY_DATA_DIR", "/var/lib/ephemery/data/lido-csm/profitability"
)
CSM_API_ENDPOINT = os.environ.get("CSM_API_ENDPOINT", "http://localhost:9000")
BEACON_API_ENDPOINT = os.environ.get("BEACON_API_ENDPOINT", "http://localhost:5052")


class ProfitabilityCalculator:
    """Class for calculating validator profitability"""

    def __init__(self, data_dir: str = PROFITABILITY_DATA_DIR):
        self.data_dir = data_dir
        self.ensure_data_dir()
        self.cost_inputs = self.load_cost_inputs()
        self.performance_history = self.load_performance_history()
        self.eth_price = self.fetch_eth_price()

    def ensure_data_dir(self) -> None:
        """Ensure the data directory exists"""
        os.makedirs(self.data_dir, exist_ok=True)

    def load_cost_inputs(self) -> Dict[str, float]:
        """Load cost inputs from configuration"""
        config_file = os.path.join(self.data_dir, "cost_inputs.json")

        if not os.path.exists(config_file):
            # Create default cost inputs
            default_costs = {
                "hardware_cost_monthly": 100.0,
                "power_cost_monthly": 20.0,
                "bandwidth_cost_monthly": 30.0,
                "maintenance_hours_monthly": 5.0,
                "maintenance_hourly_rate": 50.0,
                "bond_opportunity_cost_annual_percentage": 5.0,
                "tax_rate_percentage": 30.0,
                "validator_setup_cost": 500.0,
                "validator_exit_cost": 100.0,
            }

            with open(config_file, "w") as f:
                json.dump(default_costs, f, indent=2)

            return default_costs

        try:
            with open(config_file, "r") as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Error loading cost inputs: {e}")
            # Return default values
            return {
                "hardware_cost_monthly": 100.0,
                "power_cost_monthly": 20.0,
                "bandwidth_cost_monthly": 30.0,
                "maintenance_hours_monthly": 5.0,
                "maintenance_hourly_rate": 50.0,
                "bond_opportunity_cost_annual_percentage": 5.0,
                "tax_rate_percentage": 30.0,
                "validator_setup_cost": 500.0,
                "validator_exit_cost": 100.0,
            }

    def save_cost_inputs(self, cost_inputs: Dict[str, float]) -> None:
        """Save cost inputs to configuration"""
        config_file = os.path.join(self.data_dir, "cost_inputs.json")
        try:
            with open(config_file, "w") as f:
                json.dump(cost_inputs, f, indent=2)
            self.cost_inputs = cost_inputs
        except Exception as e:
            logger.error(f"Error saving cost inputs: {e}")

    def load_performance_history(self) -> pd.DataFrame:
        """Load historical performance data"""
        history_file = os.path.join(self.data_dir, "performance_history.csv")

        if not os.path.exists(history_file):
            # Create empty dataframe with expected columns
            df = pd.DataFrame(
                columns=[
                    "timestamp",
                    "validator_count",
                    "attestation_rate",
                    "proposal_rate",
                    "avg_balance",
                    "avg_rewards_daily",
                    "eth_price",
                ]
            )
            df.to_csv(history_file, index=False)
            return df

        try:
            return pd.read_csv(history_file, parse_dates=["timestamp"])
        except Exception as e:
            logger.error(f"Error loading performance history: {e}")
            # Return empty dataframe
            return pd.DataFrame(
                columns=[
                    "timestamp",
                    "validator_count",
                    "attestation_rate",
                    "proposal_rate",
                    "avg_balance",
                    "avg_rewards_daily",
                    "eth_price",
                ]
            )

    def save_performance_history(self) -> None:
        """Save performance history to disk"""
        history_file = os.path.join(self.data_dir, "performance_history.csv")
        try:
            self.performance_history.to_csv(history_file, index=False)
        except Exception as e:
            logger.error(f"Error saving performance history: {e}")

    def fetch_eth_price(self) -> float:
        """Fetch current ETH price from API"""
        try:
            # Try to fetch from a price API
            response = requests.get(
                "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd",
                timeout=5,
            )
            response.raise_for_status()
            data = response.json()
            return float(data["ethereum"]["usd"])
        except Exception as e:
            logger.warning(f"Error fetching ETH price: {e}")
            # Use default or last known price
            if not self.performance_history.empty:
                return self.performance_history["eth_price"].iloc[-1]
            return DEFAULT_ETH_PRICE

    def fetch_validator_performance(self) -> Dict[str, Any]:
        """Fetch current validator performance metrics"""
        try:
            # Try to fetch from CSM API
            response = requests.get(
                f"{CSM_API_ENDPOINT}/api/v1/validators/performance", timeout=10
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.warning(f"Error fetching validator performance: {e}")
            # Return dummy data for development/testing
            return {
                "validator_count": 10,
                "attestation_rate": 0.99,
                "proposal_rate": 0.98,
                "avg_balance": 32.5,
                "avg_rewards_daily": 0.00175,
                "timestamp": int(time.time()),
            }

    def update_performance_history(self) -> None:
        """Update performance history with current data"""
        current_data = self.fetch_validator_performance()

        # Convert timestamp to datetime
        if isinstance(current_data.get("timestamp"), int):
            timestamp = pd.Timestamp.fromtimestamp(current_data["timestamp"])
        else:
            timestamp = pd.Timestamp.now()

        # Create new row
        new_row = pd.DataFrame(
            [
                {
                    "timestamp": timestamp,
                    "validator_count": current_data.get("validator_count", 0),
                    "attestation_rate": current_data.get("attestation_rate", 0),
                    "proposal_rate": current_data.get("proposal_rate", 0),
                    "avg_balance": current_data.get("avg_balance", 32),
                    "avg_rewards_daily": current_data.get("avg_rewards_daily", 0),
                    "eth_price": self.eth_price,
                }
            ]
        )

        # Append to history
        self.performance_history = pd.concat(
            [self.performance_history, new_row], ignore_index=True
        )

        # Remove duplicates and sort
        self.performance_history = self.performance_history.drop_duplicates(
            subset=["timestamp"]
        ).sort_values("timestamp")

        # Save updated history
        self.save_performance_history()

    def calculate_monthly_costs(self, validator_count: int = 1) -> Dict[str, float]:
        """Calculate monthly operational costs"""
        # Fixed costs (per validator)
        hardware_cost = (
            self.cost_inputs.get("hardware_cost_monthly", 100.0) * validator_count
        )

        # Variable costs (scale with validator count but not linearly)
        power_cost = self.cost_inputs.get("power_cost_monthly", 20.0) * (
            1 + (validator_count - 1) * 0.5
        )
        bandwidth_cost = self.cost_inputs.get("bandwidth_cost_monthly", 30.0) * (
            1 + (validator_count - 1) * 0.3
        )

        # Maintenance costs
        maintenance_hours = self.cost_inputs.get("maintenance_hours_monthly", 5.0) * (
            1 + (validator_count - 1) * 0.2
        )
        maintenance_cost = maintenance_hours * self.cost_inputs.get(
            "maintenance_hourly_rate", 50.0
        )

        # Bond opportunity cost
        bond_amount = 2.0 * validator_count  # Assuming 2 ETH bond per validator
        annual_opportunity_percentage = self.cost_inputs.get(
            "bond_opportunity_cost_annual_percentage", 5.0
        )
        monthly_opportunity_percentage = annual_opportunity_percentage / 12
        bond_opportunity_cost_eth = bond_amount * (monthly_opportunity_percentage / 100)
        bond_opportunity_cost_usd = bond_opportunity_cost_eth * self.eth_price

        # Total costs
        total_cost_usd = (
            hardware_cost
            + power_cost
            + bandwidth_cost
            + maintenance_cost
            + bond_opportunity_cost_usd
        )

        return {
            "hardware_cost_usd": hardware_cost,
            "power_cost_usd": power_cost,
            "bandwidth_cost_usd": bandwidth_cost,
            "maintenance_cost_usd": maintenance_cost,
            "bond_opportunity_cost_eth": bond_opportunity_cost_eth,
            "bond_opportunity_cost_usd": bond_opportunity_cost_usd,
            "total_cost_usd": total_cost_usd,
            "total_cost_eth": total_cost_usd / self.eth_price,
        }

    def calculate_monthly_revenue(self, validator_count: int = 1) -> Dict[str, float]:
        """Calculate monthly revenue based on historical performance"""
        if self.performance_history.empty:
            # Use default values if no history
            avg_rewards_daily = 0.00175  # ETH per validator per day
        else:
            # Calculate average daily rewards from recent history (last 30 days)
            cutoff_time = pd.Timestamp.now() - pd.Timedelta(days=30)
            recent_data = self.performance_history[
                self.performance_history["timestamp"] >= cutoff_time
            ]

            if recent_data.empty:
                recent_data = self.performance_history

            avg_rewards_daily = recent_data["avg_rewards_daily"].mean()

        # Calculate monthly revenue
        monthly_rewards_eth = avg_rewards_daily * 30 * validator_count
        monthly_rewards_usd = monthly_rewards_eth * self.eth_price

        return {
            "avg_rewards_daily_eth": avg_rewards_daily,
            "monthly_rewards_eth": monthly_rewards_eth,
            "monthly_rewards_usd": monthly_rewards_usd,
        }

    def calculate_profitability(self, validator_count: int = 1) -> Dict[str, Any]:
        """Calculate overall profitability metrics"""
        # Get costs and revenue
        costs = self.calculate_monthly_costs(validator_count)
        revenue = self.calculate_monthly_revenue(validator_count)

        # Calculate profit
        monthly_profit_eth = revenue["monthly_rewards_eth"] - costs["total_cost_eth"]
        monthly_profit_usd = revenue["monthly_rewards_usd"] - costs["total_cost_usd"]

        # Calculate ROI
        initial_investment = validator_count * 32  # 32 ETH per validator
        monthly_roi_percentage = (monthly_profit_eth / initial_investment) * 100
        annual_roi_percentage = monthly_roi_percentage * 12

        # Calculate break-even time (months)
        setup_cost_usd = (
            self.cost_inputs.get("validator_setup_cost", 500.0) * validator_count
        )
        if monthly_profit_usd > 0:
            break_even_months = setup_cost_usd / monthly_profit_usd
        else:
            break_even_months = float("inf")

        # Calculate tax implications
        tax_rate = self.cost_inputs.get("tax_rate_percentage", 30.0) / 100
        monthly_tax_usd = max(0, monthly_profit_usd * tax_rate)
        monthly_after_tax_usd = monthly_profit_usd - monthly_tax_usd

        return {
            "validator_count": validator_count,
            "eth_price_usd": self.eth_price,
            "costs": costs,
            "revenue": revenue,
            "monthly_profit_eth": monthly_profit_eth,
            "monthly_profit_usd": monthly_profit_usd,
            "monthly_roi_percentage": monthly_roi_percentage,
            "annual_roi_percentage": annual_roi_percentage,
            "break_even_months": break_even_months,
            "monthly_tax_usd": monthly_tax_usd,
            "monthly_after_tax_usd": monthly_after_tax_usd,
        }

    def forecast_profitability(
        self, validator_count: int = 1, months: int = 12
    ) -> List[Dict[str, Any]]:
        """Forecast profitability over time"""
        # Initial profitability calculation
        initial_calc = self.calculate_profitability(validator_count)

        # Forecast parameters
        reward_decay_rate = 0.995  # 0.5% reduction in rewards per month
        eth_price_growth_rate = 1.01  # 1% increase in ETH price per month

        # Initialize forecast
        forecast = []

        # Current values
        current_eth_price = self.eth_price
        current_rewards_daily = initial_calc["revenue"]["avg_rewards_daily_eth"]

        for month in range(1, months + 1):
            # Update parameters for this month
            current_rewards_daily *= reward_decay_rate
            current_eth_price *= eth_price_growth_rate

            # Create temporary calculator with updated values
            temp_calculator = ProfitabilityCalculator(self.data_dir)
            temp_calculator.cost_inputs = self.cost_inputs
            temp_calculator.eth_price = current_eth_price

            # Create temporary performance history with projected rewards
            temp_df = pd.DataFrame(
                [
                    {
                        "timestamp": pd.Timestamp.now(),
                        "validator_count": validator_count,
                        "attestation_rate": 0.99,
                        "proposal_rate": 0.98,
                        "avg_balance": 32 + (current_rewards_daily * 30 * month),
                        "avg_rewards_daily": current_rewards_daily,
                        "eth_price": current_eth_price,
                    }
                ]
            )
            temp_calculator.performance_history = temp_df

            # Calculate profitability for this month
            month_calc = temp_calculator.calculate_profitability(validator_count)

            # Add to forecast
            forecast.append(
                {
                    "month": month,
                    "eth_price_usd": current_eth_price,
                    "avg_rewards_daily_eth": current_rewards_daily,
                    "monthly_profit_eth": month_calc["monthly_profit_eth"],
                    "monthly_profit_usd": month_calc["monthly_profit_usd"],
                    "cumulative_profit_eth": month_calc["monthly_profit_eth"] * month,
                    "cumulative_profit_usd": month_calc["monthly_profit_usd"] * month,
                    "roi_percentage": month_calc["monthly_roi_percentage"] * month,
                }
            )

        return forecast

    def calculate_optimal_validator_count(self) -> Dict[str, Any]:
        """Calculate the optimal number of validators for maximum profitability"""
        max_profit_usd = float("-inf")
        optimal_count = 1
        results = {}

        # Test different validator counts
        for count in range(1, 21):  # Test 1-20 validators
            profit_calc = self.calculate_profitability(count)
            monthly_profit_usd = profit_calc["monthly_profit_usd"]

            results[count] = {
                "monthly_profit_usd": monthly_profit_usd,
                "monthly_profit_eth": profit_calc["monthly_profit_eth"],
                "roi_percentage": profit_calc["annual_roi_percentage"],
            }

            if monthly_profit_usd > max_profit_usd:
                max_profit_usd = monthly_profit_usd
                optimal_count = count

        return {
            "optimal_validator_count": optimal_count,
            "max_monthly_profit_usd": max_profit_usd,
            "results_by_count": results,
        }

    def get_profitability_analysis(self, validator_count: int = 1) -> Dict[str, Any]:
        """Get comprehensive profitability analysis"""
        # Update performance history with current data
        self.update_performance_history()

        # Calculate current profitability
        profitability = self.calculate_profitability(validator_count)

        # Generate forecast
        forecast = self.forecast_profitability(validator_count, 12)

        # Calculate optimal validator count
        optimization = self.calculate_optimal_validator_count()

        # Get historical performance
        history_data = []
        if not self.performance_history.empty:
            # Resample to daily data for UI display
            daily_data = (
                self.performance_history.set_index("timestamp")
                .resample("D")
                .mean()
                .reset_index()
            )

            for _, row in daily_data.iterrows():
                history_data.append(
                    {
                        "timestamp": row["timestamp"].isoformat(),
                        "avg_rewards_daily": row["avg_rewards_daily"],
                        "eth_price": row["eth_price"],
                    }
                )

        return {
            "current_profitability": profitability,
            "forecast": forecast,
            "optimization": optimization,
            "history": history_data,
            "cost_inputs": self.cost_inputs,
        }


# Initialize calculator instance
profitability_calculator = ProfitabilityCalculator()


@profitability_bp.route("/")
def index():
    """Render profitability calculator dashboard"""
    return render_template("profitability_calculator.html")


@profitability_bp.route("/api/analysis")
def get_profitability_analysis():
    """API endpoint to get profitability analysis"""
    validator_count = request.args.get("validator_count", 1, type=int)
    return jsonify(profitability_calculator.get_profitability_analysis(validator_count))


@profitability_bp.route("/api/forecast")
def get_forecast():
    """API endpoint to get profitability forecast"""
    validator_count = request.args.get("validator_count", 1, type=int)
    months = request.args.get("months", 12, type=int)
    return jsonify(
        profitability_calculator.forecast_profitability(validator_count, months)
    )


@profitability_bp.route("/api/optimization")
def get_optimization():
    """API endpoint to get optimal validator count"""
    return jsonify(profitability_calculator.calculate_optimal_validator_count())


@profitability_bp.route("/api/cost-inputs", methods=["GET", "POST"])
def manage_cost_inputs():
    """API endpoint to get or update cost inputs"""
    if request.method == "POST":
        try:
            new_inputs = request.json
            profitability_calculator.save_cost_inputs(new_inputs)
            return jsonify(
                {"status": "success", "message": "Cost inputs updated successfully"}
            )
        except Exception as e:
            return jsonify({"status": "error", "message": str(e)}), 400
    else:
        return jsonify(profitability_calculator.cost_inputs)


@profitability_bp.route("/api/update", methods=["POST"])
def update_data():
    """API endpoint to manually trigger data update"""
    profitability_calculator.update_performance_history()
    return jsonify(
        {"status": "success", "message": "Performance data updated successfully"}
    )


def register_profitability_blueprint(app):
    """Register the profitability blueprint with the Flask app"""
    app.register_blueprint(profitability_bp)

    # Schedule regular updates
    @app.before_first_request
    def initialize_data():
        profitability_calculator.update_performance_history()
