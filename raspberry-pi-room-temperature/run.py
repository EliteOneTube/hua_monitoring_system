import os
import glob
import time
import subprocess

TARGET_URL = "http://10.100.106.227:8080/api/v1/iqq5mvy2rjeu4krmsah5/telemetry"

# Load 1-Wire modules
os.system("modprobe w1-gpio")
os.system("modprobe w1-therm")

# Find the sensor file
base_dir = "/sys/bus/w1/devices/"
device_folder = glob.glob(base_dir + "28*")[0]
device_file = device_folder + "/w1_slave"

def read_temp_raw():
    with open(device_file, "r") as f:
        return f.readlines()

def read_temp():
    lines = read_temp_raw()
    while "YES" not in lines[0]:
        time.sleep(0.2)
        lines = read_temp_raw()
    temp_output = lines[1].split("t=")[-1]
    temp_c = float(temp_output) / 1000.0
    return temp_c

while True:
    temp_value = read_temp()
    print(f"Temperature: {temp_value:.2f}  C")

    # Use cURL to send the temperature to another machine
    curl_command = [
        "curl",
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "-d", f'{{"temperature": {temp_value:.2f}}}',
        TARGET_URL
    ]
    subprocess.run(curl_command)
    # print(curl_command)

    time.sleep(30)  # Send every 10 seconds

