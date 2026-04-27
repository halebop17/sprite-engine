# Sprite Engine

Sprite Engine is a macOS-native arcade emulator built for Apple Silicon. It was created out of frustration with the lack of a proper Neo Geo emulator on the Mac platform. For good measure, it also includes CPS 1 and CPS 2 support. Credit to Geolith and FB Neo for the cores.

The app is built entirely in Swift and SwiftUI and behaves like a proper macOS application — not a ported emulator wrapped in an unfamiliar interface. It uses Metal for rendering, runs emulation on a dedicated background thread, and keeps all configuration persistent and accessible from a standard settings panel.

---

## Game Library

When you launch Sprite Engine for the first time, you are presented with a game library. This is the main screen of the app. It shows all the games you have imported, organised in a grid with box art, title, system, and genre.

To add games, click the Import button in the toolbar. From there you can point the app at a folder containing ROM files. Sprite Engine supports Neo Geo `.neo` files natively, as well as MAME-compatible `.zip` archives. If you have MAME-format Neo Geo zips, the app can convert them to `.neo` format automatically before adding them to the library.

You can filter the library by system, genre, or use the search field in the toolbar to find a specific title quickly. The library can be displayed as a grid of cards or a compact list — toggle between the two with the view-mode buttons in the toolbar.

Box art for each game is downloaded automatically from ScreenScraper.fr. See **Artwork** below for setup and usage.

---

## Artwork

Sprite Engine pulls box art, logos, marquees, screenshots and additional media from [ScreenScraper.fr](https://www.screenscraper.fr), the same community database used by EmulationStation and RetroPie. All artwork is cached locally so it only needs to download once.

### One-time setup

1. Create a free account at [screenscraper.fr](https://www.screenscraper.fr).
2. Open **Settings → Scraping** in Sprite Engine and enter your ScreenScraper username and password.
3. Click **Test** to confirm the credentials work. On success you'll see your account level and daily quota.

The app already ships with developer credentials registered to "Sprite Engine" — you only need a personal user account.

### Triggering a download

There are three ways to fetch artwork:

**Automatic on import.** When you scan a new ROM folder (Settings → ROM Folders → Add ROM Folder, or the Rescan button), any newly-discovered games are queued for artwork in the background. No prompt — covers just start appearing on the cards within seconds.

**Per game.** Open a game's detail page and click **Fetch Artwork** in the top bar (the button reads **Refresh Artwork** if the game already has art). One round-trip, takes about a second.

**Whole library.** Click the **Artwork** button in the library toolbar to open the bulk-scrape sheet. It shows a per-game status list (saved, scraping, not found, error) plus a running progress counter. Closing the sheet does not stop the queue — work continues in the background and you can keep using the app. A **Re-scrape existing** toggle lets you refresh art for games that already have it.

ScreenScraper rate-limits API calls per user, so the bulk scrape processes one game per second. Image downloads themselves run in parallel and don't count against the rate limit, so a library of ~100 games typically completes in two to three minutes.

### What gets downloaded

On the first scrape, the front box art (`box-2D`), logo (`wheel-hd`) and arcade marquee are downloaded immediately and shown on the library card and detail page. The URLs for additional media (back box, 3D box, fanart, title screen, support art, bezel, screenshots) are stored locally so they can be downloaded later without another API call.

The first time you open a game's **Media tab**, those extras are fetched automatically. Each scraped image gets a thumbnail in the new **From ScreenScraper** section, alongside your existing user-uploaded screenshots and PDFs. Click any thumbnail to open it in the full-window lightbox; use the left/right arrows or arrow keys to flip through the gallery.

### Manual cover override

Three ways to override the auto-picked cover:

- **From the detail page**: click the ⋯ menu and choose **Set Cover Image…** to pick any local image file.
- **From the Media tab**: every scraped thumbnail has a **Set as Cover** button that promotes that image (e.g. a screenshot or back box) to the main card.
- A manually-set cover is flagged as such and will not be overwritten by future re-scrapes.

To revert, use **Clear Artwork** in the ⋯ menu and re-fetch.

### Name override (for misnamed ROMs)

If ScreenScraper can't find a match because the ROM filename is unusual (for example `TMNT (USA, prototype).zip` instead of the canonical `tmnt.zip`), you can tell the scraper to use a different name without renaming the actual file:

1. On the game's detail page, open the ⋯ menu and choose **Set Name Override…**.
2. Enter the canonical name ScreenScraper expects (with or without `.zip`).
3. Click **Save & Refetch** — the request goes out immediately with the new name.

The override persists across re-scrapes, library rescans, and app restarts. To remove it, open the same dialog and click **Clear Override**.

### Where artwork is stored

All scraped media is cached on disk under your user Application Support directory:

```
~/Library/Application Support/SpriteEngine/Artwork/<game-id>/
    box.jpg          ← main cover (used on cards and detail page)
    wheel.png        ← logo / wheel
    marquee.png      ← arcade marquee
    boxback.jpg      ← back of the box
    box3d.jpg        ← 3D rendered box
    fanart.jpg       ← fan art / backdrop
    title.jpg        ← title screen
    support.jpg      ← cartridge / CD art
    bezel.jpg        ← arcade bezel
    screenshot_0.jpg, screenshot_1.jpg, …
    metadata.json    ← cached ScreenScraper URLs (so extras can be fetched without re-calling the API)
```

The library index itself lives at `~/Library/Application Support/SpriteEngine/library.json` and stores the per-game `hasArtwork` and `coverIsManual` flags as well as any name overrides you've set.

You can safely delete the `Artwork/<game-id>` folder for any game to wipe its cache — the next scrape will rebuild it.

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

**Scraping.** ScreenScraper.fr credentials for downloading game artwork. Includes a Test button that validates the login and reports your daily quota. See **Artwork** above for details.

**Appearance.** Switch between three visual themes: Dark Cinematic (the default), macOS Native, and CRT Amber.

---

## Game Detail Page

The detail page shows the box art, marquee, and game stats on the left, with tabbed sections for Info, Notes, Media, and Save States on the right. The cover image is clickable — it opens in a full-window lightbox at the largest size that fits.

You can step through your library directly from the detail page using the floating **‹** and **›** arrow buttons in the bottom corners, or with the **left** and **right** arrow keys on your keyboard. Order is alphabetical by title and matches the library list view. Arrow-key navigation is suspended while you're typing in the Notes editor or any other text field.