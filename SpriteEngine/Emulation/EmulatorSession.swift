import Foundation
import QuartzCore
import os.lock

final class EmulatorSession: ObservableObject {

    private let core:  any EmulatorCore
    private let audio: AudioEngine
    private var emulationThread: Thread?
    private var running = false

    // Double-buffer: emulation writes to backBuffer, main thread reads frontBuffer.
    // Both are sized to frameWidth * frameHeight on start().
    private var frontBuffer: [UInt32] = []
    private var backBuffer:  [UInt32] = []
    private var bufferLock = os_unfair_lock_s()

    @Published var isRunning: Bool = false

    // Fired on the main thread after every frame swap.
    // Caller should read the front buffer inside this callback via withFrontBuffer(_:).
    var onFrameReady: (() -> Void)?

    init(core: any EmulatorCore) {
        self.core  = core
        self.audio = AudioEngine()
    }

    // MARK: - Lifecycle

    func start() {
        let count = core.frameWidth * core.frameHeight
        frontBuffer = [UInt32](repeating: 0, count: count)
        backBuffer  = frontBuffer
        running = true
        DispatchQueue.main.async { self.isRunning = true }

        let t = Thread { [weak self] in self?.runLoop() }
        t.name = "com.spriteengine.emulation"
        t.qualityOfService = .userInteractive
        t.start()
        emulationThread = t
    }

    func stop() {
        running = false
        core.shutdown()
        audio.stop()
        DispatchQueue.main.async { self.isRunning = false }
    }

    // MARK: - Thread-safe buffer access

    // Read the front buffer on the main thread inside onFrameReady.
    func withFrontBuffer(_ body: (UnsafePointer<UInt32>, Int, Int) -> Void) {
        let w = core.frameWidth
        let h = core.frameHeight
        os_unfair_lock_lock(&bufferLock)
        frontBuffer.withUnsafeBufferPointer { ptr in
            body(ptr.baseAddress!, w, h)
        }
        os_unfair_lock_unlock(&bufferLock)
    }

    // MARK: - Input (safe to call from any thread — uint32 writes are atomic on ARM64)

    func setInput(player: Int, buttons: UInt32) {
        core.setInput(player: player, buttons: buttons)
    }

    func setSysInput(_ buttons: UInt32) {
        core.setSysInput(buttons)
    }

    // MARK: - Save state pass-through

    func saveState() throws -> Data { try core.saveState() }
    func loadState(_ data: Data) throws { try core.loadState(data) }

    // MARK: - Emulation loop

    private func runLoop() {
        let targetFrameTime = 1.0 / core.nativeFPS
        var lastTime = CACurrentMediaTime()

        while running {
            core.runFrame()

            // Copy emulator framebuffer into the back buffer, then swap.
            let fb = core.framebuffer()
            let count = core.frameWidth * core.frameHeight
            os_unfair_lock_lock(&bufferLock)
            backBuffer.withUnsafeMutableBufferPointer { dst in
                dst.baseAddress!.initialize(from: fb, count: count)
            }
            swap(&frontBuffer, &backBuffer)
            os_unfair_lock_unlock(&bufferLock)

            let (audioPtr, audioCount) = core.audioSamples()
            if audioCount > 0 {
                audio.push(samples: audioPtr, count: audioCount)
            }

            // FPS throttle.
            let now = CACurrentMediaTime()
            let elapsed = now - lastTime
            if elapsed < targetFrameTime {
                Thread.sleep(forTimeInterval: targetFrameTime - elapsed)
            }
            lastTime = CACurrentMediaTime()

            DispatchQueue.main.async { [weak self] in
                self?.onFrameReady?()
            }
        }
    }
}
