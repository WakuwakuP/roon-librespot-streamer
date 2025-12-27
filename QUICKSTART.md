# Quick Start Guide / クイックスタートガイド

## English

### Prerequisites
- Docker and Docker Compose installed
- Spotify Premium account
- Roon Core with WebRadio feature
- Network access between Docker host and Roon Core

### Step 1: Clone and Build

```bash
# Clone the repository
git clone https://github.com/WakuwakuP/roon-librespot-streamer.git
cd roon-librespot-streamer

# Build and start (may take several minutes for first build)
docker compose up -d
```

### Step 2: Verify It's Running

```bash
# Check logs
docker compose logs -f

# Check health
curl http://localhost:3000/health
```

You should see:
```json
{"status":"ok","clients":0,"fifo":true}
```

### Step 3: Connect from Spotify

1. Open your Spotify app (phone, desktop, etc.)
2. Start playing any song
3. Tap/click the "Devices Available" icon
4. Select "Spotify Connect (Roon)" from the list
5. Music should start playing through the streamer

### Step 4: Add to Roon

1. Open Roon
2. Go to Settings → Extensions → Internet Radio
3. Click "Add Radio"
4. Enter the following:
   - **Name:** Spotify Connect
   - **URL:** `http://<YOUR_DOCKER_HOST_IP>:3000/stream`
   - **Image URL:** (optional)
5. Save

### Step 5: Play in Roon

1. In Roon, go to your Library
2. Look for "Spotify Connect" in Internet Radio
3. Select it and start playback
4. Start playing music in Spotify app

That's it! Your Spotify music should now be playing through Roon.

---

## 日本語

### 前提条件
- Docker と Docker Compose がインストール済み
- Spotify Premium アカウント
- Roon Core (WebRadio 機能付き)
- Docker ホストと Roon Core 間のネットワークアクセス

### ステップ 1: クローンとビルド

```bash
# リポジトリをクローン
git clone https://github.com/WakuwakuP/roon-librespot-streamer.git
cd roon-librespot-streamer

# ビルドと起動（初回は数分かかります）
docker compose up -d
```

### ステップ 2: 動作確認

```bash
# ログを確認
docker compose logs -f

# ヘルスチェック
curl http://localhost:3000/health
```

以下のような応答があれば OK:
```json
{"status":"ok","clients":0,"fifo":true}
```

### ステップ 3: Spotify から接続

1. Spotify アプリを開く（スマホ、PC など）
2. 任意の曲を再生
3. 「デバイスで再生」アイコンをタップ/クリック
4. リストから「Spotify Connect (Roon)」を選択
5. 音楽がストリーマー経由で再生開始

### ステップ 4: Roon に追加

1. Roon を開く
2. 設定 → Extensions → Internet Radio へ移動
3. 「Add Radio」をクリック
4. 以下を入力:
   - **Name:** Spotify Connect
   - **URL:** `http://<Docker ホストの IP>:3000/stream`
   - **Image URL:** (オプション)
5. 保存

### ステップ 5: Roon で再生

1. Roon のライブラリを開く
2. Internet Radio で「Spotify Connect」を探す
3. 選択して再生開始
4. Spotify アプリで音楽を再生

これで完了！Spotify の音楽が Roon で再生されます。

---

## Common Issues / よくある問題

### Spotify device not found / Spotify デバイスが見つからない

**Solution:**
```bash
# Make sure container is running with host network
docker compose ps

# Restart with host network mode
docker compose down
docker compose up -d
```

### Cannot connect to stream / ストリームに接続できない

**Solution:**
```bash
# Check if port 3000 is accessible
curl http://localhost:3000/health

# Check firewall rules
sudo ufw allow 3000/tcp  # Ubuntu/Debian
```

### Audio is stuttering / 音声が途切れる

**Solution:**
Edit `docker-compose.yml` and lower the bitrate:
```yaml
environment:
  - BITRATE=160  # or 96
```

Then restart:
```bash
docker compose restart
```

### Build fails with SSL errors / SSL エラーでビルドが失敗

**Solution:**
See [BUILD_NOTES.md](BUILD_NOTES.md) for detailed workarounds.

---

## Advanced Configuration / 詳細設定

### Custom Device Name / デバイス名のカスタマイズ

Edit `docker-compose.yml`:
```yaml
environment:
  - DEVICE_NAME=My Custom Name
```

### Different Port / ポート変更

Edit `docker-compose.yml`:
```yaml
environment:
  - STREAMING_PORT=8080
ports:
  - "8080:8080"
```

### Different Audio Format / 音声形式の変更

Edit `docker-compose.yml`:
```yaml
environment:
  - STREAM_FORMAT=opus  # or aac, flac, etc.
```

---

## Support / サポート

For issues and questions:
- GitHub Issues: https://github.com/WakuwakuP/roon-librespot-streamer/issues
- Check [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
- Check [BUILD_NOTES.md](BUILD_NOTES.md) for build issues
