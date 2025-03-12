// dashboard.js - Main JavaScript for Ephemery Checkpoint Sync Dashboard

// Global variables
let syncChart = null;
let statusUpdateInterval = null;
let chartUpdateInterval = null;
let chart;
let chartData = {
    labels: [],
    lighthouseData: [],
    gethData: []
};
let webSocket;
let reconnectAttempts = 0;
const maxReconnectAttempts = 5;
const reconnectDelay = 3000; // 3 seconds

// DOM Ready
document.addEventListener('DOMContentLoaded', function() {
    // Initialize dashboard
    initDashboard();

    // Set up event listeners
    document.getElementById('restart-lighthouse').addEventListener('click', restartLighthouse);
    document.getElementById('check-sync-url').addEventListener('click', checkSyncUrls);
    document.getElementById('run-fix-script').addEventListener('click', runFixScript);
});

// Initialize the dashboard
function initDashboard() {
    // Initialize chart
    initChart();

    // Initialize WebSocket connection
    connectWebSocket();

    // Set up action buttons
    document.getElementById('restart-lighthouse').addEventListener('click', restartLighthouse);
    document.getElementById('check-sync-url').addEventListener('click', checkSyncUrls);
    document.getElementById('run-fix-script').addEventListener('click', runFixScript);

    // Initial status fetch (fallback)
    updateStatus();

    // Add date filtering functionality
    setupDateFilters();
}

// Connect to WebSocket server
function connectWebSocket() {
    // Close existing connection if any
    if (webSocket) {
        webSocket.close();
    }

    // Create new WebSocket connection
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.hostname;
    const port = 5001; // WebSocket server port

    webSocket = new WebSocket(`${protocol}//${host}:${port}`);

    // Connection event handlers
    webSocket.onopen = function() {
        console.log('WebSocket connection established');
        reconnectAttempts = 0;
        // Request historical data
        requestHistoricalData(1); // 1 day by default
    };

    webSocket.onmessage = function(event) {
        const data = JSON.parse(event.data);

        // Handle different message types
        if (data.action === 'history_data') {
            // Handle historical data
            processHistoricalData(data.data);
        } else {
            // Handle real-time update
            processRealTimeUpdate(data);
        }
    };

    webSocket.onerror = function(error) {
        console.error('WebSocket error:', error);
    };

    webSocket.onclose = function() {
        console.log('WebSocket connection closed');

        // Try to reconnect
        if (reconnectAttempts < maxReconnectAttempts) {
            reconnectAttempts++;
            console.log(`Attempting to reconnect (${reconnectAttempts}/${maxReconnectAttempts})...`);
            setTimeout(connectWebSocket, reconnectDelay);
        } else {
            console.log('Max reconnect attempts reached. Using fallback polling.');
            // Use fallback polling if WebSocket connection fails
            setInterval(updateStatus, 5000);
        }
    };
}

// Request historical data through WebSocket
function requestHistoricalData(days) {
    if (webSocket && webSocket.readyState === WebSocket.OPEN) {
        webSocket.send(JSON.stringify({
            action: 'get_history',
            days: days
        }));
    }
}

// Process historical data
function processHistoricalData(history) {
    // Reset chart data
    chartData = {
        labels: [],
        lighthouseData: [],
        gethData: []
    };

    // Process each history entry
    history.forEach(entry => {
        // Add timestamp
        const date = new Date(entry.timestamp);
        const timeLabel = date.toLocaleTimeString();
        chartData.labels.push(timeLabel);

        // Extract and add sync distances
        if (entry.lighthouse && entry.lighthouse.data) {
            const syncDistance = parseInt(entry.lighthouse.data.sync_distance);
            chartData.lighthouseData.push(syncDistance);
        } else {
            chartData.lighthouseData.push(null);
        }

        if (entry.geth && entry.geth.result !== false) {
            let syncDistance = 0;
            if (entry.geth.result) {
                const currentBlock = parseInt(entry.geth.result.currentBlock, 16);
                const highestBlock = parseInt(entry.geth.result.highestBlock, 16);
                syncDistance = highestBlock - currentBlock;
            }
            chartData.gethData.push(syncDistance);
        } else {
            chartData.gethData.push(null);
        }
    });

    // Update chart with new data
    updateChart();
}

// Process real-time update
function processRealTimeUpdate(data) {
    // Update lighthouse status
    if (data.lighthouse) {
        updateLighthouseStatus(data.lighthouse);
    }

    // Update geth status
    if (data.geth) {
        updateGethStatus(data.geth);
    }

    // Add data point to chart
    addDataPoint(data);
}

