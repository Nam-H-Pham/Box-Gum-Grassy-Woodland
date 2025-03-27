import SwiftUI
import RealityKit
import RealityKitContent
import Foundation

struct ImmersiveView: View {
    @EnvironmentObject var globalState: GlobalState
    
    // Anchor for grass
    var grassAnchor: AnchorEntity = AnchorEntity(world: [0, 0, 0])
    
    // Lazy initialization of entitiesToUpdate
    private var entitiesToUpdate: [(String, Bool)] {
        [
            ("SkyCover", globalState.showSkybox),
            ("Landscape", globalState.showLandscape),
            ("GrassAnchor", globalState.showGrass),
            ("DistantLandscape", globalState.showDistantLandscape),
            ("Trees", globalState.showTrees),
        ]
    }
    
    var body: some View {
        RealityView { content in
            
            // Start the timed content loading process
            await startSequence(content: content)
        } update: { content in
            
            // Update the visibility of entities based on global state
            for (name, isEnabled) in entitiesToUpdate {
                if let entity = content.entities.first(where: { $0.name == name }) {
                    entity.isEnabled = isEnabled
                }
            }
            
        }
        .onAppear {
            globalState.nearbyGrass.spawnAll()
            globalState.grassPatchSpawner.spawnAll()
        }
    }

    private func startSequence(content: RealityViewContent) async {
        // Add grass immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0) {
            Task {
                await updateProgress(progress: 0.3)
                addGrass(to: content)
            }
        }
        
        // Add trees after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            Task {
                await updateProgress(progress: 0.5)
                addTrees(to: content)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
            Task {
                await updateProgress(progress: 1)
                addLandscape(to: content)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            Task {
                await updateProgress(progress: 1)
                addDistantLandscape(to: content)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            Task {
                await updateProgress(progress: 1)
                addSkyCover(to: content)
            }
        }
        
        let dissapearTime : Double = 40
        
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + dissapearTime + 2) {
            Task {
                removeSkyCover(from: content)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + dissapearTime + 3) {
            Task {
                removeDistantLandscape(from: content)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + dissapearTime + 6) {
            Task {
                removeLandscape(from: content)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + dissapearTime + 8) {
            Task {
                removeTrees(from: content)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + dissapearTime + 11) {
            Task {
                removeGrass(from: content)
            }
        }
        
        
    }

    private func addLandscape(to content: RealityViewContent) {
        globalState.landscape?.name = "Landscape"
        setInvisible(entity: globalState.landscape ?? Entity())
        content.add(globalState.landscape ?? Entity())
        fade(for: globalState.landscape ?? Entity(), to: 1, duration: 2)
    }

    private func addTrees(to content: RealityViewContent) {
        globalState.trees?.name = "Trees"
        setInvisible(entity: globalState.trees ?? Entity())
        content.add(globalState.trees ?? Entity())
        fade(for: globalState.trees ?? Entity(), to: 1, duration: 2)
    }

    private func addSkyCover(to content: RealityViewContent) {
        globalState.skyCover?.name = "SkyCover"
        setInvisible(entity: globalState.skyCover ?? Entity())
        content.add(globalState.skyCover ?? Entity())
        fade(for: globalState.skyCover ?? Entity(), to: 1, duration: 10)
    }

    private func addDistantLandscape(to content: RealityViewContent) {
        globalState.distantLandscape?.name = "DistantLandscape"
        setInvisible(entity: globalState.distantLandscape ?? Entity())
        content.add(globalState.distantLandscape ?? Entity())
        fade(for: globalState.distantLandscape ?? Entity(), to: 1, duration: 10)
    }

    private func addGrass(to content: RealityViewContent) {
        grassAnchor.name = "GrassAnchor"
        grassAnchor.addChild(globalState.grassPatchSpawner.getAnchor())
        grassAnchor.addChild(globalState.nearbyGrass.getAnchor())
        setInvisible(entity: grassAnchor)
        content.add(grassAnchor)
        fade(for: grassAnchor, to: 1, duration: 5)
    }

    private func removeLandscape(from content: RealityViewContent) {
        if let landscape = content.entities.first(where: { $0.name == "Landscape" }) {
            fade(for: landscape, to: 0, duration: 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                content.remove(landscape)
            }
        }
    }

    private func removeTrees(from content: RealityViewContent) {
        if let trees = content.entities.first(where: { $0.name == "Trees" }) {
            fade(for: trees, to: 0, duration: 2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                content.remove(trees)
            }
        }
    }

    private func removeSkyCover(from content: RealityViewContent) {
        if let skyCover = content.entities.first(where: { $0.name == "SkyCover" }) {
            fade(for: skyCover, to: 0, duration: 4)
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                content.remove(skyCover)
            }
        }
    }

    private func removeDistantLandscape(from content: RealityViewContent) {
        if let distantLandscape = content.entities.first(where: { $0.name == "DistantLandscape" }) {
            fade(for: distantLandscape, to: 0, duration: 3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                content.remove(distantLandscape)
            }
        }
    }

    private func removeGrass(from content: RealityViewContent) {
        if let grass = content.entities.first(where: { $0.name == "GrassAnchor" }) {
            fade(for: grass, to: 0, duration: 4)
//            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
//                grass.children.removeAll()
//                content.remove(grass)
//            }
        }
    }

    private func updateProgress(progress: Double) async {
        globalState.progress = progress
        await Task.yield()
    }
    
    func setInvisible(entity: Entity) {
        let opacityComponent = OpacityComponent(opacity: 0)
        entity.components.set(opacityComponent)
    }
    
    func fade(for entity: Entity, to targetOpacity: Float, duration: TimeInterval, timing: AnimationTimingFunction = .linear) {
        
        let opacityAction = FromToByAction<Float>(to: targetOpacity,
                                                  timing: timing,
                                                  isAdditive: false)
        do {
            let opacityAnimation = try AnimationResource
                .makeActionAnimation(for: opacityAction,
                                     duration: duration,
                                     bindTarget: .opacity)
            
            entity.playAnimation(opacityAnimation)
        } catch {
            print("Error when fading entity: \(error)")
        }
    }

}
