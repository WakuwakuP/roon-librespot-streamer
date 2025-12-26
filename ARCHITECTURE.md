# Architecture Documentation

## システムアーキテクチャ (System Architecture)

このプロジェクトは、Spotify Connectクライアントとして動作し、受信した音声をFLAC形式でストリーミングするDockerコンテナを提供します。

This project provides a Docker container that acts as a Spotify Connect client and streams received audio in FLAC format.

```
┌─────────────┐      ┌──────────────────────────────────────┐
│   Spotify   │      │   Docker Container                   │
│     App     │      │                                      │
│             │      │  ┌────────────┐    ┌──────────────┐ │
│  (Phone/PC) │─────▶│  │ librespot  │───▶│ Named Pipe   │ │
│             │      │  │            │    │  (PCM Audio) │ │
└─────────────┘      │  └────────────┘    └──────┬───────┘ │
                     │                           │         │
   Spotify           │                           ▼         │
   Connect           │                    ┌──────────────┐ │
   Protocol          │                    │    ffmpeg    │ │
                     │                    │  (PCM→FLAC)  │ │
                     │                    └──────┬───────┘ │
                     │                           │         │
                     │                           ▼         │
                     │                    ┌──────────────┐ │
                     │                    │ FLAC Stream  │ │
                     │                    │   (stdout)   │ │
                     │                    └──────────────┘ │
                     └──────────────────────────────────────┘
```

## Components

### 1. librespot
- **役割 (Role)**: Spotify Connectクライアント
- **機能 (Function)**: Spotifyから音声データを受信し、PCM形式で出力
- **設定 (Configuration)**: 
  - デバイス名、ビットレート、音量制御などをカスタマイズ可能
  - キャッシュ機能により、パフォーマンスが向上

### 2. Named Pipe
- **役割 (Role)**: librespotとffmpeg間のデータ転送
- **機能 (Function)**: PCM音声データをバッファリング
- **形式 (Format)**: 16-bit signed little-endian, 44.1kHz, stereo

### 3. ffmpeg
- **役割 (Role)**: オーディオフォーマット変換
- **機能 (Function)**: PCM → FLAC変換
- **設定 (Configuration)**:
  - 圧縮レベル: 5 (バランス型)
  - サンプルレート: 44.1kHz (元のまま)
  - チャンネル: 2 (ステレオ)

## Audio Pipeline

### データフロー (Data Flow)

1. **Spotify → librespot**: 
   - Ogg Vorbis形式 (Spotifyのデフォルト)
   - 指定されたビットレート (96/160/320 kbps)

2. **librespot → Named Pipe**:
   - PCM (Pulse Code Modulation)
   - 16-bit signed, little-endian
   - 44.1kHz sampling rate
   - 2 channels (stereo)

3. **Named Pipe → ffmpeg**:
   - 同じPCM形式

4. **ffmpeg → Output**:
   - FLAC (Free Lossless Audio Codec)
   - 圧縮レベル 5
   - メタデータは保持

## Configuration Options

### Backend Modes

#### 1. Pipe Backend (デフォルト / Default)
```yaml
environment:
  - BACKEND=pipe
```

**使用例 (Use Case)**:
- FLACストリーミングが必要な場合
- ネットワーク経由で音声を送信する場合
- 音声処理パイプラインに接続する場合

**利点 (Advantages)**:
- フレキシブルな出力先
- 追加処理が可能
- ネットワークストリーミングに対応

#### 2. ALSA Backend
```yaml
environment:
  - BACKEND=alsa
  - DEVICE=default
volumes:
  - /dev/snd:/dev/snd
devices:
  - /dev/snd:/dev/snd
```

**使用例 (Use Case)**:
- 直接スピーカーで再生する場合
- ローカルオーディオデバイスを使用する場合

**利点 (Advantages)**:
- 低レイテンシ
- 直接ハードウェア制御

## Performance Considerations

### キャッシュ (Cache)
- librespotはローカルキャッシュを使用してパフォーマンスを向上
- デフォルト: 1GB
- 調整可能: `CACHE_SIZE_LIMIT`環境変数

### リソース使用量 (Resource Usage)
- CPU: 低～中程度 (FLAC変換による)
- メモリ: ~100-200MB
- ディスク: キャッシュサイズによる
- ネットワーク: Spotifyストリーミング帯域幅

### レイテンシ (Latency)
- Spotify → librespot: ~1-2秒
- librespot → ffmpeg → 出力: ~0.1-0.5秒
- 合計: ~1.5-3秒

## Security Considerations

### 非rootユーザー (Non-root User)
コンテナは`librespot`ユーザーとして実行され、セキュリティが向上します。

The container runs as the `librespot` user for improved security.

### ネットワーク (Network)
- ポート57500: Spotify Connect用 (mDNS discovery)
- `network_mode: host`が推奨 (mDNS用)

### 認証情報 (Credentials)
- Spotify Connect使用時は認証情報不要
- オプション: ユーザー名/パスワード (非推奨)
- 認証情報はキャッシュに安全に保存

## Troubleshooting Guide

### 一般的な問題 (Common Issues)

#### 1. デバイスが見つからない (Device Not Found)
**症状**: Spotify Connectデバイスリストに表示されない

**解決策**:
1. `network_mode: host`が設定されているか確認
2. ファイアウォールがポート57500を許可しているか確認
3. 同じネットワークに接続されているか確認
4. ログを確認: `docker logs roon-librespot-streamer`

#### 2. 音声が再生されない (No Audio Playback)
**症状**: デバイスは見つかるが音声が出ない

**解決策**:
1. BACKENDの設定を確認
2. ALSAバックエンドの場合、デバイスマッピングを確認
3. 音量設定を確認: `INITIAL_VOLUME`
4. キャッシュをクリアして再起動

#### 3. 接続が不安定 (Unstable Connection)
**症状**: 頻繁に切断される

**解決策**:
1. ネットワークの安定性を確認
2. キャッシュサイズを増やす
3. ビットレートを下げる
4. リソース使用率を確認

### ログの確認 (Checking Logs)

```bash
# 全ログを表示
docker logs roon-librespot-streamer

# リアルタイムでログを追跡
docker logs -f roon-librespot-streamer

# 最後の100行を表示
docker logs --tail 100 roon-librespot-streamer
```

## Advanced Usage

### カスタムFFmpeg設定 (Custom FFmpeg Configuration)

エントリポイントスクリプトを編集して、FFmpegのパラメータをカスタマイズできます:

You can customize FFmpeg parameters by editing the entrypoint script:

```bash
ffmpeg -f s16le -ar 44100 -ac 2 -i "$OUTPUT_FILE" \
    -c:a flac -compression_level 8 \  # より高い圧縮
    -f flac pipe:1
```

### 複数インスタンス (Multiple Instances)

異なるデバイス名で複数のインスタンスを実行できます:

You can run multiple instances with different device names:

```bash
docker run -d --name streamer1 --network host \
  -e DEVICE_NAME="Room 1" roon-librespot-streamer

docker run -d --name streamer2 --network host \
  -e DEVICE_NAME="Room 2" roon-librespot-streamer
```

## References

- [librespot GitHub](https://github.com/librespot-org/librespot)
- [FLAC Codec](https://xiph.org/flac/)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [Spotify Connect](https://www.spotify.com/connect/)
