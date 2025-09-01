import SwiftUI

@main
struct Box_Gum_Grassy_WoodlandApp: App {
    
    @State private var appModel = AppModel()
    @StateObject private var globalState = GlobalState(environmentType: EnvironmentType.grassyWoodland)
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appModel)
                .environmentObject(globalState)
        }
        .windowResizability(.contentSize) // Allow the window to resize based on content
        
        ImmersiveSpace(id: appModel.immersiveSpaceID) {
            ImmersiveView()
                .environmentObject(globalState)
                .environment(appModel)
                .onAppear {
                    appModel.immersiveSpaceState = .open
                }
                .onDisappear {
                    appModel.immersiveSpaceState = .closed
                }
        }
        .immersionStyle(selection: .constant(.mixed), in: .mixed)
        .upperLimbVisibility(Visibility.visible)
    }
}
