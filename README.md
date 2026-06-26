# Linux MapleStory setup guide

This repo documents and automates the Linux/Proton setup used to run the Steam Windows build of MapleStory.

## What this repo does not include

The GitHub repo intentionally does **not** track proprietary patch files:

- Nexon Launcher files
- Microsoft/VC++ runtime DLL patch files
- `files.zip`
- extracted `files/`

`install.sh` downloads `files.zip` automatically from these mirrors, in order:

1. Catbox: https://files.catbox.moe/qaxsw6.zip
2. x0.at: https://x0.at/96Ia.zip
3. station307: https://l.station307.com/23wXxZg1fohbhAkbHN8wMj/files.zip
4. LimeWire: https://limewire.com/d/lzRB1#nDRoOiUHPA
5. Google Drive: https://drive.google.com/file/d/1ybJcwEGPQF3heLJnafpPX7H7kezwcvqF/view?usp=sharing

You can also pass your own local patch zip or extracted patch directory.

## Current reference setup

Observed on the original machine:

- Steam app id: `216150`
- Steam install directory: `~/.local/share/Steam/steamapps/common/MapleStory`
- Proton prefix: `~/.local/share/Steam/steamapps/compatdata/216150`
- Proton tool: `GE-Proton11-1`
- Desktop/session: KDE Wayland, with MapleStory running through Proton/XWayland
- Steam launches the Windows build through Proton, not the macOS port.

Adjust paths for your Steam library.

## Discord / support

If you need help, if this breaks, or if you find a better fix, contact `counterstrikeproaimer` on Discord.

## Disclaimer

WARNING: this is very WIP. Although this setup uses files from the MapleStory Mac package/runtime path, Nexon/BlackCipher anti-cheat may still reject, break, or flag the setup. Use at your own risk, keep backups, and expect updates to break things.

## Required patch layout

Automatic download should create this layout under the repo root:

```text
files/
  drive_c/
    .mappings.ini
    Nexon/Launcher/nexon_launcher.exe
    users/steamuser/AppData/Roaming/NexonLauncher/apps-settings.db
  vc_runtime/
    system32/*.dll
    syswow64/*.dll
```

Do not commit `files.zip` or extracted `files/` patch files. They are ignored by `.gitignore`.

## Install / first launch

1. Install Steam.
2. Install MapleStory from Steam.
3. In Steam, open MapleStory properties:
   - Compatibility: force Proton/GE-Proton if needed.
4. Launch MapleStory once from Steam so Proton creates the prefix:

   ```bash
   steam steam://rungameid/216150
   ```

5. Close MapleStory before applying patches.
6. Do not run `MapleStory.exe` directly. Steam provides the Nexon launch ticket through `nxsteam.exe`.

## All-in-one installer

From wherever you put this repo:

```bash
cd /path/to/linux_maplestory
./install.sh --desktop-size 3840x2160
```

For another monitor size:

```bash
./install.sh --desktop-size 2560x1440
```

Offline/manual patch options:

```bash
./install.sh --patch-zip /path/to/files.zip --desktop-size 3840x2160
./install.sh --patch-dir /path/to/files --desktop-size 3840x2160
```

Useful options:

- `--dry-run` prints what would happen without modifying files or registry.
- `--kill` terminates running MapleStory/Nexon helper processes before patching.
- `--install-proton-settings` adds the documented Proton env settings to that Proton tool's `user_settings.py`; this is off by default because it affects every game using that Proton build.
- `--fix-fkeys` sets `hid_apple fnmode=2` for this boot so Apple-compatible keyboards send real `F1`-`F12`; this requires sudo and is off by default because it is system-wide.
- `--persist-fkeys` also writes the reboot-persistent `hid_apple fnmode=2` config; use this only after the temporary F-key fix works for you.
- `--skip-runtime` applies only the alt-tab/input registry patches and does not download patch files.
- `--skip-alt-tab` applies only the launch/runtime patch set.
- `--steam-root PATH`, `--prefix-dir PATH`, and `--proton PATH` override auto-detection.

The installer does not copy another user's Steam config or whole `pfx`; it patches the local prefix created by Steam.

## F1-F12 / function-key hardware mode

KDE global shortcuts are not the expected cause for bare `F1` through `F12`: the reference KDE config only binds modified combinations like `Ctrl+F1`, `Alt+F1`, or `Meta+F1`.

On the reference machine, the active keyboard is an IQUNIX F97 that reports USB vendor `05ac`, so Linux handles it with the `hid_apple` kernel driver even though the desktop session is KDE/Linux. With `hid_apple fnmode=3`, the top row can send media keys by default instead of real `F1` through `F12`.

Confirmed reference fix: setting `hid_apple fnmode=2` made plain `F1`-`F12` reach MapleStory.

Quick confirmation: if `Fn+F1` works in MapleStory but plain `F1` does not, this is the issue.

Temporary fix until reboot:

```bash
cd /path/to/linux_maplestory
./install.sh --skip-runtime --skip-alt-tab --fix-fkeys
```

Direct helper equivalent:

```bash
cd /path/to/linux_maplestory
patches/20-hid-apple-fkeysfirst.sh
```

Persistent fix after the temporary fix has worked:

```bash
cd /path/to/linux_maplestory
./install.sh --skip-runtime --skip-alt-tab --persist-fkeys
```

This sets `hid_apple fnmode=2`, which makes the top row send real `F1`-`F12` first. It is intentionally not applied by default because it is a system-wide keyboard setting and requires sudo.


## Lutris installer

This repo also includes a local Lutris installer:

