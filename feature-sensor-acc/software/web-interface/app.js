// CNC Vibration Monitor - Web Interface JavaScript

// Configuration
const CONFIG = {
    wsUrl: `ws://${window.location.hostname}:81`,  // WebSocket on port 81
    reconnectDelay: 2000,  // ms
    chartMaxPoints: 100,   // Keep last 100 points
    updateInterval: 100,   // ms (10 Hz)
};

// State
let ws = null;
let reconnectTimer = null;
let chart = null;
let chartData = {
    timestamps: [],
    vibrations: [],
};

// Initialize on page load
document.addEventListener('DOMContentLoaded', () => {
    initChart();
    initWebSocket();
    initEventListeners();
});

// ============================================================================
// WebSocket Connection
// ============================================================================

function initWebSocket() {
    console.log('Connecting to WebSocket:', CONFIG.wsUrl);
    
    ws = new WebSocket(CONFIG.wsUrl);
    
    ws.onopen = () => {
        console.log('WebSocket connected');
        updateConnectionStatus(true);
        
        // Request initial status
        ws.send(JSON.stringify({ type: 'get_status' }));
    };
    
    ws.onmessage = (event) => {
        try {
            const data = JSON.parse(event.data);
            handleWebSocketMessage(data);
        } catch (e) {
            console.error('Error parsing WebSocket message:', e);
        }
    };
    
    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        updateConnectionStatus(false);
    };
    
    ws.onclose = () => {
        console.log('WebSocket disconnected');
        updateConnectionStatus(false);
        
        // Attempt to reconnect
        reconnectTimer = setTimeout(() => {
            console.log('Attempting to reconnect...');
            initWebSocket();
        }, CONFIG.reconnectDelay);
    };
}

function handleWebSocketMessage(data) {
    switch (data.type) {
        case 'data':
            updateVibrationData(data);
            break;
        
        case 'status':
            updateSystemStatus(data);
            break;
        
        case 'event':
            handleEvent(data);
            break;
        
        case 'config':
            updateConfigUI(data);
            break;
        
        default:
            console.warn('Unknown message type:', data.type);
    }
}

// ============================================================================
// Data Updates
// ============================================================================

function updateVibrationData(data) {
    // Update current values
    document.getElementById('current-vib').textContent = `${data.magnitude.toFixed(2)} G`;
    
    // Update meter bar
    const meterBar = document.getElementById('vib-meter-bar');
    const percentage = Math.min((data.magnitude / 8.0) * 100, 100);
    meterBar.style.width = `${percentage}%`;
    
    // Update status card
    updateStatusCard(data.status);
    
    // Add to chart
    addChartData(data.timestamp, data.magnitude);
}

function updateStatusCard(status) {
    const statusCard = document.getElementById('status-card');
    const statusText = document.getElementById('system-status');
    
    // Remove all status classes
    statusCard.classList.remove('ok', 'warning', 'critical', 'emergency');
    
    // Add current status class
    statusCard.classList.add(status.toLowerCase());
    statusText.textContent = status;
    
    // Shake animation for critical/emergency
    if (status === 'CRITICAL' || status === 'EMERGENCY') {
        statusCard.classList.add('alert-shake');
        setTimeout(() => statusCard.classList.remove('alert-shake'), 500);
    }
}

function updateSystemStatus(data) {
    // Update info table
    document.getElementById('firmware-version').textContent = data.version || '-';
    document.getElementById('uptime').textContent = formatUptime(data.uptime) || '-';
    document.getElementById('ip-address').textContent = window.location.hostname;
    
    // Update peak and RMS if available
    if (data.peak !== undefined) {
        document.getElementById('peak-vib').textContent = `${data.peak.toFixed(2)} G`;
    }
    if (data.rms !== undefined) {
        document.getElementById('rms-vib').textContent = `${data.rms.toFixed(2)} G`;
    }
}

function handleEvent(data) {
    console.log('Event received:', data);
    
    // Show notification for important events
    if (data.level === 'EMERGENCY') {
        alert(`⚠️ EMERGENCY STOP!\n\n${data.reason || 'Critical vibration detected'}`);
    }
}

// ============================================================================
// Chart Management
// ============================================================================

