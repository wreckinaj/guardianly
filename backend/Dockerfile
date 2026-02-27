# Use the official lightweight Python image
FROM python:3.10-slim

# Allow statements and log messages to immediately appear in the Cloud Run logs
ENV PYTHONUNBUFFERED True

# Set the working directory inside the container
WORKDIR /app

# Copy the requirements file and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the backend code into the container
COPY . .

# Run the web service on container startup using gunicorn.
# Cloud Run injects the $PORT environment variable automatically (default 8080).
CMD exec gunicorn --bind :$PORT --workers 1 --threads 8 --timeout 0 server:app