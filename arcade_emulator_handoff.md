# Arcade Emulator — macOS — Claude Code Handoff

## Project Overview

Build a native macOS emulator app for two arcade system families:
- **Neo Geo** (AES, MVS, CD, CDZ) via the **Geolith** C11 core
- **CPS-1 and CPS-2** (Capcom Play System) via **FBNeo** built with `SUBSET=cps12`

The app is written in **Swift + SwiftUI**, targets **macOS 14+ / Apple Silicon** (arm64 native, no Rosetta), and uses **Metal** for rendering and **AVAudioEngine** for audio. A custom UI design will be provided separately as a design file — implement all functionality to slot into that design.

---

## Repository Structure (Target)

```
ArcadeEmulator/
├── ArcadeEmulator.xcodeproj
├── ArcadeEmulator/                  # SwiftUI app target
│   ├── App/
│   │   ├── ArcadeEmulatorApp.swift
│   │   └── AppDelegate.swift
│   ├── UI/                          # SwiftUI views (slot design here)
│   │   ├── LibraryView.swift
│   │   ├── GameCardView.swift
│   │   ├── EmulatorWindowView.swift
│   │   ├── SettingsView.swift
│   │   └── OnboardingView.swift
│   ├── Emulation/
│   │   ├── EmulatorCore.swift       # Protocol definition
│   │   ├── EmulatorSession.swift    # Lifecycle manager
│   │   ├── GeolithCore.swift        # Geolith wrapper
│   │   ├── FBNeoCPSCore.swift       # FBNeo CPS wrapper
│   │   └── CoreRouter.swift         # ROM-to-core routing
│   ├── Rendering/
│   │   ├── MetalRenderer.swift
│   │   ├── EmulatorView.swift       # MTKView subclass
│   │   └── Shaders.metal
│   ├── Audio/
│   │   └── AudioEngine.swift
│   ├── Input/
│   │   └── InputManager.swift
│   ├── Library/
│   │   ├── ROMLibrary.swift
│   │   ├── ROMScanner.swift
│   │   ├── GameMetadata.swift
│   │   └── GameDatabase.swift       # Bundled name/system lookup table
│   ├── Conversion/
│   │   ├── NeoConverter.swift       # MAME zip → .neo conversion
│   │   └── ConversionQueue.swift
│   ├── Models/
│   │   ├── Game.swift
│   │   ├── System.swift
│   │   └── SaveState.swift
│   └── Resources/
│       ├── GameDB.json              # Bundled game list (name, system, CRC)
│       └── Assets.xcassets
├── GeolithLib/                      # C static library target
│   ├── geolith/                     # Geolith source (git submodule)
│   └── bridge/
│       ├── geolith_bridge.h
│       └── geolith_bridge.c
├── FBNeoCPSLib/                     # C++ static library target
│   ├── fbneo/                       # FBNeo source (git submodule, SUBSET=cps12)
│   └── bridge/
│       ├── fbneo_cps_bridge.h       # Pure C header — Swift-visible
│       └── fbneo_cps_bridge.cpp     # C++ implementation
└── Shared/
    └── ArcadeEmulator-Bridging-Header.h
```

---

## Cores

### Core A: Geolith (Neo Geo)

- **Source**: `https://gitlab.com/jgemu/geolith`
- **Language**: C11
- **License**: BSD-3-Clause
- **Systems**: Neo Geo AES, MVS, CD, CDZ
- **ROM format**: `.neo` single-file format (NOT MAME zip — requires conversion, see below)
- **BIOS required**: `neogeo.zip` (MVS) or `aes.zip` (AES) — user-supplied
- **Native refresh rate**: ~59.185 Hz
- **Framebuffer**: 320×224 (or 304×224) RGBA, output per `run_frame()`
- **Audio**: 16-bit stereo PCM at 55,555 Hz

**Swift interop**: Geolith is C11 — expose via bridging header directly. No C++ shim needed.

**Key Geolith API surface** (from `geolith.h`):

