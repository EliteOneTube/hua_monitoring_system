#!/bin/bash

# ThingsBoard configuration
THINGSBOARD_HOST="your-thingsboard-host"
ACCESS_TOKEN="your-device-access-token"

# Log file for debugging
LOG_FILE="/var/log/gpu_power_monitor.log"

# Check if nvidia-smi is installed
if ! command -v nvidia-smi &> /dev/null; then
    echo "$(date) - ERROR: nvidia-smi not found. Ensure NVIDIA drivers are installed."
    exit 1
fi

# Get total power consumption of all GPUs
total_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | awk '{sum += $1} END {print sum}')

# Prepare JSON payload
payload="{\"total_power_usage_watts\": $total_power}"

# Send data to ThingsBoard using HTTP API (via curl)
http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$THINGSBOARD_HOST/api/v1/$ACCESS_TOKEN/telemetry" \
    -H "Content-Type: application/json" \
    -d "$payload")

# Log response from ThingsBoard
if [ "$http_code" -eq 200 ]; then
    echo "$(date) - Data sent successfully: $payload" >> "$LOG_FILE"
else
    echo "$(date) - ERROR: Failed to send data (HTTP $http_code)" >> "$LOG_FILE"
fi