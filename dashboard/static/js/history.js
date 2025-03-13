// history.js - JavaScript for the Ephemery Sync History page

// Global variables
let historyChart = null;
let syncData = [];
let timelineEvents = [];

// DOM Ready
document.addEventListener('DOMContentLoaded', function() {
    // Initialize history page
    initHistoryPage();
});

// Initialize the history page
function initHistoryPage() {
    // Load history data for the default time period (1 day)
    loadHistoryData(1);

    // Initialize chart
    initHistoryChart();
}

// Load history data for a specific time period
function loadHistoryData(days) {
    // Highlight the selected button
    const buttons = document.querySelector('.btn-group').querySelectorAll('.btn');
    buttons.forEach(btn => btn.classList.remove('active', 'btn-primary'));
    buttons.forEach(btn => btn.classList.add('btn-outline-primary'));

    // Get the clicked button and highlight it
    const clickedIndex = days === 0 ? 3 : (days === 1 ? 0 : (days === 7 ? 1 : 2));
    buttons[clickedIndex].classList.remove('btn-outline-primary');
    buttons[clickedIndex].classList.add('active', 'btn-primary');

    // Fetch data from the API
    fetch(`/api/history?days=${days}`)
        .then(response => response.json())
        .then(data => {
            syncData = data;
            // Process and display the history data
            updateHistoryChart(data);
            calculateStatistics(data);
            generateTimeline(data);
        })
        .catch(error => {
            console.error('Error fetching history data:', error);
            displayError('Failed to load history data. Please try again.');
        });
}

// Initialize the history chart
function initHistoryChart() {
    const ctx = document.getElementById('historyChart').getContext('2d');

    historyChart = new Chart(ctx, {
        type: 'line',
        data: {
            datasets: [
                {
                    label: 'Lighthouse Head Slot',
                    data: [],
                    borderColor: 'rgba(54, 162, 235, 1)',
                    backgroundColor: 'rgba(54, 162, 235, 0.2)',
                    borderWidth: 2,
                    tension: 0.4,
                    yAxisID: 'lighthouseAxis'
                },
                {
                    label: 'Geth Current Block',
                    data: [],
                    borderColor: 'rgba(255, 99, 132, 1)',
                    backgroundColor: 'rgba(255, 99, 132, 0.2)',
                    borderWidth: 2,
                    tension: 0.4,
                    yAxisID: 'gethAxis'
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            interaction: {
                mode: 'index',
                intersect: false
            },
            scales: {
                x: {
                    type: 'time',
                    time: {
                        unit: 'hour',
                        tooltipFormat: 'MMM DD, YYYY HH:mm:ss',
                        displayFormats: {
                            hour: 'MMM DD HH:mm'
                        }
                    },
                    title: {
                        display: true,
                        text: 'Time'
                    }
                },
                lighthouseAxis: {
                    type: 'linear',
                    position: 'left',
                    title: {
                        display: true,
                        text: 'Lighthouse Head Slot'
                    },
                    beginAtZero: false
                },
                gethAxis: {
                    type: 'linear',
                    position: 'right',
                    title: {
                        display: true,
                        text: 'Geth Current Block'
                    },
                    beginAtZero: false,
                    grid: {
                        drawOnChartArea: false
                    }
                }
            },
            plugins: {
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            let label = context.dataset.label || '';
                            if (label) {
                                label += ': ';
                            }
                            label += context.parsed.y.toLocaleString();
                            return label;
                        }
                    }
                }
            }
        }
    });
}

// Update the history chart with new data
function updateHistoryChart(data) {
    // Prepare datasets
    const lighthouseData = [];
    const gethData = [];

    // Process data
    data.forEach(entry => {
        if (entry.lighthouse && entry.lighthouse.head_slot) {
            lighthouseData.push({
                x: new Date(entry.timestamp),
                y: parseInt(entry.lighthouse.head_slot)
            });
        }

        if (entry.geth && entry.geth.current_block) {
            gethData.push({
                x: new Date(entry.timestamp),
                y: parseInt(entry.geth.current_block)
            });
        }
    });

    // Update chart data
    historyChart.data.datasets[0].data = lighthouseData;
    historyChart.data.datasets[1].data = gethData;

    // Update chart
    historyChart.update();
}