```c
// Init/teardown
geolith_t* geolith_create(void);
void       geolith_destroy(geolith_t *ctx);

// Load
int  geolith_load_neo(geolith_t *ctx, const char *path);   // cartridge
int  geolith_load_cd(geolith_t *ctx, const char *path);    // CD/CDZ

// Run
void geolith_run_frame(geolith_t *ctx);

// Video
const uint32_t* geolith_get_framebuffer(geolith_t *ctx, int *w, int *h);

// Audio — returns count of stereo int16 sample pairs
int geolith_get_audio(geolith_t *ctx, const int16_t **samples);

// Input — bitmask per player
void geolith_set_input(geolith_t *ctx, int player, uint32_t buttons);

// State
int  geolith_save_state(geolith_t *ctx, void **data, size_t *size);
int  geolith_load_state(geolith_t *ctx, const void *data, size_t size);
```

> Note: Verify exact function signatures from the Geolith source header. The above represents the expected API surface; adjust the bridge file if signatures differ.

---

### Core B: FBNeo CPS-1/2 Subset

- **Source**: `https://github.com/finalburnneo/FBNeo`
- **Build flag**: `SUBSET=cps12` — produces a CPS-1 and CPS-2 only core
- **Language**: C++
- **License**: Non-commercial (do not distribute as paid or commercial software)
- **Systems**: Capcom CPS-1, Capcom CPS-2
- **ROM format**: Standard MAME zip format (same zip sets users already have)
- **Framebuffer**: Variable per game; typically 384×224 (CPS-1) or 384×224 (CPS-2)
- **Audio**: 16-bit stereo PCM

**Swift interop**: FBNeo is C++ — Swift cannot call C++ directly. A C shim is required.

**C bridge header** (`fbneo_cps_bridge.h`) — pure C, Swift-visible:

```c
#pragma once
#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct FBNeoCPSContext FBNeoCPSContext;

FBNeoCPSContext* fbneo_cps_create(void);
void             fbneo_cps_destroy(FBNeoCPSContext *ctx);

int  fbneo_cps_set_rom_path(FBNeoCPSContext *ctx, const char *path);
int  fbneo_cps_load_game(FBNeoCPSContext *ctx, const char *game_name);
void fbneo_cps_run_frame(FBNeoCPSContext *ctx);

const uint32_t* fbneo_cps_get_framebuffer(FBNeoCPSContext *ctx, int *w, int *h);
const int16_t*  fbneo_cps_get_audio(FBNeoCPSContext *ctx, int *sample_count);
void            fbneo_cps_set_input(FBNeoCPSContext *ctx, int player, uint32_t buttons);

int    fbneo_cps_save_state(FBNeoCPSContext *ctx, void **data, size_t *size);
int    fbneo_cps_load_state(FBNeoCPSContext *ctx, const void *data, size_t size);

#ifdef __cplusplus
}
#endif
```

**C++ implementation** (`fbneo_cps_bridge.cpp`): Calls into FBNeo's `BurnDriver` and `BurnLibEx` API. Follow the FBNeo libretro port (`src/burner/libretro/libretro.cpp`) as the reference implementation — it shows exactly how to drive FBNeo as an embedded core.

---

## Swift Protocol Layer

All UI and session management talks to cores through this protocol. Never call Geolith or FBNeo APIs directly from SwiftUI.

```swift
// EmulatorCore.swift

import Foundation

enum EmulatorSystem {
    case neoGeoAES
    case neoGeoMVS
    case neoGeoCD
    case cps1
    case cps2
}

protocol EmulatorCore: AnyObject {
    var system: EmulatorSystem { get }
    var frameWidth: Int { get }
    var frameHeight: Int { get }
    var nativeFPS: Double { get }

    func loadROM(at url: URL, biosDirectory: URL) throws
    func runFrame()
    func framebuffer() -> UnsafePointer<UInt32>
    func audioSamples() -> (pointer: UnsafePointer<Int16>, count: Int)
    func setInput(player: Int, buttons: UInt32)
    func saveState() throws -> Data
    func loadState(_ data: Data) throws
    func reset()
    func shutdown()
}
```

