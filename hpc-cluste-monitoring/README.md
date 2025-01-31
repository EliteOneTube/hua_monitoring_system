
![HUA Logo](https://www.hua.gr/wp-content/uploads/2024/07/HUA-Logo-Gold-RGB.png)
# HCP Cluster - Power Consumption Monitoring

This script monitors the **total power consumption of all NVIDIA GPUs** in a cluster and sends the data to **ThingsBoard** via HTTP. 

## Features
✅ Checks if `nvidia-smi` is installed before execution.  
✅ Fetches **total GPU power consumption** using `nvidia-smi`.  
✅ Sends data to **ThingsBoard via HTTP (`curl`)**.  
✅ Designed to run **as a cron job** for periodic monitoring.  
✅ Logs execution details for debugging.  

## Prerequisites
- NVIDIA drivers and `nvidia-smi` must be installed.
- `curl` installed (most Linux distributions have it by default).


## Installation
1. **Download the script:**
   ```bash
   wget -O gpu_power_monitor.sh https://raw.githubusercontent.com/EliteOneTube/hua_monitoring_system/refs/heads/main/hpc-cluste-monitoring/gpu_power_monitor.sh
   ```

2. **Make the script executable:**
   ```bash
   chmod +x gpu_power_monitor.sh
   ```

3. **Modify the script to include your ThingsBoard details:**
   ```bash
   nano gpu_power_monitor.sh
   ```
   Update these variables:
   ```bash
   THINGSBOARD_HOST="your-thingsboard-host"
   ACCESS_TOKEN="your-device-access-token"
   ```

## Setting Up as a Cron Job
To run the script automatically at regular intervals:
1. Open the crontab editor:
   ```bash
   crontab -e
   ```
2. Add the following line to execute the script every 1 minutes:
   ```bash
   * * * * * /path/to/gpu_power_monitor.sh
   ```

## Logs & Debugging
The script logs execution details to `/var/log/gpu_power_monitor.log`.
To check logs:
```bash
cat /var/log/gpu_power_monitor.log
```

## Troubleshooting
### 1. `nvidia-smi: command not found`
- Ensure NVIDIA drivers are installed:
  ```bash
  sudo apt install nvidia-driver-<version>
  ```
- Reboot and check `nvidia-smi`:
  ```bash
  nvidia-smi
  ```

## Authors
jtsoukalas@hua.gr \
itp24107@hua.gr \
nhaskaris@hua.gr 




