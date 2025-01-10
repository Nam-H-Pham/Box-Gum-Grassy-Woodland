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
            // Add the initial RealityKit content
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
            }
        
            let PS = PatchSpawner(jsonPath: "subsquare_coordinates", modelsPath: "Grasses/Rytidosperma caespitosum/", content: content)
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
