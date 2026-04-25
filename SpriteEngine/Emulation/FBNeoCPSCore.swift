import Foundation

final class FBNeoCPSCore: EmulatorCore {

    // FBNeo uses global C state (BurnDrv, s_zips, audio/video buffers, …).
    // This semaphore gates loadROM until the previous shutdown() completes.
    private static let lifecycle = DispatchSemaphore(value: 1)

    let system: EmulatorSystem
    private(set) var frameWidth: Int  = 384
    private(set) var frameHeight: Int = 224
    let nativeFPS: Double = 59.637 // CPS vertical sync frequency

    private let videoPtr: UnsafeMutablePointer<UInt32>
    private let audioPtr: UnsafeMutablePointer<Int16>

    private static let maxVideoPixels = 512 * 256
    private static let maxAudioSamples = 4096 * 2 // stereo interleaved

    private var audioSampleCount: Int = 0

    init(system: EmulatorSystem) {
        self.system = system
        videoPtr = .allocate(capacity: Self.maxVideoPixels)
        audioPtr = .allocate(capacity: Self.maxAudioSamples)
        videoPtr.initialize(repeating: 0, count: Self.maxVideoPixels)
        audioPtr.initialize(repeating: 0, count: Self.maxAudioSamples)
    }

    deinit {
        // shutdown() already calls unload + exit; just free buffers here.
        videoPtr.deallocate()
        audioPtr.deallocate()
    }

    // MARK: - EmulatorCore

    func loadROM(at url: URL, biosDirectory: URL) throws {
        FBNeoCPSCore.lifecycle.wait()
        var releaseOnFailure = true
        defer { if releaseOnFailure { FBNeoCPSCore.lifecycle.signal() } }

        fbneo_cps_init()
        fbneo_cps_set_video_buffer(videoPtr)
        fbneo_cps_set_audio_buffer(audioPtr)

        let result = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else { return -1 }
            return fbneo_cps_load_game(path)
        }
        guard result == 0 else {
            var missingBuf = [CChar](repeating: 0, count: 2048)
            let count = missingBuf.withUnsafeMutableBufferPointer { ptr -> Int32 in
                fbneo_cps_missing_roms(ptr.baseAddress, 2048)
            }
            if count > 0, let missing = String(cString: missingBuf, encoding: .utf8), !missing.isEmpty {
                throw EmulatorError.romFileMissing(missing)
            }
            throw EmulatorError.romLoadFailed
        }

        frameWidth  = Int(fbneo_cps_frame_width())
        frameHeight = Int(fbneo_cps_frame_height())
        audioSampleCount = Int(fbneo_cps_audio_sample_count())
        releaseOnFailure = false
    }

    func runFrame() {
        fbneo_cps_run_frame()
        audioSampleCount = Int(fbneo_cps_audio_sample_count())
    }

    func framebuffer() -> UnsafePointer<UInt32> {
        UnsafePointer(videoPtr)
    }

    func audioSamples() -> (pointer: UnsafePointer<Int16>, count: Int) {
        // FBNeo writes stereo interleaved int16 samples; count is per channel.
        // Multiply by 2 to get total interleaved samples.
        let total = max(0, audioSampleCount) * 2
        return (UnsafePointer(audioPtr), total)
    }

    func setInput(player: Int, buttons: UInt32) {
        fbneo_cps_set_input(Int32(player), buttons)
    }

    func saveState() throws -> Data {
        let size = fbneo_cps_state_size()
        guard size > 0 else { throw EmulatorError.saveStateFailed }
        var buf = [UInt8](repeating: 0, count: size)
        let result = buf.withUnsafeMutableBytes { ptr -> Int32 in
            fbneo_cps_state_save(ptr.baseAddress!, size)
        }
        guard result == 1 else { throw EmulatorError.saveStateFailed }
        return Data(buf)
    }

    func loadState(_ data: Data) throws {
        let result = data.withUnsafeBytes { ptr -> Int32 in
            fbneo_cps_state_load(ptr.baseAddress!, data.count)
        }
        guard result == 1 else { throw EmulatorError.loadStateFailed }
    }

    func reset() {
        fbneo_cps_reset()
    }

    func shutdown() {
        fbneo_cps_unload_game()
        fbneo_cps_exit()
        FBNeoCPSCore.lifecycle.signal()
    }
}
