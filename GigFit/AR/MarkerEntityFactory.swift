import Foundation
import SceneKit
import ARKit

/// Creates visual markers and the hexahedron wireframe in the AR scene.
enum MarkerEntityFactory {

    static let markerRadius: CGFloat = 0.025
    static let floorColor = UIColor(red: 0.27, green: 0.53, blue: 1.0, alpha: 1.0)   // #4488ff
    static let upperColor = UIColor(red: 0.40, green: 0.80, blue: 0.40, alpha: 1.0)   // green
    static let wireframeColor = UIColor(red: 0.27, green: 0.53, blue: 1.0, alpha: 0.6)
    static let floorPlaneColor = UIColor(red: 0.27, green: 0.53, blue: 1.0, alpha: 0.1)

    /// Create a sphere marker for a placed scan point
    static func createMarker(label: ScanPointLabel, position: SCNVector3) -> SCNNode {
        let sphere = SCNSphere(radius: markerRadius)
        sphere.firstMaterial?.diffuse.contents = ScanPointLabel.floorLabels.contains(label) ? floorColor : upperColor
        sphere.firstMaterial?.lightingModel = .physicallyBased
        sphere.firstMaterial?.metalness.contents = 0.0
        sphere.firstMaterial?.roughness.contents = 0.4

        let node = SCNNode(geometry: sphere)
        node.position = position
        node.name = "marker_\(label.rawValue)"
        return node
    }

    /// Create a text label floating above a marker
    static func createLabel(text: String, at position: SCNVector3) -> SCNNode {
        let textGeo = SCNText(string: text, extrusionDepth: 0.001)
        textGeo.font = UIFont.systemFont(ofSize: 0.06, weight: .medium)
        textGeo.firstMaterial?.diffuse.contents = UIColor.white
        textGeo.flatness = 0.1

        let node = SCNNode(geometry: textGeo)
        node.position = SCNVector3(position.x, position.y + 0.06, position.z)
        node.scale = SCNVector3(0.001, 0.001, 0.001)
        // Billboard constraint to always face camera
        let billboard = SCNBillboardConstraint()
        node.constraints = [billboard]
        return node
    }

    /// Build a wireframe hexahedron from the 8 corner positions
    static func createHexahedronWireframe(corners: [ScanPointLabel: SCNVector3]) -> SCNNode {
        let parent = SCNNode()
        parent.name = "hexahedron"

        // Edges: 4 floor, 4 upper, 4 vertical
        let edges: [(ScanPointLabel, ScanPointLabel)] = [
            (.rearLeftFloor,  .rearRightFloor),
            (.rearRightFloor, .frontRightFloor),
            (.frontRightFloor,.frontLeftFloor),
            (.frontLeftFloor, .rearLeftFloor),

            (.rearLeftUpper,  .rearRightUpper),
            (.rearRightUpper, .frontRightUpper),
            (.frontRightUpper,.frontLeftUpper),
            (.frontLeftUpper, .rearLeftUpper),

            (.rearLeftFloor,  .rearLeftUpper),
            (.rearRightFloor, .rearRightUpper),
            (.frontRightFloor,.frontRightUpper),
            (.frontLeftFloor, .frontLeftUpper),
        ]

        for (a, b) in edges {
            guard let from = corners[a], let to = corners[b] else { continue }
            let edge = createLine(from: from, to: to)
            parent.addChildNode(edge)
        }

        // Translucent floor plane
        if let floor = createFloorPlane(corners: corners) {
            parent.addChildNode(floor)
        }

        return parent
    }

    static func createMeasurementLine(from: SIMD3<Float>, to: SIMD3<Float>) -> SCNNode {
        createLine(from: SCNVector3FromSIMD(from), to: SCNVector3FromSIMD(to))
    }

    private static func createLine(from: SCNVector3, to: SCNVector3) -> SCNNode {
        let vector = SCNVector3(to.x - from.x, to.y - from.y, to.z - from.z)
        let distance = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
        guard distance > 0.0001 else { return SCNNode() }

        let cylinder = SCNCylinder(radius: 0.003, height: CGFloat(distance))
        cylinder.firstMaterial?.diffuse.contents = wireframeColor
        cylinder.firstMaterial?.lightingModel = .constant

        let node = SCNNode(geometry: cylinder)
        node.position = SCNVector3(
            (from.x + to.x) / 2,
            (from.y + to.y) / 2,
            (from.z + to.z) / 2
        )

        // Orient cylinder from 'from' to 'to'
        let dir = SCNVector3(vector.x / distance, vector.y / distance, vector.z / distance)
        let up = SCNVector3(0, 1, 0)
        let angle = acos(dir.y)
        let axis = SCNVector3(
            up.y * dir.z - up.z * dir.y,
            up.z * dir.x - up.x * dir.z,
            up.x * dir.y - up.y * dir.x
        )
        if simd_length(SIMD3<Float>(axis.x, axis.y, axis.z)) > 0.0001 {
            node.rotation = SCNVector4(axis.x, axis.y, axis.z, angle)
        }

        return node
    }

    private static func createFloorPlane(corners: [ScanPointLabel: SCNVector3]) -> SCNNode? {
        let floorLabels: [ScanPointLabel] = [.rearLeftFloor, .rearRightFloor, .frontRightFloor, .frontLeftFloor]
        let positions = floorLabels.compactMap { corners[$0] }
        guard positions.count == 4 else { return nil }

        var verts = positions.map { SCNVector3ToGLKVector3($0) }

        // Triangulate as two triangles
        let indices: [Int32] = [0, 1, 2, 0, 2, 3]
        let vertexData = Data(bytes: &verts, count: verts.count * MemoryLayout<GLKVector3>.stride)
        let indexData = Data(bytes: indices, count: indices.count * MemoryLayout<Int32>.stride)

        let vertexSource = SCNGeometrySource(
            data: vertexData,
            semantic: .vertex,
            vectorCount: verts.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.stride,
            dataOffset: 0,
            dataStride: MemoryLayout<GLKVector3>.stride
        )

        let indexElement = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: 2,
            bytesPerIndex: MemoryLayout<Int32>.stride
        )

        let geo = SCNGeometry(sources: [vertexSource], elements: [indexElement])
        geo.firstMaterial?.diffuse.contents = floorPlaneColor
        geo.firstMaterial?.isDoubleSided = true
        geo.firstMaterial?.lightingModel = .constant

        return SCNNode(geometry: geo)
    }
}

private func SCNVector3ToGLKVector3(_ v: SCNVector3) -> GLKVector3 {
    GLKVector3(v: (v.x, v.y, v.z))
}
