//
//  ImmersiveView.swift
//  Box Gum Grassy Woodland
//
//  Created by Nam Pham on 10/1/2025.
//

import SwiftUI
import RealityKit
import RealityKitContent

import Foundation

struct ImmersiveView: View {
    @Environment(AppModel.self) var appModel

    var body: some View {
        RealityView { content in
            
            if let scene = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(scene)
            }
            
            if let guy = try? await Entity(named: "Animals/Bird flight", in: realityKitContentBundle) {
                content.add(guy)
            }
            
            let Rytidosperma = TilesLoader(jsonPath: "Rytidosperma caespitosum - tile_data", modelsPath: "Grasses/Rytidosperma caespitosum/", content: content)
            
            let Themeda = TilesLoader(jsonPath: "Themeda Triandra - tile_data", modelsPath: "Grasses/Themeda Triandra/", content: content)
            
            let anchor = AnchorEntity(world: [0, 0, 0])
            let grassPatchSpawner = GrassPatchSpawner()
                    (0..<1000).forEach { _ in
                        anchor.addChild(grassPatchSpawner.spawn())
                    }
            content.add(anchor)
            
            
            print("Environment Loaded")
            
            
        
        }
    }
}

class GrassPatchSpawner: DistantSpawner {
    init(scale: Float = 1) {
        super.init(modelFilenames: [
            ("Grasses/Billboard Grass/grass patch", 14...250),
            ("Grasses/Billboard Grass/grass patch 2", 14...250),
            ("Grasses/Billboard Grass/grass patch 3", 14...250),
        ], scale: scale, minimumSpacing: 4)
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
