# Use an appropriate base image
FROM ubuntu:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    fuse \
    blobfuse=1.4.4

# Create necessary directories
RUN mkdir -p /mnt/blobfusetmp /mnt/blobfuseblockcache /mnt/blobfusefilecache

# Set environment variables for BlobFuse
ENV AZURE_STORAGE_ACCOUNT=<your-storage-account-name>
ENV AZURE_STORAGE_ACCESS_KEY=<your-storage-account-key>

# Copy your application code
COPY . /app

# Set the working directory
WORKDIR /app

# Run your application
CMD ["bash", "-c", "date"]