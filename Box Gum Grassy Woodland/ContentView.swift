//
//  ContentView.swift
//  Box Gum Grassy Woodland
//
//  Created by Nam Pham on 10/1/2025.
//

import SwiftUI
import RealityKit

struct ContentView: View {

    var body: some View {
        
        Text("AR Reconstruction of the Box Gum Grassy Woodland")
        
        VStack {
            ToggleImmersiveSpaceButton()
        }
    }
}

#Preview(windowStyle: .plain) {
    ContentView()
        .environment(AppModel())
}
