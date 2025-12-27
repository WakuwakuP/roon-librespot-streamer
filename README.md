# Roon LibreSpot Streamer

Spotify Connect から Roon WebRadio へ音楽をストリーミングするための Docker イメージです。

## アーキテクチャ

```
Spotify アプリ
    ↓
Spotify Connect
    ↓
librespot (Docker コンテナ内)
    ↓
FIFO パイプ
    ↓
FFmpeg + HTTP ストリーミングサーバー
    ↓
HTTP ストリーム (http://localhost:3000/stream)
    ↓
Roon (WebRadio として追加)
```

## 特徴

- **ALSA デバイス不要**: ホストマシンに ALSA デバイスがなくても動作
- **簡単なセットアップ**: Docker Compose で一発起動
- **高品質オーディオ**: 最大 320kbps でのストリーミング対応
- **Roon との統合**: Roon の WebRadio 機能で簡単に利用可能

## 必要要件

- Docker
- Docker Compose
- Spotify Premium アカウント
- Roon (WebRadio 機能)

## クイックスタート

### 1. リポジトリのクローン

```bash
git clone https://github.com/WakuwakuP/roon-librespot-streamer.git
cd roon-librespot-streamer
```

### 2. Docker イメージのビルドと起動

```bash
docker compose up -d
```

### 3. Spotify で接続

1. Spotify アプリを開く
2. 再生デバイスを選択
3. "Spotify Connect (Roon)" を選択
4. 音楽を再生

### 4. Roon に WebRadio として追加

1. Roon アプリを開く
2. Settings → Extensions → Internet Radio
3. 新しいラジオ局を追加:
   - **URL**: `http://<Docker ホストの IP>:3000/stream`
   - **Name**: Spotify Connect
4. ライブラリから "Spotify Connect" を選択して再生

## 設定

### 環境変数

`docker-compose.yml` で以下の環境変数を変更できます：

| 変数名 | デフォルト値 | 説明 |
|--------|------------|------|
| `DEVICE_NAME` | `Spotify Connect (Roon)` | Spotify アプリに表示されるデバイス名 |
| `BITRATE` | `320` | ビットレート (96, 160, 320) |
| `STREAM_FORMAT` | `mp3` | ストリーミング形式 (mp3, opus など) |
| `STREAMING_PORT` | `3000` | HTTP ストリーミングポート |
| `INITIAL_VOLUME` | `100` | 初期音量 (0-100) |
| `VOLUME_CTRL` | `linear` | 音量制御方式 (linear, log) |

### 例: 設定のカスタマイズ

```yaml
environment:
  - DEVICE_NAME=My Roon Streamer
  - BITRATE=320
  - INITIAL_VOLUME=80
  - STREAMING_PORT=8080
```

## ビルドオプション

### プリビルド版 (デフォルト)

```bash
docker compose build
```

### ソースからビルド

より細かい制御が必要な場合：

```bash
docker compose -f docker-compose.yml build --build-arg DOCKERFILE=Dockerfile.build-from-source
```

または、直接ビルド：

```bash
docker build -f Dockerfile.build-from-source -t roon-librespot-streamer .
```

## トラブルシューティング

### ストリームに接続できない

1. ヘルスチェック確認:
   ```bash
   curl http://localhost:3000/health
   ```

2. ログの確認:
   ```bash
   docker compose logs -f
   ```

### Spotify デバイスが見つからない

- コンテナが起動していることを確認
- ネットワークモードが `host` であることを確認（Spotify Connect の mDNS 検出に必要）

### 音声が途切れる

- `BITRATE` を下げてみる（例: 160）
- ネットワーク接続を確認
- Docker ホストのリソース（CPU、メモリ）を確認

## ライセンス

MIT License

## 謝辞

- [librespot](https://github.com/librespot-org/librespot) - Open Source Spotify client library
- [FFmpeg](https://ffmpeg.org/) - Audio/video processing
- [Roon](https://roonlabs.com/) - Music player
