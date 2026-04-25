import MetalKit
import SwiftUI

// MARK: - EmulatorView (MTKView)

final class EmulatorView: MTKView {

    private(set) var renderer: MetalRenderer?
    // Set by ContentView after session is created.
    weak var inputManager: InputManager?

    override init(frame: CGRect, device: MTLDevice?) {
        let dev = device ?? MTLCreateSystemDefaultDevice()
        super.init(frame: frame, device: dev)
        configure()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        colorPixelFormat        = .bgra8Unorm
        framebufferOnly         = true
        preferredFramesPerSecond = 60
        isPaused                = true   // driven externally; call setNeedsDisplay()
        enableSetNeedsDisplay   = true

        renderer = MetalRenderer(view: self)
        delegate = renderer
    }

    // Called by EmulatorSession (or a test harness) each time a new frame is ready.
    // pixels  — pointer into the emulator framebuffer (BGRA, width×height uint32)
    // width/height — texture dimensions (e.g. 320×256 for Neo Geo full buffer)
    // displayWidth/displayHeight — natural visible size for aspect-ratio calc (e.g. 320×224)
    // MARK: - First responder / keyboard

    override var acceptsFirstResponder: Bool { true }

    // Key events are handled by the local NSEvent monitor in EmulatorViewModel,
    // which works regardless of first-responder status. We override here only to
    // suppress the system "beep" that NSResponder.keyDown produces by default.
    override func keyDown(with event: NSEvent) {}
    override func keyUp(with event: NSEvent) {}

    // MARK: - Frame update

    func update(pixels: UnsafePointer<UInt32>,
                width: Int, height: Int,
                displayWidth: Int = 320, displayHeight: Int = 224) {
        renderer?.updateTexture(pixels: pixels,
                                width: width, height: height,
                                displayWidth: displayWidth,
                                displayHeight: displayHeight)
        setNeedsDisplay(bounds)
    }
}

// MARK: - SwiftUI wrapper

// Wraps a pre-existing EmulatorView so SwiftUI doesn't recreate it on redraws.
struct EmulatorViewRepresentable: NSViewRepresentable {
    let emulatorView: EmulatorView

    func makeNSView(context: Context) -> EmulatorView { emulatorView }
    func updateNSView(_ nsView: EmulatorView, context: Context) {}
}
