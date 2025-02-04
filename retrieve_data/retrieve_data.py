import requests
import json
import os
import io
from minio import Minio
from minio.error import S3Error
from datetime import datetime
import time

# Initialize MinIO client
minio_client = Minio(
    os.getenv('MINIO_SERVER'),
    access_key=os.getenv('MINIO_ACCESS_KEY'),
    secret_key=os.getenv('MINIO_SECRET_KEY'),
    secure=False
)

# Ensure the bucket exists
bucket_name = 'temperature'
if not minio_client.bucket_exists(bucket_name):
    minio_client.make_bucket(bucket_name)

# ThingsBoard API details
thingsboard_url = os.getenv('THINGSBOARD_SERVER')
entity_type = 'device'
username = os.getenv('THINGSBOARD_TENANT_USERNAME')
password = os.getenv('THINGSBOARD_TENANT_PASSWORD')

# List of device IDs you want to query telemetry data for
device_keys = {
    'device-id-1': ['temperature', 'humidity'],
    'device-id-2': ['temperature'],
    'device-id-3': ['humidity']
}

# Function to calculate the timestamp for the last hour
def get_last_hour_timestamps():
    end_ts = int(datetime.utcnow().timestamp() * 1000)  # Current time in milliseconds
    start_ts = end_ts - (60 * 60 * 1000)  # 1 hour ago in milliseconds
    return start_ts, end_ts

# Login and get the token
def get_access_token():
    url = f'{thingsboard_url}/api/auth/login'
    headers = {'Content-Type': 'application/json'}
    data = {
        'username': username,
        'password': password
    }

    response = requests.post(url, json=data, headers=headers)

    if response.status_code == 200:
        # Extract the token from the response
        token = response.json()['token']
        return token
    else:
        raise Exception(f"Error logging in: {response.text}")

# Query ThingsBoard API to get telemetry data for a specific device
def fetch_timeseries_data(token, device_id, start_ts, end_ts, keys):
    params = {
        'keys': ','.join(keys),
        'startTs': start_ts,
        'endTs': end_ts,
        'interval': 60000,  # interval in ms (1 minute for example)
        'agg': 'AVG',  # Aggregation method
        'limit': 500,  # Limit to the number of records
    }

    url = f'{thingsboard_url}/api/plugins/telemetry/{entity_type}/{device_id}/values/timeseries'
    headers = {
        'Authorization': f'Bearer {token}'
    }

    response = requests.get(url, headers=headers, params=params)

    if response.status_code != 200:
        raise Exception(f"Error fetching data for device {device_id}: {response.text}")

    return response.json()

# Process data and upload to MinIO
def upload_to_minio(data, start_ts, end_ts):
    try:
        # Convert data to bytes
        data_bytes = io.BytesIO(json.dumps(data).encode('utf-8'))

        # Define the object name based on the current timestamp
        object_name = f"timeseries_all_devices_{start_ts}_{end_ts}.json"

        # Upload the data to MinIO
        minio_client.put_object(
            bucket_name,
            object_name,
            data_bytes,
            length=data_bytes.getbuffer().nbytes,
            content_type='application/json'
        )

        print("Data uploaded successfully to MinIO.")

    except S3Error as e:
        print(f"Error uploading data to MinIO: {str(e)}")

# Main function to fetch and upload data for multiple devices every hour
def fetch_and_upload():
    while True:
        try:
            # First, authenticate to get the token
            token = get_access_token()
            
            # Get the start and end timestamps for the last hour
            start_ts, end_ts = get_last_hour_timestamps()

            # Fetch telemetry data for each device
            all_device_data = {}

            for device in device_keys:
                print(f"Fetching data for device {device}...")
                
                # Fetch data for the device
                device_data = fetch_timeseries_data(token, device, start_ts, end_ts)
                
                # Filter only the required keys for this device
                filtered_data = {key: device_data.get(key, None) for key in device_keys[device]}
                
                # Store the filtered data
                all_device_data[device] = filtered_data

            # Upload the aggregated data to MinIO
            upload_to_minio(all_device_data, start_ts, end_ts)

        except Exception as e:
            print(f"Error: {str(e)}")

        # Sleep for 1 hour (3600 seconds)
        print("Waiting for the next hour...")
        time.sleep(3600)  # Sleep for 1 hour

if __name__ == '__main__':
    fetch_and_upload()
