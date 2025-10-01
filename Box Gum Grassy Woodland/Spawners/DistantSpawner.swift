import RealityKit
import RealityKitContent
import simd

private enum DistantSpawnerError: Error {
    case failedToCloneModel(String)
}

final class DistantSpawner {
    private let translation: SIMD3<Float>
    private let modelFilenames: [(String, ClosedRange<Float>)]
    private let scale: Float
    private let minimumSpacing: Float
    private let center: SIMD3<Float>
    private let anchor: AnchorEntity
    private let spawnCount: Int

    private var modelCache: [String: ModelEntity] = [:]
    private var instancedEntities: [String: ModelEntity] = [:]
    private var fallbackClones: [String: [Entity]] = [:]
    private var storedTransforms: [String: [simd_float4x4]] = [:]

    private let weights: [Float]
    private let totalWeight: Float

    private var grid: [SIMD2<Int>: [SIMD3<Float>]] = [:]
    private var positionQueue: [(cell: SIMD2<Int>, position: SIMD3<Float>)] = []
    private let gridCellSize: Float
    private let maxPositions: Int = 1000

    init(anchor: AnchorEntity,
         modelFilenames: [(String, ClosedRange<Float>)],
         scale: Float = 1.0,
         minimumSpacing: Float = 5.0,
         translation: SIMD3<Float> = .zero,
         center: SIMD3<Float> = .zero,
         spawnCount: Int) {
        self.translation = translation
        self.modelFilenames = modelFilenames
        self.scale = scale
        self.minimumSpacing = minimumSpacing
        self.center = center
        self.anchor = anchor
        self.spawnCount = spawnCount
        self.gridCellSize = max(minimumSpacing, 0.001)

        self.weights = modelFilenames.map { Float($0.1.upperBound - $0.1.lowerBound) }
        self.totalWeight = weights.reduce(0, +)
    }

    func getAnchor() -> AnchorEntity {
        anchor
    }

    func spawnAll(clearExisting: Bool = true) {
        if clearExisting {
            removeAll()
        }

        guard spawnCount > 0, !modelFilenames.isEmpty else {
            return
        }

        var transformsByModel: [String: [simd_float4x4]] = clearExisting ? [:] : storedTransforms

        for _ in 0..<spawnCount {
            let (modelFilename, lodRange) = selectRandomModelFilenameAndRange()
            let localPosition = generateValidPosition(lodRange: lodRange)
            let worldPosition = localPosition + translation
            let scaleFactor = Float.random(in: 0.7...1.2) * scale
            let transform = makeTransform(for: worldPosition, scale: scaleFactor)

            transformsByModel[modelFilename, default: []].append(transform)
            addToGrid(position: worldPosition)
        }

        storedTransforms = transformsByModel
        applyTransformsToInstances()
    }

    func removeAll() {
        storedTransforms.removeAll()
        grid.removeAll()
        positionQueue.removeAll()

        if #available(visionOS 2.0, *) {
            for entity in instancedEntities.values {
                entity.components.remove(MeshInstancesComponent.self)
                entity.removeFromParent()
            }
        }

        for clones in fallbackClones.values {
            for entity in clones {
                entity.removeFromParent()
            }
        }

