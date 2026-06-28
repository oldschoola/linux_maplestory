# Linux MapleStory setup guide

<img src="maplestorylinux.png" alt="MapleStory Linux icon" width="200">

This repo documents and automates the Linux/Proton setup used to run the Steam Windows build of MapleStory.

![Screenshot](screen.png)

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

Join our server if you need help! https://discord.gg/eDhWPJVyBF

## Disclaimer

WARNING: this is very WIP. Although this setup uses files from the MapleStory Mac package/runtime path, Nexon/BlackCipher anti-cheat may still reject, break, or flag the setup. Use at your own risk, and expect updates to break things. I play on my main with it personaly.
This patch does not touch the anticheat at all and in fact it still runs along side the game, like the MacOS version. I am using the mac os wine environment files and registry edits to make this work. This patch with the help of AI took under 40 minutes to make.

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

From wherever you put this repo (no Wine virtual desktop by default — just the focus patch):

```bash
cd /path/to/linux_maplestory
./install.sh
```

The Wine virtual desktop is **off by default**. Enable it only if you hit the
`BadWindow`/`X_CreateWindow` launch crash or lose keyboard input after alt-tab
(common under XWayland: Hyprland, some Mint setups):

```bash
cd /path/to/linux_maplestory
./install.sh --virtual-desktop          # enable at the default size (3840x2160)
./install.sh --desktop-size 2560x1440   # enable at a custom size
```

Offline/manual patch options:

```bash
./install.sh --patch-zip /path/to/files.zip
./install.sh --patch-dir /path/to/files
```

Useful options:

- `--dry-run` prints what would happen without modifying files or registry.
- `--kill` terminates running MapleStory/Nexon helper processes before patching.
- `--fix-fkeys` sets `hid_apple fnmode=2` for this boot so Apple-compatible keyboards send real `F1`-`F12`; this requires sudo and is off by default because it is system-wide.
- `--persist-fkeys` also writes the reboot-persistent `hid_apple fnmode=2` config; use this only after the temporary F-key fix works for you.
- `--skip-runtime` applies only the alt-tab/input registry patches and does not download patch files.
- `--skip-alt-tab` applies only the launch/runtime patch set.
- `--virtual-desktop` enables the Wine virtual desktop (off by default); `--desktop-size WxH` also enables it at a custom size. Only needed for the BadWindow/X_CreateWindow launch crash or alt-tab input loss under XWayland.
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
- Prompts whether to enable the Wine virtual desktop (off by default; only needed for the `BadWindow`/`X_CreateWindow` launch crash or alt-tab input loss under XWayland).
- Clones/updates this repo into Lutris cache.
- Runs `install.sh --kill` (adds `--desktop-size <size>` only if you pick a size).

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

If that import prints `ProtonFixes [...] WARN: Skipping fix execution...` it is harmless (regedit still runs). The all-in-one installer verifies every import and falls back to the bundled Wine binary if needed; for manual imports that don't land, use Protontricks instead — see Troubleshooting.

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

Same note as above: the `ProtonFixes ... unit test` warning is harmless, and a manual import that does not apply can be done through Protontricks instead (see Troubleshooting).

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

## Troubleshooting

