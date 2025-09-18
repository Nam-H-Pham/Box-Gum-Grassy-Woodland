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
        ZStack {
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

                if let cameraTransform = content.cameraTransform {
                    globalState.distantMetalRenderer?.updateCameraTransform(cameraTransform)
                }

            }
            if let renderer = globalState.distantMetalRenderer, globalState.showGrass {
                MetalBillboardView(renderer: renderer)
                    .opacity(globalState.showGrass ? 1 : 0)
            }
        }
        .onAppear {
            globalState.nearbyGrass.spawnAll()
            globalState.grassPatchSpawner.spawnAll()
            globalState.grassClosePatchSpawner.spawnAll()
        }
    }

    private func startSequence(content: RealityViewContent) async {
        let steps: [SequenceStep] = [
            .init(delay: 0, progress: 0.3, action: addGrass),
            .init(delay: 4, progress: 0.5, action: addTrees),
            .init(delay: 8, progress: 1, action: addLandscape),
            .init(delay: 10, progress: 1, action: addDistantLandscape),
            .init(delay: 12, progress: 1, action: addSkyCover),
        ]

        steps.forEach { step in
            schedule(step: step, for: content)
        }
    }

    private func addLandscape(to content: RealityViewContent) {
        addEntity(named: "Landscape", entity: globalState.landscape, to: content, fadeDuration: 2)
    }

    private func addTrees(to content: RealityViewContent) {
        addEntity(named: "Trees", entity: globalState.trees, to: content, fadeDuration: 2) { entity in
            applyEnvironmentLighting(to: entity)
            if let landscape = globalState.landscape {
                applyEnvironmentLighting(to: landscape)
            }
        }
    }

    private func addSkyCover(to content: RealityViewContent) {
        addEntity(named: "SkyCover", entity: globalState.skyCover, to: content, fadeDuration: 10)
    }

    private func addDistantLandscape(to content: RealityViewContent) {
        addEntity(named: "DistantLandscape", entity: globalState.distantLandscape, to: content, fadeDuration: 10)
    }

    private func addGrass(to content: RealityViewContent) {
        grassAnchor.name = "GrassAnchor"
        let anchors = [
            globalState.grassPatchSpawner.getAnchor(),
            globalState.grassClosePatchSpawner.getAnchor(),
            globalState.nearbyGrass.getAnchor(),
        ]

        anchors.forEach { anchor in
            grassAnchor.addChild(anchor)
            applyEnvironmentLighting(to: anchor)
        }

        setInvisible(entity: grassAnchor)
        content.add(grassAnchor)
        fade(for: grassAnchor, to: 1, duration: 5)
    }

    private func updateProgress(progress: Double) async {
        globalState.progress = progress
        await Task.yield()
    }

    private func schedule(step: SequenceStep, for content: RealityViewContent) {
        DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
            Task {
                await updateProgress(progress: step.progress)
                step.action(content)
            }
        }
    }

    private func addEntity(named name: String, entity: Entity?, to content: RealityViewContent, fadeDuration: TimeInterval, configure: ((Entity) -> Void)? = nil) {
        guard let entity else { return }
        entity.name = name
        configure?(entity)
        setInvisible(entity: entity)
        content.add(entity)
        fade(for: entity, to: 1, duration: fadeDuration)
    }

    private func applyEnvironmentLighting(to entity: Entity) {
        entity.components.set(EnvironmentLightingConfigurationComponent(
            environmentLightingWeight: globalState.envLightIntensity))
    }

    private func setInvisible(entity: Entity) {
        let opacityComponent = OpacityComponent(opacity: 0)
        entity.components.set(opacityComponent)
    }

    private func fade(for entity: Entity, to targetOpacity: Float, duration: TimeInterval, timing: AnimationTimingFunction = .linear) {

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

    private struct SequenceStep {
        let delay: TimeInterval
        let progress: Double
        let action: (RealityViewContent) -> Void
    }
}
