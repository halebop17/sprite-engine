import AVFoundation

final class AudioEngine {

    private let engine     = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    // Separate L/R buffers so the realtime callback reads directly with no temp allocation.
    private let leftBuffer  = RingBuffer<Float>(capacity: 8192)
    private let rightBuffer = RingBuffer<Float>(capacity: 8192)

    // Emulator outputs 44100 Hz stereo int16; we match that rate so AVAudioEngine
    // inserts a resampler only if the hardware differs.
    static let emulatorSampleRate: Double = 44100.0

    init() {
        let format = AVAudioFormat(
            standardFormatWithSampleRate: AudioEngine.emulatorSampleRate,
            channels: 2)!   // standard = float32 non-interleaved

        let lb = leftBuffer
        let rb = rightBuffer

        sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList in
            let n   = Int(frameCount)
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard abl.count >= 2,
                  let left  = abl[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = abl[1].mData?.assumingMemoryBound(to: Float.self)
            else { return noErr }

            lb.read(left,  count: n)
            rb.read(right, count: n)
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    // Called from the emulation thread.
    // `samples` is stereo interleaved int16: [L0, R0, L1, R1, ...], `count` total values.
    func push(samples: UnsafePointer<Int16>, count: Int) {
        let frames = count / 2
        // Convert and deinterleave into two small stack buffers.
        // Max frames per emulator tick at 44100/59fps ≈ 746 — well within stack budget.
        withUnsafeTemporaryAllocation(of: Float.self, capacity: frames) { lBuf in
            withUnsafeTemporaryAllocation(of: Float.self, capacity: frames) { rBuf in
                for i in 0..<frames {
                    lBuf[i] = Float(samples[i * 2])     / 32767.0
                    rBuf[i] = Float(samples[i * 2 + 1]) / 32767.0
                }
                leftBuffer.write(lBuf.baseAddress!,  count: frames)
                rightBuffer.write(rBuf.baseAddress!, count: frames)
            }
        }
    }

    func stop() {
        engine.stop()
    }
}
