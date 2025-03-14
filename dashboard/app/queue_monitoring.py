#!/usr/bin/env python3
"""
Queue Monitoring Visualization Module for Lido CSM
This module provides advanced visualization and analytics for the CSM stake distribution queue.
"""

import os
import json
import time
import logging
import datetime
from typing import Dict, List, Optional, Tuple, Union, Any

import requests
import numpy as np
import pandas as pd
from flask import Blueprint, render_template, jsonify, request, current_app

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Create Blueprint
queue_bp = Blueprint('queue', __name__, url_prefix='/queue')

# Constants
DEFAULT_FORECAST_DAYS = 30
DEFAULT_HISTORY_DAYS = 90
DEFAULT_REFRESH_INTERVAL = 300  # 5 minutes
QUEUE_DATA_DIR = os.environ.get('QUEUE_DATA_DIR', '/var/lib/ephemery/data/lido-csm/queue')
CSM_API_ENDPOINT = os.environ.get('CSM_API_ENDPOINT', 'http://localhost:9000')


class QueueAnalytics:
    """Class for analyzing queue data and generating insights"""
    
    def __init__(self, data_dir: str = QUEUE_DATA_DIR):
        self.data_dir = data_dir
        self.ensure_data_dir()
        self.queue_history = self.load_queue_history()
    
    def ensure_data_dir(self) -> None:
        """Ensure the data directory exists"""
        os.makedirs(self.data_dir, exist_ok=True)
    
    def load_queue_history(self) -> pd.DataFrame:
        """Load historical queue data from disk"""
        history_file = os.path.join(self.data_dir, 'queue_history.csv')
        
        if not os.path.exists(history_file):
            # Create empty dataframe with expected columns
            df = pd.DataFrame(columns=[
                'timestamp', 'queue_length', 'position', 'wait_time_estimate', 
                'velocity', 'acceleration', 'stake_rate'
            ])
            df.to_csv(history_file, index=False)
            return df
        
        try:
            return pd.read_csv(history_file, parse_dates=['timestamp'])
        except Exception as e:
            logger.error(f"Error loading queue history: {e}")
            # Return empty dataframe
            return pd.DataFrame(columns=[
                'timestamp', 'queue_length', 'position', 'wait_time_estimate', 
                'velocity', 'acceleration', 'stake_rate'
            ])
    
    def save_queue_history(self) -> None:
        """Save queue history to disk"""
        history_file = os.path.join(self.data_dir, 'queue_history.csv')
        try:
            self.queue_history.to_csv(history_file, index=False)
        except Exception as e:
            logger.error(f"Error saving queue history: {e}")
    
    def fetch_current_queue_data(self) -> Dict[str, Any]:
        """Fetch current queue data from CSM API"""
        try:
            response = requests.get(f"{CSM_API_ENDPOINT}/api/v1/queue/status", timeout=10)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            logger.error(f"Error fetching queue data: {e}")
            # Return dummy data for development/testing
            return {
                "queue_length": 100,
                "position": 45,
                "wait_time_estimate": 72,  # hours
                "velocity": 1.2,  # positions per hour
                "acceleration": 0.05,  # change in velocity per hour
                "stake_rate": 32.0,  # ETH per hour
                "timestamp": int(time.time())
            }
    
    def update_queue_history(self) -> None:
        """Update queue history with current data"""
        current_data = self.fetch_current_queue_data()
        
        # Convert timestamp to datetime
        if isinstance(current_data.get('timestamp'), int):
            timestamp = pd.Timestamp.fromtimestamp(current_data['timestamp'])
        else:
            timestamp = pd.Timestamp.now()
        
        # Create new row
        new_row = pd.DataFrame([{
            'timestamp': timestamp,
            'queue_length': current_data.get('queue_length', 0),
            'position': current_data.get('position', 0),
            'wait_time_estimate': current_data.get('wait_time_estimate', 0),
            'velocity': current_data.get('velocity', 0),
            'acceleration': current_data.get('acceleration', 0),
            'stake_rate': current_data.get('stake_rate', 0)
        }])
        
        # Append to history
        self.queue_history = pd.concat([self.queue_history, new_row], ignore_index=True)
        
        # Remove duplicates and sort
        self.queue_history = self.queue_history.drop_duplicates(subset=['timestamp']).sort_values('timestamp')
        
        # Save updated history
        self.save_queue_history()
    
    def calculate_velocity(self, days: int = 7) -> float:
        """Calculate average queue velocity over the specified period"""
        if self.queue_history.empty:
            return 0.0
        
        # Filter data for the specified period
        cutoff_time = pd.Timestamp.now() - pd.Timedelta(days=days)
        recent_data = self.queue_history[self.queue_history['timestamp'] >= cutoff_time]
        
        if len(recent_data) < 2:
            return self.queue_history['velocity'].iloc[-1] if not self.queue_history.empty else 0.0
        
        # Calculate position change per hour
        first_position = recent_data['position'].iloc[0]
        last_position = recent_data['position'].iloc[-1]
        first_time = recent_data['timestamp'].iloc[0]
        last_time = recent_data['timestamp'].iloc[-1]
        
        hours_diff = (last_time - first_time).total_seconds() / 3600
        if hours_diff <= 0:
            return 0.0
        
        position_change = first_position - last_position  # Decreasing position is positive velocity
        velocity = position_change / hours_diff
        
        return max(0.0, velocity)  # Ensure non-negative velocity
    
    def calculate_acceleration(self, days: int = 7) -> float:
        """Calculate queue acceleration over the specified period"""
        if self.queue_history.empty or len(self.queue_history) < 3:
            return 0.0
        
        # Filter data for the specified period
        cutoff_time = pd.Timestamp.now() - pd.Timedelta(days=days)
        recent_data = self.queue_history[self.queue_history['timestamp'] >= cutoff_time]
        
        if len(recent_data) < 3:
            return 0.0
        
        # Calculate velocity at different points
        recent_data = recent_data.sort_values('timestamp')
        midpoint = len(recent_data) // 2
        
        first_half = recent_data.iloc[:midpoint]
        second_half = recent_data.iloc[midpoint:]
        
        if len(first_half) < 2 or len(second_half) < 2:
            return 0.0
        
        # Calculate velocity for each half
        first_velocity = (first_half['position'].iloc[0] - first_half['position'].iloc[-1]) / \
                         ((first_half['timestamp'].iloc[-1] - first_half['timestamp'].iloc[0]).total_seconds() / 3600)
        
        second_velocity = (second_half['position'].iloc[0] - second_half['position'].iloc[-1]) / \
                          ((second_half['timestamp'].iloc[-1] - second_half['timestamp'].iloc[0]).total_seconds() / 3600)
        
        # Calculate time difference between midpoints of each half
        first_midpoint_time = first_half['timestamp'].mean()
        second_midpoint_time = second_half['timestamp'].mean()
        hours_diff = (second_midpoint_time - first_midpoint_time).total_seconds() / 3600
        
        if hours_diff <= 0:
            return 0.0
        
        # Calculate acceleration
        acceleration = (second_velocity - first_velocity) / hours_diff
        
        return acceleration
    
    def forecast_queue_position(self, days: int = DEFAULT_FORECAST_DAYS) -> List[Dict[str, Any]]:
        """Forecast queue position for the specified number of days"""
        if self.queue_history.empty:
            return []
        
        # Get current position, velocity, and acceleration
        current_position = self.queue_history['position'].iloc[-1]
        velocity = self.calculate_velocity()
        acceleration = self.calculate_acceleration()
        
        # Generate hourly forecast
        forecast = []
        hours = days * 24
        
        for hour in range(1, hours + 1):
            # Calculate forecasted position using physics formula: s = s0 + v*t + 0.5*a*t^2
            # Where s is position, v is velocity, a is acceleration, t is time
            forecasted_position = max(0, current_position - (velocity * hour + 0.5 * acceleration * hour * hour))
            
            # Calculate timestamp
            timestamp = pd.Timestamp.now() + pd.Timedelta(hours=hour)
            
            forecast.append({
                'hour': hour,
                'timestamp': timestamp.isoformat(),
                'position': round(forecasted_position, 1),
                'activated': forecasted_position <= 0
            })
        
        return forecast
    
    def estimate_activation_time(self) -> Dict[str, Any]:
        """Estimate when the validator will be activated"""
        if self.queue_history.empty:
            return {
                'activation_time': None,
                'hours_remaining': None,
                'days_remaining': None,
                'confidence': 'low'
            }
        
        forecast = self.forecast_queue_position()
        
        # Find first entry where position <= 0
        activation_entry = next((entry for entry in forecast if entry['activated']), None)
        
        if not activation_entry:
            return {
                'activation_time': None,
                'hours_remaining': None,
                'days_remaining': None,
                'confidence': 'low'
            }
        
        # Calculate hours and days remaining
        hours_remaining = activation_entry['hour']
        days_remaining = hours_remaining / 24
        
        # Determine confidence level based on data quality
        if len(self.queue_history) < 10:
            confidence = 'low'
        elif self.calculate_acceleration() > 0.1:  # High acceleration means less predictable
            confidence = 'medium'
        else:
            confidence = 'high'
        
        return {
            'activation_time': activation_entry['timestamp'],
            'hours_remaining': hours_remaining,
            'days_remaining': round(days_remaining, 1),
            'confidence': confidence
        }
    
    def get_queue_analytics(self) -> Dict[str, Any]:
        """Get comprehensive queue analytics"""
        # Update history with current data
        self.update_queue_history()
        
        # Calculate metrics
        current_data = self.fetch_current_queue_data()
        velocity = self.calculate_velocity()
        acceleration = self.calculate_acceleration()
        activation_estimate = self.estimate_activation_time()
        
        # Get historical trends
        history_data = []
        if not self.queue_history.empty:
            # Resample to daily data for UI display
            daily_data = self.queue_history.set_index('timestamp').resample('D').mean().reset_index()
            
            for _, row in daily_data.iterrows():
                history_data.append({
                    'timestamp': row['timestamp'].isoformat(),
                    'queue_length': row['queue_length'],
                    'position': row['position'],
                    'velocity': row['velocity']
                })
        
        # Generate forecast
        forecast = self.forecast_queue_position()
        
        # Calculate queue efficiency
        queue_efficiency = self.calculate_queue_efficiency()
        
        return {
            'current': {
                'queue_length': current_data.get('queue_length', 0),
                'position': current_data.get('position', 0),
                'wait_time_estimate': current_data.get('wait_time_estimate', 0),
                'velocity': velocity,
                'acceleration': acceleration,
                'stake_rate': current_data.get('stake_rate', 0),
                'timestamp': pd.Timestamp.now().isoformat()
            },
            'activation_estimate': activation_estimate,
            'history': history_data,
            'forecast': forecast,
            'efficiency': queue_efficiency
        }
    
    def calculate_queue_efficiency(self) -> Dict[str, Any]:
        """Calculate queue efficiency metrics"""
        if self.queue_history.empty:
            return {
                'throughput': 0,
                'consistency': 0,
                'predictability': 0,
                'overall_score': 0
            }
        
        # Calculate throughput (validators processed per day)
        recent_data = self.queue_history.sort_values('timestamp')
        if len(recent_data) >= 2:
            first_queue_length = recent_data['queue_length'].iloc[0]
            last_queue_length = recent_data['queue_length'].iloc[-1]
            first_time = recent_data['timestamp'].iloc[0]
            last_time = recent_data['timestamp'].iloc[-1]
            
            days_diff = (last_time - first_time).total_seconds() / (24 * 3600)
            if days_diff > 0:
                # Calculate validators that entered and exited the queue
                processed = max(0, (first_queue_length - last_queue_length) + 
                               (last_queue_length * 0.1))  # Estimate new entries
                throughput = processed / days_diff
            else:
                throughput = 0
        else:
            throughput = 0
        
        # Calculate consistency (inverse of velocity standard deviation)
        if len(self.queue_history) >= 3:
            velocity_std = self.queue_history['velocity'].std()
            velocity_mean = self.queue_history['velocity'].mean()
            if velocity_mean > 0:
                # Coefficient of variation (lower is better)
                cv = velocity_std / velocity_mean
                consistency = max(0, min(100, 100 * (1 - cv)))
            else:
                consistency = 0
        else:
            consistency = 0
        
        # Calculate predictability (based on acceleration)
        acceleration = abs(self.calculate_acceleration())
        if acceleration < 0.01:
            predictability = 100  # Very predictable
        else:
            predictability = max(0, min(100, 100 * (1 - (acceleration * 10))))
        
        # Calculate overall score
        overall_score = (throughput * 0.4) + (consistency * 0.3) + (predictability * 0.3)
        
        return {
            'throughput': round(throughput, 2),
            'consistency': round(consistency, 2),
            'predictability': round(predictability, 2),
            'overall_score': round(overall_score, 2)
        }