- **`ProtonFixes [...] WARN: Skipping fix execution. We are probably running a unit test.`** — harmless. `proton run regedit` is not a game launch, so GE-Proton's protonfixes skips its game fixes, but regedit still runs normally. The installer verifies each import landed in the prefix registry and, if not, retries with the bundled Wine binary directly (the same path Protontricks uses) before reporting success.
- **Crash right after "MapleStory is being launched" / `X Error of failed request: BadWindow ... X_CreateWindow`** — the Wine virtual-desktop patch fixes this: it makes Wine ignore window-manager reparenting churn under XWayland so window creation cannot fail. It is **off by default**; enable it with `./install.sh --virtual-desktop` (or `--desktop-size <W>x<H>`), or import `patches/02-virtual-desktop-<size>.reg` via Protontricks.
- **Crash right after launch with `0xc0000005` and/or `Unhandled exception code c0000409`, but NO `BadWindow`/`X_CreateWindow`** — this is Nexon Game Security (`NGClient64.aes` + `gamescale64.dll`), not the window bug, so `--virtual-desktop` will **not** help. First make sure the game isn't running with `PROTON_LOG`/Wine debug channels on — NGS has been seen to fast-fail (`c0000409`) in an instrumented environment (see the caveat under Collecting logs); test a clean launch first. Beyond that it tends to be compositor / kernel / Proton-version specific — try GE-Proton10-x or stable Proton. The installer cannot fix the anti-cheat itself.
- **A `.reg` still will not apply via the installer** — import it manually with Protontricks for Steam app `216150`: select the app, choose the default wineprefix, run regedit, then Registry → Import Registry File... and pick the `.reg`. Protontricks calls the Proton Wine binary directly and bypasses protonfixes.
- **Nexon Launcher "not found" / `nexon_launcher.exe`** — Windows `.exe` files do **not** need the Linux executable (`+x`) bit; Wine runs them without it. If the installer reported the packaged copy missing after extraction, re-running it now works (detection accepts a non-executable file).
- **Do not run `MapleStory.exe` directly.** Steam hands `nxsteam.exe` the Nexon launch ticket; launching the exe directly fails immediately.
- **Hyprland / wlroots** — if window creation still misbehaves, add a Hyprland window rule (float/fullscreen) for the MapleStory window class, or run the game under `gamescope`.

### Distro-specific prerequisites

The installer handles the MapleStory/Nexon-specific patches only — it assumes Steam and a working Proton/Vulkan graphics stack are already in place. The reference setup is CachyOS (KDE Wayland), which ships these gaming prerequisites enabled by default. On other distros a fresh install can crash for reasons unrelated to this repo; check these first:

- **Fedora — SELinux (enforcing by default).** Wine/Proton can be denied `execmem`/`execstack` or access to the prefix, crashing the game. Test with `sudo setenforce 0` and relaunch; if that fixes it, generate a permanent allow rule with `audit2allow` (or run Steam under the `unconfined_t` domain) rather than leaving SELinux disabled.
- **Debian/Ubuntu — 32-bit Vulkan and multiarch.** Proton's 32-bit (syswow64) side — which MapleStory uses — needs a 32-bit Vulkan driver on the host. Enable it with `sudo dpkg --add-architecture i386 && sudo apt update && sudo apt install libvulkan1:i386`, plus the matching 32-bit driver (`mesa-vulkan-drivers:i386` for AMD/Intel, or the `:i386` NVIDIA GL package matching your driver version). On Debian, also confirm the `non-free-firmware` / `non-free` repository components are enabled for GPU firmware and drivers.
- **Older stock kernels.** `ntsync` (the Wine sync driver recent GE-Proton prefers) requires kernel **6.14+**; Debian 13 ships 6.12 and Debian 12 ships 6.1. GE-Proton falls back to fsync/esync when it is absent, so this is usually a performance gap rather than a crash — but on an old LTS kernel a backports/newer kernel is worth trying if you hit odd crashes.
- **GNOME on Wayland (default on Fedora and Debian).** This is another XWayland compositor the reference setup does not test; if you get the `BadWindow`/`X_CreateWindow` launch crash or lose input after alt-tab, try `./install.sh --virtual-desktop` (the same fix as Hyprland/Mint).

### Collecting logs

**Updated recently? Check this first.** The Wine virtual desktop is now off by default, and re-running the updated installer imports `90-disable-virtual-desktop.reg`, which **removes a virtual desktop you previously had enabled**. That re-introduces the `BadWindow`/`X_CreateWindow` close-right-after-launch crash on XWayland compositors (Hyprland, some Mint setups). Before collecting any logs, try:

```bash
./install.sh --virtual-desktop
```

to restore it. If relaunching still closes after the Nexon Launcher, the logs below pinpoint the cause:

