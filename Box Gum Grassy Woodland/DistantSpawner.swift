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
    
    init(anchor: AnchorEntity,
         modelFilenames: [(String, ClosedRange<Float>)],
         scale: Float = 1.0,
         minimumSpacing: Float = 4.0,
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
        
        // Initialize spawnAll parameters
        self.spawnCount = spawnCount
        self.batchSize = batchSize
        self.delayBetweenBatches = delayBetweenBatches
        
    }
    
    func getAnchor() -> AnchorEntity {
        return anchor
    }
    
    func selectRandomModelFilenameAndRange() -> (String, ClosedRange<Float>) {
        guard !modelFilenames.isEmpty else {
            fatalError("No model filenames provided. This method must be overridden by subclasses or modelFilenames must be set.")
        }

        let totalWeight = modelFilenames.reduce(Float(0)) { total, element in
            let rangeSize = Float(element.1.upperBound - element.1.lowerBound)
            return total + rangeSize
        }

        let randomValue = Float.random(in: 0..<totalWeight)
        var cumulativeWeight: Float = 0.0
        var selectedModels: [(String, ClosedRange<Float>)] = []

        for (filename, range) in modelFilenames {
            let rangeSize = Float(range.upperBound - range.lowerBound)
            cumulativeWeight += rangeSize
            if randomValue < cumulativeWeight {
                selectedModels.append((filename, range))
            }
        }

        guard !selectedModels.isEmpty else {
            fatalError("Failed to select a model filename. This should never happen.")
        }

        // Randomize among models with the same LOD range.
        return selectedModels.randomElement()!
    }
    
    func loadModel(named filename: String) throws -> Entity {
        return try ModelEntity.load(named: filename, in: realityKitContentBundle)
    }
    
    func spawn(at position: SIMD3<Float>? = nil) -> Entity {
        let (modelFilename, lodRange) = selectRandomModelFilenameAndRange()
        do {
            let model = try loadModel(named: modelFilename)
            let spawnPosition = (position ?? generateValidPosition(lodRange: lodRange)) + translation
            let entity = createEntityClone(from: model, lodRange: lodRange, position: spawnPosition)
            existingPositions.append(spawnPosition)
            return entity
        } catch {
            fatalError("Failed to load model: \(modelFilename), error: \(error)")
        }
    }

    private func createEntityClone(from model: Entity, lodRange: ClosedRange<Float>, position: SIMD3<Float>) -> Entity {
        let clone = model.clone(recursive: true)
        
        let randomScaleFactor = Float.random(in: 0.7...1.2) * scale
        clone.scale = SIMD3<Float>(repeating: randomScaleFactor)
        
        clone.position = position
    
        clone.look(at: center, from: position, relativeTo: nil)
        
        return clone
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
        let xPosition = radius * cos(angle)
        let zPosition = radius * sin(angle)
        return SIMD3<Float>(xPosition, 0, zPosition)
    }
    
    private func isValidPosition(_ position: SIMD3<Float>) -> Bool {
        for existingPosition in existingPositions {
            let distance = simd_distance(existingPosition, position)
            if distance < minimumSpacing {
                return false
            }
        }
        return true
    }
    
    public func spawnAll() {
        
        removeAll()
        
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
        anchor.children.removeAll(keepCapacity: true)
        existingPositions.removeAll()
    }
}