```swift
// GeolithCore.swift — wraps C11 geolith API
final class GeolithCore: EmulatorCore {
    let system: EmulatorSystem
    var frameWidth: Int = 320
    var frameHeight: Int = 224
    var nativeFPS: Double = 59.185

    private var ctx: OpaquePointer?

    init(system: EmulatorSystem) {
        self.system = system
        self.ctx = geolith_create()
    }

    func loadROM(at url: URL, biosDirectory: URL) throws {
        let result = geolith_load_neo(ctx, url.path)
        guard result == 0 else { throw EmulatorError.romLoadFailed }
    }

    func runFrame() { geolith_run_frame(ctx) }

    func framebuffer() -> UnsafePointer<UInt32> {
        var w: Int32 = 0; var h: Int32 = 0
        return geolith_get_framebuffer(ctx, &w, &h)!
    }

    func audioSamples() -> (pointer: UnsafePointer<Int16>, count: Int) {
        var ptr: UnsafePointer<Int16>? = nil
        let count = geolith_get_audio(ctx, &ptr)
        return (ptr!, Int(count))
    }

    func setInput(player: Int, buttons: UInt32) {
        geolith_set_input(ctx, Int32(player), buttons)
    }

    func saveState() throws -> Data { /* wrap geolith_save_state */ }
    func loadState(_ data: Data) throws { /* wrap geolith_load_state */ }
    func reset() { geolith_reset(ctx) }
    func shutdown() { geolith_destroy(ctx); ctx = nil }
}
```

```swift
// FBNeoCPSCore.swift — wraps C shim over C++ FBNeo
final class FBNeoCPSCore: EmulatorCore {
    let system: EmulatorSystem
    var frameWidth: Int = 384
    var frameHeight: Int = 224
    var nativeFPS: Double = 59.637

    private var ctx: OpaquePointer?

    init(system: EmulatorSystem) {
        self.system = system
        self.ctx = fbneo_cps_create()
    }

    func loadROM(at url: URL, biosDirectory: URL) throws {
        fbneo_cps_set_rom_path(ctx, url.deletingLastPathComponent().path)
        let gameName = url.deletingPathExtension().lastPathComponent
        let result = fbneo_cps_load_game(ctx, gameName)
        guard result == 0 else { throw EmulatorError.romLoadFailed }
    }

    // ... rest mirrors GeolithCore pattern
}
```

---

## Core Router

Determines which core to use based on file extension and game database lookup.

```swift
// CoreRouter.swift

final class CoreRouter {

    // Bundled lookup: zip filename stem → system
    private let gameDB: [String: EmulatorSystem]

    init() {
        self.gameDB = GameDatabase.shared.load() // from GameDB.json
    }

    func core(for url: URL) throws -> EmulatorCore {
        switch url.pathExtension.lowercased() {

        case "neo":
            return GeolithCore(system: .neoGeoAES)

        case "chd", "cue":
            return GeolithCore(system: .neoGeoCD)

        case "zip":
            let name = url.deletingPathExtension().lastPathComponent.lowercased()
            guard let system = gameDB[name] else {
                throw EmulatorError.unknownGame(name)
            }
            switch system {
            case .cps1: return FBNeoCPSCore(system: .cps1)
            case .cps2: return FBNeoCPSCore(system: .cps2)
            case .neoGeoMVS: return GeolithCore(system: .neoGeoMVS)
            default: throw EmulatorError.unsupportedSystem
            }

        default:
            throw EmulatorError.unsupportedFormat(url.pathExtension)
        }
    }
}
```

**GameDB.json format** (bundle this with the app — generate from FBNeo DAT files):

```json
{
  "sf2":     "cps1",
  "sfz":     "cps2",
  "mslug":   "neoGeoMVS",
  "kof98":   "neoGeoMVS",
  "dino":    "cps2",
  "punisher":"cps1"
}
```

---

## Rendering (Metal)

### EmulatorView.swift

```swift
import MetalKit

final class EmulatorView: MTKView {
    private var renderer: MetalRenderer!

    override init(frame: CGRect, device: MTLDevice?) {
        super.init(frame: frame, device: device ?? MTLCreateSystemDefaultDevice())
        self.renderer = MetalRenderer(view: self)
        self.delegate = renderer
        self.framebufferOnly = true
        self.preferredFramesPerSecond = 60
        self.colorPixelFormat = .bgra8Unorm
    }

    func update(framebuffer: UnsafePointer<UInt32>, width: Int, height: Int) {
        renderer.updateTexture(pixels: framebuffer, width: width, height: height)
    }
}
```

### MetalRenderer.swift

