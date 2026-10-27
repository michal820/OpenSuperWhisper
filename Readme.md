# OpenSuperWhisper (michal820 fork)

A fork of [Starmel/OpenSuperWhisper](https://github.com/Starmel/OpenSuperWhisper), the free, open-source macOS dictation app that transcribes your voice locally with Whisper and pastes the text wherever your cursor is.

This fork redesigns the recording indicator and stops recordings from interrupting music on Bluetooth headphones.

**[Download the latest build](https://github.com/michal820/OpenSuperWhisper/releases/latest)**

## What's changed in this fork

### Redesigned recording indicator

- **Live waveform** instead of a blinking red dot. Thin bars scroll as you speak, newest on the right, shaded from lavender to pink.
- **Adapts to your microphone.** Bar height follows your recent loudness, so quiet mics still fill the bars and loud ones don't clip.
- **Translucent indigo card** with a blurred, see-through background. Looks the same in light and dark mode.
- **Stays where you put it.** The indicator no longer jumps to your cursor. Drag it anywhere.
- **Resizable.** Drag its right end to make it bigger or smaller. Text stays sharp at any size.
- **Per monitor.** Each display remembers its own position and size, and the indicator appears on the display you're working on.

### Music keeps playing on AirPods and other Bluetooth headphones

The original app switches the Mac's system-wide default microphone when a recording starts and switches it back when it ends. With Bluetooth headphones, each switch flips them between music mode (A2DP) and call mode (HFP), which pauses your music and changes its volume. This fork records from the selected microphone directly and never changes the system default.

### Unreleased fixes from the original app

The last official release (0.1.0) is from March 2026. This fork is built from the original app's latest code, which adds, among other fixes:

- **Failed transcriptions keep the recording** in history, with a retry button.
- **No more broken spacing** in long transcriptions (a line break and a leading space every few seconds).
- **Errors are shown** instead of failing silently.

### Builds with Xcode 16

`KeyboardShortcuts` is pinned to 2.x, because 3.x requires Swift 6.2 (Xcode 26).

## Install

1. Download `OpenSuperWhisper-custom.zip` from [Releases](https://github.com/michal820/OpenSuperWhisper/releases/latest), unzip it and move **OpenSuperWhisper** to Applications.
2. Open it. The build is signed with a development certificate and isn't notarized, so macOS blocks the first launch. Click **Done**, then go to **System Settings → Privacy & Security** and click **Open Anyway**.
3. Allow **Microphone** and turn on OpenSuperWhisper under **Accessibility** (needed to paste).
4. Pick a model. **Whisper V3 Large** (large-v3-turbo, 1.6 GB) is a good default.
5. Press **Option + `** to start and stop recording. You can change the shortcut in Settings.

If you installed the original app with Homebrew, run `brew uninstall --cask opensuperwhisper` first so an update doesn't replace this build.

Requires an Apple Silicon Mac with macOS 14 or later.

## Build from source

    git clone https://github.com/michal820/OpenSuperWhisper.git
    cd OpenSuperWhisper
    git submodule update --init --recursive
    brew install cmake libomp rust ruby
    gem install xcpretty
    ./run.sh build

## Everything else

For the full feature list, settings and model notes, see the [original README](https://github.com/Starmel/OpenSuperWhisper#readme).

## Credits and license

OpenSuperWhisper is created by [Vyacheslav Kornienko (Starmel)](https://github.com/Starmel). Licensed under the MIT License, see [LICENSE](LICENSE).
