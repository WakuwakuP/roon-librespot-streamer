# Build Notes

## SSL Certificate Issues in CI/CD

The Docker build may encounter SSL certificate verification issues in certain CI/CD environments. This is a known issue with the build environment, not with the code itself.

### Workaround for Local Building

If you encounter SSL issues when building locally:

1. **Configure Docker to use your system's CA certificates**:
   ```bash
   docker build --network=host .
   ```

2. **Or build with BuildKit and proper SSL configuration**:
   ```bash
   DOCKER_BUILDKIT=1 docker build .
   ```

### Alternative: Use Pre-built Image

Once published to a container registry, you can use the pre-built image directly:

```yaml
services:
  roon-librespot-streamer:
    image: ghcr.io/wakuwakup/roon-librespot-streamer:latest
    # ... rest of configuration
```

## Development Environment

For development without SSL issues:

1. Clone the repository
2. Build locally with proper network configuration
3. Or use the source code with your own Rust toolchain:
   ```bash
   git clone https://github.com/librespot-org/librespot.git
   cd librespot
   cargo build --release --no-default-features
   # Copy binary to Docker image
   ```

## Testing Without Full Build

To test the streaming server component without building librespot:

```bash
cd streaming-server
npm install
FIFO_PATH=/tmp/test-audio node server.js
```

Then in another terminal:
```bash
mkfifo /tmp/test-audio
# Pipe some audio data to test
cat audio-file.raw > /tmp/test-audio
```
