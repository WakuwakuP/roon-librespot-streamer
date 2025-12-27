#!/bin/bash
set -e

# Start D-Bus and Avahi for mDNS/Zeroconf (Spotify Connect discovery)
echo "Starting D-Bus and Avahi daemon for mDNS..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork 2>/dev/null || true
avahi-daemon --daemonize --no-chroot 2>/dev/null || true
sleep 1

# Create FIFO pipe for audio data
FIFO_PATH=${FIFO_PATH:-/tmp/librespot-audio}

if [ ! -p "$FIFO_PATH" ]; then
    echo "Creating FIFO at $FIFO_PATH"
    mkfifo "$FIFO_PATH"
fi

# Function to cleanup on exit
cleanup() {
    echo "Shutting down..."
    kill $LIBRESPOT_PID 2>/dev/null || true
    kill $SERVER_PID 2>/dev/null || true
    rm -f "$FIFO_PATH"
    exit 0
}

trap cleanup SIGTERM SIGINT EXIT

# Start the streaming server in background
echo "Starting streaming server on port ${STREAMING_PORT}..."
cd /app/streaming-server
node server.js &
SERVER_PID=$!

# Wait a moment for server to start
sleep 2

# Start librespot with FIFO output
echo "Starting librespot..."
echo "Device name: ${DEVICE_NAME}"
echo "Bitrate: ${BITRATE}k"
echo "Volume control: ${VOLUME_CTRL}"
echo "Initial volume: ${INITIAL_VOLUME}%"

# Set cache directory if specified
CACHE_ARGS=""
if [ -n "$CACHE_DIR" ]; then
    echo "Cache directory: ${CACHE_DIR}"
    mkdir -p "$CACHE_DIR"
    CACHE_ARGS="--cache $CACHE_DIR"
fi

librespot \
    --name "${DEVICE_NAME}" \
    --backend pipe \
    --device "$FIFO_PATH" \
    --bitrate ${BITRATE} \
    --initial-volume ${INITIAL_VOLUME} \
    --volume-ctrl ${VOLUME_CTRL} \
    --enable-volume-normalisation \
    --verbose \
    $CACHE_ARGS \
    ${LIBRESPOT_ARGS} &

LIBRESPOT_PID=$!

echo "✓ Librespot started (PID: $LIBRESPOT_PID)"
echo "✓ Streaming server started (PID: $SERVER_PID)"
echo "✓ Stream available at: http://0.0.0.0:${STREAMING_PORT}/stream"
echo ""
echo "Waiting for Spotify Connect..."

# Wait for all background processes
wait
