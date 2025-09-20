import SwiftUI
import MetalKit

struct MetalBillboardView: View {
    @ObservedObject var renderer: MetalBillboardRenderer

    var body: some View {
        MetalBillboardViewRepresentable(renderer: renderer)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

#if os(macOS)
private struct MetalBillboardViewRepresentable: NSViewRepresentable {
    let renderer: MetalBillboardRenderer

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        renderer.configure(view: view)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        renderer.configure(view: nsView)
    }
}
#else
private struct MetalBillboardViewRepresentable: UIViewRepresentable {
    let renderer: MetalBillboardRenderer

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        renderer.configure(view: view)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        renderer.configure(view: uiView)
    }
}
#endif
