FROM debian:bullseye-slim

# Install runtime dependencies and build tools
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    libasound2 \
    ffmpeg \
    alsa-utils \
    && rm -rf /var/lib/apt/lists/*

# Download pre-built librespot binary from GitHub releases
# For x86_64 and aarch64 architectures
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl -L https://github.com/librespot-org/librespot/releases/download/v0.4.2/librespot-linux-x86_64.tar.gz -o /tmp/librespot.tar.gz && \
        tar -xzf /tmp/librespot.tar.gz -C /usr/local/bin/ && \
        chmod +x /usr/local/bin/librespot && \
        rm /tmp/librespot.tar.gz; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl -L https://github.com/librespot-org/librespot/releases/download/v0.4.2/librespot-linux-aarch64.tar.gz -o /tmp/librespot.tar.gz && \
        tar -xzf /tmp/librespot.tar.gz -C /usr/local/bin/ && \
        chmod +x /usr/local/bin/librespot && \
        rm /tmp/librespot.tar.gz; \
    else \
        echo "Architecture $ARCH not supported" && \
        echo "Please build from source using Dockerfile.build-from-source" && \
        exit 1; \
    fi

# Create a non-root user
RUN useradd -m -s /bin/bash librespot

# Create directories for configuration and cache
RUN mkdir -p /config /cache && chown -R librespot:librespot /config /cache

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER librespot
WORKDIR /home/librespot

# Expose Spotify connect port
EXPOSE 57500

# Set environment variables with defaults
ENV DEVICE_NAME="Roon Librespot FLAC Streamer"
ENV BITRATE="320"
ENV CACHE_SIZE_LIMIT="1G"
ENV INITIAL_VOLUME="50"
ENV BACKEND="pipe"
ENV VOLUME_CONTROL="linear"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
