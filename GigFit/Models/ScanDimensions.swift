import Foundation

struct ScanDimensions: Codable, Equatable, Sendable {
    var lengthMeters: Double
    var widthMeters: Double
    var heightMeters: Double
    var rawVolumeCubicMeters: Double
    var conservativeVolumeCubicMeters: Double

    var lengthInches: Double { lengthMeters * 39.3701 }
    var widthInches: Double { widthMeters * 39.3701 }
    var heightInches: Double { heightMeters * 39.3701 }

    var rawVolumeCubicFeet: Double { rawVolumeCubicMeters * 35.3147 }
    var conservativeVolumeCubicFeet: Double { conservativeVolumeCubicMeters * 35.3147 }
}
