"""Remote Apple speech synthesis through the iPhone."""
import base64
import aiohttp
from homeassistant.components import tts
from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from homeassistant.helpers.entity_platform import AddEntitiesCallback
from .const import DOMAIN

async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry, async_add_entities: AddEntitiesCallback):
    async_add_entities([IPhoneTTS(entry, hass)])

class IPhoneTTS(tts.TextToSpeechEntity):
    _attr_name = "iPhone Chinese TTS"
    _attr_supported_languages = ["zh-CN"]
    _attr_default_language = "zh-CN"

    def __init__(self, entry, hass):
        self._attr_unique_id = entry.entry_id + "_tts"
        self._url = hass.data[DOMAIN][entry.entry_id]
        self._session = async_get_clientsession(hass)

    async def async_get_tts_audio(self, message: str, language: str, options: dict):
        try:
            async with self._session.post(self._url + "/v1/audio/speech", json={"input": message}, timeout=aiohttp.ClientTimeout(total=90)) as resp:
                resp.raise_for_status()
                obj = await resp.json()
            return "wav", base64.b64decode(obj["audio_base64"], validate=True)
        except (aiohttp.ClientError, TimeoutError, ValueError, KeyError):
            return None, None
