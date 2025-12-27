# Troubleshooting Guide / トラブルシューティングガイド

This guide provides step-by-step solutions for common issues with the Roon Librespot FLAC Streamer.

## Table of Contents / 目次

- [Audio Key Errors / 音声キーエラー](#audio-key-errors--音声キーエラー)
- [Stream Not Recognized by Roon / Roonで認識されない](#stream-not-recognized-by-roon--roonで認識されない)
- [No Audio Playback / 音声が再生されない](#no-audio-playback--音声が再生されない)
- [Device Not Found in Spotify / Spotifyでデバイスが見つからない](#device-not-found-in-spotify--spotifyでデバイスが見つからない)
- [Connection Issues / 接続の問題](#connection-issues--接続の問題)

---

## Audio Key Errors / 音声キーエラー

### Symptoms / 症状

```
[ERROR librespot_core::audio_key] error audio key 0 1
[WARN librespot_playback::player] Unable to load key, continuing without decryption: Service unavailable { audio key error }
[ERROR librespot_playback::player] Unable to read audio file: Symphonia Decoder Error: Deadline expired before operation could complete
[ERROR librespot_playback::player] Skipping to next track, unable to load track
[WARN librespot_core::apresolve] Failed to resolve all access points, using fallbacks
```

### Root Cause / 根本原因

Librespot cannot retrieve audio decryption keys from Spotify servers due to DNS resolution issues with `apresolve.spotify.com`.

### Solution / 解決方法

#### Method 1: Docker Compose (Recommended / 推奨)

Docker Compose includes the necessary fix by default.

1. **Ensure you're using docker-compose.yml:**
   ```bash
   cd roon-librespot-streamer
   ```

2. **Stop and clear cache:**
   ```bash
   docker-compose down -v
   ```
   The `-v` flag removes volumes, including the cache.

3. **Start fresh:**
   ```bash
   docker-compose up -d
   ```

4. **Reconnect from Spotify:**
   - Open Spotify app (mobile/desktop)
   - Play any track
   - Select "Roon Librespot FLAC Streamer" from devices

5. **Verify it's working:**
   ```bash
   docker-compose logs -f
   ```
   
   Expected logs:
   - ✅ `Failed to resolve all access points, using fallbacks` (this is NORMAL)
   - ✅ No `error audio key` messages
   - ✅ `[StreamMixer] Streaming audio...` when playing

#### Method 2: Docker Run

If using `docker run` instead of docker-compose:

1. **Stop and remove the container:**
   ```bash
   docker stop roon-librespot-streamer
   docker rm roon-librespot-streamer
   ```

2. **Remove the cache volume:**
   ```bash
   docker volume rm librespot-cache
   ```

3. **Restart with the correct flags:**
   ```bash
   docker run -d \
     --name roon-librespot-streamer \
     --network host \
     --add-host apresolve.spotify.com:0.0.0.0 \
     -e DEVICE_NAME="Roon Librespot FLAC Streamer" \
     -v librespot-cache:/cache \
     roon-librespot-streamer
   ```
   
   **IMPORTANT:** The `--add-host apresolve.spotify.com:0.0.0.0` flag is REQUIRED.

4. **Reconnect from Spotify** (see step 4 in Method 1)

#### Method 3: System-wide Fix (No Docker)

If running librespot without Docker:

1. **Edit hosts file:**
   ```bash
   echo "0.0.0.0 apresolve.spotify.com" | sudo tee -a /etc/hosts
   ```

2. **Clear cache:**
   ```bash
   # Find and clear librespot cache (typical locations)
   # For systemd service:
   rm -rf ~/.cache/librespot/*
   
   # For custom installations, check your librespot --cache parameter
   # and clear that directory
   ```

3. **Restart librespot service**

### Why This Works / なぜこれで解決するか

Blocking `apresolve.spotify.com` forces librespot to use hardcoded fallback endpoints, which are more reliable. The "Failed to resolve all access points, using fallbacks" message is **expected behavior** and indicates the fix is working.

### Still Not Working? / まだ動かない？

If errors persist after following the above steps:

1. **Check if the block is active:**
   ```bash
   # Inside the container
   docker exec -it roon-librespot-streamer cat /etc/hosts | grep apresolve
   ```
   Should show: `0.0.0.0 apresolve.spotify.com`

2. **Verify cache was cleared:**
   ```bash
   # List volumes with librespot in the name
   docker volume ls | grep -i librespot
   ```
   If the volume wasn't removed, identify the exact volume name and remove it:
   ```bash
   # Remove specific volume (use the name from the ls command above)
   docker volume rm VOLUME_NAME
   ```
   Note: Volume names may be prefixed with the project directory (e.g., `roon-librespot-streamer_librespot-cache`).

3. **Check network connectivity:**
   ```bash
   docker exec -it roon-librespot-streamer ping -c 4 8.8.8.8
   ```

4. **Try a different Spotify account** temporarily to rule out account-specific issues.

---

## Stream Not Recognized by Roon / Roonで認識されない

### Symptoms / 症状

- Roon cannot find or recognize the stream when adding it as a Live Radio
- Stream URL returns an error or timeout
- Roon shows "Stream unavailable" or similar error

### Solution / 解決方法

#### Step 1: Verify Stream is Accessible / ストリームがアクセス可能か確認

1. **Check if the stream server is running:**
   ```bash
   docker-compose logs | grep StreamServer
   ```
   Should show: `Starting FLAC streaming server on 0.0.0.0:8080`

2. **Test with curl:**
   ```bash
   curl -I http://YOUR_IP:8080/stream
   ```
   
   Expected output:
   ```
   HTTP/1.1 200 OK
   Content-Type: audio/flac
   icy-name: Roon Librespot FLAC Streamer
   icy-genre: Spotify
   icy-br: 1411
   ```

3. **Test with a media player:**
   ```bash
   # VLC
   vlc http://YOUR_IP:8080/stream
   
   # mpv
   mpv http://YOUR_IP:8080/stream
   
   # ffplay
   ffplay http://YOUR_IP:8080/stream
   ```

#### Step 2: Check Network Configuration / ネットワーク設定を確認

1. **Verify the IP address:**
   ```bash
   # Get your Docker host IP
   hostname -I
   ```
   Use this IP in the stream URL for Roon.

2. **Check firewall rules:**
   ```bash
   # Linux
   sudo ufw status
   sudo ufw allow 8080/tcp
   
   # Check if port is listening
   ss -tlnp | grep 8080
   ```

3. **For Docker Desktop users (Mac/Windows):**
   - Use `host.docker.internal` instead of `localhost`:
     ```
     http://host.docker.internal:8080/stream
     ```
   - Or use your computer's network IP address

#### Step 3: Ensure Stream is Always Available / ストリームが常に利用可能か確認

The stream mixer ensures the stream is always available (with silence when idle).

1. **Check stream mixer logs:**
   ```bash
   docker-compose logs | grep StreamMixer
   ```
   Should show: `[StreamMixer] Streaming silence...` or `[StreamMixer] Streaming audio...`

2. **Verify FFmpeg is processing:**
   ```bash
   docker-compose logs | grep ffmpeg
   ```

#### Step 4: Add Stream to Roon / Roonにストリームを追加

1. Open Roon app
2. Go to **Settings → Add Radio → Live Radio**
3. Enter stream URL: `http://YOUR_IP:8080/stream`
4. Wait a few seconds for Roon to detect the stream
5. Roon should automatically detect the stream name and metadata

**Alternative formats to try:**
- With trailing slash: `http://YOUR_IP:8080/stream/`
- With explicit port: `http://YOUR_IP:8080/stream`
- Using hostname: `http://your-hostname.local:8080/stream`

#### Step 5: Customize Stream Metadata (Optional) / ストリームメタデータをカスタマイズ

If Roon doesn't detect the stream properly, customize the metadata:

```yaml
# docker-compose.yml
environment:
  - STREAM_NAME=My Spotify Stream
  - STREAM_GENRE=Various
  - STREAM_DESCRIPTION=Spotify streaming via Librespot
  - STREAM_URL=http://YOUR_IP:8080
```

Then restart:
```bash
docker-compose down
docker-compose up -d
```

### Still Not Working? / まだ動かない？

1. **Check container logs for errors:**
   ```bash
   docker-compose logs -f
   ```

2. **Restart the container:**
   ```bash
   docker-compose restart
   ```

3. **Try accessing from another device** on the same network to rule out device-specific issues.

4. **Check if Roon can reach the container:**
   - Ensure Roon and the container are on the same network
   - Try pinging the container's IP from the Roon device

---

## No Audio Playback / 音声が再生されない

### For FLAC Streaming (Pipe Backend)

1. **Verify the streaming pipeline is running:**
   ```bash
   docker-compose logs | grep -E "StreamMixer|ffmpeg|StreamServer"
   ```

2. **Check if the pipe exists:**
   ```bash
   docker exec -it roon-librespot-streamer ls -la /tmp/audio/
   ```
   Should show: `librespot.pcm` (named pipe)

3. **Test with VLC or mpv** (see Stream Not Recognized section)

### For ALSA Backend

1. **Verify ALSA devices are mounted:**
   ```bash
   docker exec -it roon-librespot-streamer aplay -l
   ```

2. **Check docker-compose.yml includes:**
   ```yaml
   volumes:
     - /dev/snd:/dev/snd
   devices:
     - /dev/snd:/dev/snd
   ```

---

## Device Not Found in Spotify / Spotifyでデバイスが見つからない

### Symptoms / 症状

- "Roon Librespot FLAC Streamer" doesn't appear in Spotify's device list
- Cannot connect to the device from Spotify app

### Solution / 解決方法

1. **Ensure network_mode is set to host:**
   ```yaml
   # docker-compose.yml
   network_mode: host
   ```
   This is required for mDNS/Spotify Connect discovery.

2. **Check firewall:**
   ```bash
   # Spotify Connect uses ports around 57500
   sudo ufw allow 57500/tcp
   sudo ufw allow 57500/udp
   ```

3. **Verify the container is running:**
   ```bash
   docker-compose ps
   ```

4. **Check logs for Spotify Connect messages:**
   ```bash
   docker-compose logs | grep -i spotify
   ```

5. **Restart Spotify app:**
   - Close and reopen Spotify app
   - Wait 10-20 seconds for device discovery

6. **Check if mDNS is working:**
   ```bash
   docker-compose logs | grep -i mdns
   ```

---

## Connection Issues / 接続の問題

### Container Won't Start / コンテナが起動しない

1. **Check logs:**
   ```bash
   docker-compose logs
   ```

2. **Verify Docker is running:**
   ```bash
   docker ps
   ```

3. **Check for port conflicts:**
   ```bash
   # Check if ports are already in use
   sudo lsof -i :8080
   sudo lsof -i :57500
   ```

### Container Crashes or Restarts / コンテナがクラッシュまたは再起動する

1. **Check memory and CPU:**
   ```bash
   docker stats
   ```

2. **View crash logs:**
   ```bash
   docker-compose logs --tail=100
   ```

3. **Increase log verbosity:**
   ```yaml
   environment:
     - RUST_LOG=info  # or debug
   ```

### Network Connectivity Issues / ネットワーク接続の問題

1. **Test DNS resolution:**
   ```bash
   docker exec -it roon-librespot-streamer nslookup google.com
   ```

2. **Test outbound connectivity:**
   ```bash
   docker exec -it roon-librespot-streamer curl -I https://www.google.com
   ```

3. **Check Docker network:**
   ```bash
   docker network ls
   docker network inspect host
   ```

---

## Getting Help / ヘルプを得る

If you're still experiencing issues after trying these solutions:

1. **Collect diagnostic information:**
   ```bash
   # Save logs
   docker-compose logs > logs.txt
   
   # Check configuration
   docker-compose config > config.txt
   
   # Check container status
   docker-compose ps > status.txt
   ```

2. **Create a GitHub issue** with:
   - Your `docker-compose.yml` (remove sensitive data)
   - Container logs (last 100 lines)
   - Steps you've already tried
   - Your environment (OS, Docker version)

3. **Include relevant commands:**
   ```bash
   docker --version
   docker-compose --version
   uname -a
   ```

---

## Quick Reference / クイックリファレンス

### Essential Commands / 重要なコマンド

```bash
# Start
docker-compose up -d

# Stop
docker-compose down

# Stop and clear cache
docker-compose down -v

# View logs (follow mode)
docker-compose logs -f

# View last 100 lines
docker-compose logs --tail=100

# Restart
docker-compose restart

# Rebuild
docker-compose up -d --build

# Check status
docker-compose ps

# Check resource usage
docker stats
```

### Test Commands / テストコマンド

```bash
# Test stream with curl
curl -I http://localhost:8080/stream

# Test stream with VLC
vlc http://localhost:8080/stream

# Test stream with mpv
mpv http://localhost:8080/stream

# Check if port is listening
ss -tlnp | grep 8080

# Test from another machine
curl -I http://YOUR_IP:8080/stream
```

### Debug Commands / デバッグコマンド

```bash
# Enter container shell
docker exec -it roon-librespot-streamer /bin/bash

# Check hosts file (verify apresolve block)
docker exec -it roon-librespot-streamer cat /etc/hosts | grep apresolve

# Check process list
docker exec -it roon-librespot-streamer ps aux

# Check network
docker exec -it roon-librespot-streamer ip addr
docker exec -it roon-librespot-streamer ping -c 4 8.8.8.8

# Check pipe
docker exec -it roon-librespot-streamer ls -la /tmp/audio/
```
