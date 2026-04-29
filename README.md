# Sprite Engine

A native macOS arcade emulator for Apple Silicon. Built in Swift / SwiftUI with Metal rendering, written from frustration at the lack of a proper Neo Geo emulator on the Mac platform — and extended to cover the major sprite-based arcade hardware of the late 80s and early 90s.

The app feels like a real macOS application rather than a ported emulator wrapped in unfamiliar UI: a SwiftUI library grid, themeable interface, ScreenScraper artwork integration, save states, per-game notes and media, and per-system controller remapping. ROMs and BIOS files are user-supplied — none are bundled or distributed with the app.

## Supported Systems

| System | Hardware | Core | Notes |
|---|---|---|---|
| **Neo Geo MVS / AES / CD** | SNK Neo Geo | Geolith | Primary focus — full MVS/AES support plus Neo Geo CD |
| **CPS-1** | Capcom Play System 1 | FBNeo | 68000 / Z80 — Final Fight, Strider, Ghouls 'n Ghosts era |
| **CPS-2** | Capcom Play System 2 | FBNeo | 68000 / Q-Sound — Street Fighter Alpha, Marvel vs Capcom, etc. |
| **Sega System 16 / 18** | Sega arcade boards | FBNeo | Shinobi, Golden Axe, Altered Beast, Shadow Dancer |
| **Toaplan 1 & 2** | Toaplan arcade hardware | FBNeo | Flying Shark, Batsugun and the GP9001 vertical shooters |
| **Konami GX** | 32-bit Konami board | FBNeo | Run and Gun, Martial Champion |
| **Konami 16-bit (68K)** | K052109 / K053260 era | FBNeo | TMNT, The Simpsons, X-Men, Sunset Riders, Contra |
| **Irem M72 / M92** | Irem arcade hardware | FBNeo | R-Type, Image Fight, Ninja Baseball Batman |
| **Taito F2 / F3** | Taito arcade hardware | FBNeo | Rainbow Islands, Ninja Warriors, Elevator Action Returns |

## Highlights

- **Native macOS app** — SwiftUI library, detail and emulator windows, theming (Dark Cinematic, macOS Native, CRT Amber), save states with thumbnails.
- **Metal renderer** with nearest-neighbour scaling and an optional CRT shader.
- **ScreenScraper artwork** — automatic box art, marquees, screenshots and additional media via [screenscraper.fr](https://www.screenscraper.fr); per-game manual cover override and ROM-name override for misnamed files.
- **Per-system controller remapping** — keyboard and gamepad, with a different binding profile per arcade system. Xbox / MFi / DualSense detected automatically.
- **ROM verifier** — checks file presence and CRC against FBNeo's database for every supported system.
- **Neo Geo MAME-zip → `.neo` conversion** built in.
- **Apple Silicon only**, macOS 14+.

## Documentation

End-user manual lives at [docs/manual.md](docs/manual.md). Internal notes and the phase-by-phase development plan are in [docs/DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md).

## Credits

Sprite Engine wouldn't exist without the work of two upstream emulation projects:

- **[Geolith](https://github.com/rofl0r/geolith)** by neopong — a clean, modern Neo Geo core (C11). Geolith powers all Neo Geo emulation in this app and is the reason a Mac-native Neo Geo emulator is finally possible.
- **[FBNeo (FinalBurn Neo)](https://github.com/finalburnneo/FBNeo)** — the broad arcade core covering CPS-1/2, Sega, Toaplan, Konami, Irem, Taito and many more. FBNeo is the result of decades of work by the FB Alpha and FBNeo teams; Sprite Engine bundles the subsets relevant to its supported systems.

Game artwork (cover, wheel, marquee, screenshots, fanart) is provided by the **[ScreenScraper](https://www.screenscraper.fr)** community database when the user supplies their own ScreenScraper account credentials.

System logos and badges shown in the UI are trademarks of their respective owners (SNK, Capcom, Sega, Toaplan, Konami, Irem, Taito) and are used here solely to identify the hardware each game ran on.

## License

This repository does not currently carry an open-source licence file. All rights are reserved by the author. The code is published publicly so that users can read and learn from it; redistribution, modification, or commercial use of the Sprite Engine source is not granted by default.

The bundled emulation cores remain under their own licences:

- **Geolith** — BSD-3-Clause (permissive).
- **FBNeo** — custom non-commercial licence. The compiled Sprite Engine binary, by virtue of including FBNeo, is subject to that non-commercial restriction in addition to anything stated above.

Sprite Engine is and will remain free of charge.

## Disclaimer

Sprite Engine is an emulator. It does not include any ROM data, BIOS files, or copyrighted game content. Users supply their own files for any system they wish to run, and are responsible for ensuring they have the legal right to do so.
