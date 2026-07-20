import SwiftUI

struct ScanView: View {
    @ObservedObject var scanStore: ScanStore
    @StateObject private var coordinator = ARScanCoordinator()
    @Environment(\.dismiss) private var dismiss

    @State private var session = ScanSession(name: "")
    @State private var showingCalibration = false
    @State private var showingReview = false
    @State private var calibrationAlert = false

    var body: some View {
        ZStack {
            // AR camera feed
            ARScanView(coordinator: coordinator)
                .ignoresSafeArea()

            // Top overlay
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
        }
        .onAppear {
            coordinator.onPointPlaced = { point in
                session.upsertPoint(label: point.label,
                                     position: point.position.simd,
                                     source: point.source)
            }
            coordinator.onAllPointsPlaced = {
                computeResults()
                showingReview = true
            }
        }
        .fullScreenCover(isPresented: $showingReview) {
            ScanReviewView(scan: session, scanStore: scanStore)
        }
    }

    // MARK: — Top Bar —

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("Point \(session.currentPointNumber) of 8")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                    progressDots
                }

                Spacer()

                Button(action: { coordinator.undoLastPoint() }) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title2)
                        .foregroundColor(coordinator.placedPoints.isEmpty ? .white.opacity(0.3) : .white.opacity(0.8))
                }
                .disabled(coordinator.placedPoints.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 8)

            // Instruction
            Text(coordinator.sessionMessage)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .background(
            LinearGradient(colors: [.black.opacity(0.5), .clear],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<8, id: \.self) { i in
                Circle()
                    .fill(i < coordinator.placedPoints.count ? Color.green : Color.white.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    // MARK: — Bottom Bar —

    private var bottomBar: some View {
        VStack(spacing: 12) {
            // Current label instruction
            if coordinator.isPlacementEnabled {
                Text(coordinator.currentLabel.instruction)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("All points placed — review your scan")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.green)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Place point button (large, centered)
            if coordinator.isPlacementEnabled {
                Button(action: {
                    // Tap handled by ARSCNView gesture recognizer
                    // This button is for visual feedback only
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 72, height: 72)
                        Circle()
                            .strokeBorder(Color(red: 0.27, green: 0.53, blue: 1.0), lineWidth: 4)
                            .frame(width: 64, height: 64)
                        Text("Tap")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.black)
                    }
                }
            } else {
                Button(action: { showingReview = true }) {
                    Label("Review Scan", systemImage: "cube.transparent")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.27, green: 0.53, blue: 1.0))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(.bottom, 40)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: — Results —

    private func computeResults() {
        let positions = session.pointPositions()
        let sources = session.pointSources()

        // Dimensions
        if let dims = DimensionExtractor.extract(from: positions) {
            session.dimensions = dims
        }

        // Confidence
        let conf = ConfidenceScoring.assess(points: positions,
                                              hasCalibration: session.calibration != nil,
                                              pointSources: sources)
        session.confidenceScore = conf.score
        session.confidenceLevel = conf.level

        // Volume
        if let vol = VolumeCalculator.compute(points: positions,
                                               insetPercent: SafetyInsetCalculator.insetPercent(for: conf.score)) {
            session.volumeResult = ScanSession.VolumeResultData(
                rawCubicMeters: vol.rawCubicMeters,
                conservativeCubicMeters: vol.conservativeCubicMeters,
                hasNegativeTetrahedra: vol.hasNegativeTetrahedra
            )

            // Update dimensions with actual volume
            if var dims = session.dimensions {
                dims.rawVolumeCubicMeters = vol.rawCubicMeters
                dims.conservativeVolumeCubicMeters = vol.conservativeCubicMeters
                session.dimensions = dims
            }
        }

        // Auto-name
        let df = DateFormatter()
        df.dateFormat = "MMM d, h:mm a"
        session.name = "Scan — \(df.string(from: Date()))"
    }
}
