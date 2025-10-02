import SwiftUI
import RealityKit
import RealityKitContent

class DistantSpawner {
    private let translation: SIMD3<Float>
    private let modelFilenames: [(String, ClosedRange<Float>)]
    private let scale: Float
    private let minimumSpacing: Float
    private let center: SIMD3<Float>
    private let anchor: AnchorEntity
    
    // New properties for spawnAll parameters
    private let spawnCount: Int
    private let batchSize: Int
    private let delayBetweenBatches: TimeInterval
    
    // Cache for loaded models
    private var modelCache: [String: Entity] = [:]
    
    // Precomputed weights for model selection
    private let weights: [Float]
    private let totalWeight: Float
    
    
    // Entity pool for reuse
    private var entityPool: [String: [Entity]] = [:]
    
    // Memory management
    private let maxPositions: Int = 1000 // Adjust as needed

    private var spawnTimer: DispatchSourceTimer?
    private var remainingSpawnCount: Int = 0
    
    init(anchor: AnchorEntity,
         modelFilenames: [(String, ClosedRange<Float>)],
         scale: Float = 1.0,
         minimumSpacing: Float = 5.0,
         translation: SIMD3<Float> = SIMD3<Float>(0,0,0),
         center: SIMD3<Float> = .zero,
         spawnCount: Int,
         batchSize: Int,
         delayBetweenBatches: TimeInterval = 0.4) {
        
        self.translation = translation
        self.modelFilenames = modelFilenames
        self.scale = scale
        self.minimumSpacing = minimumSpacing
        self.center = center
        self.anchor = anchor
        self.spawnCount = spawnCount
        self.batchSize = batchSize
        self.delayBetweenBatches = delayBetweenBatches
        
        // Precompute weights
        self.weights = modelFilenames.map { Float($0.1.upperBound - $0.1.lowerBound) }
        self.totalWeight = weights.reduce(0, +)
        
        // Preload entity pool
        for (filename, _) in modelFilenames {
            entityPool[filename] = []
            if let model = try? loadModel(named: filename) {
                for _ in 0..<batchSize { // Pre-clone for batch size
                    let clone = model.clone(recursive: true)
                    clone.isEnabled = false
                    entityPool[filename]?.append(clone)
                }
            }
        }
    }
    
    func getAnchor() -> AnchorEntity {
        return anchor
    }
    
    func selectRandomModelFilenameAndRange() -> (String, ClosedRange<Float>) {
        guard !modelFilenames.isEmpty else {
            fatalError("No model filenames provided.")
        }

        let randomValue = Float.random(in: 0..<totalWeight)
        var cumulativeWeight: Float = 0.0

        for (index, weight) in weights.enumerated() {
            cumulativeWeight += weight
            if randomValue < cumulativeWeight {
                return modelFilenames[index]
            }
        }

        // Fallback to last model (should rarely happen)
        return modelFilenames.last!
    }
    
    func loadModel(named filename: String) throws -> Entity {
        if let cachedModel = modelCache[filename] {
            return cachedModel
        }
        let model = try ModelEntity.load(named: filename, in: realityKitContentBundle)
        modelCache[filename] = model
        return model
    }
    
    func spawn(at position: SIMD3<Float>? = nil) -> Entity {
        let (modelFilename, lodRange) = selectRandomModelFilenameAndRange()
        do {
            let model = try loadModel(named: modelFilename)
            let spawnPosition = generateRandomPosition(lodRange: lodRange) + translation
            let entity = createEntityClone(from: model, lodRange: lodRange, position: spawnPosition, filename: modelFilename)
            return entity
        } catch {
            fatalError("Failed to load model: \(modelFilename), error: \(error)")
        }
    }

