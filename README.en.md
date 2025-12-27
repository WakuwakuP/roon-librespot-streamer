# Roon LibreSpot Streamer

A Docker image for streaming music from Spotify Connect to Roon WebRadio.

## Architecture

```
Spotify App
    ↓
Spotify Connect
    ↓
librespot (in Docker container)
    ↓
FIFO pipe
    ↓
FFmpeg + HTTP Streaming Server
    ↓
HTTP Stream (http://localhost:3000/stream)
    ↓
Roon (add as WebRadio)
```

## Features

- **No ALSA device required**: Works without ALSA devices on the host machine
- **Easy setup**: One-command deployment with Docker Compose
- **High-quality audio**: Supports streaming up to 320kbps
- **Roon integration**: Easy to use with Roon's WebRadio feature

## Requirements

- Docker
- Docker Compose
- Spotify Premium account
- Roon (with WebRadio feature)

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/WakuwakuP/roon-librespot-streamer.git
cd roon-librespot-streamer
```

### 2. Build and start with Docker Compose

```bash
docker compose up -d
```

### 3. Connect from Spotify

1. Open Spotify app
2. Select playback device
3. Choose "Spotify Connect (Roon)"
4. Play music

### 4. Add to Roon as WebRadio

1. Open Roon app
2. Go to Settings → Extensions → Internet Radio
3. Add a new radio station:
   - **URL**: `http://<Docker host IP>:3000/stream`
   - **Name**: Spotify Connect
4. Play "Spotify Connect" from your library

## Configuration

### Environment Variables

You can customize the following environment variables in `docker-compose.yml`:

| Variable | Default | Description |
|----------|---------|-------------|
| `DEVICE_NAME` | `Spotify Connect (Roon)` | Device name shown in Spotify app |
| `BITRATE` | `320` | Bitrate (96, 160, 320) |
| `STREAM_FORMAT` | `mp3` | Streaming format (mp3, opus, etc.) |
| `STREAMING_PORT` | `3000` | HTTP streaming port |
| `INITIAL_VOLUME` | `100` | Initial volume (0-100) |
| `VOLUME_CTRL` | `linear` | Volume control type (linear, log) |

### Example: Custom Configuration

```yaml
environment:
  - DEVICE_NAME=My Roon Streamer
  - BITRATE=320
  - INITIAL_VOLUME=80
  - STREAMING_PORT=8080
```

## Build Options

### Build from source (default)

```bash
docker compose build
```

**Note**: Some CI/CD environments may encounter SSL certificate verification issues. See [BUILD_NOTES.md](BUILD_NOTES.md) for details.

For local builds:
```bash
DOCKER_BUILDKIT=1 docker compose build
```

## Troubleshooting

### Cannot connect to stream

1. Check health status:
   ```bash
   curl http://localhost:3000/health
   ```

2. Check logs:
   ```bash
   docker compose logs -f
   ```

### Spotify device not found

- Ensure container is running
- Verify network mode is set to `host` (required for Spotify Connect mDNS discovery)

### Audio stuttering

- Try lowering `BITRATE` (e.g., 160)
- Check network connection
- Verify Docker host resources (CPU, memory)

## License

MIT License

## Acknowledgments

- [librespot](https://github.com/librespot-org/librespot) - Open Source Spotify client library
- [FFmpeg](https://ffmpeg.org/) - Audio/video processing
- [Roon](https://roonlabs.com/) - Music player
