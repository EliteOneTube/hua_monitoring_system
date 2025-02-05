#!/bin/bash

# ThingsBoard configuration
THINGSBOARD_HOST="your-thingsboard-host"
ACCESS_TOKEN="your-device-access-token"

# Log file for debugging
LOG_FILE="/tmp/gpu_power_monitor.log"

# Check if nvidia-smi is installed
if ! command -v nvidia-smi &> /dev/null; then
    echo "$(date) - ERROR: nvidia-smi not found. Ensure NVIDIA drivers are installed." >> "$LOG_FILE"
    exit 1
fi

# Get total power consumption of all GPUs
total_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | awk '{sum += $1} END {print sum}')

# Initialize JSON payload
payload="{\"total_power_usage_watts\": $total_power, \"gpus\":["

# Loop through each GPU
num_gpus=$(nvidia-smi --list-gpus | grep -v "MIG" | wc -l)
for ((gpu=0; gpu<num_gpus; gpu++)); do
    gpu_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits -i $gpu)
    gpu_utilization=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -i $gpu)
    
    # Ignore "N/A" for memory_utilization and rely on total memory usage instead
    total_mem_usage=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits -i $gpu | awk -F',' '{sum += $2} END {print sum+0}')  # Ensure sum is numeric

    temperature=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i $gpu)
    gpu_clock_mhz=$(nvidia-smi --query-gpu=clocks.gr --format=csv,noheader,nounits -i $gpu)
    memory_clock_mhz=$(nvidia-smi --query-gpu=clocks.mem --format=csv,noheader,nounits -i $gpu)

    # Get process information for this GPU
    processes=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits -i $gpu)

    # Process JSON array
    process_json="\"processes\":["

    # Parse processes and estimate power usage based on memory usage
    while IFS=',' read -r pid mem_usage; do
        if [[ -z "$pid" || -z "$mem_usage" ]]; then
            continue  # Skip empty lines
        fi

        # Compute estimated power usage per process
        if [ "$total_mem_usage" -gt 0 ] && [ "$mem_usage" -gt 0 ]; then
            power_usage=$(awk "BEGIN {printf \"%.2f\", ($mem_usage / $total_mem_usage) * $gpu_power}")
        else
            power_usage=0
        fi

        process_json+="{\"pid\": \"$pid\", \"memory_usage_mb\": $mem_usage, \"estimated_power_watts\": $power_usage},"
    done <<< "$processes"

    # Remove trailing comma if processes exist
    process_json=${process_json%,}
    process_json+="]"

    # Append GPU data
    payload+="{\"gpu_id\": $gpu, \"power_usage_watts\": $gpu_power, \"gpu_utilization\": $gpu_utilization, \"memory_utilization\": $total_mem_usage, \"temperature\": $temperature, \"gpu_clock_mhz\": $gpu_clock_mhz, \"memory_clock_mhz\": $memory_clock_mhz, $process_json},"
done

# Remove last comma from GPU array and close JSON
payload=${payload%,}
payload+="]}"

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
