import SwiftUI
import SceneKit
#if os(macOS)
import AppKit
private typealias BoardColor = NSColor
#else
import UIKit
private typealias BoardColor = UIColor
#endif

/// A native, lit 3D board. GameEngine remains the sole authority for legal moves.
struct Board3DView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @EnvironmentObject var loc: Localization
    @State private var resetViewRequest = 0
    @State private var zoomStepRequest = 0
    let tiles: [GameTile]
    let freeIDs: Set<Int>
    let selectedID: Int?
    let highlightedIDs: Set<Int>
    let shakeTokens: [Int: Int]
    let generation: Int
    let overhead: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        if voiceOver {
            // A spatial renderer alone has no semantic tile elements. Keep a fully
            // actionable, labelled alternative for VoiceOver, with the same rules.
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 64))]) {
                    ForEach(tiles.filter { !$0.removed }) { tile in
                        Button(action: { onSelect(tile.id) }) {
                            TileFaceView(typeId: tile.typeId ?? "")
                                .frame(width: 44, height: 60).padding(6)
                                .background(Theme.tileFace).cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(tileAccessibilityName(tile.typeId ?? "", loc))
                        .accessibilityValue(freeIDs.contains(tile.id) ? (loc.lang == .pt ? "Livre" : "Free") : (loc.lang == .pt ? "Bloqueada" : "Blocked"))
                        .accessibilityAddTraits(selectedID == tile.id ? [.isSelected] : [])
                    }
                }.padding()
            }
        } else {
            NativeBoardScene(tiles: tiles, freeIDs: freeIDs, selectedID: selectedID,
                             highlightedIDs: highlightedIDs, shakeTokens: shakeTokens,
                             generation: generation, resetViewRequest: resetViewRequest, zoomStepRequest: zoomStepRequest, overhead: overhead,
                             reduceMotion: reduceMotion, onSelect: onSelect)
                .accessibilityHidden(true)
                .overlay(alignment: .bottomTrailing) {
                    HStack(spacing: 2) {
                        cameraButton("minus.magnifyingglass", label: loc.lang == .pt ? "Reduzir" : "Zoom out") { zoomStepRequest -= 1 }
                        cameraButton("plus.magnifyingglass", label: loc.lang == .pt ? "Ampliar" : "Zoom in") { zoomStepRequest += 1 }
                        cameraButton("arrow.up.left.and.arrow.down.right", label: loc.lang == .pt ? "Mostrar mesa inteira" : "Show whole table") { resetViewRequest += 1 }
                    }
                    .padding(4)
                    .background(Theme.bgPanel2.opacity(0.95), in: Capsule())
                    .padding(12)
                }
        }
    }
    private func cameraButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(Theme.text).frame(width: 44, height: 44)
        }.buttonStyle(.plain).accessibilityLabel(label).help(label)
    }

}

final class BoardSceneController: NSObject {
    private weak var view: BoardSceneView?
    private let scene = SCNScene()
    private let table = SCNNode()
    private let pieces = SCNNode()
    private let camera = SCNNode()
    private var nodes: [Int: SCNNode] = [:]
    private var lastTiles: [Int: GameTile] = [:]
    private var lastShakes: [Int: Int] = [:]
    private var textures: [String: Any] = [:]
    private var generation = -1
    private var reduceMotion = false
    private var overhead = false
    private var boardWidth: CGFloat = 8
    private var boardDepth: CGFloat = 10
    private var boardHeight: CGFloat = 1
    private var yaw: Float = 0
    private var dragStart: Float = 0
    private var zoom: CGFloat = 1
    private var pinchStart: CGFloat = 1
    private var pan = CGPoint.zero
    private var panStart = CGPoint.zero
    private var lastResetRequest = 0
    private var lastZoomStepRequest = 0
    private var fittedScale: CGFloat = 1
    var onSelect: (Int) -> Void = { _ in }

    private func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> BoardColor {
        BoardColor(red: r, green: g, blue: b, alpha: a)
    }