        instancedEntities.removeAll()
        fallbackClones.removeAll()
        anchor.children.removeAll(keepCapacity: true)
    }

    private func selectRandomModelFilenameAndRange() -> (String, ClosedRange<Float>) {
        let randomValue = Float.random(in: 0..<totalWeight)
        var cumulativeWeight: Float = 0.0

        for (index, weight) in weights.enumerated() {
            cumulativeWeight += weight
            if randomValue < cumulativeWeight {
                return modelFilenames[index]
            }
        }

        return modelFilenames.last ?? ("", 0...0)
    }

    private func loadModel(named filename: String) throws -> ModelEntity {
        if let cached = modelCache[filename] {
            return cached
        }

        let model = try ModelEntity.load(named: filename, in: realityKitContentBundle)
        modelCache[filename] = model
        return model
    }

    private func prepareInstancedEntity(for filename: String) throws -> ModelEntity {
        if let entity = instancedEntities[filename] {
            return entity
        }

        let baseModel = try loadModel(named: filename)
        let clonedEntity = baseModel.clone(recursive: true)

        guard let modelEntity = clonedEntity as? ModelEntity else {
            throw DistantSpawnerError.failedToCloneModel(filename)
        }

        modelEntity.isEnabled = true
        anchor.addChild(modelEntity)
        instancedEntities[filename] = modelEntity
        return modelEntity
    }

    private func applyTransformsToInstances() {
        let filenames = Set(storedTransforms.keys)
            .union(instancedEntities.keys)
            .union(fallbackClones.keys)

        for filename in filenames {
            let transforms = storedTransforms[filename] ?? []

            if transforms.isEmpty {
                clearEntities(for: filename)
                continue
            }

            do {
                if #available(visionOS 2.0, *) {
                    try applyInstancedTransforms(for: filename, transforms: transforms)
                } else {
                    try applyFallbackTransforms(for: filename, transforms: transforms)
                }
            } catch {
                print("Failed to apply mesh instancing for \(filename): \(error)")
            }
        }
    }

    private func clearEntities(for filename: String) {
        if #available(visionOS 2.0, *) {
            if let entity = instancedEntities.removeValue(forKey: filename) {
                entity.components.remove(MeshInstancesComponent.self)
                entity.removeFromParent()
            }
        }

        if let clones = fallbackClones.removeValue(forKey: filename) {
            for entity in clones {
                entity.removeFromParent()
            }
        }
    }

    @available(visionOS 2.0, *)
    private func applyInstancedTransforms(for filename: String, transforms: [simd_float4x4]) throws {
        let instancedEntity = try prepareInstancedEntity(for: filename)
        var meshInstances = MeshInstancesComponent()
        let instanceData = try LowLevelInstanceData(instanceCount: transforms.count)
        meshInstances[partIndex: 0] = instanceData
        instanceData.withMutableTransforms { buffer in
            for (index, matrix) in transforms.enumerated() {
                buffer[index] = matrix
            }
        }
        instancedEntity.components.set(meshInstances)
    }

    private func applyFallbackTransforms(for filename: String, transforms: [simd_float4x4]) throws {
        let baseModel = try loadModel(named: filename)

        if let clones = fallbackClones[filename] {
            for entity in clones {
                entity.removeFromParent()
            }
        }

        var newClones: [Entity] = []
        for matrix in transforms {
            let clone = baseModel.clone(recursive: true)
            clone.transform.matrix = matrix
            anchor.addChild(clone)
            newClones.append(clone)
        }

        fallbackClones[filename] = newClones
    }

    private func makeTransform(for worldPosition: SIMD3<Float>, scale: Float) -> simd_float4x4 {
        let rotation = rotationTowardCenter(from: worldPosition)
        let transform = Transform(scale: SIMD3<Float>(repeating: scale),
                                  rotation: rotation,
                                  translation: worldPosition)
        return transform.matrix
    }

    private func rotationTowardCenter(from worldPosition: SIMD3<Float>) -> simd_quatf {
        let direction = SIMD3<Float>(center.x - worldPosition.x, 0, center.z - worldPosition.z)
        let lengthSquared = simd_length_squared(direction)

        guard lengthSquared > 0.0001 else {
            return simd_quatf(angle: 0, axis: [0, 1, 0])
        }

        let normalized = normalize(direction)
        let angle = atan2(normalized.x, normalized.z)
        return simd_quatf(angle: angle, axis: [0, 1, 0])
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
        let (sinAngle, cosAngle) = (sin(angle), cos(angle))
        return SIMD3<Float>(radius * cosAngle, 0, radius * sinAngle)
    }

    private func isValidPosition(_ position: SIMD3<Float>) -> Bool {
        let worldPosition = position + translation
        let baseKey = gridKey(for: worldPosition)

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
}
