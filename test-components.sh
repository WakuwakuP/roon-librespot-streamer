#!/bin/bash
# Test script for the streaming server component
# This tests the server without requiring librespot to be built

set -e

echo "=== Testing Streaming Server Component ==="

# Navigate to streaming-server directory
cd "$(dirname "$0")/streaming-server"

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found"
    exit 1
fi
echo "✓ package.json found"

# Check if server.js exists
if [ ! -f "server.js" ]; then
    echo "❌ server.js not found"
    exit 1
fi
echo "✓ server.js found"

# Validate package.json
if ! node -e "JSON.parse(require('fs').readFileSync('package.json', 'utf8'))"; then
    echo "❌ package.json is not valid JSON"
    exit 1
fi
echo "✓ package.json is valid JSON"

# Check for required dependencies
if ! grep -q '"express"' package.json; then
    echo "❌ express dependency not found in package.json"
    exit 1
fi
echo "✓ express dependency found"

# Validate server.js syntax
if ! node --check server.js; then
    echo "❌ server.js has syntax errors"
    exit 1
fi
echo "✓ server.js syntax is valid"

# Check for required environment variables handling
if ! grep -q "STREAMING_PORT" server.js; then
    echo "❌ STREAMING_PORT environment variable not handled"
    exit 1
fi
echo "✓ STREAMING_PORT environment variable handled"

if ! grep -q "FIFO_PATH" server.js; then
    echo "❌ FIFO_PATH environment variable not handled"
    exit 1
fi
echo "✓ FIFO_PATH environment variable handled"

# Check for required endpoints
if ! grep -q "/stream" server.js; then
    echo "❌ /stream endpoint not found"
    exit 1
fi
echo "✓ /stream endpoint found"

if ! grep -q "/health" server.js; then
    echo "❌ /health endpoint not found"
    exit 1
fi
echo "✓ /health endpoint found"

# Check entrypoint.sh exists
cd ..
if [ ! -f "entrypoint.sh" ]; then
    echo "❌ entrypoint.sh not found"
    exit 1
fi
echo "✓ entrypoint.sh found"

# Check if entrypoint.sh has proper shebang
if ! head -n 1 entrypoint.sh | grep -q "^#!/bin/bash"; then
    echo "❌ entrypoint.sh missing proper shebang"
    exit 1
fi
echo "✓ entrypoint.sh has proper shebang"

# Check if entrypoint.sh is executable (in git)
if [ ! -x "entrypoint.sh" ]; then
    echo "⚠ entrypoint.sh is not executable (this may be expected in CI)"
else
    echo "✓ entrypoint.sh is executable"
fi

# Check Dockerfile exists
if [ ! -f "Dockerfile" ]; then
    echo "❌ Dockerfile not found"
    exit 1
fi
echo "✓ Dockerfile found"

# Check docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ docker-compose.yml not found"
    exit 1
fi
echo "✓ docker-compose.yml found"

# Validate docker-compose.yml syntax (basic check)
if ! grep -q "services:" docker-compose.yml; then
    echo "❌ docker-compose.yml is missing 'services:' section"
    exit 1
fi
echo "✓ docker-compose.yml has services section"

echo ""
echo "=== All Component Tests Passed ✓ ==="
echo ""
echo "Note: Full integration testing requires building the Docker image"
echo "See BUILD_NOTES.md for information about building with SSL issues"