    private func material(_ color: BoardColor, roughness: CGFloat = 0.45, metallic: CGFloat = 0) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .physicallyBased
        m.roughness.contents = roughness
        m.metalness.contents = metallic
        // Trilinear mipmaps avoid shimmering; anisotropy preserves the engraved
        // detail and wood grain when seen obliquely, including at maximum zoom.
        m.diffuse.minificationFilter = .linear
        m.diffuse.magnificationFilter = .linear
        m.diffuse.mipFilter = .linear
        m.diffuse.maxAnisotropy = 16
        return m
    }

    func attach(to view: BoardSceneView) {
        self.view = view
        view.scene = scene
        view.backgroundColor = color(0.085, 0.072, 0.060)
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.autoenablesDefaultLighting = false
        view.isPlaying = true
        scene.rootNode.addChildNode(table)
        table.addChildNode(pieces)
        camera.camera = SCNCamera()
        camera.camera?.usesOrthographicProjection = true
        camera.camera?.zNear = 0.1
        camera.camera?.zFar = 200
        camera.camera?.wantsHDR = true
        camera.camera?.exposureOffset = -0.35
        camera.camera?.screenSpaceAmbientOcclusionIntensity = 0.65
        camera.camera?.screenSpaceAmbientOcclusionRadius = 0.3
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 420
        ambient.light?.color = color(0.95, 0.94, 0.90)
        scene.rootNode.addChildNode(ambient)
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 780
        key.light?.color = color(1, 0.91, 0.75)
        key.light?.castsShadow = true
        key.light?.shadowRadius = 8
        key.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        key.light?.shadowColor = color(0.04, 0.025, 0.01, 0.35)
        key.eulerAngles = SCNVector3(-Float.pi / 3, -Float.pi / 5, 0)
        scene.rootNode.addChildNode(key)

        #if os(macOS)
        let tap = NSClickGestureRecognizer(target: self, action: #selector(tap(_:)))
        let drag = NSPanGestureRecognizer(target: self, action: #selector(drag(_:)))
        let pinch = NSMagnificationGestureRecognizer(target: self, action: #selector(pinch(_:)))
        #else
        let tap = UITapGestureRecognizer(target: self, action: #selector(tap(_:)))
        let drag = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
        drag.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:)))
        #endif
        view.addGestureRecognizer(tap)
        view.addGestureRecognizer(drag)
        view.addGestureRecognizer(pinch)
        view.onResize = { [weak self] in self?.fitCamera() }
    }

    func update(tiles: [GameTile], freeIDs: Set<Int>, selectedID: Int?, highlightedIDs: Set<Int>,
                shakeTokens: [Int: Int], generation: Int, resetViewRequest: Int, zoomStepRequest: Int, overhead: Bool, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        let fresh = self.generation != generation
        if fresh || resetViewRequest != lastResetRequest || self.overhead != overhead {
            zoom = 1
            pan = .zero
            lastResetRequest = resetViewRequest
            lastZoomStepRequest = zoomStepRequest
        }
        self.overhead = overhead
        if zoomStepRequest != lastZoomStepRequest {
            setZoom(zoom * pow(1.25, CGFloat(zoomStepRequest - lastZoomStepRequest)))
            lastZoomStepRequest = zoomStepRequest
        }
        if fresh {
            self.generation = generation
            nodes.values.forEach { $0.removeAllActions(); $0.removeFromParentNode() }
            // Include outgoing, animated nodes from the previous deal.
            pieces.childNodes.forEach { $0.removeFromParentNode() }
            nodes = [:]
            lastTiles = [:]
            lastShakes = [:]
            yaw = -0.18
            table.eulerAngles = SCNVector3(0, yaw, 0)
            buildTable(tiles)
        }
        let extents = BoardExtents(tiles: tiles)
        let centerX = Float(extents.minX + extents.maxX) / 2
        let centerZ = Float(extents.minY + extents.maxY) / 2
        let activeIDs = Set(tiles.filter { !$0.removed }.map(\.id))
        for id in Array(nodes.keys) where !activeIDs.contains(id) {
            guard let node = nodes.removeValue(forKey: id) else { continue }
            node.name = nil
            node.enumerateChildNodes { child, _ in child.name = nil }
            if reduceMotion { node.removeFromParentNode() }
            else {
                let lift = SCNAction.moveBy(x: 0, y: 1.8, z: 0, duration: 0.24)
                lift.timingMode = .easeOut
                node.runAction(.sequence([
                    .group([lift, .rotateBy(x: 0, y: 0.4, z: 0.2, duration: 0.24)]),
                    .group([.scale(to: 0.1, duration: 0.18), .fadeOut(duration: 0.18)]),
                    .removeFromParentNode()
                ]))
                sparkle(at: node.position)
            }
        }
        for tile in tiles where !tile.removed {
            let isNew = nodes[tile.id] == nil
            let node: SCNNode
            if let existing = nodes[tile.id] { node = existing }
            else {
                node = makeTile(id: tile.id)
                nodes[tile.id] = node
                pieces.addChildNode(node)
            }
            if isNew || lastTiles[tile.id]?.typeId != tile.typeId {
                node.childNode(withName: "face", recursively: false)?.geometry?.firstMaterial?.diffuse.contents = texture(tile.typeId ?? "p1")
            }
            let selected = selectedID == tile.id
            let highlighted = highlightedIDs.contains(tile.id)
            let target = SCNVector3((Float(tile.x) - centerX) * 1.12,
                                    Float(tile.z) * 0.60 + (selected ? 0.95 : 0.30),
                                    (Float(tile.y) - centerZ) * 1.51)
            let glow = node.childNode(withName: "rim", recursively: false)?.geometry?.firstMaterial
            glow?.emission.contents = selected ? color(0.75, 0.40, 0.08) : (highlighted ? color(0.04, 0.48, 0.33) : color(0, 0, 0))
            let face = node.childNode(withName: "face", recursively: false)?.geometry?.firstMaterial
            face?.multiply.contents = freeIDs.contains(tile.id) ? color(1, 1, 1) : color(0.91, 0.90, 0.87)
            if isNew && !reduceMotion {
                node.position = SCNVector3(target.x, target.y + 3, target.z)
                node.opacity = 0
                let settle = SCNAction.move(to: target, duration: 0.38)
                settle.timingMode = .easeOut
                node.runAction(.sequence([.wait(duration: Double(tile.id % 24) * 0.012), .group([settle, .fadeIn(duration: 0.25)])]), forKey: "position")
            } else if node.position.x != target.x || node.position.y != target.y || node.position.z != target.z {
                node.removeAction(forKey: "position")
                if reduceMotion { node.position = target }
                else {
                    let move = SCNAction.move(to: target, duration: 0.20)
                    move.timingMode = .easeOut
                    node.runAction(move, forKey: "position")
                }
            }
            if shakeTokens[tile.id, default: 0] != lastShakes[tile.id, default: 0], !reduceMotion {
                node.runAction(.sequence([.rotateBy(x: 0, y: 0, z: 0.10, duration: 0.06), .rotateBy(x: 0, y: 0, z: -0.20, duration: 0.12), .rotateBy(x: 0, y: 0, z: 0.10, duration: 0.06)]))
            }
        }
        lastTiles = Dictionary(uniqueKeysWithValues: tiles.map { ($0.id, $0) })
        lastShakes = shakeTokens
        fitCamera()
    }

    private func makeTile(id: Int) -> SCNNode {
        let node = SCNNode()
        node.name = "tile-\(id)"
        let base = SCNBox(width: 1, height: 0.48, length: 1.35, chamferRadius: 0.09)
        base.chamferSegmentCount = 6
        base.firstMaterial = material(color(0.54, 0.32, 0.12), roughness: 0.48)
        let body = SCNNode(geometry: base)
        body.name = "rim"
        node.addChildNode(body)
        let cap = SCNBox(width: 0.99, height: 0.27, length: 1.34, chamferRadius: 0.075)
        cap.chamferSegmentCount = 6
        cap.firstMaterial = material(color(0.88, 0.82, 0.67), roughness: 0.38)
        let ceramic = SCNNode(geometry: cap)
        ceramic.position.y = 0.23
        node.addChildNode(ceramic)
        let face = SCNPlane(width: 0.85, height: 1.20)
        face.cornerRadius = 0.06
        face.firstMaterial = material(color(1, 1, 1), roughness: 0.55)
        let printNode = SCNNode(geometry: face)
        printNode.name = "face"
        printNode.position.y = 0.367
        printNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        node.addChildNode(printNode)
        return node
    }

    @MainActor private func renderTexture(_ typeID: String) -> Any? {
        let content = TraditionalTileArtwork(typeID: typeID)
        let renderer = ImageRenderer(content: content)
        // 192×256 logical points -> 768×1024 actual texels, not an upscaled bitmap.
        // CGImage supplies explicit pixels to SceneKit on both platforms, avoiding
        // an NSImage representation being selected at its logical point size.
        renderer.scale = 4
        renderer.isOpaque = true
        return renderer.cgImage
    }

    private func texture(_ typeID: String) -> Any {
        let key = typeID
        if let cached = textures[key] { return cached }
        // Representable updates and input callbacks execute on the main thread.
        let image = MainActor.assumeIsolated { renderTexture(typeID) } ?? color(1, 0.95, 0.84)
        textures[key] = image
        return image
    }

    private func buildTable(_ tiles: [GameTile]) {
        table.childNodes.filter { $0 !== pieces }.forEach { $0.removeFromParentNode() }
        let e = BoardExtents(tiles: tiles)
        boardWidth = CGFloat(e.maxX - e.minX + 1) * 1.12 + 1.1
        boardDepth = CGFloat(e.maxY - e.minY + 1) * 1.51 + 1.1
        boardHeight = CGFloat(e.maxZ + 1) * 0.60
        let wood = SCNBox(width: boardWidth + 0.45, height: 0.48, length: boardDepth + 0.45, chamferRadius: 0.22)
        let walnut = material(color(0.65, 0.53, 0.39), roughness: 0.65)
        #if os(macOS)
        walnut.diffuse.contents = NSImage(named: "Walnut")
        #else
        walnut.diffuse.contents = UIImage(named: "Walnut")
        #endif
        wood.firstMaterial = walnut
        let frame = SCNNode(geometry: wood)
        frame.position.y = -0.25
        table.addChildNode(frame)
        // Thin inset perimeter, deliberately not a bright gold picture frame.
        let inset = SCNBox(width: boardWidth - 0.02, height: 0.025, length: boardDepth - 0.02, chamferRadius: 0.14)
        inset.firstMaterial = material(color(0.12, 0.075, 0.04), roughness: 0.8)
        let outline = SCNNode(geometry: inset)
        outline.position.y = -0.005
        table.addChildNode(outline)
        let surface = SCNBox(width: boardWidth - 0.10, height: 0.025, length: boardDepth - 0.10, chamferRadius: 0.12)
        surface.firstMaterial = walnut
        let top = SCNNode(geometry: surface)
        top.position.y = 0.005
        table.addChildNode(top)
    }

    private func fitCamera() {
        guard let view, view.bounds.width > 0, view.bounds.height > 0 else { return }
        let angle: CGFloat = overhead ? 0.01 : 0.83
        let aspect = view.bounds.width / view.bounds.height
        let rotatedWidth = boardWidth * CGFloat(cos(yaw)) + boardDepth * CGFloat(abs(sin(yaw)))
        let rotatedDepth = boardDepth * CGFloat(cos(yaw)) + boardWidth * CGFloat(abs(sin(yaw)))
        let visibleHeight = rotatedDepth * cos(angle) + (boardHeight + 1.5) * sin(angle)
        fittedScale = max(visibleHeight, rotatedWidth / aspect) * 0.53
        let limitX = rotatedWidth * 0.5 * (1 - 1 / zoom)
        let limitY = visibleHeight * 0.5 * (1 - 1 / zoom)
        pan.x = min(limitX, max(-limitX, pan.x))
        pan.y = min(limitY, max(-limitY, pan.y))
        let target = SCNVector3(Float(pan.x), Float(pan.y * sin(angle)), Float(-pan.y * cos(angle)))
        camera.position = SCNVector3(Float(pan.x), Float(24 * cos(angle) + pan.y * sin(angle)), Float(24 * sin(angle) - pan.y * cos(angle)))
        camera.look(at: target)
        camera.camera?.orthographicScale = Double(fittedScale / zoom)
    }

    private func sparkle(at position: SCNVector3) {
        for i in 0..<8 {
            let gem = SCNSphere(radius: 0.035)
            gem.firstMaterial = material(color(1, 0.72, 0.25))
            gem.firstMaterial?.emission.contents = color(0.8, 0.35, 0.08)
            let particle = SCNNode(geometry: gem)
            particle.position = position
            pieces.addChildNode(particle)
            let angle = CGFloat(i) * .pi / 4
            particle.runAction(.sequence([
                .group([.moveBy(x: cos(angle) * 0.8, y: 0.7, z: sin(angle) * 0.8, duration: 0.45), .fadeOut(duration: 0.45)]),
                .removeFromParentNode()
            ]))
        }
    }

    #if os(macOS)
    @objc private func tap(_ gesture: NSClickGestureRecognizer) { select(at: gesture.location(in: view)) }
    @objc private func pinch(_ gesture: NSMagnificationGestureRecognizer) {
        if gesture.state == .began { pinchStart = zoom }
        setZoom(pinchStart * (1 + gesture.magnification))
    }
    @objc private func drag(_ gesture: NSPanGestureRecognizer) {
        if gesture.state == .began { dragStart = yaw; panStart = pan }
        let translation = gesture.translation(in: view)
        moveView(CGPoint(x: translation.x, y: -translation.y))
    }
    #else
    @objc private func tap(_ gesture: UITapGestureRecognizer) { select(at: gesture.location(in: view)) }
    @objc private func pinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began { pinchStart = zoom }
        setZoom(pinchStart * gesture.scale)
    }
    @objc private func drag(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .began { dragStart = yaw; panStart = pan }
        moveView(gesture.translation(in: view))
    }
    #endif

    private func setZoom(_ value: CGFloat) {
        guard value.isFinite else { return }
        zoom = min(3, max(1, value))
        if zoom == 1 { pan = .zero }
        fitCamera()
    }

    private func moveView(_ translation: CGPoint) {
        if zoom > 1.01 {
            guard let view else { return }
            let unitsPerPoint = fittedScale * 2 / zoom / max(1, view.bounds.height)
            pan = CGPoint(x: panStart.x - translation.x * unitsPerPoint,
                          y: panStart.y + translation.y * unitsPerPoint)
            fitCamera()
        } else {
            rotate(by: translation.x)
        }
    }

    private func rotate(by translation: CGFloat) {
        guard !reduceMotion else { return }
        yaw = min(0.32, max(-0.32, dragStart + Float(translation) * 0.0025))
        table.eulerAngles = SCNVector3(0, yaw, 0)
        fitCamera()
    }

    private func select(at point: CGPoint) {
        guard let view else { return }
        // Only the first physical surface counts. Never select a covered tile through
        // the tile above it or through the table.
        guard let hit = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.closest.rawValue]).first else { return }
        var node: SCNNode? = hit.node
        while let current = node {
            if let name = current.name, name.hasPrefix("tile-"), let id = Int(name.dropFirst(5)) {
                onSelect(id)
                return
            }
            node = current.parent
        }
    }
}
