import CoreVideo
import Metal
import MetalKit
import simd

struct TheaterUniforms {
    var viewProjection: float4x4
    var angWidth: Float
    var curve: Float
    var videoAspect: Float
    var radius: Float
    var showVideo: Float
    var rotation: Float
    var pad0: Float = 0
    var pad1: Float = 0
}

@MainActor
final class TheaterRenderer {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipeline: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var indexBuffer: MTLBuffer?
    private var indexCount = 0
    private var textureCache: CVMetalTextureCache?
    private var currentTexture: MTLTexture?
    private var currentCV: CVMetalTexture?
    private var dummyTexture: MTLTexture?
    private var pixelFormat: MTLPixelFormat = .bgra8Unorm

    init(device: MTLDevice) {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal command queue was not created")
        }
        self.commandQueue = commandQueue
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache)
        dummyTexture = Self.makeDummy(device: device)
        buildMesh()
    }

    func draw(
        in view: MTKView,
        rotation: simd_quatf,
        screenSize: Float,
        curve: Float,
        videoAspect: Float,
        videoRotation: Float,
        pixelBuffer: CVPixelBuffer?
    ) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else { return }

        if pipeline == nil || pixelFormat != view.colorPixelFormat {
            pixelFormat = view.colorPixelFormat
            pipeline = makePipeline(pixelFormat: pixelFormat)
        }
        guard let pipeline, let vertexBuffer, let indexBuffer else {
            encoder.endEncoding()
            commandBuffer.commit()
            return
        }

        if let produced = cvTexture(from: pixelBuffer) {
            currentCV = produced
            currentTexture = CVMetalTextureGetTexture(produced)
        }
        let frameCV = currentCV
        let boundTexture = currentTexture ?? dummyTexture

        let drawableSize = view.drawableSize
        let aspect = Float(drawableSize.width / max(drawableSize.height, 1))
        let horizontal = Float(44 * Float.pi / 180)
        let vertical = 2 * atan(tan(horizontal / 2) / max(aspect, 0.01))
        let projection = perspective(fovy: vertical, aspect: aspect, near: 0.05, far: 30)
        let modelView = float4x4(rotation)

        var uniforms = TheaterUniforms(
            viewProjection: projection * modelView,
            angWidth: (18 + 28 * screenSize) * .pi / 180,
            curve: curve,
            videoAspect: max(videoAspect, 0.01),
            radius: 1.6,
            showVideo: currentTexture == nil ? 0 : 1,
            rotation: videoRotation
        )

        encoder.setRenderPipelineState(pipeline)
        encoder.setCullMode(.none)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<TheaterUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<TheaterUniforms>.stride, index: 1)
        if let boundTexture {
            encoder.setFragmentTexture(boundTexture, index: 0)
        }
        encoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: indexCount,
            indexType: .uint16,
            indexBuffer: indexBuffer,
            indexBufferOffset: 0
        )
        encoder.endEncoding()
        let hold = TextureHold(frameCV)
        commandBuffer.addCompletedHandler { _ in
            _ = hold
        }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func buildMesh() {
        let columns = 80
        let rows = 45
        var vertices: [SIMD2<Float>] = []
        vertices.reserveCapacity((columns + 1) * (rows + 1))
        for row in 0 ... rows {
            for column in 0 ... columns {
                vertices.append(SIMD2(
                    Float(column) / Float(columns),
                    Float(row) / Float(rows)
                ))
            }
        }
        var indices: [UInt16] = []
        indices.reserveCapacity(columns * rows * 6)
        let stride = columns + 1
        for row in 0 ..< rows {
            for column in 0 ..< columns {
                let start = UInt16(row * stride + column)
                let nextRow = UInt16(stride)
                indices.append(start)
                indices.append(start + nextRow)
                indices.append(start + 1)
                indices.append(start + 1)
                indices.append(start + nextRow)
                indices.append(start + nextRow + 1)
            }
        }
        indexCount = indices.count
        vertexBuffer = device.makeBuffer(
            bytes: vertices,
            length: MemoryLayout<SIMD2<Float>>.stride * vertices.count,
            options: .storageModeShared
        )
        indexBuffer = device.makeBuffer(
            bytes: indices,
            length: MemoryLayout<UInt16>.stride * indices.count,
            options: .storageModeShared
        )
    }

    private func makePipeline(pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState? {
        guard let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "theaterVertex"),
              let fragment = library.makeFunction(name: "theaterFragment")
        else { return nil }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func cvTexture(from buffer: CVPixelBuffer?) -> CVMetalTexture? {
        guard let buffer, let textureCache else { return nil }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        guard width > 0, height > 0 else { return nil }
        var cvTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            buffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        guard result == kCVReturnSuccess else { return nil }
        return cvTexture
    }

    private static func makeDummy(device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: 1,
            height: 1,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        var pixel: UInt32 = 0
        texture.replace(
            region: MTLRegionMake2D(0, 0, 1, 1),
            mipmapLevel: 0,
            withBytes: &pixel,
            bytesPerRow: 4
        )
        return texture
    }

    private func perspective(fovy: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let yScale = 1 / tan(fovy * 0.5)
        let xScale = yScale / aspect
        let zScale = far / (near - far)
        return float4x4(columns: (
            SIMD4<Float>(xScale, 0, 0, 0),
            SIMD4<Float>(0, yScale, 0, 0),
            SIMD4<Float>(0, 0, zScale, -1),
            SIMD4<Float>(0, 0, zScale * near, 0)
        ))
    }
}

private final class TextureHold: @unchecked Sendable {
    let texture: CVMetalTexture?
    init(_ texture: CVMetalTexture?) {
        self.texture = texture
    }
}
