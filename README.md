# Roon LibreSpot Streamer

Spotify Connect から Roon WebRadio へ音楽をストリーミングするための Docker イメージです。

📖 **[クイックスタートガイド (QUICKSTART.md)](QUICKSTART.md)** - 今すぐ始める！  
📐 **[アーキテクチャ詳細 (ARCHITECTURE.md)](ARCHITECTURE.md)** - 技術詳細

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
| `BITRATE` | `320` | ビットレート (96, 160, 320) - 非可逆圧縮形式用 |
| `STREAM_FORMAT` | `flac` | ストリーミング形式 (flac, mp3, opus など) |
| `STREAMING_PORT` | `3000` | HTTP ストリーミングポート |
| `SILENCE_ON_NO_INPUT` | `true` | librespot からの入力がない時に無音をストリーミング |
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

### ソースからビルド (デフォルト)

```bash
docker compose build
```

**注意**: CI/CD環境によってはSSL証明書の検証問題が発生する場合があります。詳細は [BUILD_NOTES.md](BUILD_NOTES.md) を参照してください。

ローカル環境でビルドする場合:
```bash
DOCKER_BUILDKIT=1 docker compose build
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

### Connection Reset エラー (ECONNRESET)

クライアント切断時に `ECONNRESET` エラーが表示される場合:

- これは正常な動作です。クライアントが接続を切断したことを示しています
- サーバーは自動的にクリーンアップを行い、FFmpeg プロセスを終了します
- エラーログは情報提供のためのものであり、機能には影響しません

### Spotify デバイスが見つからない

- コンテナが起動していることを確認
- ネットワークモードが `host` であることを確認（Spotify Connect の mDNS 検出に必要）

### 音声が途切れる

- `BITRATE` を下げてみる（例: 160）
- ネットワーク接続を確認
- Docker ホストのリソース（CPU、メモリ）を確認

### 認証情報のリセット

Spotify アカウントを変更したい、または認証をやり直したい場合:

```bash
# キャッシュボリュームを削除
docker compose down
docker volume rm roon-librespot-streamer_librespot-cache
docker compose up -d
```

再起動後、Spotify アプリから再度デバイスを選択すると、新しい認証情報が保存されます。

## ライセンス

MIT License

## 謝辞

- [librespot](https://github.com/librespot-org/librespot) - Open Source Spotify client library
- [FFmpeg](https://ffmpeg.org/) - Audio/video processing
- [Roon](https://roonlabs.com/) - Music player
