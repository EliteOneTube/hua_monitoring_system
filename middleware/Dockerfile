# Use a lightweight Python image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the script and .env file
COPY snmp_to_tb.py .

# Run the script
CMD ["python3", "snmp_to_tb.py"]
