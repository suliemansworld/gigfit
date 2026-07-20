import Foundation

/// The complete state of a single scan session.
/// Persisted via Codable to JSON in the app's documents directory.
struct ScanSession: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var createdAt: Date = Date()

    // Points
    var points: [ScanPoint] = []
    var calibration: CalibrationData?

    // Computed results
    var dimensions: ScanDimensions?
    var confidenceScore: Int?
    var confidenceLevel: ScanConfidence?
    var volumeResult: VolumeResultData?

    // MARK: — Computed —

    var isComplete: Bool {
        points.count == 8
    }

    var nextLabel: ScanPointLabel? {
        let placed = Set(points.map { $0.label })
        for label in ScanPointLabel.allCases {
            if !placed.contains(label) { return label }
        }
        return nil
    }

    var currentPointNumber: Int {
        points.count + 1
    }

    var floorPointsPlaced: Int {
        points.filter { ScanPointLabel.floorLabels.contains($0.label) }.count
    }

    var upperPointsPlaced: Int {
        points.filter { ScanPointLabel.upperLabels.contains($0.label) }.count
    }

    // MARK: — Subtypes —

    struct CalibrationData: Codable, Equatable {
        var scaleFactor: Double
        var knownDistanceInches: Double
        var pointALabel: ScanPointLabel
        var pointBLabel: ScanPointLabel
    }

    struct VolumeResultData: Codable, Equatable {
        var rawCubicMeters: Double
        var conservativeCubicMeters: Double
        var hasNegativeTetrahedra: Bool
    }

    // MARK: — Helpers —

    func pointPositions() -> [ScanPointLabel: SIMD3<Float>] {
        Dictionary(uniqueKeysWithValues: points.map { ($0.label, $0.position.simd) })
    }

    func pointSources() -> [ScanPointLabel: PointSource] {
        Dictionary(uniqueKeysWithValues: points.map { ($0.label, $0.source) })
    }

    mutating func upsertPoint(label: ScanPointLabel, position: SIMD3<Float>, source: PointSource) {
        if let idx = points.firstIndex(where: { $0.label == label }) {
            points[idx] = ScanPoint(label: label, position: CodableVector3(position), source: source)
        } else {
            points.append(ScanPoint(label: label, position: CodableVector3(position), source: source))
        }
    }
}