// Add new data point to chart
function addDataPoint(data) {
    // Add timestamp
    const date = new Date(data.timestamp);
    const timeLabel = date.toLocaleTimeString();
    chartData.labels.push(timeLabel);

    // Limit number of points to display
    const maxPoints = 50;
    if (chartData.labels.length > maxPoints) {
        chartData.labels.shift();
        chartData.lighthouseData.shift();
        chartData.gethData.shift();
    }

    // Add lighthouse data
    if (data.lighthouse && data.lighthouse.data) {
        const syncDistance = parseInt(data.lighthouse.data.sync_distance);
        chartData.lighthouseData.push(syncDistance);
    } else {
        chartData.lighthouseData.push(null);
    }

    // Add geth data
    if (data.geth && data.geth.result !== false) {
        let syncDistance = 0;
        if (data.geth.result) {
            const currentBlock = parseInt(data.geth.result.currentBlock, 16);
            const highestBlock = parseInt(data.geth.result.highestBlock, 16);
            syncDistance = highestBlock - currentBlock;
        }
        chartData.gethData.push(syncDistance);
    } else {
        chartData.gethData.push(null);
    }

    // Update chart
    updateChart();
}

// Fallback polling update method
function updateStatus() {
    // Only use if WebSocket is not connected
    if (webSocket && webSocket.readyState === WebSocket.OPEN) {
        return;
    }

    fetch('/api/status')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                if (data.lighthouse) {
                    updateLighthouseStatus(data.lighthouse);
                }
                if (data.geth) {
                    updateGethStatus(data.geth);
                }

                // Add point to chart
                addDataPoint({
                    lighthouse: data.lighthouse,
                    geth: data.geth,
                    timestamp: new Date().toISOString()
                });
            }
        })
        .catch(error => {
            console.error('Error fetching sync status:', error);
            setStatusError('lighthouse');
            setStatusError('geth');
        });
}

// Setup date filtering
function setupDateFilters() {
    const dateFilter = document.getElementById('date-filter');
    if (dateFilter) {
        dateFilter.addEventListener('change', function() {
            const days = parseInt(this.value);
            requestHistoricalData(days);
        });
    }
}

// Update the status display
function updateStatus() {
    fetch('/api/status')
        .then(response => response.json())
        .then(data => {
            updateLighthouseStatus(data.lighthouse);
            updateGethStatus(data.geth);

            // Update timestamp
            const timestamp = new Date(data.timestamp);
            document.querySelector('footer .text-muted').textContent =
                `Last updated: ${timestamp.toLocaleString()} | Ephemery Checkpoint Sync Dashboard`;
        })
        .catch(error => {
            console.error('Error fetching status:', error);
            setStatusError('lighthouse');
            setStatusError('geth');
        });
}

// Update Lighthouse status
function updateLighthouseStatus(data) {
    const statusElement = document.getElementById('lighthouse-status');
    const headSlotElement = document.getElementById('head-slot');
    const syncDistanceElement = document.getElementById('sync-distance');

    // Clear previous status
    statusElement.innerHTML = '';
    statusElement.className = 'status-indicator';

    if (data.is_syncing === null) {
        // Unknown state
        statusElement.classList.add('status-unknown');
        statusElement.textContent = '?';
        headSlotElement.textContent = 'Unknown';
        syncDistanceElement.textContent = 'Unknown';
    } else if (data.is_syncing) {
        // Syncing
        statusElement.classList.add('status-syncing');
        statusElement.textContent = '⟳';
        headSlotElement.textContent = data.head_slot;
        syncDistanceElement.textContent = data.sync_distance;
    } else {
        // Synced
        statusElement.classList.add('status-synced');
        statusElement.textContent = '✓';
        headSlotElement.textContent = data.head_slot;
        syncDistanceElement.textContent = '0';
    }
}

// Update Geth status
function updateGethStatus(data) {
    const statusElement = document.getElementById('geth-status');
    const currentBlockElement = document.getElementById('current-block');
    const highestBlockElement = document.getElementById('highest-block');
    const syncProgressElement = document.getElementById('sync-progress');

    // Clear previous status
    statusElement.innerHTML = '';
    statusElement.className = 'status-indicator';

    if (data.is_syncing === null) {
        // Unknown state
        statusElement.classList.add('status-unknown');
        statusElement.textContent = '?';
        currentBlockElement.textContent = 'Unknown';
        highestBlockElement.textContent = 'Unknown';
        syncProgressElement.textContent = 'Unknown';
    } else if (data.is_syncing) {
        // Syncing
        statusElement.classList.add('status-syncing');
        statusElement.textContent = '⟳';
        currentBlockElement.textContent = data.current_block.toLocaleString();
        highestBlockElement.textContent = data.highest_block.toLocaleString();

        // Calculate progress
        const progress = (data.current_block / data.highest_block * 100).toFixed(2);
        syncProgressElement.textContent = `${progress}%`;
    } else {
        // Synced
        statusElement.classList.add('status-synced');
        statusElement.textContent = '✓';
        currentBlockElement.textContent = data.current_block.toLocaleString();
        highestBlockElement.textContent = data.current_block.toLocaleString();
        syncProgressElement.textContent = '100%';
    }
}

