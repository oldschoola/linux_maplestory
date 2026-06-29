# Linux MapleStory setup guide

<img src="maplestorylinux.png" alt="MapleStory Linux icon" width="200">

This repo documents and automates the Linux/Proton setup used to run the Steam Windows build of MapleStory. The launch fixes have been upstreamed (see below); this installer is the stopgap until they land in a GE-Proton release.

## Why MapleStory doesn't just work (and what this installer does)

MapleStory is a Windows game. On Linux, Steam runs it through **Proton** (a
compatibility layer that translates Windows programs to Linux). But Proton isn't
a perfect Windows impersonator — a few things it gets wrong break MapleStory
right at launch. This installer patches those three things so the game can start:

1. **A crash on startup (`0xc0000005`)** — a bug in Wine's translation code
   causes the game to crash the moment the Nexon launcher hands off to the game
   client. The installer patches the two Wine files responsible
   (`kernelbase.dll` and `win32u.so`) inside the **GE-Proton11-1** Proton tool to
   fix it. These patches only work on that exact build — stock Proton or any
   other version is skipped, and the crash comes back.
2. **Missing C++ runtime** — the game needs a set of Microsoft C++ library files
   (the VC++ 2022 runtime, including `vcruntime140_threads.dll`, which the game's
   own installer forgets to install). The installer copies these into the right
   Windows system folders inside the Proton prefix.
3. **Wine environment mismatches** — the Nexon launcher expects a `nxl:` link
   handler to be registered, the game's keyboard input needs special settings
   and membership in your system's `input` group, the game expects to be running
   on Windows 10, and some Linux desktops (Wayland compositors like Hyprland)
   crash when the game tries to create its window. The installer imports the
   registry patches for all of these and offers the Wine virtual desktop
   (`--virtual-desktop`) as a workaround for the window-creation crash.

It also writes the app-name mapping, sets the launcher locale to English, and —
on Apple-compatible keyboards — switches the top row so `F1`–`F12` reach the
game instead of media keys.

**What it does *not* do:** this installer does not touch, disable, or bypass
Nexon Game Security (`NGClient64.aes` / `BlackCipher`). The anti-cheat still
runs alongside the game, just like on Windows. The installer only fixes the
Wine/runtime/prefix mismatches above so the normal Steam launch can get past
them — if NGS later rejects the Linux environment, that is outside this tool's
scope.

![Screenshot](screen.png)

## Upstream fixes (in progress - the path to "just works")

All three MapleStory launch blockers have been fixed upstream. Once the
patches below land in a GE-Proton release, MapleStory should work out of
the box - select GE-Proton and launch, no installer needed. Until then,
this repo's installer applies the same fixes locally.

