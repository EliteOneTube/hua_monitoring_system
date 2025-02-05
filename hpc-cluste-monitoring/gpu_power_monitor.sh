#!/bin/bash

# ThingsBoard configuration
THINGSBOARD_HOST="your-thingsboard-host"
ACCESS_TOKENS=("your-device-access-token-1" "your-device-access-token-2" "your-device-access-token-3" "your-device-access-token-4")  # Array of access tokens

# Log file for debugging
LOG_FILE="/tmp/gpu_power_monitor.log"

# Check if nvidia-smi is installed
if ! command -v nvidia-smi &> /dev/null; then
    echo "$(date) - ERROR: nvidia-smi not found. Ensure NVIDIA drivers are installed." >> "$LOG_FILE"
    exit 1
fi

# Get total power consumption of all GPUs
total_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits | awk '{sum += $1} END {print sum}')

# Loop through each GPU
num_gpus=$(nvidia-smi --list-gpus | grep -v "MIG" | wc -l)
for ((gpu=0; gpu<num_gpus; gpu++)); do
    gpu_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits -i $gpu)
    
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

        # Retrieve the user associated with the process
        process_user=$(ps -p $pid -o user=)

        # Compute estimated power usage per process
        if [ "$total_mem_usage" -gt 0 ] && [ "$mem_usage" -gt 0 ]; then
            power_usage=$(awk "BEGIN {printf \"%.2f\", ($mem_usage / $total_mem_usage) * $gpu_power}")
        else
            power_usage=0
        fi

        # Add user info to process JSON
        process_json+="{\"pid\": \"$pid\", \"memory_usage_mb\": $mem_usage, \"estimated_power_watts\": $power_usage, \"user\": \"$process_user\"},"
    done <<< "$processes"

    # Remove trailing comma if processes exist
    process_json=${process_json%,}
    process_json+="]"

    # Prepare GPU data JSON without gpu_id and with memory_usage_mb instead
    gpu_json="{\"power_usage_watts\": $gpu_power, \"memory_usage_mb\": $total_mem_usage, \"temperature\": $temperature, \"gpu_clock_mhz\": $gpu_clock_mhz, \"memory_clock_mhz\": $memory_clock_mhz, $process_json}"

    # Select the corresponding access token for this GPU
    access_token=${ACCESS_TOKENS[$gpu]}

    # Send data to ThingsBoard using HTTP API (via curl)
    http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$THINGSBOARD_HOST/api/v1/$access_token/telemetry" \
        -H "Content-Type: application/json" \
        -d "$gpu_json")

    # Log response from ThingsBoard
    if [ "$http_code" -eq 200 ]; then
        echo "$(date) - Data sent successfully for GPU $gpu: $gpu_json" >> "$LOG_FILE"
    else
        echo "$(date) - ERROR: Failed to send data for GPU $gpu (HTTP $http_code)" >> "$LOG_FILE"
    fi
done
