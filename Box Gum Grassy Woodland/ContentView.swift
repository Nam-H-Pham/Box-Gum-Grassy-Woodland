import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @State private var appModel = AppModel()
    @EnvironmentObject var globalState: GlobalState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("AR Reconstruction of the Australian Grasslands")
                .font(.title)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            
            // Environment selector
            Picker("Environment", selection: $globalState.environmentType) {
                ForEach(EnvironmentType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 340)
            .onChange(of: globalState.environmentType) { newType in
                globalState.loadEnvironment(envType: newType)
            }
            
            // Show the progress bar only when loading is in progress
            if globalState.progress > 0 && globalState.progress < 1.0 {
                VStack(spacing: 10) {
                    Text("Loading, please wait...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    ProgressView(value: globalState.progress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(.green) // Change the color of the progress bar to green
                        .frame(width: 300) // Set a custom width for the progress bar
                        .padding(.horizontal)
                }
            } else {
                ToggleImmersiveSpaceButton()
                    .padding(.vertical, 10)
                
                // Dropdown section for additional settings
                DisclosureGroup("Developer Settings") {
                    VStack(alignment: .leading, spacing: 10) {
                        
                        
                        // Environment Light Intensity slider
                        HStack {
                            Text("Env. Light Intensity:")
                            Slider(value: $globalState.envLightIntensity, in: 0...0.9, step: 0.1)
                                .frame(width: 200)
                            Text("\(globalState.envLightIntensity, specifier: "%.1f")")
                                .frame(width: 40, alignment: .trailing)
                        }
                        .padding(.vertical, 5)
                        
                        
                        Toggle("Show Skybox", isOn: $globalState.showSkybox)
                            .padding(.vertical, 5)
                        Toggle("Show Landscape", isOn: $globalState.showLandscape)
                            .padding(.vertical, 5)
                        Toggle("Show Grass", isOn: $globalState.showGrass)
                            .padding(.vertical, 5)
                        Toggle("Show Trees", isOn: $globalState.showTrees)
                            .padding(.vertical, 5)
                        Toggle("Show Distant Land", isOn: $globalState.showDistantLandscape)
                            .padding(.vertical, 5)
                    }
                    .padding(.top, 10)
                }
                .padding()
                .background(Color(.systemGray6).opacity(0.1))
                .cornerRadius(30)
                .padding(.horizontal)
            }
        }
        .frame(width: 500, height: 500) // Adjusted height to accommodate the new dropdown section
        .padding(20)
        .fixedSize(horizontal: true, vertical: true)
    }
}
