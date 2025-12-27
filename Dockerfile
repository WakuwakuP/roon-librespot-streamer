FROM rust:1.75-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
	build-essential \
	libasound2-dev \
	libavahi-compat-libdnssd-dev \
	pkg-config \
	git \
	ca-certificates \
	&& rm -rf /var/lib/apt/lists/*

# Build librespot from source
WORKDIR /build
# Use latest stable version - v0.4.2 is too old and doesn't work with current Spotify API
# v0.5.0 or later is required for current Spotify authentication
ARG LIBRESPOT_VERSION=v0.8.0
# Note: SSL verification disabled as temporary workaround for CI/CD environments
# with self-signed certificates. In production, this image should be built in
# a properly configured environment with valid certificates.
ENV CARGO_HTTP_CHECK_REVOKE=false
RUN git config --global http.sslVerify false && \
	git clone --branch ${LIBRESPOT_VERSION} --depth 1 https://github.com/librespot-org/librespot.git && \
	cd librespot && \
	mkdir -p /root/.cargo && \
	echo '[http]' > /root/.cargo/config.toml && \
	echo 'check-revoke = false' >> /root/.cargo/config.toml && \
	echo '[net]' >> /root/.cargo/config.toml && \
	echo 'git-fetch-with-cli = true' >> /root/.cargo/config.toml && \
	cargo build --release --no-default-features --features with-dns-sd

# Final stage
FROM node:18-slim

# Install runtime dependencies
# libavahi-compat-libdnssd1 is required for Spotify Connect (Zeroconf/mDNS) discovery
RUN apt-get update && apt-get install -y \
	ffmpeg \
	curl \
	dbus \
	avahi-daemon \
	libavahi-compat-libdnssd1 \
	libnss-mdns \
	&& rm -rf /var/lib/apt/lists/*

# Copy librespot binary from builder
COPY --from=builder /build/librespot/target/release/librespot /usr/local/bin/librespot
RUN chmod +x /usr/local/bin/librespot

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
