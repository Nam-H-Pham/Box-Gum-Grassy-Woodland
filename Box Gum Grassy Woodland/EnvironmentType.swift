import Foundation
import RealityKit
import RealityKitContent


/// Represents all configuration for a specific environment
struct EnvironmentConfiguration {
    var landscape: Entity
    var skyCover: Entity
    var distantLandscape: Entity
    var trees: Entity
    
    var grassPatches: [(path: String, range: ClosedRange<Int>)]
    var closeGrassPatches: [(path: String, range: ClosedRange<Int>)]
    var nearbyGrass: [String]
    
    var grassScale: Float
    var closeGrassScale: Float
    var grassSpawnCount: Int
    var closeGrassSpawnCount: Int
}

enum EnvironmentType: String, CaseIterable, Identifiable {
    case grassyWoodland = "Grassy Woodland"
    case desert = "Desert"

    var id: String { rawValue }

    var configuration: EnvironmentConfiguration {
        switch self {
            
            
        case .desert:
            return EnvironmentConfiguration(
                landscape: loadModel(named: "Desert/DesertEnvrionment"),
                skyCover: loadModel(named: "Green Grasslands/SkyDome/SkyCover"),
                distantLandscape: loadModel(named: "Green Grasslands/SkyDome/DistantLand"),
                trees: loadModel(named: "Desert/Trees/Trees"),
                
                grassPatches: [
                    ("Green Grasslands/New Version Assets/Grass/Billboards/GrassGroupLargeBillboard1.usda", 15...100),
                    ("Green Grasslands/New Version Assets/Grass/Billboards/GrassGroupLargeBillboard2.usda", 15...100)
                ],
                closeGrassPatches: [
                    ("Green Grasslands/New Version Assets/Grass/Billboards/GrassGroupBillboard1.usda", 1...15),
                    ("Green Grasslands/New Version Assets/Grass/Billboards/GrassGroupBillboard2.usda", 1...15),
                    ("Green Grasslands/New Version Assets/Grass/Billboards/GrassGroupBillboard3.usda", 1...15)
                ],
                nearbyGrass: [
                    "Desert/Grass/3.75_0.8_ring",
//                    "Desert/Grass/7.5_1.6_ring",
                    "Desert/Grass/15.0_3.2.usda"
                ],
                
                grassScale: 1.3,
                closeGrassScale: 1.1,
                grassSpawnCount: 40,
                closeGrassSpawnCount: 10
            )
            
        case .grassyWoodland:
            return EnvironmentConfiguration(
                landscape: loadModel(named: "Green Grasslands/New Version Assets/Scene"),
                skyCover: loadModel(named: "Green Grasslands/SkyDome/SkyCover"),
                distantLandscape: loadModel(named: "Green Grasslands/SkyDome/DistantLand"),
                trees: loadModel(named: "Green Grasslands/New Version Assets/SceneTrees"),
                
                grassPatches: [
                    ("Green Grasslands/New Version Assets/Grass/Billboards/GrassGroupLargeBillboard1.usda", 15...100),
                    ("Green Grasslands/New Version Assets/Grass/Billboards/GrassGroupLargeBillboard2.usda", 15...100)
                ],
                closeGrassPatches: [
                    ("Green Grasslands/New Version Assets/Grass/Billboards/GrassGroupBillboard1.usda", 1...15),
                    ("Green Grasslands/New Version Assets/Grass/Billboards/GrassGroupBillboard2.usda", 1...15),
                    ("Green Grasslands/New Version Assets/Grass/Billboards/GrassGroupBillboard3.usda", 1...15)
                ],
                nearbyGrass: ["Green Grasslands/New Version Assets/Grass/GrassRing_0.5"],
                
                grassScale: 1.3,
                closeGrassScale: 1.1,
                grassSpawnCount: 1200,
                closeGrassSpawnCount: 400
            )
        }
    
    }
    
    private func loadModel(named name: String) -> Entity {
        do {
            let model = try ModelEntity.load(named: name, in: realityKitContentBundle)
            print("✅ Loaded: \(name)")
            return model
        } catch {
            print("❌ Failed to load: \(name) — \(error)")
            return ModelEntity()
        }
    }
}
