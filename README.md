# LayoutSwitch

**English** | [Русский](README.ru.md)

A small macOS menu bar app that switches keyboard layouts with **Ctrl + Shift** or any of your configured shortcuts. It runs in the background and can be built without the full Xcode app.

## Install with Homebrew

With [Homebrew](https://brew.sh/) installed, run:

```sh
brew tap lukdut/layoutswitch https://github.com/lukdut/LayoutSwitch.git
brew install --cask lukdut/layoutswitch/layoutswitch
```

This repository also serves as the Homebrew tap. Keep the explicit URL in the first command. The cask installs the published **Apple Silicon (arm64)** app for **macOS 13 or later** into `/Applications` and verifies its SHA-256 checksum.

Homebrew installs the same ad hoc signed release. You may still need to allow its first launch in **System Settings → Privacy & Security → Open Anyway**, then grant **Input Monitoring**. The app is not notarized by Apple.

If you already installed LayoutSwitch manually, quit it and move the old `LayoutSwitch.app` out of `/Applications` before installing with Homebrew. Your preferences are kept separately.

To update after a new version is added to the cask:

```sh
brew update
brew upgrade --cask lukdut/layoutswitch/layoutswitch
```

## Download

Download [LayoutSwitch 1.1.0 for Apple Silicon](https://github.com/lukdut/LayoutSwitch/releases/download/v1.1.0/LayoutSwitch-1.1.0-macos-arm64.zip) from the [release page](https://github.com/lukdut/LayoutSwitch/releases/tag/v1.1.0), extract the archive, and move `LayoutSwitch.app` to `/Applications`. Requires macOS 13 or later. The app interface in version 1.1.0 is in Russian.

The prebuilt app is for **Apple Silicon (arm64)**. On an Intel Mac, build from source using the instructions below. The release also includes `SHA256SUMS.txt` to verify the archive:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

Run this command in the directory containing both downloaded files.

The app is ad hoc signed and is not notarized by Apple. If macOS blocks the first launch, follow [Apple's instructions for opening apps](https://support.apple.com/en-us/102445) only if you trust the download. After opening the app, grant Input Monitoring access as described below.

## Build from source

Requirements: macOS 13 or later to run the app, and Swift 6.0 or later to build and test it (Xcode 16+ or compatible Command Line Tools). If the tools are missing, install them with `xcode-select --install`.

From the `LayoutSwitch` directory, run:

```sh
./scripts/build.sh
open dist/LayoutSwitch.app
```

The finished app is at `dist/LayoutSwitch.app`. For everyday use, move it to `/Applications` first and launch that copy. The build targets the architecture of the current Mac. No dependencies are downloaded from the internet.

## First launch

1. Click **Request access** (`Запросить доступ`) in the settings window.
2. Open **System Settings → Privacy & Security → Input Monitoring** and enable **LayoutSwitch**. The **Open macOS settings** (`Открыть настройки macOS`) button takes you there. If the app is missing from the list, add the `.app` using the “+” button.
3. If macOS asks you to quit the app, quit and reopen it. Use **Retry connection** (`Повторить подключение`) if needed.
4. Make sure at least two input sources are selected. Press **Ctrl + Shift** and release either key in a regular text field.

The user grants permission in System Settings. The app listens passively and does not request Accessibility access.

### Input Monitoring after an update

The ad hoc signature changes when the app is rebuilt. macOS may require permission again even if LayoutSwitch is already enabled in Input Monitoring. If quitting and reopening the app does not help:

1. Quit LayoutSwitch from its menu bar menu.
2. In **System Settings → Privacy & Security → Input Monitoring**, select **LayoutSwitch** and remove its entry with “−”.
3. Add `/Applications/LayoutSwitch.app` with “+” and enable it.
4. Reopen LayoutSwitch; if macOS requests a restart, quit and reopen it again.

## Features

- **Multiple shortcuts.** Click **Add shortcut…** (`Добавить сочетание…`), hold your shortcut, and release all keys. Every shortcut cycles through the same selected sources. Use **Edit…** (`Изменить…`) or the trash button for individual entries. Duplicate shortcuts are rejected; at least one shortcut must remain. **Keep only Ctrl + Shift** (`Оставить только Ctrl + Shift`) resets the list. Use two to four modifiers from Ctrl, Shift, Option, and Command, or one to four modifiers with one regular key. Esc cancels recording. Moving focus away from the window also cancels it.
- **Either side of the keyboard.** Left and right Ctrl/Shift/Option/Command keys are equivalent and can be mixed.
- **Input source selection.** Cycle through checked input sources. The numbers on the right show their order. **All layouts** (`Все раскладки`) also includes new sources added in macOS automatically.
- **Pause.** Use the menu bar menu or the switch in settings. The manual **Next layout** (`Следующая раскладка`) command remains available while paused.
- **Launch at login.** Enable **Launch at macOS login** (`Запускать при входе в macOS`) separately. The app reads its actual status from the system and offers to open system approval settings when needed.
- **Current layout.** Shown in the menu bar and updated when you switch input sources through macOS.
- **Saved settings.** The shortcut list, selected sources, and pause state are stored in the app's UserDefaults (`local.masos.LayoutSwitch`). An existing shortcut is automatically loaded as the first entry when upgrading.

## Shortcut behavior

| Action | Result |
| --- | --- |
| Press Ctrl, then Shift; release either key | One switch immediately on release; releasing the remaining key does not switch again |
| Press Shift, then Ctrl; release in either order | Same behavior |
| Configure Alt + Shift, hold Alt (Option), and repeatedly press and release Shift | One switch per Shift release; holding Shift and repeatedly pressing and releasing Alt also works |
| Hold Ctrl + Shift | No switch until release |
| Press Ctrl + Shift + a letter | No switch; the active app receives the shortcut |
| Hold Ctrl + Shift, release Ctrl, then press a letter while holding Shift | The layout already switched on Ctrl release; the letter does not trigger another switch |
| Add Option, Command, or Fn before releasing a shortcut key | No switch if the extra modifier is not part of the configured shortcut |
| Click, drag, or scroll before releasing a shortcut key | No switch |
| Configure Ctrl + Option + Space | One switch when Ctrl, Option, or Space is released; pressing and releasing it again while holding the other keys switches again |
| Start the app while keys are already held | Release them first; the next gesture can switch layouts |

With overlapping shortcuts, such as Ctrl + Shift and Ctrl + Shift + Space, completing the larger chord switches once. Releasing its remaining keys does not trigger the smaller chord. After a successful switch, you can use another configured shortcut while holding a shared modifier.

To switch again, complete the chord again and release any of its keys. After a cancelled gesture, release all keys before trying again. An unrelated key or mouse action after a switch also blocks further switches until everything is released. Keyboard events are not suppressed globally. If you configure a shortcut with a regular key, the active app also receives it, so choose an unused combination. Letters shown during recording refer to **physical English keyboard positions**, regardless of the current input language.

Caps Lock and Fn cannot be assigned as shortcuts. An already enabled Caps Lock does not interfere; pressing Caps Lock before releasing a shortcut key cancels switching. F1–F16 can be recorded when the keyboard sends regular function keys without holding Fn. Media keys are not supported.

## macOS limitations

- **Secure Input.** Monitoring may be unavailable during protected input, such as Terminal's Secure Keyboard Entry. The app displays this state and resumes when it ends. Keep the standard macOS input source shortcut as a fallback.
- **Complex input methods.** The app selects enabled, selectable sources, including IME modes. Finish composing Chinese or Japanese characters before switching: handling of unfinished composition depends on the input method and macOS version. This version has no special composition handling.
- **System shortcut conflicts.** A shortcut reserved by macOS may perform a system action or never reach the app. Choose another combination when recording.
- **Local signing.** The build script uses an ad hoc signature by default. For more stable trust across rebuilds, use `CODESIGN_IDENTITY="your certificate name" ./scripts/build.sh`. Rebuilding, moving the app, or changing its signature may require granting permission again. The script does not automatically perform Developer ID signing or notarization. The downloadable 1.1.0 archive also uses an ad hoc signature.
- **One running copy.** A second process with the same bundle ID exits so that one gesture does not switch layouts twice.

## Development and verification

```sh
# Test shortcut recognition, recording, and input source cycling
./scripts/swift.sh test

# Debug build
./scripts/swift.sh build

# Optimized .app bundle with an icon and local signature
./scripts/build.sh

# Diagnostics without requesting permission or changing the input source
dist/LayoutSwitch.app/Contents/MacOS/LayoutSwitch --diagnose
```

Diagnostics print JSON with the app and diagnostics versions, the process's Input Monitoring permission, Secure Input state, current source, and available sources. Launch the `.app` to test global shortcuts: running its executable from Terminal may use a different macOS permission context.

To collect a report to share, run `scripts/collect-diagnostics.command` (named `Собрать диагностику.command` in the build archive). It saves `LayoutSwitch-diagnostics-…txt` on the Desktop with the app version from `/Applications`, a diagnostic snapshot, and the last hour of system logs. Version information is included even if the log contains no events.

Shortcut switches taking at least 100 ms after the key release that triggered them write timing information to the system log: event delivery (`delivery`), waiting to run the handler (`queue`), and switching (`switch`). A following `Switch phases` entry breaks down `switch`: reading the current source (`readCurrent`), validating sources and finding the next one (`prepare`), the system selection call (`select`), reading back the result or refreshing the cache after an error (`confirm`), and updating LayoutSwitch's UI (`publish`). To view these entries from the last 10 minutes:

```sh
/usr/bin/log show --last 10m --style compact --predicate 'subsystem == "local.masos.LayoutSwitch" AND category == "SwitchLatency"'
```

These entries contain durations and monitoring interruption reasons, with no typed text or key codes. Monitoring state changes use the same subsystem's `Monitoring` category to distinguish delays from pauses caused by permissions or Secure Input. Timing ends after the selection call and LayoutSwitch's indicator update; the other app may finish applying the layout later.

For a shortcut that never switches the layout, check all categories:

```sh
/usr/bin/log show --last 10m --style compact --predicate 'subsystem == "local.masos.LayoutSwitch"'
```

The `Shortcut` category records recognition, cancellation, and selection outcomes. Cancellation reasons are `otherKey` for another key, including one still held before the chord; `extraModifier` for an additional modifier; `pointerAction` for a mouse button; `otherAction` for actions such as scrolling; `unexpectedKeyRelease` for a release with no observed press; and `heldAtReset` for keys or buttons held when monitoring starts or resets. A recognized shortcut cancelled by a monitoring state change is logged separately.

The result is `confirmed` when the source read after selection matches the target, `unconfirmed` when the system call succeeded but the current source does not yet match, `failed` for a system error, or `unavailable` when no next source is available. `unconfirmed` alone does not prove failure: the source may change later. Ordinary typing does not generate shortcut entries.

Build caches stay in `.build`. The `scripts/swift.sh` wrapper disables SwiftPM's nested sandbox so builds work in restricted development environments. The package has no external dependencies, plugins, or network requests.

For each release, update `version` and `sha256` in `Casks/layoutswitch.rb` to match the published archive. Homebrew uses this version for upgrades.

### Project structure

```text
Sources/ShortcutCore/      shortcut recognition and recording, input source cycling
Sources/LayoutSwitch/     CGEventTap, TIS, preferences, SwiftUI, and the menu bar app
Tests/ShortcutCoreTests/   tests without global input or system permissions
Tests/LayoutSwitchTests/   source cache and switching tests with a fake system API
Casks/layoutswitch.rb     Homebrew installation from GitHub Releases
Resources/Info.plist       app bundle configuration
scripts/                  build scripts and AppKit icon generation
dist/LayoutSwitch.app     build output (not tracked in Git)
```

`CGEventTap` with `.listenOnly` receives modifier flags, key codes, and mouse actions on the main run loop. Shortcut state is separate from AppKit and TIS. Input source selection runs outside the event callback in the run loop's common modes, which also run while the menu is open. An unfinished gesture is reset when the tap is disabled, the Mac sleeps, the session changes, or Secure Input is detected.

`TISSelectInputSource` selects an input source directly. The source list and system handles are cached and refreshed when enabled sources change, the app becomes active, the Mac wakes, or the user requests a refresh. Normal switching reads the current source and checks selected sources' availability without rebuilding the list. An insufficient list, an unavailable source, or a selection error refreshes the cache. Selection notifications update only the current source; an unknown source triggers a list refresh. If fewer than two checked sources are available, the app does not substitute unchecked sources.

Permission is checked with [CGPreflightListenEventAccess](https://developer.apple.com/documentation/coregraphics/cgpreflightlisteneventaccess()) and requested with [CGRequestListenEventAccess](https://developer.apple.com/documentation/coregraphics/cgrequestlisteneventaccess()). Launch at login uses [SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp) and [register()](https://developer.apple.com/documentation/servicemanagement/smappservice/register()). TIS documentation is also available in `TextInputSources.h` in the local macOS SDK.

The app does not extract typed text from keyboard events or send data over the network. Diagnostic entries contain only configured shortcut outcomes, cancellation reasons, system error codes, and durations. Typed text and key codes are not logged; held key codes and modifier state are kept in memory during a gesture.

### Manual checks

1. Grant Input Monitoring and test Ctrl + Shift in TextEdit with English and Russian layouts, using both sides of the keyboard and different press/release orders.
2. Test Ctrl + Shift + an arrow or letter in an editor: the editor's action should work and the layout should stay unchanged.
3. Hold the shortcut, then release any of its keys: one switch. Releasing the remaining keys must not switch again. With Alt + Shift, repeatedly press and release Shift while holding Alt, then try the reverse: each release switches layouts. Check cancellation by clicking and scrolling before releasing a key.
4. Add two shortcuts, edit and remove entries, and try saving a duplicate. Cancel recording with Esc and by switching windows. Restart the app and check that the list persists. Check an upgrade from a single saved shortcut. Test overlapping shortcuts for double switches and alternate shortcuts while holding a shared modifier.
5. Select two of three sources, remove one in macOS, and check that the app shows a warning without switching to an unchecked source.
6. Test pause, sleep/wake, and Terminal's Secure Keyboard Entry. Disable secure input and check that monitoring resumes.
7. Enable launch at login and check it in System Settings; disable it if you do not need it.
8. Switch several times quickly, then repeat after switching with the macOS shortcut and while LayoutSwitch's menu is open. Check the `SwitchLatency` log if a switch feels slow.
9. If a switch is missed entirely, check `Shortcut` and `Monitoring`. Retry after releasing all keys and stopping scrolling, then compare with switching during fast typing.

Automated tests cover logic without generating global events. Permissions, hardware event delivery, IME behavior, and login need to be verified on the Mac where the app will run.

## Uninstall

For a Homebrew installation, first disable launch at login in the app, then run:

```sh
brew uninstall --cask lukdut/layoutswitch/layoutswitch
```

This keeps your preferences. To remove preferences too, use `brew uninstall --cask --zap lukdut/layoutswitch/layoutswitch` instead. If you no longer need the tap, remove it with `brew untap lukdut/layoutswitch` after uninstalling the app.

For a manual installation:

Disable launch at login in the app's settings, choose **Quit LayoutSwitch** (`Завершить LayoutSwitch`), and delete the `.app`. If needed, remove LayoutSwitch from the Input Monitoring list in System Settings.
