import MetalKit

enum VideoScaleMode: String, CaseIterable {
    case aspectFit = "aspectFit"
    case stretch   = "stretch"
    case integer   = "integer"

    var label: String {
        switch self {
        case .aspectFit: return "Aspect Fit"
        case .stretch:   return "Stretch"
        case .integer:   return "Integer"
        }
    }
}

enum FilterMode {
    case sharp, smooth, crt
}

final class MetalRenderer: NSObject, MTKViewDelegate {

    var scaleMode:  VideoScaleMode = .aspectFit
    var filterMode: FilterMode     = .sharp

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let sharpPipeline:  MTLRenderPipelineState
    private let smoothPipeline: MTLRenderPipelineState
    private let crtPipeline:    MTLRenderPipelineState

    private var texture: MTLTexture?
    private var textureWidth:  Int = 0
    private var textureHeight: Int = 0

    // Natural display dimensions — set via updateTexture, used for aspect + integer scale.
    private var naturalAspect:  Double = 320.0 / 224.0
    private var displayWidth:   Int    = 320
    private var displayHeight:  Int    = 224

    init?(view: MTKView) {
        guard let dev = view.device ?? MTLCreateSystemDefaultDevice() else { return nil }
        guard let queue = dev.makeCommandQueue() else { return nil }
        device = dev
        commandQueue = queue

        guard let library  = dev.makeDefaultLibrary(),
              let vertFn   = library.makeFunction(name: "vertex_passthrough"),
              let sharpFn  = library.makeFunction(name: "fragment_sharp"),
              let smoothFn = library.makeFunction(name: "fragment_smooth"),
              let crtFn    = library.makeFunction(name: "fragment_crt")
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

        desc.fragmentFunction = crtFn
        guard let crt = try? dev.makeRenderPipelineState(descriptor: desc) else { return nil }
        crtPipeline = crt

        super.init()
    }

    // Called every frame with the latest pixel data.
    // displayWidth/displayHeight define the natural visible area for aspect ratio / integer scale.
    func updateTexture(pixels: UnsafePointer<UInt32>,
                       width: Int, height: Int,
                       displayWidth: Int, displayHeight: Int) {
        self.displayWidth  = displayWidth
        self.displayHeight = displayHeight
        naturalAspect = Double(displayWidth) / Double(displayHeight)

        if texture == nil || textureWidth != width || textureHeight != height {
            let td = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width, height: height,
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
        guard let tex        = texture,
              let drawable   = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let buffer     = commandQueue.makeCommandBuffer(),
              let encoder    = buffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        let pipeline: MTLRenderPipelineState
        switch filterMode {
        case .sharp:  pipeline = sharpPipeline
        case .smooth: pipeline = smoothPipeline
        case .crt:    pipeline = crtPipeline
        }

        encoder.setRenderPipelineState(pipeline)
        encoder.setViewport(viewport(drawableSize: view.drawableSize))
        encoder.setFragmentTexture(tex, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()

        buffer.present(drawable)
        buffer.commit()
    }

    // MARK: - Viewport layout

    private func viewport(drawableSize: CGSize) -> MTLViewport {
        let dw = drawableSize.width
        let dh = drawableSize.height

        let vw, vh, vx, vy: Double

        switch scaleMode {
        case .stretch:
            (vw, vh, vx, vy) = (dw, dh, 0, 0)

        case .integer:
            // Largest N such that N*displayW ≤ dw and N*displayH ≤ dh.
            let scale = max(1.0, min(floor(dw / Double(displayWidth)),
                                     floor(dh / Double(displayHeight))))
            vw = Double(displayWidth)  * scale
            vh = Double(displayHeight) * scale
            vx = (dw - vw) / 2
            vy = (dh - vh) / 2

        case .aspectFit:
            if naturalAspect > dw / dh {
                vw = dw; vh = dw / naturalAspect; vx = 0; vy = (dh - vh) / 2
            } else {
                vh = dh; vw = dh * naturalAspect; vx = (dw - vw) / 2; vy = 0
            }
        }

        return MTLViewport(originX: vx, originY: vy, width: vw, height: vh, znear: 0, zfar: 1)
    }
}
