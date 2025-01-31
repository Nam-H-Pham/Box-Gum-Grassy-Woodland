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
            
            let Rytidosperma = PatchSpawner(jsonPath: "Rytidosperma caespitosum - tile_data", modelsPath: "Grasses/Rytidosperma caespitosum/", content: content)
//            let Rytidosperma = PatchSpawner(jsonPath: "Rytidosperma caespitosum Dense - tile_data", modelsPath: "Grasses/Rytidosperma caespitosum/", content: content)
            
            let Themeda = PatchSpawner(jsonPath: "Themeda Triandra - tile_data", modelsPath: "Grasses/Themeda Triandra/", content: content)
//            let Themeda = PatchSpawner(jsonPath: "Themeda Triandra Dense - tile_data", modelsPath: "Grasses/Themeda Triandra/", content: content)
            
            
            
            class EnvironmentSoundManager: SpatialSoundManager {
                init() {
                    super.init(soundFiles:[
                        "Fan_Tailed_Cuckoo",
                        "Flies",
                        "Gang_Gang_Cockatoo",
                        "Rainbow Bee Eater",
                        "Red Wattlebird"
                    ])
                }
            }
            let anchor = AnchorEntity(world: [0, 0, 0])
            anchor.addChild(AnchorEntity(plane: .horizontal))
            let environmentSoundManager = EnvironmentSoundManager()
            let spatialSoundEntities = environmentSoundManager.spawnAll()
            spatialSoundEntities.forEach { anchor.addChild($0) }
            content.add(anchor)
            
            print("Environment Loaded")
            
            
        
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