- Creates an `MTLTexture` of size `frameWidth × frameHeight`, pixel format `.bgra8Unorm`
- On each frame, replaces texture contents with the emulator framebuffer via `texture.replace(region:mipmapLevel:withBytes:bytesPerRow:)`
- Renders a fullscreen quad in the vertex shader; samples texture with `min_filter::nearest, mag_filter::nearest` (integer scale) or `linear` when smoothing is enabled
- Maintains aspect ratio: Neo Geo is 4:3, CPS is ~1.7:1 — letterbox/pillarbox appropriately

### Shaders.metal

Provide two fragment shader variants selectable at runtime:
1. **Sharp** — nearest-neighbor sampling only
2. **CRT** — approximate scanline overlay using a sine-based luminance modulation per row

---

## Audio (AVAudioEngine)

```swift
// AudioEngine.swift

import AVFoundation

final class AudioEngine {
    private let engine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private var ringBuffer = RingBuffer<Int16>(capacity: 8192)
    private let sampleRate: Double

    init(sampleRate: Double = 55555.0) {
        self.sampleRate = sampleRate
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                   sampleRate: sampleRate,
                                   channels: 2,
                                   interleaved: true)!
        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, buffers in
            // Pull from ring buffer into buffers
            self?.ringBuffer.read(into: buffers, count: Int(frameCount))
            return noErr
        }
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func push(samples: UnsafePointer<Int16>, count: Int) {
        ringBuffer.write(from: samples, count: count)
    }
}
```

**Ring buffer**: Implement a simple thread-safe `RingBuffer<T>` using an `os_unfair_lock` or a `DispatchSemaphore`. The emulation thread writes; the Core Audio thread reads.

---

## Input (GameController + Keyboard)

```swift
// InputManager.swift

import GameController

final class InputManager {
    // Neo Geo / CPS button bitmask
    struct Buttons: OptionSet {
        let rawValue: UInt32
        static let up      = Buttons(rawValue: 1 << 0)
        static let down    = Buttons(rawValue: 1 << 1)
        static let left    = Buttons(rawValue: 1 << 2)
        static let right   = Buttons(rawValue: 1 << 3)
        static let a       = Buttons(rawValue: 1 << 4)
        static let b       = Buttons(rawValue: 1 << 5)
        static let c       = Buttons(rawValue: 1 << 6)
        static let d       = Buttons(rawValue: 1 << 7)
        static let start   = Buttons(rawValue: 1 << 8)
        static let select  = Buttons(rawValue: 1 << 9)
    }

    var onInputChanged: ((Int, UInt32) -> Void)?

    private var keyboardState: [UInt16: Bool] = [:]
    private let keymap: [UInt16: (player: Int, button: Buttons)] = [
        // Player 1 — WASD + UIJK
        0x0D: (1, .up), 0x01: (1, .down), 0x00: (1, .left), 0x02: (1, .right),
        0x20: (1, .a),  0x22: (1, .b),    0x09: (1, .c),    0x0B: (1, .d),
        // Extend as needed
    ]

    func setupGameController() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] n in
            self?.connectController(n.object as! GCController)
        }
        GCController.startWirelessControllerDiscovery()
    }

    private func connectController(_ controller: GCController) {
        controller.extendedGamepad?.valueChangedHandler = { [weak self] pad, _ in
            var buttons: UInt32 = 0
            if pad.dpad.up.isPressed    { buttons |= Buttons.up.rawValue }
            if pad.dpad.down.isPressed  { buttons |= Buttons.down.rawValue }
            if pad.dpad.left.isPressed  { buttons |= Buttons.left.rawValue }
            if pad.dpad.right.isPressed { buttons |= Buttons.right.rawValue }
            if pad.buttonA.isPressed    { buttons |= Buttons.a.rawValue }
            if pad.buttonB.isPressed    { buttons |= Buttons.b.rawValue }
            if pad.buttonX.isPressed    { buttons |= Buttons.c.rawValue }
            if pad.buttonY.isPressed    { buttons |= Buttons.d.rawValue }
            self?.onInputChanged?(1, buttons)
        }
    }
}
```

---

## ROM Library

### Models

