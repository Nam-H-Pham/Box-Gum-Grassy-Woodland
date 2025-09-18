import SwiftUI
import RealityKit
import RealityKitContent

class DistantSpawner {
    private let translation: SIMD3<Float>
    private let modelFilenames: [(String, ClosedRange<Float>)]
    private let scale: Float
    private var existingPositions: [SIMD3<Float>] = []
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
    private let gridCellSize: Float = 5.0 // Adjust based on minimumSpacing
    
    // Entity pool for reuse
    private var entityPool: [String: [Entity]] = [:]
    
    // Memory management
    private let maxPositions: Int = 1000 // Adjust as needed
    
    init(anchor: AnchorEntity,
         modelFilenames: [(String, ClosedRange<Float>)],
         scale: Float = 1.0,
         minimumSpacing: Float = 5.0,
         translation: SIMD3<Float> = .zero,
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
            let spawnPosition = (position ?? generateValidPosition(lodRange: lodRange)) + translation
            let entity = createEntityClone(from: model, lodRange: lodRange, position: spawnPosition, filename: modelFilename)
            existingPositions.append(spawnPosition)
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
        let gridX = Int(position.x / gridCellSize)
        let gridZ = Int(position.z / gridCellSize)
        
        // Check neighboring grid cells
        for dx in -1...1 {
            for dz in -1...1 {
                let key = SIMD2<Int>(gridX + dx, gridZ + dz)
                if let positions = grid[key] {
                    for existingPosition in positions {
                        let distance = simd_distance(existingPosition, position)
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
        if existingPositions.count >= maxPositions {
            existingPositions.removeFirst() // Remove oldest position
            // Rebuild grid
            grid = [:]
            for pos in existingPositions {
                let gridX = Int(pos.x / gridCellSize)
                let gridZ = Int(pos.z / gridCellSize)
                let key = SIMD2<Int>(gridX, gridZ)
                grid[key, default: []].append(pos)
            }
        }
        let gridX = Int(position.x / gridCellSize)
        let gridZ = Int(position.z / gridCellSize)
        let key = SIMD2<Int>(gridX, gridZ)
        grid[key, default: []].append(position)
    }
    
    public func spawnAll(clearExisting: Bool = true) {
        if clearExisting {
            removeAll()
        }
        
        var remainingSpawnCount = spawnCount
        
        func spawnBatch() {
            let currentBatchSize = min(batchSize, remainingSpawnCount)
            
            for _ in 0..<currentBatchSize {
                let entity = spawn()
                anchor.addChild(entity)
            }
            
            remainingSpawnCount -= currentBatchSize
            
            if remainingSpawnCount > 0 {
                // Schedule the next batch after the delay
                DispatchQueue.main.asyncAfter(deadline: .now() + delayBetweenBatches) {
                    spawnBatch()
                }
            }
        }
        
        // Start the first batch
        spawnBatch()
    }
    
    public func removeAll() {
        for entities in entityPool.values {
            for entity in entities {
                entity.isEnabled = false // Disable instead of removing
            }
        }
        anchor.children.removeAll(keepCapacity: true)
        existingPositions.removeAll()
        grid.removeAll()
    }
}
