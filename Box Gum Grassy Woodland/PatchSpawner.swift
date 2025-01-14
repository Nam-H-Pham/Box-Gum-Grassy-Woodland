import Foundation
import _RealityKit_SwiftUI
import RealityKit
import RealityKitContent
import simd

class PatchSpawner {
    
    var jsonData: [String: Any] = [:]
    var models: [String: Entity] = [:]
    let modelsPath: String
    
    let anchor = AnchorEntity(world: [0, 0, 0])
    let content: RealityViewContent
    
    func SizeSpacingtoKey(size: Float, spacing: Float) -> String {
        return "\(size)_\(spacing)"
    }
    
    init(jsonPath: String, modelsPath: String, content: RealityViewContent) {
        
        self.modelsPath = modelsPath
        self.content = content  
        anchor.addChild(AnchorEntity(plane: .horizontal))
        content.add(anchor)
        
        // Get the URL for the Resources folder in the app bundle
        if let resourceURL = Bundle.main.url(forResource: jsonPath, withExtension: "json") {
            do {
                // Read the content of the JSON file
                let data = try Data(contentsOf: resourceURL)
                
                // Parse the JSON data into a dictionary
                if let jsonDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    self.jsonData = jsonDictionary
                    LoadModels(jsonData: jsonDictionary)
                } else {
                    print("Unable to parse JSON into a dictionary")
                }
                
            } catch {
                print("Failed to read file: \(error)")
            }
        } else {
            print("Resource file not found!")
        }
        
        print(self.models.keys)
    }
    
    
    func LoadModels(jsonData: [String: Any]) {
        print("Loading Models")
        
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
                    models[key] =  loadModel(named: self.modelsPath + key)
                }
                
                let model = models[key]!
                
                let clone = model.clone(recursive: true)
//                let clone = loadCube()
                clone.position = SIMD3<Float>(Float(origin[0]), 0, Float(origin[1]))
                let uniformScale = Float(1)
                clone.scale = SIMD3<Float>(uniformScale, uniformScale, uniformScale)
                
                let angle = [0, 90, 180, 270].randomElement()! * Float.pi / 180
                clone.transform.rotation = simd_quatf(angle: angle, axis: [0, 1, 0])
                
                anchor.addChild(clone)
                content.entities.append(clone)
            }
        }
        print("Loaded Models")
    }
    
    
    
    func loadCube() -> Entity {
        // Create a mesh for the cube
        let mesh = MeshResource.generateBox(size: 1) // Adjust size as needed
        let entity = ModelEntity(mesh: mesh)
        return entity
    }

    
    func loadModel(named filename: String) -> Entity {
        do {
            return try ModelEntity.load(named: filename, in: realityKitContentBundle)
        } catch {
            fatalError("Failed to load model: \(filename), error: \(error)")
        }
    }
}
