import SwiftUI
import RealityKit
import RealityKitContent

class BasicSpawner {
    private let modelFilenames: [String]
    private let anchor: AnchorEntity
    
    private let delayBetweenSpawn: TimeInterval
    
    init(anchor: AnchorEntity,
         modelFilenames: [String],
         delayBetweenSpawn: TimeInterval = 0.4) {
        
        self.modelFilenames = modelFilenames
        self.anchor = anchor
        self.delayBetweenSpawn = delayBetweenSpawn
        
    }
    
    func getAnchor() -> AnchorEntity {
        return anchor
    }
    
    func loadModel(named filename: String) throws -> Entity {
        return try ModelEntity.load(named: filename, in: realityKitContentBundle)
    }
    
    func spawn(modelFilename: String) -> Entity {
        do {
            let model = try loadModel(named: modelFilename)
            let entity = model.clone(recursive: true)
            return entity
        } catch {
            fatalError("Failed to load model: \(modelFilename), error: \(error)")
        }
    }
    
    public func spawnAll() {
        removeAll()
        
        for (index, modelFilename) in modelFilenames.enumerated() {
            let delay = Double(index-1) * delayBetweenSpawn
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                let entity = self.spawn(modelFilename: modelFilename)
                self.anchor.addChild(entity)
            }
        }
    }
    
    public func removeAll() {
        anchor.children.removeAll(keepCapacity: true)
    }
}
