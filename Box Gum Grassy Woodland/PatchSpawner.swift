import Foundation
import _RealityKit_SwiftUI
import RealityKit
import RealityKitContent

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
    
    func loopAndPrintPatchDetails(jsonData: [String: Any]) {
        print("Printing Patch Details")
        
        for (patchName, patchData) in jsonData {
            print("Patch Name: \(patchName)")
            
            guard let patchDict = patchData as? [String: Any] else {
                print("Invalid patch data format for \(patchName)")
                continue // Skip to the next patch if the format is incorrect
            }
            
            if let topLeft = patchDict["top_left"] as? [Double],
               let bottomRight = patchDict["bottom_right"] as? [Double],
               let origin = patchDict["origin"] as? [Double],
               let size = patchDict["size"] as? Double,
               let spacing = patchDict["spacing"] as? Double {
                
                print("  Top Left: \(topLeft)")
                print("  Bottom Right: \(bottomRight)")
                print("  Origin: \(origin)")
                print("  Size: \(size)")
                print("  Spacing: \(spacing)")
                
                // Example of creating a vector from the data
                let originVector = SIMD3<Float>(Float(origin[0]), 0, Float(origin[1]))
                print("  Origin Vector: \(originVector)")
                
            } else {
                print("Missing or incorrect data types for patch \(patchName)")
            }
        }
    }

    
    func LoadModels(jsonData: [String: Any]) {
        print("Loading Models")
        
        for (patchName, patchData) in jsonData {
            
            guard let patchDict = patchData as? [String: Any] else {
                print("Invalid patch data format for \(patchName)")
                continue // Skip to the next patch if the format is incorrect
            }
            
            if let _ = patchDict["top_left"] as? [Double],
               let _ = patchDict["bottom_right"] as? [Double],
               let origin = patchDict["origin"] as? [Double],
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
                
                anchor.addChild(clone)
                content.add(clone)                
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