```bash
lutris -i /path/to/linux_maplestory/maplestory-lutris.yaml
```

What it does:

- Creates a Lutris Steam-runner entry for Steam app id `216150`.
- Prompts for the Wine virtual desktop size.
- Clones/updates this repo into Lutris cache.
- Runs `install.sh --kill --desktop-size <selected size>`.

MapleStory must still be installed through Steam and launched once first so the Proton prefix exists. The Lutris entry launches the Steam build; it does not run `MapleStory.exe` directly.

## Steam config and Proton prefix

Do not copy/share another user's whole Steam config or Proton prefix.

- `~/.local/share/Steam/steamapps/appmanifest_216150.acf`
  - Steam creates this when MapleStory is installed.
  - It records app id `216150`, install directory, depot/build state, owner/account metadata, and update state.
  - Do not include someone else's `appmanifest_216150.acf` in a public/shareable bundle.
- `~/.local/share/Steam/userdata/<steamid>/config/compat.vdf`
  - Steam writes this when the user forces Steam Play/Proton compatibility.
  - Set this through Steam's Compatibility UI, not by copying another user's file.
- `~/.local/share/Steam/userdata/<steamid>/config/localconfig.vdf`
  - Per-account Steam state: playtime, UI state, encoded app data, and sometimes launch options.
  - Do not hand-edit or redistribute it.
- `~/.local/share/Steam/steamapps/compatdata/216150/pfx`
  - This is the user's local Proton Wine prefix.
  - Launch MapleStory once through Steam to create it, then apply this repo's patches into that prefix.
  - Do not share the entire `pfx`; it contains machine/account-specific registry state, caches, and potentially login/session data.

## Manual alt-tab/input patches

Use this only if you do not want the all-in-one installer.

```bash
cd /path/to/linux_maplestory

APPID=216150
STEAM_ROOT="$HOME/.local/share/Steam"
PREFIX="$STEAM_ROOT/steamapps/compatdata/$APPID"
PROTON_NAME="$(cat "$PREFIX/version")"

if [ -x "$STEAM_ROOT/compatibilitytools.d/$PROTON_NAME/proton" ]; then
  PROTON="$STEAM_ROOT/compatibilitytools.d/$PROTON_NAME/proton"
else
  PROTON="$STEAM_ROOT/steamapps/common/$PROTON_NAME/proton"
fi

STEAM_COMPAT_DATA_PATH="$PREFIX" \
STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
SteamAppId="$APPID" SteamGameId="$APPID" \
"$PROTON" run regedit /S patches/03-combined-alt-tab-fix-3840x2160.reg
```

For a different monitor size:

```bash
cd /path/to/linux_maplestory
patches/make-virtual-desktop-patch.sh 2560x1440
```

## Manual launch/runtime patch set

Use this only if you do not want the all-in-one installer.

The VC++ DLL patch files and Nexon Launcher patch files are required. Download/extract the patch files first, then pass `PATCH_FILES_DIR`:

```bash
cd /path/to/linux_maplestory
PATCH_FILES_DIR=/path/to/extracted/files patches/13-apply-runtime-file-patches.sh
```

Then import the launcher/runtime registry patches:

```bash
cd /path/to/linux_maplestory

APPID=216150
STEAM_ROOT="$HOME/.local/share/Steam"
PREFIX="$STEAM_ROOT/steamapps/compatdata/$APPID"
PROTON_NAME="$(cat "$PREFIX/version")"

if [ -x "$STEAM_ROOT/compatibilitytools.d/$PROTON_NAME/proton" ]; then
  PROTON="$STEAM_ROOT/compatibilitytools.d/$PROTON_NAME/proton"
else
  PROTON="$STEAM_ROOT/steamapps/common/$PROTON_NAME/proton"
fi

STEAM_COMPAT_DATA_PATH="$PREFIX" \
STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
SteamAppId="$APPID" SteamGameId="$APPID" \
"$PROTON" run regedit /S patches/10-nexon-launcher-protocol.reg

STEAM_COMPAT_DATA_PATH="$PREFIX" \
STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT" \
SteamAppId="$APPID" SteamGameId="$APPID" \
"$PROTON" run regedit /S patches/11-wine-direct3d-dll-overrides.reg
```

## Test

1. Get to a screen where MapleStory accepts keyboard input.
2. Confirm movement, regular skill keys, `Alt+1` through `Alt+5`, `Escape`, `Enter`, and `F1` through `F12` work.
3. If plain `F1` through `F12` fail, test `Fn+F1`. If `Fn+F1` works, apply the `hid_apple fnmode=2` fix above, relaunch MapleStory if needed, then retest.
4. Alt-tab away and return to MapleStory.
5. Confirm the same keys still reach the game client.

## Rollback

Close MapleStory first. Then import one or both rollback patches with the same Proton import shape:

```bash
cd /path/to/linux_maplestory
# import patches/90-disable-virtual-desktop.reg and/or patches/91-remove-usetakefocus.reg
```

## Notes

- Gamescope was tried before and did not fix the alt-tab input problem on the reference setup.
- The first focus patch alone (`UseTakeFocus=N`) was not enough for the reported failure. The virtual desktop patch is the important one for this MapleStory alt-tab case.
- If `regedit` does not exit, the prefix is probably still active. Fully close MapleStory/Steam launch helpers, then run the import again.
- If bare `F1`-`F12` do not work on an Apple-compatible keyboard under KDE/Linux, check `/sys/module/hid_apple/parameters/fnmode`. `fnmode=2` means function keys first.

