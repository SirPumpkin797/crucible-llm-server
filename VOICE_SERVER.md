# iPhone XS Max AI Voice Server (experimental)

This branch adds a lightweight, foreground LAN server to the existing CrucibleLLM app. It is not a production Home Assistant integration yet.

## Capabilities
- Existing llama.cpp chat: `POST /v1/chat/completions` (JSON, model `local`)
- Apple Speech Chinese recognition: `POST /v1/audio/transcriptions`
- Apple speech playback **on the phone**: `POST /v1/audio/speak`
- Language/availability: `GET /v1/voice/status`
- Black OLED screen UI (keeps app in foreground, inhibits idle lock when enabled)

## Request bodies
STT accepts JSON of the form `{"audio_base64":"<base64-encoded WAV file>","require_offline":true}`. Record WAV mono PCM 16kHz for testing; network/client max request body is approximately 1MB including Base64. Set `require_offline` to false to permit Apple's recognition service to use the network; if enabled, recognition fails when the device lacks on-device zh-CN support. iOS will request speech-recognition authorization.

TTS accepts `{"text":"你好"}`. This version plays through the **iPhone speaker** and does not yet return WAV audio, a Wyoming endpoint, or media for an Echo Dot.

For a 5-second 16kHz PCM16 mono WAV file `sample.wav`, a test client may submit JSON audio using Python:

```python
import requests, base64
audio=base64.b64encode(open("sample.wav","rb").read()).decode()
print(requests.post("http://IPHONE_IP:8080/v1/audio/transcriptions",
 json={"audio_base64":audio,"require_offline":False}, timeout=120).json())
```

## Known limitations
- Device's Apple Speech support for offline zh-CN is checked at runtime; it cannot be assumed.
- App must stay in foreground. Pure black OLED UI is not locked-screen background execution.
- No authentication/TLS; use only on a trusted private LAN, not exposed to the internet.
- Voice recognition accepts complete WAV data, not a live Wyoming audio stream.
- TTS output is local playback only.
- Apple Speech may use Apple's remote service unless offline recognition is required and supported.
- Qwen and speech services share iOS memory; hardware stability and latency need on-device testing.
