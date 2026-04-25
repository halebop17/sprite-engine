# Sprite Engine — Architecture

## Overview

Sprite Engine is a macOS arcade emulator built in Swift/SwiftUI with Metal rendering. It hosts multiple emulation cores behind a common Swift protocol, routes ROMs to the right core by identifying the hardware platform, and presents a single-window SwiftUI UI driven by a central `AppState` navigator.

The app is **not sandboxed** (`com.apple.security.app-sandbox = false`), so it has direct filesystem access to ROM and BIOS directories chosen by the user.

---

## Layer Diagram

```
┌─────────────────────────────────────────────────────────┐
│  SwiftUI UI Layer                                        │
│  ContentView · LibraryView · DetailView · SettingsView  │
│  OnboardingView · EmulatorWindowView · ROMVerifierView  │
└────────────────────────┬────────────────────────────────┘
                         │ @EnvironmentObject AppState
┌────────────────────────▼────────────────────────────────┐
│  App Layer                                               │
│  AppState (ObservableObject, @MainActor)                 │
│  Screen enum — navigation state machine                  │
└──────┬────────────────────────────────────┬─────────────┘
       │                                    │
┌──────▼───────────┐             ┌──────────▼─────────────┐
│  Library Layer   │             │  Emulation Layer        │
│  ROMLibrary      │             │  EmulatorSession        │
│  ROMScanner      │             │  EmulatorCore (protocol)│
│  ROMVerifier     │             │  CoreRouter             │
│  GameDatabase    │             │  GeolithCore            │
│  SaveStateManager│             │  FBNeoCPSCore           │
│  GameMediaStore  │             │  FBNeoCore              │
│  NeoConverter    │             └──────┬──────────────────┘
│  ConversionQueue │                    │
└──────────────────┘             ┌──────▼──────────────────┐
                                 │  Native Bridge Layer     │
                                 │  geolith_bridge.c/h      │
                                 │  fbneo_cps_bridge.cpp/h  │
                                 │  fbneo_driver_bridge.cpp/h│
                                 └──────┬──────────────────┘
                                        │
                                 ┌──────▼──────────────────┐
                                 │  Native Cores (vendor)   │
                                 │  Geolith (Neo Geo)       │
                                 │  FBNeo (CPS-1/2, Sega,   │
                                 │         Toaplan, etc.)   │
                                 └─────────────────────────┘
```

---

## Key Architectural Decisions

### 1. Single `EmulatorCore` protocol

All cores conform to one protocol. `EmulatorSession` drives any core through that protocol, so the rendering, audio, input, and save-state path is written once.

### 2. `CoreRouter` — ROM → core selection

Routing is a two-pass lookup:

1. **Static `GameDB.json`** — a bundled JSON map of known zip stems to system strings. Fast, no native calls.
2. **Live FBNeo driver scan** — `fbneo_driver_identify()` walks the compiled FBNeo driver list. Used for ROMs not in `GameDB.json` or during scanning.

`ROMScanner` uses the same two-pass strategy when building the library.

### 3. BurnLibInit is called exactly once

`BurnLibInit()` internally calls `BurnLibExit()`, which frees per-driver heap strings. Calling it a second time corrupts the driver list. The single process-wide guard lives in `fbneo_driver_bridge.cpp` (`fbneo_driver_lib_init()`). The CPS bridge and the generic driver bridge both delegate to it — they never call `BurnLibInit()` directly.

### 4. Global C state guarded by `DispatchSemaphore`

Both `GeolithCore` and `FBNeoCPSCore` hold a `static let lifecycle = DispatchSemaphore(value: 1)`. `loadROM()` waits on it; `shutdown()` signals it. This prevents a race where a new session's `loadROM()` touches global C state before the previous session's `shutdown()` has finished.

### 5. Neo Geo ROM format conversion

Geolith consumes a custom `.neo` binary format rather than MAME zip sets. `NeoConverter` runs an offline conversion (unzip → collect ROM parts by extension → interleave C ROMs → write 4 KiB header + blobs). Converted files are stored in `~/Library/Application Support/SpriteEngine/Converted/`.

### 6. Audio pipeline

The emulation thread pushes stereo interleaved `Int16` samples into `AudioEngine`, which deinterleaves them into two `RingBuffer<Float>` (one per channel). An `AVAudioSourceNode` callback pulls from those ring buffers on the audio thread. The ring buffer is lock-protected with `os_unfair_lock`. This avoids any allocation on the real-time audio path.