    private func createEntityClone(from model: Entity, lodRange: ClosedRange<Float>, position: SIMD3<Float>, filename: String) -> Entity {
        if let pool = entityPool[filename], let clone = pool.first(where: { !$0.isEnabled }) {
            // Reuse from pool
            let randomScaleFactor = Float.random(in: 0.7...1.2) * scale
            clone.scale = SIMD3<Float>(repeating: randomScaleFactor)
            clone.position = position
            clone.look(at: center, from: position, relativeTo: nil)
            clone.isEnabled = true
            return clone
        } else {
            // Create new clone if pool is empty
            let clone = model.clone(recursive: true)
            let randomScaleFactor = Float.random(in: 0.7...1.2) * scale
            clone.scale = SIMD3<Float>(repeating: randomScaleFactor)
            clone.position = position
            clone.look(at: center, from: position, relativeTo: nil)
            entityPool[filename, default: []].append(clone)
            return clone
        }
    }
    
    
    private func generateRandomPosition(lodRange: ClosedRange<Float>) -> SIMD3<Float> {
        let angle = Float.random(in: 0...(2 * .pi))
        let radius = Float.random(in: lodRange)
        let (sinAngle, cosAngle) = (sin(angle), cos(angle)) // Compute once
        return SIMD3<Float>(radius * cosAngle, 0, radius * sinAngle)
    }
    
    
    @inline(__always)
    func yawFacing(_ center: SIMD3<Float>, from pos: SIMD3<Float>) -> Float {
        // Direction to centre in XZ plane
        let dx = center.x - pos.x
        let dz = center.z - pos.z
        // If your mesh’s “forward” is +Z (typical), use atan2(dx, dz).
        // If it’s -Z, add .pi (see note below).
        return atan2(dx, dz)
    }

    
    @MainActor
    func spawnInstances(count: Int, for filename: String, in lodRange: ClosedRange<Float>) async throws -> ModelEntity {
        let root = try await Entity(named: filename, in: realityKitContentBundle)

        // Get a renderable + its authored world transform
        guard let source = root.findRenderableModelEntity(),
              let mc = source.components[ModelComponent.self] else {
            let mesh = MeshResource.generateBox(size: 0.05)
            return ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)])
        }

        // Fresh ModelEntity with identity local transform (we’ll compose everything into the instance matrices)
        let renderable = ModelEntity()
        renderable.model = mc


        // 2) Authored Y-scale from baseWorld (handles non-uniform parent scaling)
        let baseWorld = source.transformMatrix(relativeTo: nil)
        @inline(__always) func axisLen(_ c: SIMD4<Float>) -> Float { simd_length(SIMD3<Float>(c.x, c.y, c.z)) }

        // Prepare instancing
        var mic = MeshInstancesComponent()
        let instances = try LowLevelInstanceData(instanceCount: count)
        let part = MeshInstancesComponent.Part(data: instances)

        if let llm = renderable.model?.mesh.lowLevelMesh {
            for p in 0..<llm.parts.count { mic[partIndex: p] = part }
        } else {
            mic[partIndex: 0] = part
        }

        // Fill transforms with spacing + rotation + scale + LIFT
        instances.withMutableTransforms { transforms in
            for i in 0..<count {
                let basePos = generateRandomPosition(lodRange: lodRange) + self.translation

                // Uniform scale keeps things safe with non-uniform authored base
                let scl: Float = 1.0 * self.scale

                // Yaw so each instance faces the centre
                let yaw = yawFacing(self.center, from: basePos)

                let rot = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))

                let t = Transform(
                    scale: SIMD3<Float>(repeating: scl),
                    rotation: rot,
                    translation: basePos
                ).matrix

                // Keep authored transform first, then per-instance TRS
                transforms[i] = baseWorld * t
            }
        }


        renderable.components.set(mic)
        return renderable
    }




    
    public func spawnAll(clearExisting: Bool = true) {
        Task {
            if clearExisting {
                removeAll()
            }

            cancelSpawnTimer()
            remainingSpawnCount = spawnCount
            guard remainingSpawnCount > 0 else { return }

            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
            timer.schedule(deadline: .now(), repeating: delayBetweenBatches)
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }
                guard self.remainingSpawnCount > 0 else {
                    self.cancelSpawnTimer()
                    return
                }

                let currentBatchSize = min(self.batchSize, self.remainingSpawnCount)
                Task {
                    let (filename, lodRange) = self.selectRandomModelFilenameAndRange()

                    do {
                        let instancedEntity = try await self.spawnInstances(
                            count: currentBatchSize,
                            for: filename,
                            in: lodRange
                        )
                        await self.anchor.addChild(instancedEntity)
                    } catch {
                        print("Failed to spawn instances for \(filename): \(error)")
                    }

                    self.remainingSpawnCount -= currentBatchSize
                    if self.remainingSpawnCount <= 0 {
                        self.cancelSpawnTimer()
                    }
                }
            }

            spawnTimer = timer
            timer.resume()
        }
    }


    public func removeAll() {
        cancelSpawnTimer()
        remainingSpawnCount = 0

        for entities in entityPool.values {
            for entity in entities {
                entity.isEnabled = false // Disable instead of removing
            }
        }
        anchor.children.removeAll(keepCapacity: true)
    }

    private func cancelSpawnTimer() {
        spawnTimer?.setEventHandler(handler: nil)
        spawnTimer?.cancel()
        spawnTimer = nil
    }
}

// MARK: - Find/copy a renderable while PRESERVING materials/shaders

extension Entity {
    /// Returns a ModelEntity you can render/instance.
    /// If `self` already has a ModelComponent, we *copy* it into a new ModelEntity (or return self if it's already a ModelEntity).
    func findRenderableModelEntity() -> ModelEntity? {
        // If this entity already is a ModelEntity and has a ModelComponent, keep it.
        if let me = self as? ModelEntity, me.components.has(ModelComponent.self) {
            return me
        }
        // If it has a ModelComponent but isn't a ModelEntity, copy that component into a fresh ModelEntity.
        if let mc = self.components[ModelComponent.self] {
            let me = ModelEntity()
            me.model = mc            // <-- copies mesh + *all* materials (incl. ShaderGraphMaterial / CustomMaterial)
            return me
        }
        // Depth-first search into children
        for child in children {
            if let r = child.findRenderableModelEntity() { return r }
        }
        return nil
    }
}

