import Foundation

enum ScanConfidence: String, Codable, CaseIterable {
    case high
    case medium
    case low

    var displayName: String {
        switch self {
        case .high:   return "High"
        case .medium: return "Medium"
        case .low:    return "Low"
        }
    }

    var description: String {
        switch self {
        case .high:   return "Good tracking and mostly detected surfaces"
        case .medium: return "Some approximate surfaces — verify near-limit measurements"
        case .low:    return "Rescan or verify dimensions manually before relying on results"
        }
    }

    var recommendedInsetPercent: Double {
        switch self {
        case .high:   return 2.0
        case .medium: return 4.0
        case .low:    return 5.0
        }
    }
}