### 7. Metal rendering — three shader pipelines

`MetalRenderer` compiles three `MTLRenderPipelineState` objects at init time: `sharp` (nearest-neighbour), `smooth` (bilinear), and `crt` (scanline + barrel distortion). The active pipeline is switched per frame with no recompile. Three scale modes — `aspectFit`, `integer`, `stretch` — are calculated in `viewport()` from the game's natural display dimensions.

### 8. Framebuffer double-buffering

`EmulatorSession` holds a `frontBuffer` and `backBuffer` (`[UInt32]`). The emulation thread writes into `backBuffer`, then swaps under an `os_unfair_lock`. The render callback reads from `frontBuffer` under the same lock. This avoids tearing without blocking the emulation thread for more than a pointer swap.

### 9. `AppState` is the sole navigation state machine

The `Screen` enum covers every view in the app. `ContentView` switches on it; no view pushes navigation itself. This makes the full nav graph inspectable from one place and avoids SwiftUI coordinator / navigation-stack complexity.

### 10. UserDefaults layout

| Key | Type | Notes |
|-----|------|-------|
| `biosDirectoryPath` | String (path) | Single BIOS directory |
| `romDirectoryPaths` | Data (JSON `[String]`) | Multiple ROM dirs; migrated from legacy `romDirectoryPath` |
| `hasCompletedOnboarding` | Bool | |
| `themeKey` | String | `AppThemeKey.rawValue` |
| `videoScaleMode` | String | `VideoScaleMode.rawValue` |
| `videoScanlines` | Bool | |
| `videoCRTFilter` | Bool | |
| `audioVolume` | Float | |
| `showFPSOverlay` | Bool | |

---

## Module Reference

### `Models/`

#### `EmulatorSystem` — `System.swift`
```swift
enum EmulatorSystem: String, Codable, CaseIterable {
    case neoGeoAES, neoGeoMVS, neoGeoCD
    case cps1, cps2
    case segaSys16, segaSys18
    case toaplan1, toaplan2
    case konamiGX, irem, taito

    var coreType: CoreType   // .geolith | .fbneopCPS | .fbneo
    var displayName: String
}

enum CoreType { case geolith, fbneopCPS, fbneo }
```

#### `Game` — `Game.swift`
```swift
struct Game: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let system: EmulatorSystem
    let romURL: URL
    let artworkURL: URL?
    var lastPlayed: Date?
    var isFavorite: Bool
    var saveStates: [SaveState]
}
```

#### `SaveState` — `SaveState.swift`
```swift
struct SaveState: Identifiable, Codable, Equatable {
    let id: UUID
    let gameName: String
    let system: EmulatorSystem
    let createdAt: Date
    let dataURL: URL
    let thumbnailURL: URL
}
```

#### `GameMediaItem` — `GameMediaItem.swift`
```swift
enum GameMediaKind: String, Codable { case image, pdf }

struct GameMediaItem: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: GameMediaKind
    var label: String
    let filename: String
    let addedAt: Date
}
```

---

### `App/`

#### `AppState` — `AppState.swift`
```swift
@MainActor final class AppState: ObservableObject {
    @Published var screen: Screen
    @Published var hasCompletedOnboarding: Bool
    @Published var biosDirectoryURL: URL?
    @Published var romDirectoryURLs: [URL]
    @Published var themeKey: AppThemeKey
    @Published var videoScaleMode: VideoScaleMode
    @Published var videoScanlines: Bool
    @Published var videoCRTFilter: Bool
    @Published var audioVolume: Float
    @Published var showFPSOverlay: Bool

    func navigate(to screen: Screen)
    func navigateBack()
    func completeOnboarding()
    func setBIOSDirectory(_ url: URL)
    func addROMDirectory(_ url: URL)
    func removeROMDirectory(_ url: URL)
    func setTheme(_ key: AppThemeKey)
    func setVideoScaleMode(_ mode: VideoScaleMode)
    func setVideoScanlines(_ on: Bool)
    func setVideoCRTFilter(_ on: Bool)
    func setAudioVolume(_ v: Float)
    func setShowFPSOverlay(_ on: Bool)

    var isBIOSPresent: Bool  // checks for neogeo.zip / aes.zip / qsound.zip
}

enum Screen: Equatable {
    case onboarding, library, import, settings, romVerifier
    case detail(Game)
    case emulator(Game)
}
```

