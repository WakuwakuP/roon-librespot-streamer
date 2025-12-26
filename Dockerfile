FROM golang:1.21-bullseye AS go-builder

# Build the streaming server
WORKDIR /build
COPY streaming-server/ ./
RUN go build -ldflags="-s -w" -o streaming-server main.go

FROM rust:1.83-bullseye AS builder

# Configure environment to skip SSL verification
ENV GIT_SSL_NO_VERIFY=1
ENV CARGO_HTTP_CHECK_REVOKE=false
ENV CARGO_NET_GIT_FETCH_WITH_CLI=false
ENV CARGO_HTTP_CAINFO=/dev/null

# Disable rustup auto-update
RUN rustup set auto-self-update disable

# Install build dependencies
RUN apt-get update && apt-get install -y \
    libasound2-dev \
    libpulse-dev \
    portaudio19-dev \
    build-essential \
    pkg-config \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone and build librespot
WORKDIR /build
RUN mkdir -p ~/.cargo && \
    cat > ~/.cargo/config.toml <<'EOF'
[http]
check-revoke = false
[net]
git-fetch-with-cli = false
EOF
RUN git config --global http.sslVerify false && \
    git clone https://github.com/librespot-org/librespot.git && \
    cd librespot && \
    git checkout v0.5.0 && \
    rm -f rust-toolchain.toml && \
    cargo build --release --no-default-features --features "alsa-backend"

# Final stage
FROM debian:bullseye-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libasound2 \
    ffmpeg \
    alsa-utils \
    && rm -rf /var/lib/apt/lists/*

# Copy librespot binary from builder
COPY --from=builder /build/librespot/target/release/librespot /usr/local/bin/librespot

# Create a non-root user
RUN useradd -m -s /bin/bash librespot

# Create directories for configuration and cache
RUN mkdir -p /config /cache && chown -R librespot:librespot /config /cache

# Copy streaming server binary from go-builder
COPY --from=go-builder /build/streaming-server /usr/local/bin/streaming-server
RUN chmod +x /usr/local/bin/streaming-server

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Switch to non-root user
USER librespot
WORKDIR /home/librespot

# Expose Spotify connect port and HTTP streaming port
EXPOSE 57500
EXPOSE 8080

# Set environment variables with defaults
ENV DEVICE_NAME="Roon Librespot FLAC Streamer"
ENV BITRATE="320"
ENV CACHE_SIZE_LIMIT="1G"
ENV INITIAL_VOLUME="50"
ENV BACKEND="pipe"
ENV VOLUME_CONTROL="linear"
ENV HTTP_PORT="8080"
ENV HTTP_BIND_ADDR="0.0.0.0"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
