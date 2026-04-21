# Sprite Engine

Sprite Engine is a macOS-native arcade emulator built for Apple Silicon. It was created out of frustration with the lack of a proper Neo Geo emulator on the Mac platform. For good measure, it also includes CPS 1 and CPS 2 support. Credit to Geolith and FB Neo for the cores.

The app is built entirely in Swift and SwiftUI and behaves like a proper macOS application — not a ported emulator wrapped in an unfamiliar interface. It uses Metal for rendering, runs emulation on a dedicated background thread, and keeps all configuration persistent and accessible from a standard settings panel.

---

## Game Library

When you launch Sprite Engine for the first time, you are presented with a game library. This is the main screen of the app. It shows all the games you have imported, organised in a grid with box art, title, system, and genre.

To add games, click the Import button in the toolbar. From there you can point the app at a folder containing ROM files. Sprite Engine supports Neo Geo `.neo` files natively, as well as MAME-compatible `.zip` archives. If you have MAME-format Neo Geo zips, the app can convert them to `.neo` format automatically before adding them to the library.

You can filter the library by system, genre, or use the search field in the toolbar to find a specific title quickly.

---

## Playing a Game

To start a game, click on any title in the library to open the detail screen. From there you can read basic information about the game and click Play Now to launch it.

Once a game is running, the emulator takes over the full window. The interface fades away and the game fills the screen at the correct aspect ratio — 4:3 for Neo Geo titles, approximately 16:9 for CPS titles. The renderer uses Metal with nearest-neighbour scaling to keep the pixel art sharp.

Move the mouse to bring up the HUD overlay. The HUD gives you access to pause, save state, load state, and a back button to return to the library. It fades out automatically after a few seconds of inactivity.

### Keyboard shortcuts

| Action | Shortcut |
|---|---|
| Pause / Resume | `Cmd+P` |
| Save state | `Cmd+S` |
| Load state | `Cmd+L` |
| Return to library | `Escape` |

---

## Input

Sprite Engine reads keyboard and gamepad input. By default, player one uses WASD for movement and UIJK for buttons. A connected MFi or Xbox controller is detected automatically and mapped to standard arcade controls.

You can rebind all keys and buttons from the Input section of Settings. Both player one and player two bindings are configurable independently.

---

## Save States

At any point during a game you can save your progress as a save state. Save states are stored locally under `~/Library/Application Support/SpriteEngine/SaveStates/` and include a small thumbnail of the screen at the time of saving.

To save, use `Cmd+S` or the save button in the HUD. To restore a save state, use `Cmd+L` or the load button in the HUD. Multiple save slots are supported per game.

---

## Settings

The settings panel is accessible from the sidebar or the app menu. It is divided into the following sections.

**BIOS.** Some games require system BIOS files to run. Point this setting at the folder containing your BIOS files, such as `neogeo.zip` or `qsound.zip`. The app will warn you if required BIOS files are missing when you try to launch a game.

**ROM Import Directory.** Sets the default folder the import scanner opens when you add new games.

**Video.** Choose between integer scaling, fit-to-window, or stretch scaling. You can also toggle a CRT scanline shader that overlays a subtle scanline effect on the picture, similar to a real arcade monitor.

**Audio.** Adjust the master volume and choose the audio sample rate. The default settings work well for most systems.

**Input.** Rebind keyboard keys and gamepad buttons for player one and player two independently.

**Appearance.** Switch between three visual themes: Dark Cinematic (the default), macOS Native, and CRT Amber.