function initChart() {
    const ctx = document.getElementById('vibrationChart').getContext('2d');
    
    chart = new Chart(ctx, {
        type: 'line',
        data: {
            datasets: [{
                label: 'Vibration (G)',
                data: [],
                borderColor: 'rgb(33, 150, 243)',
                backgroundColor: 'rgba(33, 150, 243, 0.1)',
                borderWidth: 2,
                tension: 0.4,
                fill: true,
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            scales: {
                x: {
                    type: 'realtime',
                    realtime: {
                        duration: 20000,  // 20 seconds
                        refresh: 100,     // 10 Hz
                        delay: 0,
                    },
                    grid: {
                        color: '#444444',
                    },
                    ticks: {
                        color: '#999999',
                    }
                },
                y: {
                    beginAtZero: true,
                    max: 8,
                    grid: {
                        color: '#444444',
                    },
                    ticks: {
                        color: '#999999',
                    }
                }
            },
            plugins: {
                legend: {
                    labels: {
                        color: '#cccccc',
                    }
                },
                annotation: {
                    annotations: {
                        warningLine: {
                            type: 'line',
                            yMin: 2.0,
                            yMax: 2.0,
                            borderColor: '#ff9800',
                            borderWidth: 1,
                            borderDash: [5, 5],
                            label: {
                                content: 'Warning',
                                enabled: true,
                                position: 'end',
                            }
                        },
                        criticalLine: {
                            type: 'line',
                            yMin: 4.0,
                            yMax: 4.0,
                            borderColor: '#f44336',
                            borderWidth: 1,
                            borderDash: [5, 5],
                            label: {
                                content: 'Critical',
                                enabled: true,
                                position: 'end',
                            }
                        }
                    }
                }
            }
        }
    });
}

function addChartData(timestamp, value) {
    // Add new data point
    chart.data.datasets[0].data.push({
        x: Date.now(),
        y: value,
    });
    
    // Keep only last N points
    if (chart.data.datasets[0].data.length > CONFIG.chartMaxPoints) {
        chart.data.datasets[0].data.shift();
    }
    
    // Update chart
    chart.update('none');  // 'none' mode for better performance
}

// ============================================================================
// UI Controls
// ============================================================================

function initEventListeners() {
    // Threshold sliders
    const sliders = ['warn', 'crit', 'emerg'];
    sliders.forEach(type => {
        const slider = document.getElementById(`threshold-${type}`);
        const display = document.getElementById(`threshold-${type}-value`);
        
        slider.addEventListener('input', (e) => {
            display.textContent = `${e.target.value} G`;
        });
    });
    
    // Save config button
    document.getElementById('save-config').addEventListener('click', saveConfig);
    
    // Reset config button
    document.getElementById('reset-config').addEventListener('click', resetConfig);
    
    // Reset peak button
    document.getElementById('reset-peak').addEventListener('click', resetPeak);
    
    // Download log button
    document.getElementById('download-log').addEventListener('click', downloadLog);
}

function saveConfig() {
    const config = {
        type: 'config',
        thresholds: {
            warning: parseFloat(document.getElementById('threshold-warn').value),
            critical: parseFloat(document.getElementById('threshold-crit').value),
            emergency: parseFloat(document.getElementById('threshold-emerg').value),
        }
    };
    
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify(config));
        console.log('Config saved:', config);
        
        // Visual feedback
        const btn = document.getElementById('save-config');
        const originalText = btn.textContent;
        btn.textContent = '✓ Opgeslagen';
        setTimeout(() => {
            btn.textContent = originalText;
        }, 2000);
    } else {
        alert('Niet verbonden met Pico. Kan configuratie niet opslaan.');
    }
}

function resetConfig() {
    // Reset to defaults
    document.getElementById('threshold-warn').value = 2.0;
    document.getElementById('threshold-warn-value').textContent = '2.0 G';
    
    document.getElementById('threshold-crit').value = 4.0;
    document.getElementById('threshold-crit-value').textContent = '4.0 G';
    
    document.getElementById('threshold-emerg').value = 6.0;
    document.getElementById('threshold-emerg-value').textContent = '6.0 G';
}

function resetPeak() {
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: 'reset_peak' }));
        document.getElementById('peak-vib').textContent = '0.00 G';
    }
}

function downloadLog() {
    // Request log download from Pico
    window.location.href = '/api/download_log';
}

function updateConfigUI(config) {
    if (config.thresholds) {
        document.getElementById('threshold-warn').value = config.thresholds.warning;
        document.getElementById('threshold-warn-value').textContent = 
            `${config.thresholds.warning} G`;
        
        document.getElementById('threshold-crit').value = config.thresholds.critical;
        document.getElementById('threshold-crit-value').textContent = 
            `${config.thresholds.critical} G`;
        
        document.getElementById('threshold-emerg').value = config.thresholds.emergency;
        document.getElementById('threshold-emerg-value').textContent = 
            `${config.thresholds.emergency} G`;
    }
}

// ============================================================================
// Utility Functions
// ============================================================================

function updateConnectionStatus(connected) {
    const indicator = document.getElementById('connection-indicator');
    const text = document.getElementById('connection-text');
    
    if (connected) {
        indicator.classList.remove('disconnected');
        indicator.classList.add('connected');
        text.textContent = 'Verbonden';
    } else {
        indicator.classList.remove('connected');
        indicator.classList.add('disconnected');
        text.textContent = 'Niet verbonden';
    }
}

function formatUptime(milliseconds) {
    if (!milliseconds) return '-';
    
    const seconds = Math.floor(milliseconds / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    if (days > 0) {
        return `${days}d ${hours % 24}u`;
    } else if (hours > 0) {
        return `${hours}u ${minutes % 60}m`;
    } else {
        return `${minutes}m ${seconds % 60}s`;
    }
}

// Clean up on page unload
window.addEventListener('beforeunload', () => {
    if (reconnectTimer) {
        clearTimeout(reconnectTimer);
    }
    if (ws) {
        ws.close();
    }
});
