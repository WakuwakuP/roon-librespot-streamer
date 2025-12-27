FROM node:18-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Download and install librespot
ARG LIBRESPOT_VERSION=v0.4.2
RUN curl -L "https://github.com/librespot-org/librespot/releases/download/${LIBRESPOT_VERSION}/librespot-linux-amd64-${LIBRESPOT_VERSION}.tar.gz" \
    -o /tmp/librespot.tar.gz && \
    tar -xzf /tmp/librespot.tar.gz -C /usr/local/bin/ && \
    chmod +x /usr/local/bin/librespot && \
    rm /tmp/librespot.tar.gz

# Set up streaming server
WORKDIR /app/streaming-server
COPY streaming-server/package*.json ./
RUN npm install --production

COPY streaming-server/ ./

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables with defaults
ENV DEVICE_NAME="Spotify Connect (Roon)"
ENV BITRATE=320
ENV STREAM_FORMAT=mp3
ENV STREAMING_PORT=3000
ENV FIFO_PATH=/tmp/librespot-audio
ENV INITIAL_VOLUME=100
ENV VOLUME_CTRL=linear

# Expose streaming port
EXPOSE 3000

ENTRYPOINT ["/entrypoint.sh"]
