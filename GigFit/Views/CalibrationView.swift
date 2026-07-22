import SwiftUI
import simd

/// One-distance calibration: user measures a known edge with tape measure.
struct CalibrationView: View {
    @Binding var session: ScanSession
    @ObservedObject var scanStore: ScanStore
    @Binding var showingReview: Bool
    var dismissAll: () -> Void = {}

    @State private var pointALabel: ScanPointLabel = .rearLeftFloor
    @State private var pointBLabel: ScanPointLabel = .rearRightFloor
    @State private var knownDistance: String = ""
    @State private var calibrationApplied = false

    @Environment(\.dismiss) private var dismiss

    private var estimatedDistance: Double? {
        guard let posA = session.pointPositions()[pointALabel],
              let posB = session.pointPositions()[pointBLabel] else { return nil }
        return Double(simd_distance(posA, posB)) * 39.3701 // meters → inches
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Calibrate for accuracy")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)

                    Text("Measure one known distance with a tape measure.\nThis scales all dimensions for better accuracy.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Point pair selection
                    VStack(spacing: 12) {
                        Text("Select two points:")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.4))

                        Picker("Point A", selection: $pointALabel) {
                            ForEach(ScanPointLabel.allCases) { label in
                                Text(label.displayName).tag(label)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.blue)

                        Picker("Point B", selection: $pointBLabel) {
                            ForEach(ScanPointLabel.allCases) { label in
                                Text(label.displayName).tag(label)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.blue)
                    }
                    .padding(.horizontal, 20)

                    // Estimated distance display
                    if let est = estimatedDistance {
                        Text("ARKit estimate: \(String(format: "%.1f", est)) in")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Known distance input
                    VStack(spacing: 6) {
                        Text("Actual measured distance:")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.4))

                        HStack {
                            TextField("e.g. 52", text: $knownDistance)
                                .keyboardType(.decimalPad)
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(width: 100)

                            Text("inches")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()

                    // Buttons
                    VStack(spacing: 12) {
                        Button(action: applyCalibration) {
                            Label("Apply Calibration", systemImage: "ruler")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(knownDistance.isEmpty ? Color.gray : Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(knownDistance.isEmpty)

                        Button(action: computeResults) {
                            Text("Skip calibration")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .padding(.top, 60)
            }
            .navigationTitle("Calibration")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { computeResults() }
                }
            }
        }
    }

    private func applyCalibration() {
        guard let inches = Double(knownDistance),
              let posA = session.pointPositions()[pointALabel],
              let posB = session.pointPositions()[pointBLabel] else { return }

        let cal = CalibrationService.calibrate(
            pointA: posA, pointB: posB,
            knownDistanceInches: inches,
            labelA: pointALabel, labelB: pointBLabel
        )

        session.calibration = ScanSession.CalibrationData(
            scaleFactor: cal.scaleFactor,
            knownDistanceInches: inches,
            pointALabel: pointALabel,
            pointBLabel: pointBLabel
        )

        // Apply scale to all points
        let scaled = CalibrationService.applyCalibration(cal, to: session.pointPositions())
        for (label, pos) in scaled {
            let source = session.pointSources()[label] ?? .estimatedPlane
            session.upsertPoint(label: label, position: pos, source: source)
        }

        calibrationApplied = true
        computeResults()
    }

    private func computeResults() {
        let positions = session.pointPositions()
        let sources = session.pointSources()
        let hasCal = session.calibration != nil

        // Dimensions
        if let dims = DimensionExtractor.extract(from: positions) {
            session.dimensions = dims
        }

        // Confidence
        let conf = ConfidenceScoring.assess(points: positions, hasCalibration: hasCal, pointSources: sources)
        session.confidenceScore = conf.score
        session.confidenceLevel = conf.level

        // Volume with inset
        if let vol = VolumeCalculator.compute(points: positions, insetPercent: SafetyInsetCalculator.insetPercent(for: conf.score)) {
            session.volumeResult = ScanSession.VolumeResultData(
                rawCubicMeters: vol.rawCubicMeters,
                conservativeCubicMeters: vol.conservativeCubicMeters,
                hasNegativeTetrahedra: vol.hasNegativeTetrahedra
            )
            // Update dimensions with volume
            if var dims = session.dimensions {
                dims.rawVolumeCubicMeters = vol.rawCubicMeters
                dims.conservativeVolumeCubicMeters = vol.conservativeCubicMeters
                session.dimensions = dims
            }
        }

        if session.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            session.name = "Cargo Scan — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
        }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            showingReview = true
        }
    }
}