---

### `Library/`

#### `ROMLibrary` — `ROMLibrary.swift`
```swift
@MainActor final class ROMLibrary: ObservableObject {
    static let shared: ROMLibrary
    @Published private(set) var games: [Game]

    func scan(directory: URL) async
    func scan(directories: [URL]) async
    func setFavorite(_ game: Game, _ value: Bool)
    func recordPlayed(_ game: Game)
    func remove(_ game: Game)
    func removeGames(inDirectory directory: URL)
    func pruneToDirectories(_ directories: [URL])  // trailing-slash-normalised path matching
    func addSaveState(_ state: SaveState, to game: Game)
    func removeSaveState(_ state: SaveState, from game: Game)
}
// Persistence: ~/Library/Application Support/SpriteEngine/library.json
```

#### `ROMScanner` — `ROMScanner.swift`
```swift
final class ROMScanner {
    func scan(directory: URL) async -> [Game]
    // Supported extensions: .neo, .zip, .chd, .cue
    // Identification: GameDatabase.shared first, fbneo_driver_identify() fallback
}
```

#### `GameDatabase` — `GameDatabase.swift`
```swift
final class GameDatabase {
    static let shared: GameDatabase
    subscript(name: String) -> EmulatorSystem?  // lookup by lowercase zip stem
    func isNeoGeoMVS(_ name: String) -> Bool
}
// Source: GameDB.json bundled resource (~100 known titles)
```

#### `ROMVerifier` — `ROMVerifier.swift`
```swift
final class ROMVerifier {
    static let shared: ROMVerifier

    func verify(
        games: [Game],
        onProgress: @escaping (Int, Int) -> Void,
        completion: @escaping ([GameVerificationResult]) -> Void
    )
    // Currently verifies CPS-1/2 games via fbneo_cps_verify_game()
}

struct GameVerificationResult: Identifiable {
    let game: Game
    let status: GameVerificationStatus  // .ok | .issues(missing:wrongCRC:) | .unknownGame
    let files: [ROMFileResult]
}

struct ROMFileResult: Identifiable {
    let name: String
    let status: ROMFileStatus  // .ok | .missing | .wrongCRC(expected:actual:) | .optional
}
```

#### `SaveStateManager` — `SaveStateManager.swift`
```swift
enum SaveStateManager {
    static func save(
        game: Game,
        session: EmulatorSession,
        thumbnailPixels: [UInt32],
        thumbnailWidth: Int,
        thumbnailHeight: Int
    ) throws -> SaveState

    static func load(_ saveState: SaveState, into session: EmulatorSession) throws
    static func delete(_ saveState: SaveState)
    static func thumbnail(for saveState: SaveState) -> NSImage?
}
// Storage: ~/Library/Application Support/SpriteEngine/SaveStates/<gameID>/<stateID>.state
//          ~/Library/Application Support/SpriteEngine/SaveStates/<gameID>/<stateID>.png
```

#### `GameMediaStore` — `GameMediaStore.swift`
```swift
enum GameMediaStore {
    static func mediaDirectory(for gameID: UUID) -> URL
    static func load(for gameID: UUID) -> [GameMediaItem]
    static func save(_ items: [GameMediaItem], for gameID: UUID)
    static func addItem(sourceURL: URL, kind: GameMediaKind, label: String, gameID: UUID) -> GameMediaItem?
    static func delete(_ item: GameMediaItem, gameID: UUID)
    static func url(for item: GameMediaItem, gameID: UUID) -> URL
    static func image(for item: GameMediaItem, gameID: UUID) -> NSImage?
    static func fileSize(for item: GameMediaItem, gameID: UUID) -> String
}
// Storage: ~/Library/Application Support/SpriteEngine/Media/<gameID>/index.json
```

---

### `Conversion/`

#### `NeoConverter` — `NeoConverter.swift`
```swift
struct NeoConverter {
    static var outputDirectory: URL  // ~/Library/Application Support/SpriteEngine/Converted/

    func convert(zipURL: URL, progress: ((Double) -> Void)? = nil) async throws -> URL
    // Steps: unzip (primary + siblings) → collect by extension → interleave C ROMs
    //        → write 4 KiB .neo header → append P, S, M1, V, C blobs
}
```

