"""Chinese speech recognition using iOS native Apple Speech."""
from collections.abc import AsyncIterable
import base64
import io
import wave
import aiohttp
from homeassistant.components import stt
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from .const import DOMAIN

async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry, async_add_entities: AddEntitiesCallback):
    async_add_entities([IPhoneSTT(entry, hass)])

class IPhoneSTT(stt.SpeechToTextEntity):
    _attr_name = "iPhone Chinese STT"

    def __init__(self, entry, hass):
        self._attr_unique_id = entry.entry_id + "_stt"
        self._url = hass.data[DOMAIN][entry.entry_id]
        self._session = async_get_clientsession(hass)

    @property
    def supported_languages(self): return ["zh-CN"]
    @property
    def supported_formats(self): return [stt.AudioFormats.WAV]
    @property
    def supported_codecs(self): return [stt.AudioCodecs.PCM]
    @property
    def supported_bit_rates(self): return [stt.AudioBitRates.BITRATE_16]
    @property
    def supported_sample_rates(self): return [stt.AudioSampleRates.SAMPLERATE_16000]
    @property
    def supported_channels(self): return [stt.AudioChannels.CHANNEL_MONO]

    async def async_process_audio_stream(self, metadata: stt.SpeechMetadata, stream: AsyncIterable[bytes]):
        try:
            audio = bytearray()
            async for chunk in stream:
                audio.extend(chunk)
                if len(audio) > 650_000:
                    raise ValueError("Audio too long for current iPhone server request limit")
            data = bytes(audio)
            if not data.startswith(b"RIFF"):
                output = io.BytesIO()
                with wave.open(output, "wb") as wav:
                    wav.setnchannels(1)
                    wav.setsampwidth(2)
                    wav.setframerate(16000)
                    wav.writeframes(data)
                data = output.getvalue()
            async with self._session.post(self._url + "/v1/audio/transcriptions", json={
                "audio_base64": base64.b64encode(data).decode("ascii"), "require_offline": False
            }, timeout=aiohttp.ClientTimeout(total=90)) as resp:
                resp.raise_for_status()
                obj = await resp.json()
            return stt.SpeechResult(obj.get("text"), stt.SpeechResultState.SUCCESS)
        except (aiohttp.ClientError, TimeoutError, ValueError, KeyError) as err:
            return stt.SpeechResult(None, stt.SpeechResultState.ERROR)