// Set status to error
function setStatusError(client) {
    const statusElement = document.getElementById(`${client}-status`);
    statusElement.innerHTML = '';
    statusElement.className = 'status-indicator status-error';
    statusElement.textContent = '!';

    if (client === 'lighthouse') {
        document.getElementById('head-slot').textContent = 'Error';
        document.getElementById('sync-distance').textContent = 'Error';
    } else if (client === 'geth') {
        document.getElementById('current-block').textContent = 'Error';
        document.getElementById('highest-block').textContent = 'Error';
        document.getElementById('sync-progress').textContent = 'Error';
    }
}

// Initialize the sync chart
function initChart() {
    const ctx = document.getElementById('syncChart').getContext('2d');

    syncChart = new Chart(ctx, {
        type: 'line',
        data: {
            datasets: [
                {
                    label: 'Lighthouse Sync Distance',
                    borderColor: 'rgb(255, 99, 132)',
                    backgroundColor: 'rgba(255, 99, 132, 0.1)',
                    borderWidth: 2,
                    fill: true,
                    cubicInterpolationMode: 'monotone',
                    data: []
                },
                {
                    label: 'Geth Sync Progress (%)',
                    borderColor: 'rgb(54, 162, 235)',
                    backgroundColor: 'rgba(54, 162, 235, 0.1)',
                    borderWidth: 2,
                    fill: true,
                    cubicInterpolationMode: 'monotone',
                    data: [],
                    yAxisID: 'y1'
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: {
                    type: 'time',
                    time: {
                        unit: 'minute',
                        tooltipFormat: 'MMM D, YYYY, h:mm:ss a',
                        displayFormats: {
                            minute: 'h:mm a'
                        }
                    },
                    title: {
                        display: true,
                        text: 'Time'
                    }
                },
                y: {
                    beginAtZero: true,
                    title: {
                        display: true,
                        text: 'Lighthouse Sync Distance'
                    }
                },
                y1: {
                    position: 'right',
                    beginAtZero: true,
                    max: 100,
                    title: {
                        display: true,
                        text: 'Geth Sync Progress (%)'
                    }
                }
            },
            interaction: {
                mode: 'index',
                intersect: false
            },
            plugins: {
                legend: {
                    position: 'top',
                },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            let label = context.dataset.label || '';
                            if (label) {
                                label += ': ';
                            }

                            if (context.datasetIndex === 0) {
                                label += context.parsed.y;
                            } else {
                                label += context.parsed.y.toFixed(2) + '%';
                            }
                            return label;
                        }
                    }
                }
            }
        }
    });

    // Initial chart data
    updateChart();
}

// Update the sync chart with historical data
function updateChart() {
    fetch('/api/history?limit=100')
        .then(response => response.json())
        .then(data => {
            // Process data for chart
            const lighthouseData = [];
            const gethData = [];

            data.forEach(entry => {
                const timestamp = new Date(entry.timestamp);

                // Lighthouse data
                if (entry.lighthouse && entry.lighthouse.sync_distance && entry.lighthouse.sync_distance !== 'Unknown') {
                    lighthouseData.push({
                        x: timestamp,
                        y: parseInt(entry.lighthouse.sync_distance, 10)
                    });
                }

                // Geth data
                if (entry.geth && entry.geth.current_block !== 'Unknown' && entry.geth.highest_block !== 'Unknown') {
                    if (entry.geth.highest_block > 0) {
                        const progress = (entry.geth.current_block / entry.geth.highest_block) * 100;
                        gethData.push({
                            x: timestamp,
                            y: progress
                        });
                    }
                }
            });

            // Update chart data
            syncChart.data.datasets[0].data = lighthouseData;
            syncChart.data.datasets[1].data = gethData;
            syncChart.update();
        })
        .catch(error => {
            console.error('Error fetching history data:', error);
        });
}

// Function to restart Lighthouse
function restartLighthouse() {
    if (confirm('Are you sure you want to restart the Lighthouse client?')) {
        // Show loading indicator
        const statusElement = document.getElementById('lighthouse-status');
        const originalStatus = statusElement.textContent;
        statusElement.textContent = 'Restarting...';

        fetch('/api/restart/lighthouse', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                statusElement.textContent = 'Restarting. Please wait...';
                // Wait 5 seconds then check status again
                setTimeout(updateStatus, 5000);
            } else {
                statusElement.textContent = 'Restart failed: ' + data.error;
                setTimeout(() => { statusElement.textContent = originalStatus; }, 3000);
            }
        })
        .catch(error => {
            console.error('Error restarting Lighthouse:', error);
            statusElement.textContent = 'Restart failed: ' + error.message;
            setTimeout(() => { statusElement.textContent = originalStatus; }, 3000);
        });
    }
}

