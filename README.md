# YTDLTT

**YTDLTT** is a small Ruby wrapper around `yt-dlp` that listens to an MQTT topic (`yt/dl`) and downloads YouTube videos or audio tracks.  
By prefixing the URL with `A---` (audio) or `V---` (video), you can control the variant.  
Downloads are stored in predefined directories (e.g. for Jellyfin), making new content instantly available.  
The tool automatically handles temp/home paths and supports custom `yt-dlp` parameters.

## Requirements

- Ruby  
- `yt-dlp` in `$PATH`  
- MQTT broker  
- Optional: [Trompie](https://github.com/your-org/trompie) library for MQTT + logging integration
