import SwiftUI
import RealityKit
import RealityKitContent
import Foundation

struct ImmersiveView: View {
    @EnvironmentObject var globalState: GlobalState
    
    var grassAnchor: AnchorEntity = AnchorEntity(world: [0, 0, 0])
    
    // Lazy initialization of entitiesToUpdate
    private var entitiesToUpdate: [(String, Bool)] {
        [
            ("SkyCover", globalState.showSkybox),
            ("Landscape", globalState.showLandscape),
            ("GrassAnchor", globalState.showGrass)
        ]
    }

    var body: some View {
        RealityView { content in
            
            // Start the loading process in a Task
            await loadContent(in: content)
            
        } update: { content in
            
            // Update the visibility of entities based on global state
            for (name, isEnabled) in entitiesToUpdate {
                if let entity = content.entities.first(where: { $0.name == name }) {
                    entity.isEnabled = isEnabled
                }
            }
            
        }
        .onAppear {
            globalState.Rytidosperma.LoadModels()
            globalState.Themeda.LoadModels()
            
            globalState.landscape?.addShadows()
            
            globalState.grassPatchSpawner.spawnAll()
        }
        
    }


    private func updateProgress(progress: Double) async {
        globalState.progress = progress
        await Task.yield()
    }

    private func loadContent(in content: RealityViewContent) async {
        // Step 1: Load the immersive scene
        await updateProgress(progress: 0.2)
        
        globalState.landscape?.name = "Landscape"
        globalState.landscape?.isEnabled = globalState.showLandscape
        content.add(globalState.landscape ?? Entity())
        await updateProgress(progress: 0.4)

        // Step 2: Load the sky cover
        globalState.skyCover?.name = "SkyCover"
        globalState.skyCover?.isEnabled = globalState.showSkybox
        content.add(globalState.skyCover ?? Entity())
        await updateProgress(progress: 0.6)

        // Step 3: Spawn grass patches in batches
        grassAnchor.name = "GrassAnchor"

        grassAnchor.addChild(globalState.grassPatchSpawner.getAnchor())
        await updateProgress(progress: 0.8)

        // Step 4: Load additional grass models
        grassAnchor.addChild(globalState.Rytidosperma.getAnchor())
        await updateProgress(progress: 0.9)

        grassAnchor.addChild(globalState.Themeda.getAnchor())
        await updateProgress(progress: 0.95)

        // Finalizing the grass anchor
        content.add(grassAnchor)
        
        print("Environment Loaded")
        await updateProgress(progress: 1.0)
        
    }

}
