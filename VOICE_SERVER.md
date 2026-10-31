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

## Home Assistant Green setup (experimental custom integration)
1. Install the IPA from the GitHub prerelease asset through SideStore.
2. Launch the app on iPhone XS Max, grant Speech Recognition when requested by **Voice status**, start server and enter Black screen. Keep the iPhone unlocked, foregrounded and connected to the same LAN.
3. On Home Assistant Green, enable Samba or SSH access to the HA configuration directory. Copy the entire `ha_custom_components/iphone_ai_voice` folder to `/config/custom_components/iphone_ai_voice` (the folder contents must contain `manifest.json`, `__init__.py`, `config_flow.py`, `stt.py` and `tts.py`). Restart HA.
4. Go to Settings > Devices & services > Add integration > **iPhone AI Voice**. Enter `http://IPHONE_LAN_IP:8080` (no /v1 suffix).
5. In Settings > Voice assistants, configure an Assist pipeline with iPhone Chinese STT and iPhone Chinese TTS, language zh-CN. Home Assistant handles the conversation and smart-home commands; the iPhone LLM is still exposed separately at `/v1/chat/completions`.
6. Start by testing STT and TTS with HA's Assist interface, then test Echo Dot integration separately. Echo Dot 3 firmware modification remains a different project.

### LAN audio APIs
`POST /v1/audio/transcriptions` accepts `{"audio_base64":"<WAV data>","require_offline":false}` and responds with `{"text":"...","language":"zh-CN"}`.

`POST /v1/audio/speech` accepts `{"input":"你好"}` and responds with `{"audio_base64":"<WAV data>","format":"wav"}`, allowing HA to play the WAV through its configured player.

`POST /v1/audio/speak` accepts `{"text":"你好"}` and plays on the iPhone itself; it **does not** return audio.

The current STT implementation buffers a full short utterance before sending to the phone; it does **not** implement live streaming or Wyoming. It supports 16kHz mono 16-bit PCM speech segments, with short commands limited by the server's 1MB HTTP body cap.

## Remaining validation gates
- GitHub Actions must successfully build and publish an IPA. Swift source has **not** been validated by an XS Max test yet.
- Confirm zh-CN Apple Speech recognition authorization, online/offline capability, STT speed.
- Confirm AVSpeechSynthesizer WAV output can be played by Home Assistant.
- Confirm concurrency and ten successive chats without repeated punctuation or crashes.
- Confirm HA Green custom integration on the deployed HA Core version, and Echo Dot voice satellite compatibility.
- Verify sustained foreground service under black-screen view, with measured power and thermal behavior.

Do not expose the server's unauthenticated HTTP port to the internet.
