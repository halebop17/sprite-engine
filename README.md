# Sprite Engine

Sprite Engine is a macOS-native Neo Geo emulator designed for Apple Silicon. This project was created out of frustration with the lack of a proper Neo Geo emulator on Mac, so it combines native macOS UI and modern rendering. FOr good measure I also icnluded CPS 1 and CPS 2 cores. Credit goes to Geolith (Neo Geo) AND FB NEO (CPS 1, CPS 2).

## Overview

Sprite Engine is intended to behave like a native Mac application, not a ported emulator with a clunky interface. It is built in Swift and SwiftUI, and it ships with a custom Metal renderer, a library browser, save-state support, and configurable input and BIOS settings.

## How to use

1. Open the app in Xcode and build the `SpriteEngine` target for macOS 14+.
2. Configure the BIOS directory in Settings if required by the emulation cores.
3. Use the ROM import screen or point the library scanner at a folder containing Neo Geo `.neo` files, `.zip` archives, or supported arcade media.
4. Select a game from the library to launch it in the emulator window.
5. Use the on-screen HUD or keyboard shortcuts for pause, save state, load state, and exit back to the library.
6. Adjust video, audio, and input settings from the app settings panel to tune the experience.

## What the app does

Sprite Engine provides a full Mac-native emulator experience:

- Presents a SwiftUI-based app shell with navigation and window management.
- Scans ROM folders and builds a browsable game library.
- Converts compatible archives to Neo Geo format when necessary.
- Loads games using a native Geolith-based Neo Geo core.
- Renders video through Metal with sharp scaling and correct aspect ratio.
- Handles audio playback through a native audio engine.
- Supports keyboard and gamepad input for player controls.
- Saves and restores game states with thumbnail support.

## Features in practice

- **Launch games from a library**: browse imported titles, select a game, and start it without leaving the app.
- **Customizable settings**: set BIOS locations, video scaling, audio options, and input bindings.
- **Native macOS look**: use menus, window controls, and responsive UI that feel like a real Mac app.
- **Save states**: save progress at any time and reload it later.
- **Modern rendering**: the emulator uses Metal for display, preserving pixel sharpness and handling Neo Geo and CPS aspect ratios correctly.

## Build notes

- Target: macOS 14.0+
- Architecture: arm64 only
- Languages: Swift, C, C++
- Dependencies: native Geolith and FBNeo source trees are included as local directories