C ROM interleaving: pairs `(c1,c2)`, `(c3,c4)`, … are interleaved byte-by-byte: `c1[0], c2[0], c1[1], c2[1], …`

#### `ConversionQueue` — `ConversionQueue.swift`
```swift
@MainActor final class ConversionQueue: ObservableObject {
    @Published private(set) var items: [ConversionItem]
    @Published private(set) var isRunning: Bool

    func enqueue(_ urls: [URL])
    func clearFinished()
}

enum ConversionState { case pending, converting(progress: Double), done(outputURL: URL), failed(error: Error) }
```

---

### `Emulation/`

#### `EmulatorCore` protocol — `EmulatorCore.swift`
```swift
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
    func setSysInput(_ buttons: UInt32)  // default no-op; meaningful for arcade cores
}
```

#### `CoreRouter` — `CoreRouter.swift`
```swift
final class CoreRouter {
    func core(for url: URL) throws -> any EmulatorCore
    // .neo → GeolithCore(.neoGeoAES)
    // .chd/.cue → GeolithCore(.neoGeoCD)
    // .zip → GameDatabase lookup → fbneo_driver_identify() fallback
}
```

#### `EmulatorSession` — `EmulatorSession.swift`
```swift
final class EmulatorSession: ObservableObject {
    @Published var isRunning: Bool
    @Published var isPaused: Bool
    @Published var measuredFPS: Double

    var onFrameReady: (() -> Void)?
    var volume: Float

    init(core: any EmulatorCore)

    func start()
    func stop()
    func pause()
    func resume()
    func togglePause()
    func withFrontBuffer(_ body: (UnsafePointer<UInt32>, Int, Int) -> Void)
    func setInput(player: Int, buttons: UInt32)
    func setSysInput(_ buttons: UInt32)
    func saveState() throws -> Data
    func loadState(_ data: Data) throws
}
// Emulation loop runs on a dedicated thread (QoS: .userInteractive).
// Frame timing: CACurrentMediaTime()-based, with single-frame catch-up limit.
// Double-buffered framebuffer; swap under os_unfair_lock.
```

#### `GeolithCore` — `GeolithCore.swift`
```swift
final class GeolithCore: EmulatorCore {
    // frameWidth  = GEO_FRAME_WIDTH  (320)
    // frameHeight = GEO_FRAME_HEIGHT (256)
    // nativeFPS   = 59.185606 (MVS) | 59.599484 (AES)
    // Audio: 44100 Hz stereo, max 4096 samples/frame buffer

    // Lifecycle guard: static DispatchSemaphore(value: 1)
    //   wait() in loadROM(), signal() in shutdown()
    //   prevents concurrent access to global Geolith C state
}
```

BIOS loading order:
1. `geo_bridge_set_system(system, region)`
2. `geo_bridge_load_bios(preferredBios)` — falls back to `geo_bridge_load_bios(fallbackBios)`
3. `geo_bridge_set_video_buffer(videoPtr)`
4. `geo_bridge_set_audio_buffer(audioPtr, rate)`
5. `geo_bridge_init()`
6. `geo_bridge_load_neo(data, size)` — Geolith holds raw pointers into `neoROMData: Data`
7. `geo_bridge_reset(1)`

#### `FBNeoCPSCore` — `FBNeoCPSCore.swift`
```swift
final class FBNeoCPSCore: EmulatorCore {
    // frameWidth/Height: queried from bridge after load (default 384×224)
    // nativeFPS = 59.637
    // Audio: 44100 Hz, stereo interleaved Int16, sample count × 2

    // Lifecycle guard: static DispatchSemaphore(value: 1)
}
```

#### `FBNeoCore` — `FBNeoCore.swift`
```swift
final class FBNeoCore: EmulatorCore {
    // Generic bridge for Sega Sys16/18, Toaplan 1/2, Konami GX, Irem, Taito
    // frameWidth/Height: queried after load (default 320×224)
    // isVertical: true for rotated cabinets
    // Save state not yet implemented

    // Lifecycle guard: static DispatchSemaphore(value: 1)
}
```

---

### `Audio/`

#### `AudioEngine` — `AudioEngine.swift`
```swift
final class AudioEngine {
    static let emulatorSampleRate: Double = 44100.0

    func push(samples: UnsafePointer<Int16>, count: Int)
    // count = total interleaved values; frames = count/2
    // Deinterleaves to two RingBuffer<Float> (8192 capacity each)
    // Called from the emulation thread

    var volume: Float  // 0.0–1.0, forwarded to AVAudioEngine.mainMixerNode
    func stop()
}
```