```swift
// Game.swift
struct Game: Identifiable, Codable {
    let id: UUID
    let title: String
    let system: EmulatorSystem
    let romURL: URL
    let artworkURL: URL?
    var lastPlayed: Date?
    var isFavorite: Bool
    var saveStates: [SaveState]
}

// System.swift
enum EmulatorSystem: String, Codable, CaseIterable {
    case neoGeoAES  = "Neo Geo AES"
    case neoGeoMVS  = "Neo Geo MVS"
    case neoGeoCD   = "Neo Geo CD"
    case cps1       = "CPS-1"
    case cps2       = "CPS-2"

    var coreType: CoreType {
        switch self {
        case .neoGeoAES, .neoGeoMVS, .neoGeoCD: return .geolith
        case .cps1, .cps2: return .fbneopCPS
        }
    }
}
```

### ROMScanner

```swift
// ROMScanner.swift
final class ROMScanner {
    func scan(directory: URL) async -> [Game] {
        // 1. Find all .neo, .zip, .chd, .cue files recursively
        // 2. For .neo → system = .neoGeoAES (or CDZ if named accordingly)
        // 3. For .zip → look up stem in GameDB.json to identify CPS1/CPS2/NeoGeo
        // 4. For .chd/.cue → system = .neoGeoCD
        // 5. Return array of Game values with placeholder artwork
    }
}
```

---

## ROM Conversion (.neo format)

CPS games load directly from MAME zip — no conversion needed.

Neo Geo games must be converted from MAME zip to `.neo` format. Build this as an in-app import flow.

### Conversion Logic

The `.neo` file format is documented at `https://gitlab.com/jgemu/geolith/-/blob/master/docs/neo_file_format.md`. The container:
- 4KB header (magic bytes + ROM region metadata)
- Concatenated ROM regions in a fixed order: P (68000 program), S (fix layer), M (Z80), V1/V2 (ADPCM), C (graphics)

**Recommended approach**: Use the `bodgit/terraonion` Go tool as a reference implementation, then re-implement the relevant conversion logic in Swift for in-app use. The conversion is essentially: unzip MAME archive → sort ROM files by region → write header → concatenate regions.

```swift
// NeoConverter.swift
final class NeoConverter {
    enum ConversionError: Error {
        case unknownGame(String)
        case missingROMFiles([String])
        case writeFailed
    }

    func convert(mameZip: URL, outputDirectory: URL) async throws -> URL {
        // 1. Unzip mameZip to temp directory
        // 2. Look up game name in GameDB to get region layout
        // 3. Build .neo header from region metadata
        // 4. Concatenate ROM regions in correct order
        // 5. Write output .neo file to outputDirectory
        // 6. Return .neo URL
    }
}
```

```swift
// ConversionQueue.swift — batch convert a folder of MAME zips
final class ConversionQueue: ObservableObject {
    @Published var progress: Double = 0
    @Published var results: [ConversionResult] = []

    func convertAll(from folder: URL, to outputFolder: URL) async {
        // Enumerate zips → NeoConverter.convert() each
        // Publish progress updates
    }
}
```

---

## Emulation Session (Threading)

The emulation loop must run on a dedicated background thread. Metal and Core Audio have their own threads. Use a double-buffer for the framebuffer.

```swift
// EmulatorSession.swift

final class EmulatorSession: ObservableObject {
    private let core: EmulatorCore
    private let audio: AudioEngine
    private var emulationThread: Thread?
    private var running = false

    // Double-buffer: emulation writes to backBuffer, Metal reads from frontBuffer
    private var frontBuffer: [UInt32] = []
    private var backBuffer: [UInt32] = []
    private var bufferLock = os_unfair_lock()

    @Published var isRunning: Bool = false

    init(core: EmulatorCore) {
        self.core = core
        self.audio = AudioEngine(sampleRate: 55555.0)
    }

    func start() {
        running = true
        isRunning = true
        emulationThread = Thread {
            self.runLoop()
        }
        emulationThread?.qualityOfService = .userInteractive
        emulationThread?.start()
    }

    private func runLoop() {
        let targetFrameTime: TimeInterval = 1.0 / core.nativeFPS
        var lastTime = CACurrentMediaTime()

        while running {
            core.runFrame()

            // Copy framebuffer to back buffer
            let fb = core.framebuffer()
            let pixelCount = core.frameWidth * core.frameHeight
            os_unfair_lock_lock(&bufferLock)
            backBuffer = Array(UnsafeBufferPointer(start: fb, count: pixelCount))
            swap(&frontBuffer, &backBuffer)
            os_unfair_lock_unlock(&bufferLock)

            // Push audio
            let (audioPtr, audioCount) = core.audioSamples()
            audio.push(samples: audioPtr, count: audioCount)

            // Throttle to native FPS
            let now = CACurrentMediaTime()
            let elapsed = now - lastTime
            if elapsed < targetFrameTime {
                Thread.sleep(forTimeInterval: targetFrameTime - elapsed)
            }
            lastTime = CACurrentMediaTime()
        }
    }

    func stop() {
        running = false
        isRunning = false
        core.shutdown()
    }

    func saveState() throws -> Data {
        return try core.saveState()
    }

    func loadState(_ data: Data) throws {
        try core.loadState(data)
    }
}
```

