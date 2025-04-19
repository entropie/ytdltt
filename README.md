## YTDLTT – MQTT-Controlled YouTube Downloader

ytdltt listens to the `yt/dl` MQTT topic and downloads YouTube videos or audio using `yt-dlp`.

### Features

- Audio or video download via URL prefix:
  - `A---https://...` → audio (MP3)
  - `V---https://...` → video (MP4)
- Telegram message via MQTT on completion
- Optional: [Magic Wormhole](https://magic-wormhole.readthedocs.io/) one-time download code

### Requirements

- `yt-dlp` in `$PATH`
- MQTT broker
- Ruby with [`Trompie`](https://github.com/entropie/trompie)
- Optional: `magic-wormhole`

### Example MQTT Payload

```json
{
  "url": "A---https://youtu.be/xyz123",
  "senderid": 849936978,
  "mid": 2834,
  "parameters": ["-P", "/home/media/mom/incoming"]
}
