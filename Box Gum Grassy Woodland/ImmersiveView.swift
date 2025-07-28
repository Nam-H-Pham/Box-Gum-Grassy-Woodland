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
            globalState.grassClosePatchSpawner.spawnAll()
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
        globalState.trees?.components.set(EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: globalState.envLightIntensity))
        globalState.landscape?.components.set(EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: globalState.envLightIntensity))
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
        grassAnchor.addChild(globalState.grassClosePatchSpawner.getAnchor())
        grassAnchor.addChild(globalState.nearbyGrass.getAnchor())
        setInvisible(entity: grassAnchor)
        globalState.nearbyGrass.getAnchor().components.set(EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: globalState.envLightIntensity))
        globalState.grassPatchSpawner.getAnchor().components.set(EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: globalState.envLightIntensity))
        globalState.grassClosePatchSpawner.getAnchor().components.set(EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: globalState.envLightIntensity))
        content.add(grassAnchor)
        fade(for: grassAnchor, to: 1, duration: 5)
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
