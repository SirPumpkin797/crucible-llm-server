"""Configure iPhone voice host address."""
import aiohttp
import voluptuous as vol
from homeassistant import config_entries
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from .const import DOMAIN, DEFAULT_URL

class ConfigFlow(config_entries.ConfigFlow, domain=DOMAIN):
    VERSION = 1

    async def async_step_user(self, user_input=None):
        errors = {}
        if user_input is not None:
            url = user_input["url"].rstrip("/")
            try:
                session = async_get_clientsession(self.hass)
                async with session.get(url + "/v1/models", timeout=aiohttp.ClientTimeout(total=8)) as response:
                    response.raise_for_status()
                await self.async_set_unique_id(url)
                self._abort_if_unique_id_configured()
                return self.async_create_entry(title="iPhone AI Voice", data={"url": url})
            except (aiohttp.ClientError, TimeoutError):
                errors["base"] = "cannot_connect"
        return self.async_show_form(step_id="user", data_schema=vol.Schema({vol.Required("url", default=DEFAULT_URL): str}), errors=errors)
