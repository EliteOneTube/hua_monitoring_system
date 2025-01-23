from flask import Flask, request, jsonify
from minio import Minio
from minio.error import S3Error
import os
import io

app = Flask(__name__)

# Initialize MinIO client
minio_client = Minio(
    os.getenv('MINIO_ENDPOINT', 'localhost:9000'),
    access_key=os.getenv('MINIO_ACCESS_KEY', 'minio_access_key'),
    secret_key=os.getenv('MINIO_SECRET_KEY', 'minio_secret_key'),
    secure=False  # Set to True if using HTTPS
)

# Ensure the bucket exists
bucket_name = os.getenv('MINIO_BUCKET')
if not minio_client.bucket_exists(bucket_name):
    minio_client.make_bucket(bucket_name)

@app.route('/upload', methods=['POST'])
def upload_data():
    try:
        # Retrieve JSON data from the request
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400

        # Convert data to bytes
        data_bytes = io.BytesIO(str(data).encode('utf-8'))

        # Define object name
        object_name = f"{data.get('device_id', 'unknown_device')}_{data.get('timestamp', 'no_timestamp')}.json"

        # Upload the data to MinIO
        minio_client.put_object(
            bucket_name,
            object_name,
            data_bytes,
            length=data_bytes.getbuffer().nbytes,
            content_type='application/json'
        )

        return jsonify({'message': 'Data uploaded successfully'}), 200

    except S3Error as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
