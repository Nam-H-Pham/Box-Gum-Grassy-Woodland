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
            
            let Grass = PatchSpawner(jsonPath: "Rytidosperma caespitosum - tile_data", modelsPath: "Grasses/Rytidosperma caespitosum/", content: content)
            
            let Leaves = PatchSpawner(jsonPath: "Leaves - tile_data", modelsPath: "Leaves/", content: content)
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
