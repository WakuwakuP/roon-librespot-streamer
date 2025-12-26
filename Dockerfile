FROM rust:1.75-bullseye as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    libasound2-dev \
    libpulse-dev \
    portaudio19-dev \
    build-essential \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Build librespot
WORKDIR /build
RUN cargo install librespot --no-default-features --features "alsa-backend"

# Final stage
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libasound2 \
    libpulse0 \
    ffmpeg \
    alsa-utils \
    && rm -rf /var/lib/apt/lists/*

# Copy librespot binary from builder
COPY --from=builder /usr/local/cargo/bin/librespot /usr/local/bin/librespot

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
