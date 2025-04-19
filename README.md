## YTDLTT – MQTT-Controlled YouTube Downloader

ytdltt listens to the `yt/dl` MQTT topic and downloads YouTube videos or audio using `yt-dlp`.

The intended usecase is that this apps runs as systemd service (user
is fine). It watches a mqtt topic for a JSON string of paramters,
downloads the content and another mqtt topic to reply a wormhole code
to the sender who will be able to use that code to download directly.

It should work well with node-red and telegram. node-red receives the
telegram messages:

* checks if sender is authorized
* optionally we may apply params, debending on senderID
* downloads video
* replies with wormhole code if applicable  - and fills mqtt-topic.

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


* `url`: mandatory; prefix says if audio (A---) only or complete video (V---), prefix defaults to config[:variant] // audio
* `senderid`: optional; could be used (is not) except for telegram reply
* `mid`: optional; telegrams conversation id, 
* `paramters`: optional; expand yt-dlp argument list, also add different output path ( ["-P", "/tmp/foo"] )

```json
{
  "url": "A---https://youtu.be/xyz123",
  "senderid": 849936978,
  "mid": 2834,
  "parameters": ["-P", "/home/media/mom/incoming"]
}
```

### Example ytdltt.servie for systemd


placed in `~/.config/systemd/user/ytdltt.service`, edit to your needs


    Θ cat ~/.config/systemd/user/ytdltt.service
    [Unit]
    Description=Run ytdltt Ruby script (user)
    After=network.target

    [Service]
    Type=simple
    ExecStart=/run/current-system/sw/bin/ruby /etc/nixos/res/gems/ytdltt/bin/ytdltt
    WorkingDirectory=/etc/nixos/res/gems/ytdltt
    Environment=PATH=/run/current-system/sw/bin:/etc/nixos/res/gems/bin
    RestartSec=30s
    StartLimitBurst=5


    Restart=on-failure

    [Install]
    WantedBy=default.target