---

## Xcode Build Configuration

### GeolithLib Target (C static library)
- Add Geolith source as a git submodule at `GeolithLib/geolith/`
- Compile all `.c` files with `-std=c11`
- Build for `arm64` only (Apple Silicon)
- Add `GeolithLib/bridge/geolith_bridge.h` to the bridging header

### FBNeoCPSLib Target (C++ static library)
- Add FBNeo source as git submodule at `FBNeoCPSLib/fbneo/`
- Build with `SUBSET=cps12` defined as a preprocessor macro: `SUBSET_CPS12=1`
- Compile C++ files with `-std=c++17`
- Build for `arm64` only
- Expose only `fbneo_cps_bridge.h` (pure C header) to Swift

### Bridging Header (`ArcadeEmulator-Bridging-Header.h`)
```c
// Geolith — C11, import directly
#include "../GeolithLib/bridge/geolith_bridge.h"

// FBNeo CPS — C shim only (pure C header wrapping C++ internals)
#include "../FBNeoCPSLib/bridge/fbneo_cps_bridge.h"
```

### Build Settings
- Deployment target: macOS 14.0
- Swift version: 5.10+
- Enable Hardened Runtime
- Disable App Sandbox if needed (file system access for ROM directories)
- Architectures: `arm64`

---

## Emulator Timing

| System | FPS | Audio Sample Rate | Frame Size |
|---|---|---|---|
| Neo Geo AES/MVS | 59.185 Hz | 55,555 Hz | 320×224 |
| Neo Geo CD | 59.185 Hz | 44,100 Hz | 320×224 |
| CPS-1 | 59.637 Hz | 44,100 Hz | 384×224 |
| CPS-2 | 59.637 Hz | 44,100 Hz | 384×224 |

Use `CVDisplayLink` on the rendering side (macOS display typically 60 Hz). The emulation thread drives at native core FPS independently. The Metal renderer samples the front buffer whenever display sync fires.

---

## UI Views (Slot Design Here)

These views should be implemented as functional shells, ready for the design file's styles and layout to be applied. The design file will be provided separately.

### LibraryView
- Grid of `GameCardView` items
- Filter bar: All / Neo Geo / CPS-1 / CPS-2 / Favorites
- Search field
- Import button (triggers `ROMScanner` + `ConversionQueue`)
- Settings button

### GameCardView
- Box art image (async loaded from `artworkURL`)
- Game title
- System badge (color-coded: Neo Geo = gold, CPS-1 = red, CPS-2 = blue)
- Last played date
- Favorite star toggle
- On double-click → launch `EmulatorWindowView`

### EmulatorWindowView
- Full-window `EmulatorView` (Metal MTKView)
- Overlay HUD (fade out after 2s): pause, save state, load state, settings
- Keyboard shortcut: `Cmd+P` = pause, `Cmd+S` = save state, `Escape` = return to library

### SettingsView
- BIOS Directory (file picker, persisted to UserDefaults)
- ROM Import Directory (file picker)
- Video: Scale mode (integer / fit / stretch), Scanlines toggle, CRT filter toggle
- Audio: Volume, sample rate
- Input: Key binding editor (player 1 & 2)
- Emulation: Show FPS overlay toggle

### OnboardingView
- First-launch flow: set BIOS directory → set ROM directory → import ROMs → done
- Shows conversion progress for Neo Geo MAME zips

---

## BIOS Handling

Both cores require BIOS files that the user must supply legally.