# Initialize analytics instance
queue_analytics = QueueAnalytics()

@queue_bp.route('/')
def index():
    """Render queue monitoring dashboard"""
    return render_template('queue_monitoring.html')

@queue_bp.route('/api/data')
def get_queue_data():
    """API endpoint to get queue data"""
    return jsonify(queue_analytics.get_queue_analytics())

@queue_bp.route('/api/forecast')
def get_forecast():
    """API endpoint to get queue forecast"""
    days = request.args.get('days', DEFAULT_FORECAST_DAYS, type=int)
    return jsonify(queue_analytics.forecast_queue_position(days))

@queue_bp.route('/api/history')
def get_history():
    """API endpoint to get queue history"""
    days = request.args.get('days', DEFAULT_HISTORY_DAYS, type=int)
    
    # Filter history for the specified period
    cutoff_time = pd.Timestamp.now() - pd.Timedelta(days=days)
    history = queue_analytics.queue_history[queue_analytics.queue_history['timestamp'] >= cutoff_time]
    
    # Convert to list of dicts for JSON serialization
    history_data = []
    for _, row in history.iterrows():
        history_data.append({
            'timestamp': row['timestamp'].isoformat(),
            'queue_length': row['queue_length'],
            'position': row['position'],
            'velocity': row['velocity'],
            'acceleration': row['acceleration'],
            'wait_time_estimate': row['wait_time_estimate']
        })
    
    return jsonify(history_data)

@queue_bp.route('/api/efficiency')
def get_efficiency():
    """API endpoint to get queue efficiency metrics"""
    return jsonify(queue_analytics.calculate_queue_efficiency())

@queue_bp.route('/api/update', methods=['POST'])
def update_data():
    """API endpoint to manually trigger data update"""
    queue_analytics.update_queue_history()
    return jsonify({'status': 'success', 'message': 'Queue data updated successfully'})


def register_queue_blueprint(app):
    """Register the queue blueprint with the Flask app"""
    app.register_blueprint(queue_bp)
    
    # Schedule regular updates
    @app.before_first_request
    def initialize_data():
        queue_analytics.update_queue_history() 