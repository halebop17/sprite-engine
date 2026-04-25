import Foundation

final class GeolithCore: EmulatorCore {

    // Geolith uses global C state (mrom, romdata, resampler, …).
    // This semaphore ensures shutdown() of one instance completes before
    // loadROM() of the next touches that state.  Starts at 1 (available).
    private static let lifecycle = DispatchSemaphore(value: 1)

    // MARK: - EmulatorCore

    let system: EmulatorSystem
    let frameWidth: Int  = Int(GEO_FRAME_WIDTH)
    let frameHeight: Int = Int(GEO_FRAME_HEIGHT)

    var nativeFPS: Double {
        switch system {
        case .neoGeoAES: return 59.599484
        default:         return 59.185606
        }
    }

    // MARK: - Heap-allocated buffers (stable pointers passed to C)

    // Max stereo int16 samples per frame: 44100 / ~59 fps ≈ 747 frames * 2 channels = 1494
    private static let audioBufCapacity = 4096
    private static let videoBufCapacity = Int(GEO_FRAME_WIDTH) * Int(GEO_FRAME_HEIGHT)

    private let videoPtr: UnsafeMutablePointer<UInt32>
    private let audioPtr: UnsafeMutablePointer<Int16>
    private let audioRate: Int = 44100

    private var initialized = false
    private var neoROMData: Data?  // kept alive because Geolith holds raw pointers into it

    // MARK: - Init / deinit

    init(system: EmulatorSystem) {
        self.system = system
        videoPtr = UnsafeMutablePointer<UInt32>.allocate(capacity: Self.videoBufCapacity)
        videoPtr.initialize(repeating: 0, count: Self.videoBufCapacity)
        audioPtr = UnsafeMutablePointer<Int16>.allocate(capacity: Self.audioBufCapacity)
        audioPtr.initialize(repeating: 0, count: Self.audioBufCapacity)
    }

    deinit {
        if initialized { shutdown() }
        videoPtr.deallocate()
        audioPtr.deallocate()
    }

    // MARK: - EmulatorCore methods

    func loadROM(at url: URL, biosDirectory: URL) throws {
        // Wait for any previous GeolithCore instance to finish its shutdown()
        // before we touch the global Geolith C state.
        GeolithCore.lifecycle.wait()
        var releaseOnFailure = true
        defer { if releaseOnFailure { GeolithCore.lifecycle.signal() } }

        let geoSystem: Int32
        switch system {
        case .neoGeoAES: geoSystem = Int32(GEO_SYSTEM_AES)
        case .neoGeoMVS: geoSystem = Int32(GEO_SYSTEM_MVS)
        default:         geoSystem = Int32(GEO_SYSTEM_MVS)
        }
        geo_bridge_set_system(geoSystem, Int32(GEO_REGION_US))

        let preferredBios = geoSystem == Int32(GEO_SYSTEM_AES) ? "aes.zip" : "neogeo.zip"
        let fallbackBios  = geoSystem == Int32(GEO_SYSTEM_AES) ? "neogeo.zip" : "aes.zip"
        let biosLoaded = [preferredBios, fallbackBios].contains { name in
            geo_bridge_load_bios(biosDirectory.appendingPathComponent(name).path) == 1
        }
        guard biosLoaded else {
            throw EmulatorError.biosNotFound("\(preferredBios) / \(fallbackBios)")
        }

        geo_bridge_set_video_buffer(videoPtr)
        geo_bridge_set_audio_buffer(audioPtr, audioRate)
        geo_bridge_init()

        let romData = try Data(contentsOf: url)
        neoROMData = romData  // must outlive this session; Geolith holds raw pointers into it
        let loadResult = romData.withUnsafeBytes { ptr -> Int32 in
            geo_bridge_load_neo(ptr.baseAddress!, romData.count)
        }
        guard loadResult == 1 else {
            neoROMData = nil
            geo_bridge_deinit()
            throw EmulatorError.romLoadFailed
        }

        geo_bridge_reset(1)
        initialized = true
        releaseOnFailure = false  // success — lifecycle.signal() will be called in shutdown()
    }

    func runFrame() {
        geo_bridge_exec()
    }

    func framebuffer() -> UnsafePointer<UInt32> {
        UnsafePointer(videoPtr)
    }

    func audioSamples() -> (pointer: UnsafePointer<Int16>, count: Int) {
        let count = Int(geo_bridge_audio_sample_count())
        return (UnsafePointer(audioPtr), count)
    }

    func setInput(player: Int, buttons: UInt32) {
        geo_bridge_set_input(UInt32(player), buttons)
    }

    func setSysInput(_ buttons: UInt32) {
        geo_bridge_set_sys_input(buttons)
    }

    func saveState() throws -> Data {
        guard initialized else { throw EmulatorError.saveStateFailed }
        guard let ptr = geo_bridge_state_save() else { throw EmulatorError.saveStateFailed }
        return Data(bytes: ptr, count: Int(geo_bridge_state_size()))
    }

    func loadState(_ data: Data) throws {
        guard initialized else { throw EmulatorError.loadStateFailed }
        let result = data.withUnsafeBytes { ptr -> Int32 in
            geo_bridge_state_load(ptr.baseAddress!)
        }
        guard result == 1 else { throw EmulatorError.loadStateFailed }
    }

    func reset() {
        geo_bridge_reset(0)
    }

    func shutdown() {
        guard initialized else { return }
        geo_bridge_deinit()
        neoROMData = nil
        initialized = false
        GeolithCore.lifecycle.signal()  // allow the next loadROM() to proceed
    }
}