| Core | Required BIOS | Where to place |
|---|---|---|
| Geolith (MVS) | `neogeo.zip` (MAME format) | User-set BIOS directory |
| Geolith (AES) | `aes.zip` (MAME format) | User-set BIOS directory |
| FBNeo CPS-1 | None required | — |
| FBNeo CPS-2 | `qsound.zip` (optional, for Q-Sound games) | User-set BIOS directory |

At first launch, validate BIOS files and show warnings for missing ones.

---

## Save States

- Stored in `~/Library/Application Support/ArcadeEmulator/SaveStates/<game_name>/`
- One slot system (can expand to multiple numbered slots)
- Format: raw binary data from core save state API, wrapped in a small JSON envelope with metadata (timestamp, game name, system, screenshot)
- Screenshots: capture the Metal framebuffer as a PNG thumbnail at save time

```swift
// SaveState.swift
struct SaveState: Codable {
    let id: UUID
    let gameName: String
    let system: EmulatorSystem
    let createdAt: Date
    let dataURL: URL        // raw binary
    let thumbnailURL: URL   // PNG screenshot
}
```

---

## Error Handling

```swift
enum EmulatorError: LocalizedError {
    case romLoadFailed
    case biosNotFound(String)
    case unknownGame(String)
    case unsupportedFormat(String)
    case unsupportedSystem
    case saveStateFailed
    case loadStateFailed

    var errorDescription: String? {
        switch self {
        case .romLoadFailed:            return "Failed to load ROM file."
        case .biosNotFound(let name):   return "BIOS file '\(name)' not found. Please set your BIOS directory in Settings."
        case .unknownGame(let name):    return "'\(name)' is not in the game database."
        case .unsupportedFormat(let e): return ".\(e) files are not supported."
        case .unsupportedSystem:        return "This system is not supported."
        case .saveStateFailed:          return "Save state failed."
        case .loadStateFailed:          return "Load state failed."
        }
    }
}
```

---

## Key Third-Party Dependencies

All dependencies are embedded as git submodules or local source — no Swift Package Manager external dependencies are needed.

| Dependency | Purpose | Source |
|---|---|---|
| Geolith | Neo Geo emulation | `gitlab.com/jgemu/geolith` |
| FBNeo | CPS-1/2 emulation | `github.com/finalburnneo/FBNeo` |
| bodgit/terraonion | Reference impl for .neo conversion | `github.com/bodgit/terraonion` (reference only, not linked) |

---

## Implementation Order (Suggested)

1. **Xcode project scaffold** — create targets, set up bridging headers, confirm both C/C++ libraries compile for arm64
2. **Geolith integration** — load a `.neo` file, get a framebuffer, confirm pixel output
3. **Metal renderer** — display Geolith framebuffer in a window at correct aspect ratio
4. **Audio** — Geolith audio through AVAudioEngine, confirm sound
5. **Input** — keyboard + GameController, confirm playability
6. **FBNeo CPS bridge** — write the C shim, load a CPS-1 zip, confirm output
7. **Core router** — unified `EmulatorCore` protocol, routing by file type + GameDB
8. **EmulatorSession** — threading, double-buffer, timing
9. **ROM library** — scanner, GameDB lookup, Game model, persistence
10. **NEO converter** — in-app MAME zip → .neo conversion
11. **SwiftUI shell** — LibraryView, EmulatorWindowView, SettingsView
12. **Design integration** — apply provided design file to SwiftUI views
13. **Save states** — implement for both cores
14. **Polish** — CRT shader, integer scaling, onboarding, BIOS validation

---

## Notes for Claude Code

- The UI design will be provided as a separate file. When it arrives, map the visual components to the SwiftUI view shells described above.
- Treat the `EmulatorCore` protocol as the hard boundary — UI code never crosses it.
- All emulation-related C/C++ code lives in `GeolithLib/` and `FBNeoCPSLib/` targets only.
- The FBNeo non-commercial license means this app cannot be sold or placed on the Mac App Store without replacing the FBNeo core.
- When in doubt about Geolith's API, read `GeolithLib/geolith/src/geolith.h` directly from source.
- When in doubt about FBNeo's driver system, read `FBNeoCPSLib/fbneo/src/burner/libretro/libretro.cpp` as the reference embedding example.
