#!/bin/bash

# ThingsBoard configuration
THINGSBOARD_HOST="your-thingsboard-host"
ACCESS_TOKEN="your-device-access-token"

# Log file for debugging
LOG_FILE="/tmp/gpu_power_monitor.log"

# Check if nvidia-smi is installed
if ! command -v nvidia-smi &> /dev/null; then
    echo "$(date) - ERROR: nvidia-smi not found. Ensure NVIDIA drivers are installed."
    exit 1
fi

# Get total power consumption of all GPUs
total_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | awk '{sum += $1} END {print sum}')

# Prepare JSON payload with total power
payload="{\"total_power_usage_watts\": $total_power"

# Loop through each GPU
num_gpus=$(nvidia-smi --list-gpus | wc -l)
for ((gpu=0; gpu<num_gpus; gpu++)); do
    gpu_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits -i $gpu)
    gpu_utilization=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i $gpu)
    memory_utilization=$(nvidia-smi --query-gpu=utilization.memory --format=csv,noheader,nounits -i $gpu)
    temperature=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i $gpu)
    gpu_clock_mhz=$(nvidia-smi --query-gpu=clocks.gr --format=csv,noheader,nounits -i $gpu)
    memory_clock_mhz=$(nvidia-smi --query-gpu=clocks.mem --format=csv,noheader,nounits -i $gpu)
    
    # Append GPU data to payload
    payload+=",\"gpu_${gpu}_power_usage\": $gpu_power"
    payload+=",\"gpu_${gpu}_gpu_utilization\": $gpu_utilization"
    payload+=",\"gpu_${gpu}_memory_utilization\": $memory_utilization"
    payload+=",\"gpu_${gpu}_temperature\": $temperature"
    payload+=",\"gpu_${gpu}_gpu_clock_mhz\": $gpu_clock_mhz"
    payload+=",\"gpu_${gpu}_memory_clock_mhz\": $memory_clock_mhz"
    
    # Get process-level memory usage
    processes=$(nvidia-smi --query-compute-apps=pid,memory_used --format=csv,noheader,nounits -i $gpu)
    process_json="\"gpu_${gpu}_processes\": ["
    
    # Check if processes are returned
    if [ -n "$processes" ]; then
        while IFS=',' read -r pid mem_usage; do
            # Ensure mem_usage has a value, else set to 0
            mem_usage=${mem_usage:-0}
            process_json+="{\"pid\": \"$pid\", \"memory_usage_mb\": $mem_usage},"
        done <<< "$processes"
        
        # Remove trailing comma if any process info was added
        process_json=${process_json%,}
    fi
    
    process_json+="]"
    
    # Append process data to GPU section
    payload+=", $process_json"
done

# Close the JSON payload
payload+="}"

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
