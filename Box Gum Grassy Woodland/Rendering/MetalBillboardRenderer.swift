import Foundation
import MetalKit
import simd

final class MetalBillboardRenderer: NSObject, ObservableObject {
    struct InstanceDescriptor {
        let position: SIMD3<Float>
        let scale: Float
        let yaw: Float
        let color: SIMD4<Float>
    }

    private struct Vertex {
        var position: SIMD3<Float>
        var uv: SIMD2<Float>
    }

    private struct InstanceData {
        var modelMatrix: simd_float4x4
        var color: SIMD4<Float>
    }

    private struct Uniforms {
        var viewProjectionMatrix: simd_float4x4
    }

    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let commandQueue: MTLCommandQueue
    private let vertexBuffer: MTLBuffer

    private var instanceBuffer: MTLBuffer?
    private var instanceCount: Int = 0
    private var pendingDescriptors: [InstanceDescriptor] = []

    private var projectionMatrix: simd_float4x4 = matrix_identity_float4x4
    private var viewMatrix: simd_float4x4 = matrix_identity_float4x4

    private weak var view: MTKView?

    init?(device: MTLDevice? = MTLCreateSystemDefaultDevice()) {
        guard let device, let commandQueue = device.makeCommandQueue() else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue

        guard let library = try? device.makeDefaultLibrary(bundle: .main) ?? device.makeDefaultLibrary() else {
            return nil
        }

        let vertexFunction = library.makeFunction(name: "instanced_billboard_vertex")
        let fragmentFunction = library.makeFunction(name: "instanced_billboard_fragment")

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Instanced Billboards"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
            return nil
        }

        self.pipelineState = pipelineState

        let quadVertices: [Vertex] = [
            Vertex(position: SIMD3<Float>(-0.5, 0, -0.5), uv: SIMD2<Float>(0, 1)),
            Vertex(position: SIMD3<Float>(0.5, 0, -0.5), uv: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD3<Float>(-0.5, 1, -0.5), uv: SIMD2<Float>(0, 0)),
            Vertex(position: SIMD3<Float>(0.5, 0, -0.5), uv: SIMD2<Float>(1, 1)),
            Vertex(position: SIMD3<Float>(0.5, 1, -0.5), uv: SIMD2<Float>(1, 0)),
            Vertex(position: SIMD3<Float>(-0.5, 1, -0.5), uv: SIMD2<Float>(0, 0))
        ]

        guard let vertexBuffer = device.makeBuffer(bytes: quadVertices,
                                                   length: MemoryLayout<Vertex>.stride * quadVertices.count,
                                                   options: [.storageModeShared]) else {
            return nil
        }

        self.vertexBuffer = vertexBuffer
        super.init()
    }

    func configure(view: MTKView) {
        self.view = view
        view.device = device
        view.delegate = self
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .invalid
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.preferredFramesPerSecond = 60
        view.isOpaque = false
        mtkView(view, drawableSizeWillChange: view.drawableSize)
    }

    func replaceInstances(_ descriptors: [InstanceDescriptor]) {
        pendingDescriptors = descriptors
        updateInstanceBuffer()
    }

    func appendInstance(_ descriptor: InstanceDescriptor) {
        pendingDescriptors.append(descriptor)
        updateInstanceBuffer()
    }

    func clearInstances() {
        pendingDescriptors.removeAll(keepingCapacity: true)
        instanceBuffer = nil
        instanceCount = 0
    }

    func updateCameraTransform(_ transform: simd_float4x4) {
        viewMatrix = transform.inverse
    }

    private func updateInstanceBuffer() {
        guard !pendingDescriptors.isEmpty else {
            instanceBuffer = nil
            instanceCount = 0
            return
        }

        let data = pendingDescriptors.map { descriptor -> InstanceData in
            let translation = matrix_float4x4(translation: descriptor.position)
            let rotation = matrix_float4x4(rotationAroundY: descriptor.yaw)
            let scaleMatrix = matrix_float4x4(uniformScale: descriptor.scale)
            let modelMatrix = translation * rotation * scaleMatrix
            return InstanceData(modelMatrix: modelMatrix, color: descriptor.color)
        }

        let length = MemoryLayout<InstanceData>.stride * data.count
        instanceBuffer = device.makeBuffer(bytes: data, length: length, options: .storageModeShared)
        instanceCount = data.count
    }
}

extension MetalBillboardRenderer: MTKViewDelegate {
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        let aspect = Float(size.width / max(size.height, 1))
        projectionMatrix = matrix_perspective_right_hand(fovyRadians: .pi / 4,
                                                         aspectRatio: aspect,
                                                         nearZ: 0.1,
                                                         farZ: 500)
    }

    func draw(in view: MTKView) {
        guard instanceCount > 0,
              let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        var uniforms = Uniforms(viewProjectionMatrix: projectionMatrix * viewMatrix)

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        if let instanceBuffer {
            renderEncoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
        }
        renderEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 2)
        renderEncoder.drawPrimitives(type: .triangle,
                                     vertexStart: 0,
                                     vertexCount: 6,
                                     instanceCount: instanceCount)
        renderEncoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

private extension matrix_float4x4 {
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3 = SIMD4<Float>(translation, 1)
    }

    init(uniformScale scale: Float) {
        self = matrix_identity_float4x4
        columns.0.x = scale
        columns.1.y = scale
        columns.2.z = scale
    }

    init(rotationAroundY angle: Float) {
        let cosine = cos(angle)
        let sine = sin(angle)
        self = matrix_identity_float4x4
        columns.0.x = cosine
        columns.0.z = -sine
        columns.2.x = sine
        columns.2.z = cosine
    }
}

private func matrix_perspective_right_hand(fovyRadians: Float,
                                           aspectRatio: Float,
                                           nearZ: Float,
                                           farZ: Float) -> simd_float4x4 {
    let ys = 1 / tan(fovyRadians * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)

    let column0 = SIMD4<Float>(xs, 0, 0, 0)
    let column1 = SIMD4<Float>(0, ys, 0, 0)
    let column2 = SIMD4<Float>(0, 0, zs, -1)
    let column3 = SIMD4<Float>(0, 0, zs * nearZ, 0)

    return simd_float4x4(columns: (column0, column1, column2, column3))
}
