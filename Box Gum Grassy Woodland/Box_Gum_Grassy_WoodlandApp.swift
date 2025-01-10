//
//  Box_Gum_Grassy_WoodlandApp.swift
//  Box Gum Grassy Woodland
//
//  Created by Nam Pham on 10/1/2025.
//

import SwiftUI

@main
struct Box_Gum_Grassy_WoodlandApp: App {
    
    @State private var appModel = AppModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
        }
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