// Function to check sync URLs
function checkSyncUrls() {
    if (confirm('Do you want to check available checkpoint sync URLs?')) {
        // Create modal for results
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <span class="close">&times;</span>
                <h2>Checkpoint Sync URLs</h2>
                <div class="loading">Checking URLs...</div>
                <pre class="results"></pre>
            </div>
        `;
        document.body.appendChild(modal);

        // Show modal
        modal.style.display = 'block';

        // Close button functionality
        const closeBtn = modal.querySelector('.close');
        closeBtn.onclick = function() {
            modal.style.display = 'none';
            document.body.removeChild(modal);
        };

        // Click outside to close
        window.onclick = function(event) {
            if (event.target == modal) {
                modal.style.display = 'none';
                document.body.removeChild(modal);
            }
        };

        // Fetch results
        fetch('/api/check-sync-urls')
            .then(response => response.json())
            .then(data => {
                const loading = modal.querySelector('.loading');
                const results = modal.querySelector('.results');

                loading.style.display = 'none';

                if (data.success) {
                    results.textContent = data.output;
                } else {
                    results.textContent = 'Error checking URLs: ' + data.error;
                }
            })
            .catch(error => {
                const loading = modal.querySelector('.loading');
                const results = modal.querySelector('.results');

                loading.style.display = 'none';
                results.textContent = 'Error: ' + error.message;
            });
    }
}

// Function to run fix script
function runFixScript() {
    if (confirm('Do you want to run the fix checkpoint sync script? This may take a few minutes and will restart the client.')) {
        // Create modal for progress
        const modal = document.createElement('div');
        modal.className = 'modal';
        modal.innerHTML = `
            <div class="modal-content">
                <h2>Running Fix Script</h2>
                <div class="progress-container">
                    <div class="progress-bar"></div>
                </div>
                <div class="status-message">Initializing...</div>
                <pre class="output-log"></pre>
            </div>
        `;
        document.body.appendChild(modal);

        // Show modal
        modal.style.display = 'block';

        // Cannot close until finished

        // Update progress animation
        const progressBar = modal.querySelector('.progress-bar');
        const statusMessage = modal.querySelector('.status-message');
        const outputLog = modal.querySelector('.output-log');
        let progress = 0;

        // Animate progress bar
        const progressInterval = setInterval(() => {
            progress += 0.5;
            if (progress > 100) progress = 99; // Never complete until we get response
            progressBar.style.width = progress + '%';
        }, 500);

        // Update status message
        statusMessage.textContent = 'Running fix script. This may take several minutes...';

        // Run the fix script
        fetch('/api/run-fix-script', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            }
        })
        .then(response => response.json())
        .then(data => {
            clearInterval(progressInterval);
            progressBar.style.width = '100%';

            if (data.success) {
                statusMessage.textContent = 'Fix script completed successfully!';
                outputLog.textContent = data.output;

                // Add close button now that it's done
                const closeBtn = document.createElement('button');
                closeBtn.textContent = 'Close';
                closeBtn.className = 'close-button';
                closeBtn.onclick = function() {
                    modal.style.display = 'none';
                    document.body.removeChild(modal);
                    // Refresh status after closing
                    updateStatus();
                };
                modal.querySelector('.modal-content').appendChild(closeBtn);
            } else {
                statusMessage.textContent = 'Fix script encountered an error.';
                outputLog.textContent = data.error;

                // Add close button
                const closeBtn = document.createElement('button');
                closeBtn.textContent = 'Close';
                closeBtn.className = 'close-button';
                closeBtn.onclick = function() {
                    modal.style.display = 'none';
                    document.body.removeChild(modal);
                };
                modal.querySelector('.modal-content').appendChild(closeBtn);
            }
        })
        .catch(error => {
            clearInterval(progressInterval);
            progressBar.style.width = '100%';
            statusMessage.textContent = 'Error running fix script.';
            outputLog.textContent = 'Error: ' + error.message;

            // Add close button
            const closeBtn = document.createElement('button');
            closeBtn.textContent = 'Close';
            closeBtn.className = 'close-button';
            closeBtn.onclick = function() {
                modal.style.display = 'none';
                document.body.removeChild(modal);
            };
            modal.querySelector('.modal-content').appendChild(closeBtn);
        });
    }
}
