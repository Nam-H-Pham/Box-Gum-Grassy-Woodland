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
    
    // Grid for spatial partitioning
    private var grid: [SIMD2<Int>: [SIMD3<Float>]] = [:]
    private var positionQueue: [(cell: SIMD2<Int>, position: SIMD3<Float>)] = []
    private let gridCellSize: Float
    
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
        self.gridCellSize = max(minimumSpacing, 0.001)
        
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
            let spawnPosition = (position ?? generateValidPosition(lodRange: lodRange)) + translation
            let entity = createEntityClone(from: model, lodRange: lodRange, position: spawnPosition, filename: modelFilename)
            addToGrid(position: spawnPosition)
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
    
    private func generateValidPosition(lodRange: ClosedRange<Float>) -> SIMD3<Float> {
        var position: SIMD3<Float>
        var attempts = 0
        repeat {
            position = generateRandomPosition(lodRange: lodRange)
            attempts += 1
        } while (!isValidPosition(position) && attempts < 10)
        return position
    }
    
    private func generateRandomPosition(lodRange: ClosedRange<Float>) -> SIMD3<Float> {
        let angle = Float.random(in: 0...(2 * .pi))
        let radius = Float.random(in: lodRange)
        let (sinAngle, cosAngle) = (sin(angle), cos(angle)) // Compute once
        return SIMD3<Float>(radius * cosAngle, 0, radius * sinAngle)
    }
    
    private func isValidPosition(_ position: SIMD3<Float>) -> Bool {
        let worldPosition = position + translation
        let baseKey = gridKey(for: worldPosition)

        // Check neighboring grid cells
        for dx in -1...1 {
            for dz in -1...1 {
                let key = SIMD2<Int>(baseKey.x + dx, baseKey.y + dz)
                if let positions = grid[key] {
                    for existingPosition in positions {
                        let distance = simd_distance(existingPosition, worldPosition)
                        if distance < minimumSpacing {
                            return false
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func addToGrid(position: SIMD3<Float>) {
        if positionQueue.count >= maxPositions, let oldest = positionQueue.first {
            positionQueue.removeFirst()
            if var positions = grid[oldest.cell] {
                if let index = positions.firstIndex(of: oldest.position) {
                    positions.remove(at: index)
                }
                if positions.isEmpty {
                    grid.removeValue(forKey: oldest.cell)
                } else {
                    grid[oldest.cell] = positions
                }
            }
        }

        let key = gridKey(for: position)
        grid[key, default: []].append(position)
        positionQueue.append((cell: key, position: position))
    }

    private func gridKey(for position: SIMD3<Float>) -> SIMD2<Int> {
        let gridX = Int(floor(position.x / gridCellSize))
        let gridZ = Int(floor(position.z / gridCellSize))
        return SIMD2<Int>(gridX, gridZ)
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
    func spawnInstances(
        count: Int,
        for filename: String,
        in lodRange: ClosedRange<Float>,
        onPositionAccepted: ((SIMD3<Float>) -> Void)? = nil
    ) async throws -> ModelEntity {
        let root = try await Entity(named: filename, in: realityKitContentBundle)

        guard let source = root.findRenderableModelEntity(),
              let mc = source.components[ModelComponent.self] else {
            let mesh = MeshResource.generateBox(size: 0.05)
            return ModelEntity(mesh: mesh, materials: [SimpleMaterial(color: .systemBlue, isMetallic: false)])
        }

        let renderable = ModelEntity()
        renderable.model = mc

        let baseWorld = source.transformMatrix(relativeTo: nil)

        var mic = MeshInstancesComponent()
        let instances = try LowLevelInstanceData(instanceCount: count)
        let part = MeshInstancesComponent.Part(data: instances)

        if let llm = renderable.model?.mesh.lowLevelMesh {
            for p in 0..<llm.parts.count { mic[partIndex: p] = part }
        } else {
            mic[partIndex: 0] = part
        }

        instances.withMutableTransforms { transforms in
            for i in 0..<count {
                let basePos = generateValidPosition(lodRange: lodRange) + self.translation

                // Yaw to face center
                let yaw = yawFacing(self.center, from: basePos)
                let rot = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))

                var t = Transform(rotation: rot, translation: basePos)
                // Optional authored scale if needed:
                // t.scale = ...

                transforms[i] = t.matrix * baseWorld

                // IMPORTANT: record each position so spacing applies across future batches
                self.addToGrid(position: basePos)
                onPositionAccepted?(basePos)
            }
        }

        renderable.components.set(mic)
        return renderable
    }





    
    public func spawnAll(clearExisting: Bool = true) {
        Task { @MainActor in
            if clearExisting {
                removeAll()
            }

            cancelSpawnTimer()
            remainingSpawnCount = spawnCount
            guard remainingSpawnCount > 0 else { return }

            var batchIndex = 0
            while remainingSpawnCount > 0 {
                let currentBatchSize = min(self.batchSize, remainingSpawnCount)
                let (filename, lodRange) = self.selectRandomModelFilenameAndRange()

                do {
                    // Spawn a batch of instances and add to anchor on main actor
                    let instancedEntity = try await self.spawnInstances(
                        count: currentBatchSize,
                        for: filename,
                        in: lodRange
                    ) { _ in /* optional hook if you want to log positions */ }

                    self.anchor.addChild(instancedEntity)

                    #if DEBUG
                    print("Batch \(batchIndex): +\(currentBatchSize) of \(filename) (lodRange: \(lodRange.lowerBound)–\(lodRange.upperBound))")
                    #endif
                } catch {
                    print("Failed to spawn instances for \(filename): \(error)")
                }

                remainingSpawnCount -= currentBatchSize
                batchIndex += 1

                // Respect pacing between batches (non-blocking)
                if remainingSpawnCount > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(delayBetweenBatches * 1_000_000_000))
                }
            }
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
        grid.removeAll()
        positionQueue.removeAll()
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

