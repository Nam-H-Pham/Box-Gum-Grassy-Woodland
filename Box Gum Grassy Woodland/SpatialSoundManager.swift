//
//  SpatialSoundManager.swift
//  Grassy Woodland
//
//  Created by Nam Pham on 10/10/2024.
//
import SwiftUI
import RealityKit
import RealityKitContent


class SpatialSoundManager {
    private let soundFiles: [String]
    
    init(soundFiles: [String]) {
        self.soundFiles = soundFiles
    }
    
    func generateRandomPosition(radius: Float) -> SIMD3<Float> {
        let theta = Float.random(in: 0...Float.pi * 2)
        let phi = Float.random(in: 0...Float.pi)
        let x = radius * sin(phi) * cos(theta)
        let y = radius * sin(phi) * sin(theta)
        let z = radius * cos(phi)
        
        return SIMD3<Float>(x, y, z)
    }
    
    func spawn(soundFile: String) -> Entity {
        let entity = Entity()
        
        let randomPosition = generateRandomPosition(radius: 4)
        entity.position = randomPosition
        
        entity.addChild(createSpatialAudio(filename: soundFile))
        
        return entity
    }
    
    func spawnAll() -> [Entity] {
        let entities: [Entity] = self.soundFiles.map(spawn)
        return entities
    }
    
    func createSpatialAudio(filename: String) -> Entity {
            // refer to https://www.createwithswift.com/adding-spatial-audio-to-an-entity-with-realitykit/
        
            // 1. Create an audio source entity
            let audioSource = Entity()
            
            // 2. Add a spatial audio component with a gain level
            audioSource.spatialAudio = SpatialAudioComponent(gain: -2)
            
            // Setting directivity property
        audioSource.spatialAudio?.directivity = .beam(focus: 0.0)
            
            do {
                // 3. Load the audio file resource with looping configuration
                let resource = try AudioFileResource.load(
                    named: filename,
                    configuration: .init(shouldLoop: true))

                // 4. Play the audio resource on the entity
                audioSource.playAudio(resource)
            } catch {
                // Handle the error if the audio file fails to load
                print("Error loading audio file: \(error.localizedDescription)")
            }
            
            // 5. Return the audio source entity
            return audioSource
        }
}
