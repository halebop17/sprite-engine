import MetalKit

final class MetalRenderer: NSObject, MTKViewDelegate {

    // Toggle between sharp (nearest) and smooth (bilinear) sampling.
    var isSmoothing: Bool = false

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let sharpPipeline: MTLRenderPipelineState
    private let smoothPipeline: MTLRenderPipelineState

    private var texture: MTLTexture?
    private var textureWidth:  Int = 0
    private var textureHeight: Int = 0

    // Natural display aspect ratio of the content (not the texture dimensions).
    // Neo Geo: 320/224 ≈ 1.429. Updated via updateTexture.
    private var naturalAspect: Double = 320.0 / 224.0

    init?(view: MTKView) {
        guard let dev = view.device ?? MTLCreateSystemDefaultDevice() else { return nil }
        guard let queue = dev.makeCommandQueue() else { return nil }
        device = dev
        commandQueue = queue

        guard let library = dev.makeDefaultLibrary(),
              let vertFn = library.makeFunction(name: "vertex_passthrough"),
              let sharpFn = library.makeFunction(name: "fragment_sharp"),
              let smoothFn = library.makeFunction(name: "fragment_smooth")
        else { return nil }

        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vertFn
        desc.colorAttachments[0].pixelFormat = view.colorPixelFormat

        desc.fragmentFunction = sharpFn
        guard let sharp = try? dev.makeRenderPipelineState(descriptor: desc) else { return nil }
        sharpPipeline = sharp

        desc.fragmentFunction = smoothFn
        guard let smooth = try? dev.makeRenderPipelineState(descriptor: desc) else { return nil }
        smoothPipeline = smooth

        super.init()
    }

    // Called every frame by EmulatorView with the latest pixel data.
    // width/height are the texture dimensions; aspectWidth/aspectHeight define
    // the natural display ratio (e.g. 320×224 for Neo Geo visible area).
    func updateTexture(pixels: UnsafePointer<UInt32>,
                       width: Int, height: Int,
                       displayWidth: Int, displayHeight: Int) {
        naturalAspect = Double(displayWidth) / Double(displayHeight)

        if texture == nil || textureWidth != width || textureHeight != height {
            let td = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false)
            td.usage = [.shaderRead]
            td.storageMode = .shared
            texture = device.makeTexture(descriptor: td)
            textureWidth  = width
            textureHeight = height
        }

        texture?.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixels,
            bytesPerRow: width * 4)
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let tex = texture,
              let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let buffer = commandQueue.makeCommandBuffer(),
              let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        encoder.setRenderPipelineState(isSmoothing ? smoothPipeline : sharpPipeline)
        encoder.setViewport(letterboxViewport(drawableSize: view.drawableSize))
        encoder.setFragmentTexture(tex, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        buffer.present(drawable)
        buffer.commit()
    }

    // MARK: - Layout

    private func letterboxViewport(drawableSize: CGSize) -> MTLViewport {
        let dw = drawableSize.width
        let dh = drawableSize.height
        let viewAspect = dw / dh

        let vw: Double
        let vh: Double
        let vx: Double
        let vy: Double

        if naturalAspect > viewAspect {
            // Content wider than window → pillarbox top/bottom
            vw = dw
            vh = dw / naturalAspect
            vx = 0
            vy = (dh - vh) / 2
        } else {
            // Content taller than window → letterbox left/right
            vh = dh
            vw = dh * naturalAspect
            vx = (dw - vw) / 2
            vy = 0
        }

        return MTLViewport(originX: vx, originY: vy, width: vw, height: vh, znear: 0, zfar: 1)
    }
}
