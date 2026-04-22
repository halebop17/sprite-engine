import Foundation
import QuartzCore
import os.lock

final class EmulatorSession: ObservableObject {

    private let core:  any EmulatorCore
    private let audio: AudioEngine
    private var emulationThread: Thread?
    private var running = false

    // Bool written by main thread, read by emulation thread.
    // ARM64 1-byte reads/writes are naturally atomic.
    private var paused = false

    private var frontBuffer: [UInt32] = []
    private var backBuffer:  [UInt32] = []
    private var bufferLock = os_unfair_lock_s()

    @Published var isRunning: Bool  = false
    @Published var isPaused:  Bool  = false
    @Published var measuredFPS: Double = 0

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
        paused  = false
        core.shutdown()
        audio.stop()
        DispatchQueue.main.async { self.isRunning = false; self.isPaused = false }
    }

    // MARK: - Pause / resume

    func pause() {
        paused = true
        DispatchQueue.main.async { self.isPaused = true }
    }

    func resume() {
        paused = false
        DispatchQueue.main.async { self.isPaused = false }
    }

    func togglePause() { if paused { resume() } else { pause() } }

    // MARK: - Audio volume (forwarded to engine)

    var volume: Float {
        get { audio.volume }
        set { audio.volume = newValue }
    }

    // MARK: - Thread-safe buffer access

    func withFrontBuffer(_ body: (UnsafePointer<UInt32>, Int, Int) -> Void) {
        let w = core.frameWidth
        let h = core.frameHeight
        os_unfair_lock_lock(&bufferLock)
        frontBuffer.withUnsafeBufferPointer { ptr in
            body(ptr.baseAddress!, w, h)
        }
        os_unfair_lock_unlock(&bufferLock)
    }

    // MARK: - Input

    func setInput(player: Int, buttons: UInt32) { core.setInput(player: player, buttons: buttons) }
    func setSysInput(_ buttons: UInt32)          { core.setSysInput(buttons) }

    // MARK: - Save state pass-through

    func saveState() throws -> Data { try core.saveState() }
    func loadState(_ data: Data) throws { try core.loadState(data) }

    // MARK: - Emulation loop

    private func runLoop() {
        let targetFrameTime = 1.0 / core.nativeFPS
        var lastTime = CACurrentMediaTime()
        var fpsFrameCount = 0
        var fpsWindowStart = CACurrentMediaTime()

        while running {
            if paused {
                Thread.sleep(forTimeInterval: 0.008)
                continue
            }

            core.runFrame()

            let fb    = core.framebuffer()
            let count = core.frameWidth * core.frameHeight
            os_unfair_lock_lock(&bufferLock)
            backBuffer.withUnsafeMutableBufferPointer { dst in
                dst.baseAddress!.initialize(from: fb, count: count)
            }
            swap(&frontBuffer, &backBuffer)
            os_unfair_lock_unlock(&bufferLock)

            let (audioPtr, audioCount) = core.audioSamples()
            if audioCount > 0 { audio.push(samples: audioPtr, count: audioCount) }

            let now     = CACurrentMediaTime()
            let elapsed = now - lastTime
            if elapsed < targetFrameTime {
                Thread.sleep(forTimeInterval: targetFrameTime - elapsed)
            }
            lastTime = CACurrentMediaTime()

            fpsFrameCount += 1
            let fpsDelta = now - fpsWindowStart
            if fpsDelta >= 0.5 {
                let fps = Double(fpsFrameCount) / fpsDelta
                fpsFrameCount  = 0
                fpsWindowStart = now
                DispatchQueue.main.async { [weak self] in self?.measuredFPS = fps }
            }

            DispatchQueue.main.async { [weak self] in self?.onFrameReady?() }
        }
    }
}
