# Testing Radio Registration Feature

This document explains how to test the web radio registration feature for Roon and VLC.

## What Was Fixed

The streaming server now supports continuous streaming even when librespot is idle (not playing any music). This allows the stream to be registered as a web radio station in Roon and other clients like VLC.

### Key Improvements

1. **Low-latency FFmpeg encoding**: Added flags to ensure immediate stream availability
   - `-fflags +nobuffer`: Disables internal buffering in FFmpeg
   - `-flags low_delay`: Minimizes encoding delay
   - `-max_delay 0`: Prevents buffering in the muxer

2. **Continuous silence streaming**: stream-mixer.py ensures audio is always flowing, even when librespot is idle

3. **Icecast-compatible headers**: The streaming server sends proper metadata headers that Roon and VLC can recognize

## Testing Prerequisites

- Docker and Docker Compose installed
- Access to the server's IP address from your test device
- Roon app (for Roon testing) or VLC (for VLC testing)

## Test 1: Stream Availability Before Librespot Plays

This tests that the stream is available immediately on startup, before any music is playing.

### Steps:

1. Start the container:
   ```bash
   docker compose up -d
   ```

2. Wait a few seconds for initialization

3. Test with curl (from the server or another machine on the network):
   ```bash
   # Check health
   curl http://YOUR_SERVER_IP:8080/health
   
   # Should return: {"status":"ok","clients":0,"max_clients":10}
   ```

4. Check stream headers:
   ```bash
   curl -I http://YOUR_SERVER_IP:8080/stream
   ```
   
   Expected headers should include:
   ```
   HTTP/1.1 200 OK
   Content-Type: audio/flac
   Transfer-Encoding: chunked
   icy-name: Roon Librespot FLAC Streamer
   icy-genre: Spotify
   icy-br: 1411
   ```

5. Test with VLC (before playing any Spotify music):
   ```bash
   vlc http://YOUR_SERVER_IP:8080/stream
   ```
   
   **Expected**: VLC should connect and play silence (or show that it's connected and buffering)

## Test 2: Roon Radio Registration

This tests that Roon can register the stream as an internet radio station.

### Steps:

1. Ensure the container is running

2. Open the Roon app

3. Navigate to: **Settings → Add Radio → Live Radio**

4. Enter the stream URL:
   ```
   http://YOUR_SERVER_IP:8080/stream
   ```

5. Click "Add Station"

**Expected**: 
- Roon should detect the stream metadata automatically
- Stream name should appear as "Roon Librespot FLAC Streamer"
- Genre should appear as "Spotify"
- The station should be added successfully

6. Try to play the radio station in Roon

**Expected**: 
- The stream should start playing (silence if no music is playing on Spotify)
- No errors or timeout messages

## Test 3: VLC Radio Registration

### Steps:

1. Open VLC

2. Go to: **Media → Open Network Stream** (or press Ctrl+N)

3. Enter:
   ```
   http://YOUR_SERVER_IP:8080/stream
   ```

4. Click **Play**

**Expected**: VLC should connect and either:
- Play silence (if nothing is playing on Spotify)
- Show as connected in the VLC interface

## Test 4: Stream Continues When Music Starts

This verifies that the stream transitions from silence to actual music seamlessly.

### Steps:

1. While VLC or Roon is connected to the stream (playing silence):

2. Open your Spotify app (phone, desktop, etc.)

3. Select "Roon Librespot FLAC Streamer" as the playback device

4. Start playing a song

**Expected**:
- The stream should transition from silence to music smoothly
- No disconnection or buffering
- Audio should be clear and in sync

## Test 5: Multiple Clients

### Steps:

1. Connect with VLC:
   ```bash
   vlc http://YOUR_SERVER_IP:8080/stream
   ```

2. In another terminal or device, connect with curl:
   ```bash
   curl http://YOUR_SERVER_IP:8080/stream > /tmp/test-stream.flac
   ```

3. Check health endpoint:
   ```bash
   curl http://YOUR_SERVER_IP:8080/health
   ```

**Expected**: 
- Should show 2 connected clients
- Both clients should receive the stream
- Response: `{"status":"ok","clients":2,"max_clients":10}`

## Troubleshooting

### Stream takes too long to start

If clients timeout or take a very long time to connect:

1. Check container logs:
   ```bash
   docker logs roon-librespot-streamer
   ```

2. Look for:
   - `[StreamServer]` messages showing server activity
   - `[StreamMixer]` messages showing stream-mixer activity
   - Any ffmpeg errors

### Stream disconnects immediately

1. Check if the container is running:
   ```bash
   docker ps | grep roon-librespot
   ```

2. Try connecting with verbose curl:
   ```bash
   curl -v http://YOUR_SERVER_IP:8080/stream
   ```

3. Check the response headers - they should include the Icecast headers

### No audio in Roon/VLC

1. Verify that health check shows the stream is running:
   ```bash
   curl http://YOUR_SERVER_IP:8080/health
   ```

2. Try playing something on Spotify to the device

3. Check container logs for errors

## Success Criteria

All tests pass if:

1. ✅ Stream is accessible immediately after container startup
2. ✅ VLC can connect and play the stream before Spotify playback
3. ✅ Roon can register the stream as an internet radio station
4. ✅ Stream transitions smoothly from silence to music
5. ✅ Multiple clients can connect simultaneously
6. ✅ Stream includes proper Icecast-compatible metadata headers

## Technical Details

### How It Works

1. **Stream Mixer**: `stream-mixer.py` monitors the librespot pipe and:
   - Outputs real audio when librespot is playing
   - Outputs silence (zeros) when librespot is idle
   - This ensures continuous audio flow

2. **FFmpeg Encoding**: Converts PCM to FLAC with low-latency flags:
   - Immediate encoding without buffering
   - Suitable for live streaming

3. **HTTP Streaming Server**: Go-based server that:
   - Broadcasts FLAC stream to multiple clients
   - Sends Icecast-compatible headers
   - Handles client timeouts gracefully

### Configuration

You can customize the stream metadata in `docker-compose.yml`:

```yaml
environment:
  - STREAM_NAME=My Custom Stream Name
  - STREAM_GENRE=Various
  - STREAM_DESCRIPTION=My personal Spotify stream
  - STREAM_URL=http://YOUR_SERVER_IP:8080
```

This metadata will appear in Roon and VLC when the stream is registered.
