import Foundation

/// Generic FBNeo core — handles any driver family other than CPS (which keeps
/// its own FBNeoCPSCore for historical compatibility).
/// Uses fbneo_driver_bridge rather than fbneo_cps_bridge.
final class FBNeoCore: EmulatorCore {

    private static let lifecycle = DispatchSemaphore(value: 1)

    let system: EmulatorSystem
    private(set) var frameWidth:  Int = 320
    private(set) var frameHeight: Int = 224
    private(set) var isVertical:  Bool = false
    let nativeFPS: Double = 59.637

    private let videoPtr: UnsafeMutablePointer<UInt32>
    private let audioPtr: UnsafeMutablePointer<Int16>

    private static let maxVideoPixels  = 512 * 256
    private static let maxAudioSamples = 4096 * 2

    private var audioSampleCount: Int = 0

    init(system: EmulatorSystem) {
        self.system = system
        videoPtr = .allocate(capacity: Self.maxVideoPixels)
        audioPtr = .allocate(capacity: Self.maxAudioSamples)
        videoPtr.initialize(repeating: 0, count: Self.maxVideoPixels)
        audioPtr.initialize(repeating: 0, count: Self.maxAudioSamples)
    }

    deinit {
        videoPtr.deallocate()
        audioPtr.deallocate()
    }

    // MARK: - EmulatorCore

    func loadROM(at url: URL, biosDirectory: URL) throws {
        FBNeoCore.lifecycle.wait()
        var releaseOnFailure = true
        defer { if releaseOnFailure { FBNeoCore.lifecycle.signal() } }

        fbneo_driver_set_video_buffer(videoPtr)
        fbneo_driver_set_audio_buffer(audioPtr)

        let result = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return fbneo_driver_load(path)
        }
        guard result == 0 else {
            var buf = [CChar](repeating: 0, count: 2048)
            let count = buf.withUnsafeMutableBufferPointer { ptr -> Int32 in
                fbneo_driver_missing_roms(ptr.baseAddress, 2048)
            }
            if count > 0, let missing = String(cString: buf, encoding: .utf8), !missing.isEmpty {
                throw EmulatorError.romFileMissing(missing)
            }
            throw EmulatorError.romLoadFailed
        }

        frameWidth       = Int(fbneo_driver_frame_width())
        frameHeight      = Int(fbneo_driver_frame_height())
        isVertical       = fbneo_driver_is_vertical() == 1
        audioSampleCount = Int(fbneo_driver_audio_sample_count())
        releaseOnFailure = false
    }

    func runFrame() {
        fbneo_driver_run_frame()
        audioSampleCount = Int(fbneo_driver_audio_sample_count())
    }

    func framebuffer() -> UnsafePointer<UInt32> {
        UnsafePointer(videoPtr)
    }

    func audioSamples() -> (pointer: UnsafePointer<Int16>, count: Int) {
        let total = max(0, audioSampleCount) * 2
        return (UnsafePointer(audioPtr), total)
    }

    func setInput(player: Int, buttons: UInt32) {
        fbneo_driver_set_input(Int32(player), buttons)
    }

    func saveState() throws -> Data {
        let size = fbneo_driver_state_size()
        guard size > 0 else { throw EmulatorError.saveStateFailed }
        var buf = [UInt8](repeating: 0, count: size)
        let result = buf.withUnsafeMutableBytes { ptr -> Int32 in
            fbneo_driver_state_save(ptr.baseAddress!, size)
        }
        guard result == 1 else { throw EmulatorError.saveStateFailed }
        return Data(buf)
    }

    func loadState(_ data: Data) throws {
        let result = data.withUnsafeBytes { ptr -> Int32 in
            fbneo_driver_state_load(ptr.baseAddress!, data.count)
        }
        guard result == 1 else { throw EmulatorError.loadStateFailed }
    }

    func reset() {
        fbneo_driver_reset()
    }

    func shutdown() {
        fbneo_driver_unload()
        FBNeoCore.lifecycle.signal()
    }
}
