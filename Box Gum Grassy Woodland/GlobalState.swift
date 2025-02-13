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
    
    @Published var landscape = try? ModelEntity.load(named: "Immersive", in: realityKitContentBundle)
    @Published var skyCover = try? ModelEntity.load(named: "SkyDome/SkyCover", in: realityKitContentBundle)
    
    @Published var grassPatchSpawner = GrassPatchSpawner(anchor: AnchorEntity(world: [0, 0, 0]))
    
    @Published var Rytidosperma = TilesLoader(
        jsonPath: "Rytidosperma caespitosum - tile_data",
        modelsPath: "Grasses/Rytidosperma caespitosum/",
        anchor: AnchorEntity(world: [0, 0, 0])
    )
    
    @Published var Themeda = TilesLoader(
        jsonPath: "Themeda Triandra - tile_data",
        modelsPath: "Grasses/Themeda Triandra/",
        anchor: AnchorEntity(world: [0, 0, 0])
    )
}

class GrassPatchSpawner: DistantSpawner {
    init(anchor: AnchorEntity) {
        super.init(anchor: anchor, modelFilenames: [
            ("Grasses/Billboard Grass/grass patch", 15...150),
            ("Grasses/Billboard Grass/grass patch 2", 15...150),
            ("Grasses/Billboard Grass/grass patch 3", 15...150),
        ], scale: 0.9, minimumSpacing: 4)
    }
}
