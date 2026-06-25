import os

_appid = os.environ.get("SteamAppId") or os.environ.get("SteamGameId") or "216150"
_prefix = os.environ.get("STEAM_COMPAT_DATA_PATH") or os.path.expanduser(f"~/.local/share/Steam/steamapps/compatdata/{_appid}")

user_settings = {
    "PROTON_LOG": "1",
    "RAW_AUDIO_PARSE": "1",
    "WINE_APPNAME_INI": os.path.join(_prefix, "pfx", "drive_c", ".mappings.ini"),
}
