# HTTP Streaming Quick Start Guide

このガイドでは、新しく追加されたHTTPストリーミング機能の使い方を説明します。

This guide explains how to use the newly added HTTP streaming feature.

## 概要 (Overview)

このプロジェクトは、SpotifyからFLAC形式でHTTP経由で音声をストリーミングできるようになりました。

This project now supports streaming audio from Spotify in FLAC format over HTTP.

## セットアップ (Setup)

### 1. コンテナを起動 (Start the container)

```bash
docker compose up -d
```

デフォルトでは、HTTPストリーミングサーバーはポート8080で起動します。

By default, the HTTP streaming server starts on port 8080.

### 2. Spotifyに接続 (Connect Spotify)

1. Spotifyアプリを開く
2. 音楽を再生する
3. デバイス選択で"Roon Librespot FLAC Streamer"を選択

1. Open Spotify app
2. Play some music
3. Select "Roon Librespot FLAC Streamer" from devices

### 3. ストリームにアクセス (Access the stream)

音楽が再生されると、以下のURLでストリームにアクセスできます:

Once music is playing, you can access the stream at:

```
http://localhost:8080/stream
```

## 使用方法 (Usage)

### Webインターフェース (Web Interface)

ブラウザで以下にアクセス:

Open in browser:

```
http://localhost:8080/
```

使用方法、状態、接続クライアント数が表示されます。

Shows usage instructions, status, and connected client count.

### メディアプレイヤーで再生 (Play with Media Players)

#### VLC
```bash
vlc http://localhost:8080/stream
```

または、VLCの「ファイル」→「ネットワークストリームを開く」からURL入力

Or in VLC: File → Open Network Stream → Enter URL

#### mpv
```bash
mpv http://localhost:8080/stream
```

#### ffplay
```bash
ffplay http://localhost:8080/stream
```

### プログラムから利用 (Use from Programs)

#### Python Example
```python
import requests
import subprocess

# Stream to a media player
stream_url = "http://localhost:8080/stream"
subprocess.run(["ffplay", "-nodisp", "-autoexit", stream_url])
```

#### curl (保存)
```bash
# FLACファイルとして保存 (Save as FLAC file)
curl http://localhost:8080/stream > output.flac
```

### ヘルスチェック (Health Check)

サーバーの状態を確認:

Check server status:

```bash
curl http://localhost:8080/health
```

レスポンス例 (Example response):
```json
{
  "status": "ok",
  "clients": 2,
  "max_clients": 10
}
```

## カスタマイズ (Customization)

### ポート番号を変更 (Change Port)

```yaml
# docker-compose.yml
environment:
  - HTTP_PORT=9000
```

アクセス: `http://localhost:9000/stream`

### ネットワーク設定 (Network Settings)

特定のIPアドレスでのみリッスン (Listen on specific IP):

```yaml
environment:
  - HTTP_BIND_ADDR=192.168.1.100
  - HTTP_PORT=8080
```

## トラブルシューティング (Troubleshooting)

### ストリームにアクセスできない

1. コンテナが起動しているか確認:
```bash
docker ps | grep roon-librespot
```

2. ログを確認:
```bash
docker logs roon-librespot-streamer
```

3. ポートが開いているか確認:
```bash
curl http://localhost:8080/health
```

### 音声が途切れる (Audio stuttering)

- ネットワークの帯域幅を確認
- 同時接続数を確認 (最大10)
- ログでエラーを確認

### エラーメッセージの確認

サーバーのログ:
```bash
docker logs -f roon-librespot-streamer 2>&1 | grep StreamServer
```

## 技術仕様 (Technical Specifications)

- **フォーマット (Format)**: FLAC
- **サンプルレート (Sample Rate)**: 44.1kHz
- **ビット深度 (Bit Depth)**: 16-bit
- **チャンネル (Channels)**: 2 (Stereo)
- **圧縮レベル (Compression Level)**: 5
- **最大同時接続 (Max Concurrent Clients)**: 10
- **クライアントタイムアウト (Client Timeout)**: 30秒
- **プロトコル (Protocol)**: HTTP/1.1 with Icecast-compatible headers

### Icecast互換ヘッダー (Icecast-compatible Headers)

このサーバーは以下のIcecast互換ヘッダーを送信します:

This server sends the following Icecast-compatible headers:

- `icy-name`: ストリーム名 (Stream name)
- `icy-genre`: ジャンル情報 (Genre information)
- `icy-url`: 情報URL (Information URL)
- `icy-br`: ビットレート (Bitrate - 1411 kbps for FLAC 44.1kHz/16-bit)
- `icy-description`: ストリーム説明 (Stream description)
- `icy-pub`: 公開リスト設定 (Public listing - always 0/private)
- `icy-metaint`: メタデータ間隔 (Metadata interval - 0 for FLAC)

これらのヘッダーにより、RoonやVLC、その他のインターネットラジオクライアントがストリームを正しく認識できます。

These headers allow Roon, VLC, and other internet radio clients to properly recognize the stream.

## Roonへの登録方法 (How to Register in Roon)

1. コンテナを起動 (Start container)
2. Roonアプリで Settings → Add Radio → Live Radio
3. URL入力: `http://{YOUR_IP}:8080/stream`
4. ストリーム情報が自動検出されます (Stream info will be auto-detected)

**注意:** Spotifyで音楽を再生していなくても登録可能です。アイドル時は無音が配信されます。

**Note:** Registration works even when no music is playing on Spotify. Silence is streamed when idle.

**カスタム設定 (Custom configuration):**
```yaml
environment:
  - STREAM_NAME=My Custom Stream Name
  - STREAM_GENRE=Jazz
  - STREAM_DESCRIPTION=My personal Spotify stream
```

## セキュリティについて (Security Notes)

- このサーバーは認証なしで動作します
- ファイアウォールで適切にポートを制限してください
- 信頼できるネットワークでのみ使用してください

- This server operates without authentication
- Properly restrict ports with firewall rules
- Use only on trusted networks

## 次のステップ (Next Steps)

より高度な使い方については、以下を参照:

For advanced usage, see:

- [README.md](README.md) - Full documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - Implementation details

## サポート (Support)

問題が発生した場合は、GitHubのIssueで報告してください:

For issues, please report on GitHub Issues:

https://github.com/WakuwakuP/roon-librespot-streamer/issues
