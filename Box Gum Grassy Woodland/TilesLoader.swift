import Foundation
import _RealityKit_SwiftUI
import RealityKit
import RealityKitContent
import simd

class TilesLoader {
    
    var jsonData: [String: Any] = [:]
    var models: [String: Entity] = [:]
    let modelsPath: String
    
    let anchor: AnchorEntity
    
    func SizeSpacingtoKey(size: Float, spacing: Float) -> String {
        return "\(size)_\(spacing)"
    }
    
    func getAnchor() -> AnchorEntity {
        return anchor
    }
    
    init(jsonPath: String, modelsPath: String, anchor: AnchorEntity) {
        self.modelsPath = modelsPath
        self.anchor = anchor
        
        Task {
            await loadJSONAndModels(jsonPath: jsonPath)
        }
    }
    
    func loadJSONAndModels(jsonPath: String) async {
        // Get the URL for the Resources folder in the app bundle
        if let resourceURL = Bundle.main.url(forResource: jsonPath, withExtension: "json") {
            do {
                // Read the content of the JSON file
                let data = try Data(contentsOf: resourceURL)
                
                // Parse the JSON data into a dictionary
                if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    self.jsonData = jsonDictionary
                    await LoadModels(jsonData: jsonDictionary)
                } else {
                    print("Unable to parse JSON into a dictionary")
                }
                
            } catch {
                print("Failed to read file: \(error)")
            }
        } else {
            print("Resource file not found!")
        }
    }
    
    func LoadModels(jsonData: [String: Any]) async {
        for (patchName, patchData) in jsonData {
            
            guard let patchDict = patchData as? [String: Any] else {
                print("Invalid patch data format for \(patchName)")
                continue // Skip to the next patch if the format is incorrect
            }
            
            if let origin = patchDict["origin"] as? [Double],
               let size = patchDict["size"] as? Double,
               let spacing = patchDict["spacing"] as? Double {
                
                _ = SIMD3<Float>(Float(origin[0]), 0, Float(origin[1]))
                
                let size = Float(size)
                let spacing = Float(spacing)
                
                let key = SizeSpacingtoKey(size: size, spacing: spacing)
                
                if models[key] != nil {
                    // key already exists
                } else {
                    models[key] = await loadModel(named: self.modelsPath + key)
                }
                
                let model = models[key]!
                
                let clone = await model.clone(recursive: true)
                clone.position = SIMD3<Float>(Float(origin[0]), 0, Float(origin[1]))
                let uniformScale = Float(1)
                clone.scale = SIMD3<Float>(uniformScale, uniformScale, uniformScale)
                
                let angle = [0, 90, 180, 270].randomElement()! * Float.pi / 180
                clone.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
                
                await anchor.addChild(clone)
            }
        }
    }
    
    func loadCube() -> Entity {
        // Create a mesh for the cube
        let mesh = MeshResource.generateBox(size: 1) // Adjust size as needed
        let entity = ModelEntity(mesh: mesh)
        return entity
    }

    func loadModel(named filename: String) async -> Entity {
        do {
            return try await ModelEntity.load(named: filename, in: realityKitContentBundle)
        } catch {
            fatalError("Failed to load model: \(filename), error: \(error)")
        }
    }
}