// Calculate and display statistics
function calculateStatistics(data) {
    if (data.length < 2) {
        return; // Not enough data to calculate statistics
    }

    // Sort data by timestamp
    data.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    // Calculate Lighthouse statistics
    let lighthouseSlots = data.filter(entry => entry.lighthouse && entry.lighthouse.head_slot)
        .map(entry => ({
            timestamp: new Date(entry.timestamp),
            slot: parseInt(entry.lighthouse.head_slot)
        }));

    if (lighthouseSlots.length >= 2) {
        // Calculate average slots per hour
        const hourDiff = (lighthouseSlots[lighthouseSlots.length - 1].timestamp - lighthouseSlots[0].timestamp) / (1000 * 60 * 60);
        const slotDiff = lighthouseSlots[lighthouseSlots.length - 1].slot - lighthouseSlots[0].slot;
        const avgSlotsPerHour = hourDiff > 0 ? (slotDiff / hourDiff).toFixed(2) : 0;

        // Calculate max sync rate (over 1-hour periods)
        let maxSyncRate = 0;
        for (let i = 1; i < lighthouseSlots.length; i++) {
            const hourDiff = (lighthouseSlots[i].timestamp - lighthouseSlots[i-1].timestamp) / (1000 * 60 * 60);
            if (hourDiff > 0) {
                const rate = (lighthouseSlots[i].slot - lighthouseSlots[i-1].slot) / hourDiff;
                maxSyncRate = Math.max(maxSyncRate, rate);
            }
        }

        // Calculate time to sync estimate
        const latestSlot = lighthouseSlots[lighthouseSlots.length - 1].slot;
        const slotDistance = data[data.length - 1].lighthouse?.sync_distance || 0;
        const timeToSyncHours = slotDistance > 0 && avgSlotsPerHour > 0
            ? (slotDistance / avgSlotsPerHour)
            : 0;

        // Calculate head slot gain in last 24h
        const oneDayAgo = new Date();
        oneDayAgo.setDate(oneDayAgo.getDate() - 1);
        const slotsOneDayAgo = lighthouseSlots.find(item => item.timestamp >= oneDayAgo);
        const slotGain = slotsOneDayAgo
            ? latestSlot - slotsOneDayAgo.slot
            : slotDiff;

        // Update UI
        document.getElementById('avg-slots-hour').textContent = `${avgSlotsPerHour} slots/hour`;
        document.getElementById('max-sync-rate').textContent = `${maxSyncRate.toFixed(2)} slots/hour`;
        document.getElementById('time-to-sync').textContent = timeToSyncHours > 0
            ? `${formatTimeEstimate(timeToSyncHours)}`
            : 'Sync complete';
        document.getElementById('head-slot-gain').textContent = `+${slotGain.toLocaleString()} slots`;
    }

    // Calculate Geth statistics
    let gethBlocks = data.filter(entry => entry.geth && entry.geth.current_block)
        .map(entry => ({
            timestamp: new Date(entry.timestamp),
            block: parseInt(entry.geth.current_block)
        }));

    if (gethBlocks.length >= 2) {
        // Calculate average blocks per hour
        const hourDiff = (gethBlocks[gethBlocks.length - 1].timestamp - gethBlocks[0].timestamp) / (1000 * 60 * 60);
        const blockDiff = gethBlocks[gethBlocks.length - 1].block - gethBlocks[0].block;
        const avgBlocksPerHour = hourDiff > 0 ? (blockDiff / hourDiff).toFixed(2) : 0;

        // Calculate max block rate (over 1-hour periods)
        let maxBlockRate = 0;
        for (let i = 1; i < gethBlocks.length; i++) {
            const hourDiff = (gethBlocks[i].timestamp - gethBlocks[i-1].timestamp) / (1000 * 60 * 60);
            if (hourDiff > 0) {
                const rate = (gethBlocks[i].block - gethBlocks[i-1].block) / hourDiff;
                maxBlockRate = Math.max(maxBlockRate, rate);
            }
        }

        // Calculate time to sync estimate
        const latestBlock = gethBlocks[gethBlocks.length - 1].block;
        const highestBlock = data[data.length - 1].geth?.highest_block || latestBlock;
        const blockDistance = highestBlock - latestBlock;
        const timeToSyncHours = blockDistance > 0 && avgBlocksPerHour > 0
            ? (blockDistance / avgBlocksPerHour)
            : 0;

        // Calculate block gain in last 24h
        const oneDayAgo = new Date();
        oneDayAgo.setDate(oneDayAgo.getDate() - 1);
        const blocksOneDayAgo = gethBlocks.find(item => item.timestamp >= oneDayAgo);
        const blockGain = blocksOneDayAgo
            ? latestBlock - blocksOneDayAgo.block
            : blockDiff;

        // Update UI
        document.getElementById('avg-blocks-hour').textContent = `${avgBlocksPerHour} blocks/hour`;
        document.getElementById('max-block-rate').textContent = `${maxBlockRate.toFixed(2)} blocks/hour`;
        document.getElementById('block-time-to-sync').textContent = timeToSyncHours > 0
            ? `${formatTimeEstimate(timeToSyncHours)}`
            : 'Sync complete';
        document.getElementById('block-gain').textContent = `+${blockGain.toLocaleString()} blocks`;
    }
}

