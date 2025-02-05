#!/bin/bash

# ThingsBoard configuration
THINGSBOARD_HOST="your-thingsboard-host"
ACCESS_TOKENS=("your-device-access-token-1" "your-device-access-token-2" "your-device-access-token-3" "your-device-access-token-4" "your-cluster-access-token")  # Array of access tokens

# Log file for debugging
LOG_FILE="/tmp/gpu_power_monitor.log"

# Check if nvidia-smi is installed
if ! command -v nvidia-smi &> /dev/null; then
    echo "$(date) - ERROR: nvidia-smi not found. Ensure NVIDIA drivers are installed." >> "$LOG_FILE"
    exit 1
fi

# Initialize variables for cluster-wide data
total_cluster_power=0
total_cluster_mem_usage=0
total_processes_count=0

# Loop through each GPU
num_gpus=$(nvidia-smi --list-gpus | grep -v "MIG" | wc -l)
for ((gpu=0; gpu<num_gpus; gpu++)); do
    gpu_power=$(nvidia-smi --query-gpu=power.draw --format=csv,noheader,nounits -i $gpu)
    
    # Ignore "N/A" for memory_utilization and rely on total memory usage instead
    total_mem_usage=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits -i $gpu | awk -F',' '{sum += $2} END {print sum+0}')  # Ensure sum is numeric

    temperature=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits -i $gpu)
    gpu_clock_mhz=$(nvidia-smi --query-gpu=clocks.gr --format=csv,noheader,nounits -i $gpu)
    memory_clock_mhz=$(nvidia-smi --query-gpu=clocks.mem --format=csv,noheader,nounits -i $gpu)

    # Get the number of processes for this GPU
    processes_count=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader,nounits -i $gpu | wc -l)

    # Prepare GPU data JSON without process details, only count
    gpu_json="{\"power_usage_watts\": $gpu_power, \"memory_usage_mb\": $total_mem_usage, \"temperature\": $temperature, \"gpu_clock_mhz\": $gpu_clock_mhz, \"memory_clock_mhz\": $memory_clock_mhz, \"processes_count\": $processes_count}"

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

    # Accumulate data for the cluster (total values)
    total_cluster_power=$(echo "$total_cluster_power + $gpu_power" | bc)
    total_cluster_mem_usage=$(echo "$total_cluster_mem_usage + $total_mem_usage" | bc)
    total_processes_count=$((total_processes_count + processes_count))
done

# Prepare total cluster data JSON
cluster_json="{\"total_power_usage_watts\": $total_cluster_power, \"memory_usage_mb\": $total_cluster_mem_usage, \"processes_count\": $total_processes_count}"

# Send cluster-wide data to ThingsBoard using the fifth access token
access_token=${ACCESS_TOKENS[4]}

# Send data to ThingsBoard
http_code=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$THINGSBOARD_HOST/api/v1/$access_token/telemetry" \
    -H "Content-Type: application/json" \
    -d "$cluster_json")

# Log response from ThingsBoard
if [ "$http_code" -eq 200 ]; then
    echo "$(date) - Cluster data sent successfully: $cluster_json" >> "$LOG_FILE"
else
    echo "$(date) - ERROR: Failed to send cluster data (HTTP $http_code)" >> "$LOG_FILE"
fi
