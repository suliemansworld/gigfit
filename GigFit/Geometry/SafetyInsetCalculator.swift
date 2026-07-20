import Foundation

/// Computes the conservative safety inset percentage based on confidence score.
/// Higher confidence → smaller inset (less space wasted).
/// Lower confidence → larger inset (more safety margin).
enum SafetyInsetCalculator {

    static func insetPercent(for confidenceScore: Int) -> Double {
        switch confidenceScore {
        case 80...:   return 2.0
        case 50..<80: return 4.0
        case ..<50:   return 5.0
        default:      return 4.0
        }
    }

    /// Apply a 3D safety inset: conservativeVolume = rawVolume × (1 − inset%)³
    static func applyInset(to volumeCubicMeters: Double, insetPercent: Double) -> Double {
        let scale = pow(1.0 - insetPercent / 100.0, 3)
        return volumeCubicMeters * max(scale, 0.001)
    }
}
