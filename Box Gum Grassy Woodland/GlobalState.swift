//
//  GlobalState.swift
//  Box Gum Grassy Woodland
//
//  Created by Nam Pham on 8/2/2025.
//

import SwiftUI
import RealityKit
import RealityKitContent


class GlobalState: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var showSkybox: Bool = true
    @Published var showLandscape: Bool = true
    @Published var showGrass: Bool = true
    
    @Published var landscape = try? ModelEntity.load(named: "New Version Assets/Scene", in: realityKitContentBundle)
    @Published var skyCover = try? ModelEntity.load(named: "SkyDome/SkyCover", in: realityKitContentBundle)
    
    @Published var grassPatchSpawner = DistantSpawner(anchor: AnchorEntity(world: [0, 0, 0]), modelFilenames: [
        ("Grasses/Billboard Grass/grass patch", 18...150),
        ("Grasses/Billboard Grass/grass patch 2", 18...150),
//            ("Grasses/Billboard Grass/grass patch 3", 15...150),
    ], scale: 0.9, spawnCount: 800, batchSize: 100, delayBetweenBatches: 0.5)
    
    @Published var nearbyGrass = BasicSpawner(anchor: AnchorEntity(world: [0, 0, 0]), modelFilenames: [
        ("New Version Assets/Grass/GrassRing_0.5"),
        ("New Version Assets/Grass/GrassRing_1"),
//        ("New Version Assets/Grass/GrassRing_1.1"),
//        ("New Version Assets/Grass/GrassRing_3"),
        ("New Version Assets/Grass/GrassRing_t"),
    ], delayBetweenSpawn: 1)
}
