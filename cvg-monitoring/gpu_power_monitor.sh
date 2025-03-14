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

# Get process-level usage using nvidia-smi pmon -c 1
processes=$(nvidia-smi pmon -c 1 | awk 'NR>2 {print $2 "," ($6 == "-" ? 0 : $6) "," ($4 == "-" ? 0 : $4)}')

# Count total processes
total_processes_count=$(echo "$processes" | wc -l)

# Add total process count to JSON
payload+=",\"total_processes_count\": $total_processes_count"

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

    # Process JSON for this GPU
    process_json="\"gpu_${gpu}_processes\": ["

    # Calculate total SM utilization to distribute power
    total_sm_util=$(echo "$processes" | awk -F',' '{sum += $3} END {print sum}')

    # Check if processes exist
    if [ -n "$processes" ]; then
        while IFS=',' read -r pid mem_usage sm_util; do
            # If SM utilization is 0 or total_sm_util is 0, allocate equal power
            if [ "$total_sm_util" -gt 0 ] && [ "$sm_util" -gt 0 ]; then
                power_usage=$(awk "BEGIN {printf \"%.2f\", ($sm_util / $total_sm_util) * $gpu_power}")
            else
                power_usage=0
            fi
            
            process_json+="{\"pid\": \"$pid\", \"memory_usage_mb\": $mem_usage, \"sm_utilization\": $sm_util, \"estimated_power_watts\": $power_usage},"
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