#### `RingBuffer<T>` — `RingBuffer.swift`
```swift
final class RingBuffer<T: ExpressibleByIntegerLiteral> {
    init(capacity: Int)
    var availableToRead: Int
    func write(_ ptr: UnsafePointer<T>, count: Int)  // silently drops overflow
    func read(_ ptr: UnsafeMutablePointer<T>, count: Int)  // pads with 0 on underrun
}
// Thread-safe via os_unfair_lock
```

---

### `Input/`

#### `InputManager` — `InputManager.swift`
```swift
final class InputManager {
    struct Buttons: OptionSet {
        // up, down, left, right, select, start, a, b, c, d
    }

    var onInputChanged: ((Int, UInt32) -> Void)?    // (player, bitmask)
    var onSysInputChanged: ((UInt32) -> Void)?       // coin/service bitmask

    func keyDown(keyCode: UInt16)
    func keyUp(keyCode: UInt16)
    func startControllerDiscovery()  // MFi / Xbox / DualSense via GCController
}
```

Keyboard layout:
- P1 movement: WASD or arrow keys
- P1 buttons: U=A, I=B, J=C, K=D, Return=Start, Space=Select
- System: C=Coin1

---

### `Rendering/`

#### `MetalRenderer` — `MetalRenderer.swift`
```swift
final class MetalRenderer: NSObject, MTKViewDelegate {
    var scaleMode: VideoScaleMode   // .aspectFit | .integer | .stretch
    var filterMode: FilterMode      // .sharp | .smooth | .crt

    func updateTexture(pixels: UnsafePointer<UInt32>,
                       width: Int, height: Int,
                       displayWidth: Int, displayHeight: Int)
    // Pipelines: vertex_passthrough + fragment_{sharp,smooth,crt}
    // Texture format: .bgra8Unorm
}

enum VideoScaleMode: String, CaseIterable { case aspectFit, stretch, integer }
enum FilterMode { case sharp, smooth, crt }
```

Integer scale mode: largest N such that `N × displayWidth ≤ drawableWidth` and `N × displayHeight ≤ drawableHeight`.

#### `EmulatorView` — `EmulatorView.swift`
```swift
final class EmulatorView: MTKView {
    private(set) var renderer: MetalRenderer?
    weak var inputManager: InputManager?

    func update(pixels: UnsafePointer<UInt32>,
                width: Int, height: Int,
                displayWidth: Int = 320,
                displayHeight: Int = 224)
}

struct EmulatorViewRepresentable: NSViewRepresentable {
    let emulatorView: EmulatorView
}
// MTKView is driven externally (isPaused = true, enableSetNeedsDisplay = true).
// setNeedsDisplay() is called by EmulatorSession.onFrameReady.
```

---

### Native Bridge Layer

#### `geolith_bridge.h` — Geolith C bridge
```c
// Constants
#define GEO_FRAME_WIDTH   320
#define GEO_FRAME_HEIGHT  256
#define GEO_VISIBLE_WIDTH  320
#define GEO_VISIBLE_HEIGHT 224
#define GEO_SYSTEM_AES 0 / GEO_SYSTEM_MVS 1
#define GEO_REGION_US  0 / GEO_REGION_JP  1

// Button bits: GEO_BTN_UP(0)..GEO_BTN_D(9)
// System bits: GEO_SYS_COIN1(0), GEO_SYS_COIN2(1), GEO_SYS_SERVICE(2), GEO_SYS_TEST(3)

void geo_bridge_set_system(int system, int region);
int  geo_bridge_load_bios(const char *path);     // 1 = success
int  geo_bridge_load_neo(const void *data, size_t size);  // 1 = success
void geo_bridge_init(void);
void geo_bridge_deinit(void);
void geo_bridge_set_video_buffer(uint32_t *buf);
void geo_bridge_set_audio_buffer(int16_t *buf, size_t rate);
size_t geo_bridge_audio_sample_count(void);
void geo_bridge_set_input(unsigned player, uint32_t buttons);
void geo_bridge_set_sys_input(uint32_t buttons);
void geo_bridge_exec(void);
void geo_bridge_reset(int hard);                  // hard=1 cold reset
const void *geo_bridge_state_save(void);
size_t      geo_bridge_state_size(void);
int         geo_bridge_state_load(const void *data);  // 1 = success
```