1. **Proton log (most useful).** By default Proton writes nothing. Set a launch option — Steam → MapleStory → Properties → Launch Options:

   ```
   PROTON_LOG=1 %command%
   ```

   Reproduce the crash, then send the Proton log. Modern Proton/GE-Proton writes it to **`~/steam-216150.log`** (`$HOME/steam-<appid>.log`, or `$PROTON_LOG_DIR/...` if that is set). If it's not there, find it with `find ~ /tmp -maxdepth 2 -name 'steam-216150.log'`. It captures DLL load failures, unhandled exceptions, X errors, and anti-cheat (`BlackCipher`/`DwarfAxe`) failures — usually enough to pinpoint the cause in one file.

   **Anti-cheat caveat — read before enabling logging.** `PROTON_LOG` (and the Wine debug channels it turns on) can *itself* trip Nexon Game Security — `NGClient64.aes` / `gamescale64.dll` have been observed to fast-fail (`Unhandled exception code c0000409`) in an instrumented environment. If the game launches cleanly with logging **off** but only dies with it **on**, the logging is the trigger, not a genuine bug. Always test a clean launch (no `PROTON_LOG`) first; enable logging only to diagnose an already-broken launch.

2. **Console output (fastest signal).** Launch from a terminal or the Steam console. The `BadWindow`/`X_CreateWindow` error prints here immediately — see the bullet above for the fix (`--virtual-desktop`).

3. **Nexon Launcher logs**, in the prefix, show whether the handoff to `nxsteam` succeeded:

   ```
   ~/.local/share/Steam/steamapps/compatdata/216150/pfx/drive_c/users/steamuser/AppData/Roaming/NexonLauncher/
   ~/.local/share/Steam/steamapps/compatdata/216150/pfx/drive_c/users/steamuser/AppData/LocalLow/Nexon/
   ```

Also tell us your **compositor / desktop** (KDE, Hyprland, Gamescope, Mint-on-XWayland, …) — several crashes are compositor-specific. And if you ran an older version of this installer before it verified `.reg` imports, re-run the current `./install.sh` once; a silently-failed registry import is itself a crash cause.

## Notes

- Gamescope was tried before and did not fix the alt-tab input problem on the reference setup.
- `UseTakeFocus=N` is applied by default and is sufficient for alt-tab input on the reference (KDE) setup. The Wine virtual desktop is **off by default**; it was added for a reported alt-tab / `BadWindow` case under other compositors — enable it with `--virtual-desktop` only if you need it.
- **In-game keyboard/mouse input** (movement, skill keys like `Q`/`W`/`E`/`R`, `Alt+1`–`Alt+5`) is a separate concern from alt-tab. MapleStory uses DirectInput8; the installer applies `patches/04-input-fixes.reg` by default (`UseLinuxInputEvents`, `KeyboardUseNonExclusive`, `MouseUseNonExclusive`, and `Grab=N`/`GrabFullscreen=N`) so raw scancodes reach the game, plus `patches/05-appdefaults-winver.reg` to report Windows 10 to `MapleStory.exe`, `nxsteam.exe`, and `SteamConnectorHelper.exe`. If in-game keys don't register, confirm those `.reg` imports landed (the installer verifies each).
- If `regedit` does not exit, the prefix is probably still active. Fully close MapleStory/Steam launch helpers, then run the import again.
- If bare `F1`-`F12` do not work on an Apple-compatible keyboard under KDE/Linux, check `/sys/module/hid_apple/parameters/fnmode`. `fnmode=2` means function keys first.
- **The game installs its own redistributables on first launch.** When the Nexon Launcher first runs MapleStory, it executes the bundled VC++ and legacy DirectX installers straight into the Proton prefix (visible as `dd_vcredist_*.log` under the prefix's `…/drive_c/users/steamuser/AppData/Local/Temp/`). This auto-populates the full legacy DirectX set — `d3dx9_*`, `d3dcompiler_*`, `x3daudio*`, `xaudio2*`, `xactengine*`, `xinput*` in both `system32` and `syswow64`. The installer therefore ships only the VC++ runtime override (`files/vc_runtime`, including `vcruntime140_threads.dll`, which the game's bundled redist omits); no `winetricks` or DirectX step is needed.

