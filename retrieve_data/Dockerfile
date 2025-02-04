# Use the official Python image as the base
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Set the working directory
WORKDIR /app

# Copy the requirements file
COPY requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the application code
COPY retrieve_data.py .

# Expose the port the app runs on
EXPOSE 5000

# Define the default command to run the application
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "retrieve_data:app"]