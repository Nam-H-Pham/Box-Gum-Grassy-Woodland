import SwiftUI
import RealityKit
import RealityKitContent

class GlobalState: ObservableObject {
    
    @Published var progress: Double = 0.0
    @Published var showSkybox: Bool = true
    @Published var showDistantLandscape: Bool = true
    @Published var showTrees: Bool = true
    @Published var showLandscape: Bool = true
    @Published var showGrass: Bool = true

    @Published var envLightIntensity: Float = 0.9

    @Published var landscape: Entity!
    @Published var skyCover: Entity!
    @Published var distantLandscape: Entity!
    @Published var trees: Entity!

    @Published var grassPatchSpawner: DistantSpawner!
    @Published var grassClosePatchSpawner: DistantSpawner!
    @Published var nearbyGrass: BasicSpawner!

    init(configuration: EnvironmentConfiguration) {
        loadEnvironment(configuration: configuration)
    }

    private func loadEnvironment(configuration: EnvironmentConfiguration) {
        // Use preloaded models from the configuration directly
        landscape = configuration.landscape
        skyCover = configuration.skyCover
        distantLandscape = configuration.distantLandscape
        trees = configuration.trees

        grassPatchSpawner = DistantSpawner(
            anchor: AnchorEntity(world: [0, 0, 0]),
            modelFilenames: configuration.grassPatches.map { ($0.path, Float($0.range.lowerBound)...Float($0.range.upperBound)) },
            scale: configuration.grassScale,
            spawnCount: configuration.grassSpawnCount,
            batchSize: 50,
            delayBetweenBatches: 0.5
        )

        grassClosePatchSpawner = DistantSpawner(
            anchor: AnchorEntity(world: [0, 0, 0]),
            modelFilenames: configuration.closeGrassPatches.map { ($0.path, Float($0.range.lowerBound)...Float($0.range.upperBound)) },
            scale: configuration.closeGrassScale,
            spawnCount: configuration.closeGrassSpawnCount,
            batchSize: 50,
            delayBetweenBatches: 0.5
        )


        nearbyGrass = BasicSpawner(
            anchor: AnchorEntity(world: [0, 0, 0]),
            modelFilenames: configuration.nearbyGrass.map { ($0) },
            delayBetweenSpawn: 1
        )
    }

}

