import Foundation

enum UnitFormatter {
    static let inchesPerMeter: Double = 39.3701
    static let cubicFeetPerCubicMeter: Double = 35.3147

    static func metersToInches(_ meters: Double) -> Double {
        meters * inchesPerMeter
    }

    static func inchesToMeters(_ inches: Double) -> Double {
        inches / inchesPerMeter
    }

    static func cubicMetersToCubicFeet(_ m3: Double) -> Double {
        m3 * cubicFeetPerCubicMeter
    }

    static func formatInches(_ meters: Double) -> String {
        let inches = metersToInches(meters)
        return String(format: "%.1f in", inches)
    }

    static func formatFeetAndInches(_ meters: Double) -> String {
        let totalInches = metersToInches(meters)
        let feet = Int(totalInches) / 12
        let inches = Int(totalInches) % 12
        if feet > 0 {
            return "\(feet)' \(inches)\""
        }
        return "\(inches)\""
    }

    static func formatCubicFeet(_ cubicMeters: Double) -> String {
        let cf = cubicMetersToCubicFeet(cubicMeters)
        return String(format: "%.1f ft³", cf)
    }

    static func formatMeters(_ meters: Double) -> String {
        String(format: "%.2f m", meters)
    }

    static func formatCubicMeters(_ cubicMeters: Double) -> String {
        String(format: "%.2f m³", cubicMeters)
    }
}