#### `fbneo_driver_bridge.h` — Generic FBNeo bridge
```c
// System ID constants: FBNEO_SYSTEM_UNKNOWN(0)..FBNEO_SYSTEM_TAITO(10)
// ROM status constants: FBNEO_ROM_OK(0), MISSING(1), WRONG_CRC(2), OPTIONAL(3)
// Button bits: FBNEO_BTN_UP..FBNEO_BTN_Y (12 buttons)

void fbneo_driver_lib_init(void);           // idempotent; owns single BurnLibInit() call
int  fbneo_driver_identify(const char* name); // returns FBNEO_SYSTEM_* constant
int  fbneo_driver_load(const char* zipPath);  // 0 = success
void fbneo_driver_unload(void);
int  fbneo_driver_is_loaded(void);
int  fbneo_driver_frame_width(void);
int  fbneo_driver_frame_height(void);
int  fbneo_driver_is_vertical(void);
void fbneo_driver_set_video_buffer(uint32_t* buf);
void fbneo_driver_set_audio_buffer(int16_t* buf);
int  fbneo_driver_audio_sample_count(void);
void fbneo_driver_set_input(int player, uint32_t buttons);
void fbneo_driver_run_frame(void);
void fbneo_driver_reset(void);
int  fbneo_driver_missing_roms(char* buf, size_t bufSize);
int  fbneo_driver_verify_game(const char* zipPath, FBNeoRomFile* outFiles, int maxFiles);
```

#### `fbneo_cps_bridge.h` — Dedicated CPS-1/2 bridge
```c
int  fbneo_cps_init(void);                  // delegates to fbneo_driver_lib_init()
void fbneo_cps_exit(void);
int  fbneo_cps_load_game(const char* zipPath);   // 0 = success
void fbneo_cps_unload_game(void);
int  fbneo_cps_is_loaded(void);
int  fbneo_cps_frame_width(void);
int  fbneo_cps_frame_height(void);
void fbneo_cps_set_video_buffer(uint32_t* buf);
void fbneo_cps_set_audio_buffer(int16_t* buf);
int  fbneo_cps_audio_sample_count(void);
int  fbneo_cps_audio_sample_rate(void);         // always 44100
void fbneo_cps_set_input(int player, uint32_t buttons);
void fbneo_cps_run_frame(void);
void fbneo_cps_reset(void);
size_t fbneo_cps_state_size(void);
int    fbneo_cps_state_save(void* buf, size_t bufSize);  // 1 = success
int    fbneo_cps_state_load(const void* buf, size_t bufSize);
int    fbneo_cps_driver_type(const char* name);          // 1=CPS1, 2=CPS2, 0=unknown
int    fbneo_cps_missing_roms(char* buf, size_t bufSize);
int    fbneo_cps_verify_game(const char* zipPath, FBNeoRomFile* outFiles, int maxFiles);
```

---

## Filesystem Layout

```
~/Library/Application Support/SpriteEngine/
├── library.json                   # ROMLibrary persistence ([Game] encoded)
├── Converted/                     # NeoConverter output (.neo files)
│   └── <stem>.neo
├── SaveStates/
│   └── <gameID>/
│       ├── <stateID>.state        # raw emulator state blob
│       └── <stateID>.png          # thumbnail captured from framebuffer
└── Media/
    └── <gameID>/
        ├── index.json             # [GameMediaItem] encoded
        └── <uuid>.<ext>           # image or PDF files
```

---

## Supported Systems

| System | Core | BIOS required | ROM format |
|--------|------|---------------|------------|
| Neo Geo AES | Geolith | `aes.zip` (fallback: `neogeo.zip`) | `.neo` (converted from MAME zip) |
| Neo Geo MVS | Geolith | `neogeo.zip` (fallback: `aes.zip`) | `.neo` |
| Neo Geo CD | Geolith | — | `.chd` / `.cue` |
| CPS-1 | FBNeoCPS | — | `.zip` (MAME set) |
| CPS-2 | FBNeoCPS | — | `.zip` |
| Sega System 16/18 | FBNeo | — | `.zip` |
| Toaplan 1/2 | FBNeo | — | `.zip` |
| Konami GX | FBNeo | — | `.zip` |
| Irem | FBNeo | — | `.zip` |
| Taito | FBNeo | — | `.zip` |