| Fix | Wine upstream (Bugzilla) | proton-ge-custom (source patch) | umu-protonfixes (registry) |
|---|---|---|---|
| **kernelbase CharPrevExA NULL-deref** (`0xc0000005` launch crash) | [bug 59926](https://bugs.winehq.org/show_bug.cgi?id=59926) + patch | [PR #603](https://github.com/GloriousEggroll/proton-ge-custom/pull/603) | n/a |
| **win32u SPI_SETSTICKYKEYS/SETFILTERKEYS** (accessibility SET returns failure) | [bug 59927](https://bugs.winehq.org/show_bug.cgi?id=59927) + patch | [PR #601](https://github.com/GloriousEggroll/proton-ge-custom/pull/601) | n/a |
| **winver + input + protocol registry** (AppDefaults, DirectInput, nxl: handler) | n/a | n/a | [PR #597](https://github.com/Open-Wine-Components/umu-protonfixes/pull/597) |

**What this means:**
- The **source patches** (CharPrevExA + SPI) are carried by proton-ge-custom
  as game-patches until Wine merges them upstream. Once a GE-Proton build
  includes PRs #601 + #603, the `0xc0000005` launch crash and the SPI
  failure are fixed at the Wine source level - no binary patching needed.
- The **registry gamefix** (umu-protonfixes PR #597) applies the winver,
  DirectInput, X11 focus, and Nexon `nxl:` protocol settings automatically
  at launch time for appid `216150`. Once merged, it replaces this repo's
  manual `.reg` imports.
- The local installer (`./install.sh`) remains the **stopgap** until both
  land in a GE-Proton release. It applies the same fixes via byte-patching
  + `.reg` import into your prefix.


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


## Install / first launch

1. Install Steam.
2. Install MapleStory from Steam.
3. In Steam, open MapleStory properties:
   - Compatibility: force **GE-Proton11-1** (not stock Proton). Install it via
     [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) or extract a
     [proton-ge-custom release](https://github.com/GloriousEggroll/proton-ge-custom/releases)
     tarball to `~/.local/share/Steam/compatibilitytools.d/GE-Proton11-1/`.
     The Wine binary patches that fix the `0xc0000005` launch crash are
     build-specific to GE-Proton11-1; stock Proton will skip them.
4. Launch MapleStory once from Steam so Proton creates the prefix:
5. Close MapleStory before applying patches.

## All-in-one installer

From wherever you put this repo (no Wine virtual desktop by default — just the focus patch):

```bash
cd /path/to/linux_maplestory
./install.sh
```

The Wine virtual desktop is **off by default**. Enable it only if you hit the
`BadWindow`/`X_CreateWindow` launch crash or lose keyboard input after alt-tab
(common under XWayland: Hyprland, some Mint setups) `--virtual-desktop`

Useful options:

- `--dry-run` prints what would happen without modifying files or registry.
- `--kill` terminates running MapleStory/Nexon helper processes before patching.
- `--fix-fkeys` / `--persist-fkeys` control the hid_apple F-key mode (`fnmode=2`, so Apple-compatible keyboards send real `F1`–`F12`). **On by default** — the installer applies `--persist-fkeys` (also written to `/etc/modprobe.d` for reboot persistence); requires sudo. Use `--skip-runtime --skip-alt-tab` to run only this step.
- `--skip-runtime` applies only the alt-tab/input registry patches, skipping the VC++ runtime DLL copy, runtime registry imports, and Wine binary patches.
- `--skip-alt-tab` applies only the launch/runtime patch set.
- The Wine virtual desktop is **off by default**. An interactive `./install.sh` asks whether to enable it and at what size (1920×1080 / 2560×1440 / 3840×2160 / custom); `--virtual-desktop` enables it non-interactively at the default size, and `--desktop-size WxH` only sets the size (it does not enable the virtual desktop on its own). Only needed for the `BadWindow`/`X_CreateWindow` launch crash or alt-tab input loss under XWayland.
- `--steam-root PATH`, `--prefix-dir PATH`, and `--proton PATH` override auto-detection.

The installer does not copy another user's Steam config or whole `pfx`; it patches the local prefix created by Steam.

### Multiple Steam libraries / non-default install paths

The installer auto-detects `~/.local/share/Steam` (then `~/.steam/steam`, then
`~/.steam/debian-installation`). `--steam-root` is the Steam **library root that
contains `steamapps/compatdata/216150/pfx`** — not where the Steam client is
installed. If MapleStory is on **another Steam library** (e.g. a second drive
mounted at `/mnt/ssd0/steam`, while the client stays under `~/.local/share/Steam`),
auto-detection points at the client's empty/default prefix and the patches land
there instead — silently doing nothing useful, or failing to find the Proton tool
at all. Symptoms: `ERROR: could not find Proton executable`, or an "Install
complete" that never fixes the game. In that case, point the installer at the
library root that holds the game prefix:

```bash
./install.sh --steam-root /mnt/ssd0/steam \
  --proton /path/to/GE-Proton11-1/proton
```

> **Use GE-Proton11-1, not stock Proton 11.** The Wine binary patches that fix
> the `0xc0000005` launch crash are **build-specific** — they only apply when the
> Proton version string matches `*GE-Proton11-1*`. With stock Proton (e.g.
> `proton-11.0-1-beta5`) the installer prints `Skipping Wine binary patches ...
> is not GE-Proton11-1` and the game will not get past the launcher. Install
> GE-Proton11-1 (via [ProtonUp-Qt](https://github.com/DavidoTek/ProtonUp-Qt) or
> download the tarball from
> [proton-ge-custom releases](https://github.com/GloriousEggroll/proton-ge-custom/releases)
> and extract it), select it as MapleStory's compatibility tool, launch once to
> create the prefix, then re-run the installer pointing at its `proton` binary.

`--steam-root` sets both the prefix path (`$STEAM_ROOT/steamapps/compatdata/216150`)
and the common dir (`$STEAM_ROOT/steamapps/common`). You can also pass
`--prefix-dir /mnt/ssd0/steam/steamapps/compatdata/216150` alone if you only need
to redirect the prefix.

`--proton` points at the **GE-Proton11-1** `proton` binary. Its location depends
on where you installed it — common paths:
- `~/.local/share/Steam/compatibilitytools.d/GE-Proton11-1/proton` (ProtonUp-Qt default; client root, NOT the game library)
- `/mnt/ssd0/steam/compatibilitytools.d/GE-Proton11-1/proton` (if you extracted it under the secondary library)

Custom GE tools are usually installed under the Steam **client root**
(`~/.local/share/Steam/compatibilitytools.d/`), not the game library — even when
the game prefix lives on another drive. If `--proton` is omitted, the installer
tries to resolve it from the prefix's `version` file under `$STEAM_ROOT/compatibilitytools.d/`.

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
- Runs `install.sh --kill` (adds `--virtual-desktop --desktop-size <size>` only if you opt into the virtual desktop).

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

> **Secondary Steam library?** The snippets below hardcode `STEAM_ROOT="$HOME/.local/share/Steam"`.
> If MapleStory is on another library (e.g. `/mnt/ssd0/steam`), set `STEAM_ROOT` to that library root and `PROTON` to the actual GE-Proton11-1 `proton` binary (usually under the **client root** `~/.local/share/Steam/compatibilitytools.d/`, not the game library). Or just run `./install.sh --steam-root /mnt/ssd0/steam --proton /path/to/GE-Proton11-1/proton`, which handles all of this.

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
"$PROTON" run regedit /S patches/01-usetakefocus.reg
```
This imports only the focus patch (`UseTakeFocus=N`), matching the installer default — **no virtual desktop**. For the `BadWindow`/`X_CreateWindow` launch crash, generate and import the virtual-desktop patch: `patches/make-virtual-desktop-patch.sh 1920x1080` then import `patches/02-virtual-desktop-1920x1080.reg` (or `patches/03-combined-alt-tab-fix-1920x1080.reg` for focus + virtual desktop at once).

If that import prints `ProtonFixes [...] WARN: Skipping fix execution...` it is harmless (regedit still runs). The all-in-one installer verifies every import and falls back to the bundled Wine binary if needed; for manual imports that don't land, use Protontricks instead — see Troubleshooting.

For a different monitor size:

```bash
cd /path/to/linux_maplestory
patches/make-virtual-desktop-patch.sh 2560x1440
```

## Manual launch/runtime patch set

Use this only if you do not want the all-in-one installer.

The VC++ runtime DLLs ship in-repo under `files/vc_runtime/` (the `.mappings.ini` app-name mapping and NexonLauncher `apps-settings.db` locale setting are generated automatically by the script). Run from a full checkout of the repo (needs `patches/` and `files/` alongside `install.sh`):

```bash
cd /path/to/linux_maplestory
patches/13-apply-runtime-file-patches.sh
```

The script reads `STEAM_ROOT`, `PFX`, and `APPID` from the environment (with the same defaults as `install.sh`); override them if your prefix is elsewhere.

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

   On a **secondary Steam library**, replace `~/.local/share/Steam` with your library root (e.g. `/mnt/ssd0/steam`).

Also tell us your **compositor / desktop** (KDE, Hyprland, Gamescope, Mint-on-XWayland, …) — several crashes are compositor-specific. And if you ran an older version of this installer before it verified `.reg` imports, re-run the current `./install.sh` once; a silently-failed registry import is itself a crash cause.

## Notes

- Gamescope was tried before and did not fix the alt-tab input problem on the reference setup.
- `UseTakeFocus=N` is applied by default and is sufficient for alt-tab input on the reference (KDE) setup. The Wine virtual desktop is **off by default**; it was added for a reported alt-tab / `BadWindow` case under other compositors — enable it with `--virtual-desktop` only if you need it.
- **In-game keyboard/mouse input** (movement, skill keys like `Q`/`W`/`E`/`R`, `Alt+1`–`Alt+5`, the number row, `Enter`) is a separate concern from alt-tab. MapleStory uses DirectInput8; the installer applies `patches/04-input-fixes.reg` by default (`UseLinuxInputEvents`, `KeyboardUseNonExclusive`, `MouseUseNonExclusive`, `Grab=N`/`GrabFullscreen=N`) plus `patches/05-appdefaults-winver.reg` (report Windows 10). **Skill keys also require membership in the system `input` group**: `UseLinuxInputEvents` reads `/dev/input/event*` (root:`input`, `rw-rw----`), so without it those keys silently don't register. The installer adds you to `input` (and prompts for your sudo password) then tells you to **log out and back in**; until you re-login, skill keys and held-key repeat won't work.
- If `regedit` does not exit, the prefix is probably still active. Fully close MapleStory/Steam launch helpers, then run the import again.
- If bare `F1`-`F12` do not work on an Apple-compatible keyboard under KDE/Linux, check `/sys/module/hid_apple/parameters/fnmode`. `fnmode=2` means function keys first.
- **The game installs its own redistributables on first launch.** When the Nexon Launcher first runs MapleStory, it executes the bundled VC++ and legacy DirectX installers straight into the Proton prefix (visible as `dd_vcredist_*.log` under the prefix's `…/drive_c/users/steamuser/AppData/Local/Temp/`). This auto-populates the full legacy DirectX set — `d3dx9_*`, `d3dcompiler_*`, `x3daudio*`, `xaudio2*`, `xactengine*`, `xinput*` in both `system32` and `syswow64`. The installer therefore ships only the VC++ runtime override (`files/vc_runtime`, including `vcruntime140_threads.dll`, which the game's bundled redist omits); no `winetricks` or DirectX step is needed.

