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

    enum RenderBackend {
        case realityKit
        case metal(MetalBillboardRenderer)
    }

    private let renderBackend: RenderBackend
    
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
         translation: SIMD3<Float> = .zero,
         center: SIMD3<Float> = .zero,
         spawnCount: Int,
         batchSize: Int,
         delayBetweenBatches: TimeInterval = 0.4,
         metalRenderer: MetalBillboardRenderer? = nil) {

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

        if let metalRenderer {
            self.renderBackend = .metal(metalRenderer)
        } else {
            self.renderBackend = .realityKit
        }

        // Precompute weights
        self.weights = modelFilenames.map { Float($0.1.upperBound - $0.1.lowerBound) }
        self.totalWeight = weights.reduce(0, +)

        switch renderBackend {
        case .realityKit:
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
        case .metal:
            break
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
    
    func spawn(at position: SIMD3<Float>? = nil) -> Entity? {
        let (modelFilename, lodRange) = selectRandomModelFilenameAndRange()
        let spawnPosition = (position ?? generateValidPosition(lodRange: lodRange)) + translation
        addToGrid(position: spawnPosition)

        switch renderBackend {
        case .realityKit:
            do {
                let model = try loadModel(named: modelFilename)
                let entity = createEntityClone(from: model, lodRange: lodRange, position: spawnPosition, filename: modelFilename)
                return entity
            } catch {
                fatalError("Failed to load model: \(modelFilename), error: \(error)")
            }
        case .metal(let renderer):
            let descriptor = makeInstanceDescriptor(position: spawnPosition, filename: modelFilename)
            renderer.appendInstance(descriptor)
            return nil
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
    
    public func spawnAll(clearExisting: Bool = true) {
        if clearExisting {
            removeAll()
        }

        cancelSpawnTimer()

        remainingSpawnCount = spawnCount

        guard remainingSpawnCount > 0 else {
            return
        }

        switch renderBackend {
        case .realityKit:
            let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
            timer.schedule(deadline: .now(), repeating: delayBetweenBatches)
            timer.setEventHandler { [weak self] in
                guard let self = self else { return }

                guard self.remainingSpawnCount > 0 else {
                    self.cancelSpawnTimer()
                    return
                }

                let currentBatchSize = min(self.batchSize, self.remainingSpawnCount)

                for _ in 0..<currentBatchSize {
                    if let entity = self.spawn() {
                        self.anchor.addChild(entity)
                    }
                }

                self.remainingSpawnCount -= currentBatchSize

                if self.remainingSpawnCount <= 0 {
                    self.cancelSpawnTimer()
                }
            }

            spawnTimer = timer
            timer.resume()
        case .metal(let renderer):
            var descriptors: [MetalBillboardRenderer.InstanceDescriptor] = []
            for _ in 0..<remainingSpawnCount {
                let (filename, lodRange) = selectRandomModelFilenameAndRange()
                let localPosition = generateValidPosition(lodRange: lodRange)
                let spawnPosition = localPosition + translation
                addToGrid(position: spawnPosition)
                descriptors.append(makeInstanceDescriptor(position: spawnPosition, filename: filename))
            }
            renderer.replaceInstances(descriptors)
            remainingSpawnCount = 0
        }
    }

    public func removeAll() {
        cancelSpawnTimer()
        remainingSpawnCount = 0

        switch renderBackend {
        case .realityKit:
            for entities in entityPool.values {
                for entity in entities {
                    entity.isEnabled = false // Disable instead of removing
                }
            }
            anchor.children.removeAll(keepCapacity: true)
        case .metal(let renderer):
            renderer.clearInstances()
        }

        grid.removeAll()
        positionQueue.removeAll()
    }

    private func cancelSpawnTimer() {
        spawnTimer?.setEventHandler(handler: nil)
        spawnTimer?.cancel()
        spawnTimer = nil
    }

    private func makeInstanceDescriptor(position: SIMD3<Float>, filename: String) -> MetalBillboardRenderer.InstanceDescriptor {
        let randomScaleFactor = Float.random(in: 0.7...1.2) * scale
        let direction = center - position
        let yaw = atan2(direction.x, direction.z)
        let normalizedIndex = colorIndex(for: filename)
        let baseColor = SIMD4<Float>(0.45, 0.6, 0.3, 0.85)
        let tint = SIMD4<Float>(normalizedIndex * 0.1, normalizedIndex * 0.05, normalizedIndex * 0.02, 0)
        let color = SIMD4<Float>(baseColor.x + tint.x,
                                 baseColor.y + tint.y,
                                 baseColor.z + tint.z,
                                 baseColor.w)
        return MetalBillboardRenderer.InstanceDescriptor(position: position,
                                                         scale: randomScaleFactor,
                                                         yaw: yaw,
                                                         color: color)
    }

    private func colorIndex(for filename: String) -> Float {
        guard let index = modelFilenames.firstIndex(where: { $0.0 == filename }) else {
            return 0
        }
        return Float(index) / Float(max(modelFilenames.count - 1, 1))
    }
}
