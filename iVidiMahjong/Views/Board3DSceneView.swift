import SwiftUI
import SceneKit

/// SwiftUI bridge for the 3D board: the SceneKit view and its representable wrapper.
/// BoardSceneController (Board3DView.swift) owns the scene itself.
struct NativeBoardScene {
    let tiles: [GameTile]
    let freeIDs: Set<Int>
    let selectedID: Int?
    let highlightedIDs: Set<Int>
    let shakeTokens: [Int: Int]
    let generation: Int
    let resetViewRequest: Int
    let zoomStepRequest: Int
    let overhead: Bool
    let reduceMotion: Bool
    let onSelect: (Int) -> Void

    func makeCoordinator() -> BoardSceneController { BoardSceneController() }

    func configure(_ view: BoardSceneView, coordinator: BoardSceneController) {
        coordinator.attach(to: view)
        update(view, coordinator: coordinator)
    }

    func update(_ view: BoardSceneView, coordinator: BoardSceneController) {
        coordinator.onSelect = onSelect
        coordinator.update(tiles: tiles, freeIDs: freeIDs, selectedID: selectedID,
                           highlightedIDs: highlightedIDs, shakeTokens: shakeTokens,
                           generation: generation, resetViewRequest: resetViewRequest, zoomStepRequest: zoomStepRequest,
                           overhead: overhead, reduceMotion: reduceMotion)
    }
}

#if os(macOS)
extension NativeBoardScene: NSViewRepresentable {
    func makeNSView(context: Context) -> BoardSceneView {
        let view = BoardSceneView(frame: .zero)
        configure(view, coordinator: context.coordinator)
        return view
    }
    func updateNSView(_ view: BoardSceneView, context: Context) { update(view, coordinator: context.coordinator) }
}
#else
extension NativeBoardScene: UIViewRepresentable {
    func makeUIView(context: Context) -> BoardSceneView {
        let view = BoardSceneView(frame: .zero)
        configure(view, coordinator: context.coordinator)
        return view
    }
    func updateUIView(_ view: BoardSceneView, context: Context) { update(view, coordinator: context.coordinator) }
}
#endif

final class BoardSceneView: SCNView {
    var onResize: (() -> Void)?
    #if os(macOS)
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateDisplayScale()
    }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDisplayScale()
    }
    private func updateDisplayScale() {
        guard let window else { return }
        wantsLayer = true
        layer?.contentsScale = window.backingScaleFactor
    }
    override func layout() { super.layout(); updateDisplayScale(); onResize?() }
    #else
    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDisplayScale()
    }
    private func updateDisplayScale() {
        guard let screen = window?.screen else { return }
        if contentScaleFactor != screen.scale { contentScaleFactor = screen.scale }
    }
    override func layoutSubviews() { super.layoutSubviews(); updateDisplayScale(); onResize?() }
    #endif
}
