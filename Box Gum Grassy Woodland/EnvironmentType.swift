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
    
    var grassScale: Float
    var closeGrassScale: Float
    var grassSpawnCount: Int
    var closeGrassSpawnCount: Int
}

enum EnvironmentType: String, CaseIterable, Identifiable {
    case grassyWoodland = "Grasslands"
    case desert = "Desert"

    var id: String { rawValue }

    var configuration: EnvironmentConfiguration {
        switch self {
            
        case .desert:
            return EnvironmentConfiguration(
                landscape: loadModel(named: "Desert/DesertEnvrionment"),
                skyCover: loadModel(named: "Desert/Skydome/SkyCover"),
                distantLandscape: loadModel(named: "Desert/Skydome/DistantLand"),
                trees: loadModel(named: "Desert/Trees/Trees"),
                
                grassPatches: [
                    ("Desert/Grass/Billboards/GrassLargeGroup1", 15...120),
                    ("Desert/Grass/Billboards/GrassLargeGroup3", 15...120),
                    ("Desert/Grass/Billboards/Grass2", 5...15),
                ],
                closeGrassPatches: [
                    ("Desert/Grass/models/Grass/Dry_grass.usdc", 0...30),
                    ("Desert/Grass/Billboards/Grass1", 5...15),
                ],
                
                grassScale: 1.3,
                closeGrassScale: 1,
                grassSpawnCount: 2000,
                closeGrassSpawnCount: 1000
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
                    ("Green Grasslands/New Version Assets/Grass/Rytidosperma caespitosum/Rytidosperma_caespitosum_1_LOD1.usdc", 0...20),
                    ("Green Grasslands/New Version Assets/Grass/Rytidosperma caespitosum/Rytidosperma_caespitosum_2_LOD1.usdc", 0...20),
                    ("Green Grasslands/New Version Assets/Grass/Rytidosperma caespitosum/Rytidosperma_caespitosum_3_LOD1.usdc", 0...20),
                    ("Green Grasslands/New Version Assets/Grass/Rytidosperma caespitosum/Rytidosperma_caespitosum_4_LOD1.usdc", 0...20),
                    
                    ("Green Grasslands/New Version Assets/Grass/Themeda Triandra/Themeda_triandra_1_LOD1", 0...20),
                    ("Green Grasslands/New Version Assets/Grass/Themeda Triandra/Themeda_triandra_2_LOD1", 0...20),
                    ("Green Grasslands/New Version Assets/Grass/Themeda Triandra/Themeda_triandra_3_LOD1", 0...20),
                    ("Green Grasslands/New Version Assets/Grass/Themeda Triandra/Themeda_triandra_4_LOD1", 0...20),

                ],
                
                grassScale: 1.3,
                closeGrassScale: 1.1,
                grassSpawnCount: 1800,
                closeGrassSpawnCount: 1500
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
