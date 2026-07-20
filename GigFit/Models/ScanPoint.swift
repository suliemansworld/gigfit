import Foundation
import simd

struct CodableVector3: Codable, Equatable {
    var x: Float
    var y: Float
    var z: Float

    init(_ simd: SIMD3<Float>) {
        self.x = simd.x
        self.y = simd.y
        self.z = simd.z
    }

    var simd: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

enum ScanPointLabel: String, Codable, CaseIterable, Identifiable {
    case rearLeftFloor
    case rearRightFloor
    case frontRightFloor
    case frontLeftFloor
    case rearLeftUpper
    case rearRightUpper
    case frontRightUpper
    case frontLeftUpper

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rearLeftFloor:   return "Rear-Left Floor"
        case .rearRightFloor:  return "Rear-Right Floor"
        case .frontRightFloor: return "Front-Right Floor"
        case .frontLeftFloor:  return "Front-Left Floor"
        case .rearLeftUpper:   return "Rear-Left Upper"
        case .rearRightUpper:  return "Rear-Right Upper"
        case .frontRightUpper: return "Front-Right Upper"
        case .frontLeftUpper:  return "Front-Left Upper"
        }
    }

    var instruction: String {
        switch self {
        case .rearLeftFloor:   return "Aim at the REAR-LEFT FLOOR boundary and tap Place Point"
        case .rearRightFloor:  return "Aim at the REAR-RIGHT FLOOR boundary and tap Place Point"
        case .frontRightFloor: return "Aim at the FRONT-RIGHT FLOOR boundary and tap Place Point"
        case .frontLeftFloor:  return "Aim at the FRONT-LEFT FLOOR boundary and tap Place Point"
        case .rearLeftUpper:   return "Aim at the REAR-LEFT UPPER boundary and tap Place Point"
        case .rearRightUpper:  return "Aim at the REAR-RIGHT UPPER boundary and tap Place Point"
        case .frontRightUpper: return "Aim at the FRONT-RIGHT UPPER boundary and tap Place Point"
        case .frontLeftUpper:  return "Aim at the FRONT-LEFT UPPER boundary and tap Place Point"
        }
    }

    var pointNumber: Int {
        ScanPointLabel.allCases.firstIndex(of: self)! + 1
    }

    static var floorLabels: [ScanPointLabel] {
        [.rearLeftFloor, .rearRightFloor, .frontRightFloor, .frontLeftFloor]
    }

    static var upperLabels: [ScanPointLabel] {
        [.rearLeftUpper, .rearRightUpper, .frontRightUpper, .frontLeftUpper]
    }
}

enum PointSource: String, Codable {
    case existingPlaneGeometry
    case existingPlaneInfinite
    case estimatedPlane

    var displayName: String {
        switch self {
        case .existingPlaneGeometry: return "Detected surface"
        case .existingPlaneInfinite: return "Estimated flat surface"
        case .estimatedPlane:        return "Approximate surface"
        }
    }
}

struct ScanPoint: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var label: ScanPointLabel
    var position: CodableVector3
    var source: PointSource
}