// Generate timeline events
function generateTimeline(data) {
    const timelineContainer = document.getElementById('sync-events-timeline');
    timelineContainer.innerHTML = '';  // Clear previous events

    if (data.length === 0) {
        timelineContainer.innerHTML = '<div class="placeholder-message">No sync events available</div>';
        return;
    }

    // Detect significant events in the data
    const events = detectSignificantEvents(data);

    if (events.length === 0) {
        timelineContainer.innerHTML = '<div class="placeholder-message">No significant sync events detected</div>';
        return;
    }

    // Create event elements
    events.forEach(event => {
        const eventEl = document.createElement('div');
        eventEl.className = 'timeline-event';

        const dateObj = new Date(event.timestamp);
        const formattedDate = dateObj.toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });

        eventEl.innerHTML = `
            <div class="timeline-date">${formattedDate}</div>
            <div class="timeline-indicator ${event.type}"></div>
            <div class="timeline-content">
                <h5>${event.title}</h5>
                <p>${event.description}</p>
            </div>
        `;

        timelineContainer.appendChild(eventEl);
    });
}

// Detect significant events in the sync data
function detectSignificantEvents(data) {
    const events = [];

    // Sort data by timestamp
    data.sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));

    // Check for Lighthouse sync start
    if (data.length > 0 && data[0].lighthouse) {
        events.push({
            timestamp: data[0].timestamp,
            type: 'info',
            title: 'Sync Started',
            description: `Lighthouse sync started at head slot ${data[0].lighthouse.head_slot}`
        });
    }

    // Check for significant sync progress jumps
    for (let i = 1; i < data.length; i++) {
        const current = data[i];
        const previous = data[i-1];

        // Large slot jump (more than 5000 slots in a short period)
        if (current.lighthouse && previous.lighthouse &&
            current.lighthouse.head_slot && previous.lighthouse.head_slot) {

            const slotDiff = current.lighthouse.head_slot - previous.lighthouse.head_slot;
            const timeDiff = (new Date(current.timestamp) - new Date(previous.timestamp)) / (1000 * 60); // minutes

            if (slotDiff > 5000 && timeDiff < 30) {
                events.push({
                    timestamp: current.timestamp,
                    type: 'success',
                    title: 'Rapid Progress',
                    description: `Head slot jumped by ${slotDiff.toLocaleString()} slots in ${timeDiff.toFixed(1)} minutes`
                });
            }
        }

        // Sync stalled (no progress for a long time)
        if (current.lighthouse && previous.lighthouse &&
            current.lighthouse.head_slot && previous.lighthouse.head_slot) {

            const slotDiff = current.lighthouse.head_slot - previous.lighthouse.head_slot;
            const timeDiff = (new Date(current.timestamp) - new Date(previous.timestamp)) / (1000 * 60); // minutes

            if (slotDiff === 0 && timeDiff > 15) {
                events.push({
                    timestamp: current.timestamp,
                    type: 'warning',
                    title: 'Sync Stalled',
                    description: `No progress for ${timeDiff.toFixed(1)} minutes`
                });
            }
        }

        // Error events (can be detected by sudden drops in progress or other anomalies)
        if (current.lighthouse && previous.lighthouse &&
            current.lighthouse.head_slot && previous.lighthouse.head_slot) {

            const slotDiff = current.lighthouse.head_slot - previous.lighthouse.head_slot;

            if (slotDiff < -1000) { // Significant backward movement in slots
                events.push({
                    timestamp: current.timestamp,
                    type: 'error',
                    title: 'Sync Error',
                    description: `Head slot decreased by ${Math.abs(slotDiff).toLocaleString()} slots`
                });
            }
        }
    }

    // Check for sync completion or being nearly complete
    const lastEntry = data[data.length - 1];
    if (lastEntry.lighthouse && lastEntry.lighthouse.sync_distance !== undefined) {
        const syncDistance = parseInt(lastEntry.lighthouse.sync_distance);
        if (syncDistance === 0) {
            events.push({
                timestamp: lastEntry.timestamp,
                type: 'success',
                title: 'Sync Complete',
                description: 'Lighthouse sync completed successfully'
            });
        } else if (syncDistance < 100) {
            events.push({
                timestamp: lastEntry.timestamp,
                type: 'info',
                title: 'Near Complete',
                description: `Lighthouse sync almost complete (${syncDistance} slots remaining)`
            });
        }
    }

    return events;
}

// Helper function to format time estimate
function formatTimeEstimate(hours) {
    if (hours < 1) {
        return `${Math.ceil(hours * 60)} minutes`;
    } else if (hours < 24) {
        return `${Math.ceil(hours)} hours`;
    } else {
        const days = Math.floor(hours / 24);
        const remainingHours = Math.ceil(hours % 24);
        return `${days} days, ${remainingHours} hours`;
    }
}

// Display error message
function displayError(message) {
    // Simple implementation - can be enhanced with a modal or toast
    alert(message);
}
