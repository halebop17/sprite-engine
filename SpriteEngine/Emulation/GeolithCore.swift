import Foundation

final class GeolithCore: EmulatorCore {

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
        let geoSystem: Int32
        switch system {
        case .neoGeoAES: geoSystem = Int32(GEO_SYSTEM_AES)
        case .neoGeoMVS: geoSystem = Int32(GEO_SYSTEM_MVS)
        default:         geoSystem = Int32(GEO_SYSTEM_MVS)
        }
        geo_bridge_set_system(geoSystem, Int32(GEO_REGION_US))

        let biosName = geoSystem == Int32(GEO_SYSTEM_AES) ? "aes.zip" : "neogeo.zip"
        let biosURL = biosDirectory.appendingPathComponent(biosName)
        guard geo_bridge_load_bios(biosURL.path) == 1 else {
            throw EmulatorError.biosNotFound(biosName)
        }

        let romData = try Data(contentsOf: url)
        let loadResult = romData.withUnsafeBytes { ptr -> Int32 in
            geo_bridge_load_neo(ptr.baseAddress!, romData.count)
        }
        guard loadResult == 1 else {
            throw EmulatorError.romLoadFailed
        }

        geo_bridge_set_video_buffer(videoPtr)
        geo_bridge_set_audio_buffer(audioPtr, audioRate)

        geo_bridge_init()
        geo_bridge_reset(1)
        initialized = true
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
        initialized = false
    }
}
