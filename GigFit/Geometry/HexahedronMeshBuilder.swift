import Foundation
import SceneKit
import simd

/// Builds a standalone SCNScene for the non-AR 3D review view.
enum HexahedronMeshBuilder {

    static func buildScene(from points: [ScanPointLabel: SIMD3<Float>],
                            dimensions: ScanDimensions? = nil) -> SCNScene {
        let scene = SCNScene()

        // Background
        scene.background.contents = UIColor(red: 0.06, green: 0.06, blue: 0.14, alpha: 1.0)

        // Ambient + directional light
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.6, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        let directional = SCNNode()
        directional.light = SCNLight()
        directional.light?.type = .directional
        directional.light?.intensity = 800
        directional.position = SCNVector3(5, 5, 5)
        directional.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directional)

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(2.5, 1.8, 3.5)
        cameraNode.look(at: SCNVector3Zero)

        scene.rootNode.addChildNode(cameraNode)

        // Hexahedron
        var corners: [ScanPointLabel: SCNVector3] = [:]
        // Center the hexahedron at origin for review
        let allPositions = Array(points.values)
        let center = SIMDHelpers.centroid(of: allPositions)
        for (label, pos) in points {
            let centered = pos - center
            corners[label] = SCNVector3(centered.x, centered.y, centered.z)
        }

        let wireframe = MarkerEntityFactory.createHexahedronWireframe(corners: corners)
        scene.rootNode.addChildNode(wireframe)

        // Markers at each corner
        for (label, corner) in corners {
            let marker = MarkerEntityFactory.createMarker(label: label, position: corner)
            scene.rootNode.addChildNode(marker)
        }

        // Reference grid
        let grid = createReferenceGrid()
        scene.rootNode.addChildNode(grid)

        return scene
    }

    private static func createReferenceGrid() -> SCNNode {
        let gridSize: Float = 3.0
        let spacing: Float = 0.5
        let node = SCNNode()

        let path = UIBezierPath()
        for i in stride(from: -gridSize, through: gridSize, by: spacing) {
            path.move(to: CGPoint(x: CGFloat(i), y: CGFloat(-gridSize)))
            path.addLine(to: CGPoint(x: CGFloat(i), y: CGFloat(gridSize)))
            path.move(to: CGPoint(x: CGFloat(-gridSize), y: CGFloat(i)))
            path.addLine(to: CGPoint(x: CGFloat(gridSize), y: CGFloat(i)))
        }

        let shape = SCNShape(path: path, extrusionDepth: 0)
        shape.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.1)
        shape.firstMaterial?.lightingModel = .constant

        let gridNode = SCNNode(geometry: shape)
        gridNode.position = SCNVector3(0, -0.01, 0)
        gridNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0) // flat on floor
        node.addChildNode(gridNode)

        return node
    }
}
