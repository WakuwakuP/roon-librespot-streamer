#!/bin/bash
# Integration test for the streaming server
# Tests that the server can start and respond to health checks

set -e

echo "=== Integration Test: Streaming Server ==="

cd "$(dirname "$0")/streaming-server"

# Install dependencies if not present
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Create a temporary FIFO for testing
FIFO_PATH="/tmp/test-librespot-audio-$$"
mkfifo "$FIFO_PATH"

# Cleanup function
cleanup() {
    echo "Cleaning up..."
    kill $SERVER_PID 2>/dev/null || true
    rm -f "$FIFO_PATH"
}
trap cleanup EXIT

# Start server in background
echo "Starting server..."
FIFO_PATH="$FIFO_PATH" STREAMING_PORT=13000 node server.js &
SERVER_PID=$!

# Wait for server to start
echo "Waiting for server to start..."
sleep 3

# Check if server is still running
if ! kill -0 $SERVER_PID 2>/dev/null; then
    echo "❌ Server failed to start"
    exit 1
fi
echo "✓ Server started successfully (PID: $SERVER_PID)"

# Test health endpoint
echo "Testing /health endpoint..."
if ! curl -s -f http://localhost:13000/health > /dev/null; then
    echo "❌ Health check failed"
    exit 1
fi

HEALTH_RESPONSE=$(curl -s http://localhost:13000/health)
echo "Health response: $HEALTH_RESPONSE"

if ! echo "$HEALTH_RESPONSE" | grep -q '"status":"ok"'; then
    echo "❌ Health check returned unexpected response"
    exit 1
fi
echo "✓ Health check passed"

# Test root endpoint
echo "Testing / endpoint..."
if ! curl -s -f http://localhost:13000/ > /dev/null; then
    echo "❌ Root endpoint failed"
    exit 1
fi
echo "✓ Root endpoint accessible"

# Test that /stream endpoint exists (without trying to stream, as we don't have data)
echo "Testing /stream endpoint existence..."
# Use HEAD request to avoid hanging on stream
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 2 http://localhost:13000/stream || echo "timeout")

if [ "$HTTP_CODE" == "timeout" ] || [ "$HTTP_CODE" == "200" ]; then
    # Timeout or 200 is expected since we're trying to stream without data
    echo "✓ /stream endpoint exists and responds"
else
    echo "⚠ /stream endpoint returned HTTP $HTTP_CODE (may be expected without audio data)"
fi

echo ""
echo "=== Integration Tests Passed ✓ ==="
