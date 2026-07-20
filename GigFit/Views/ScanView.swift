import SwiftUI

/// The main AR scanning view — 8-point guided placement.
struct ScanView: View {
    @Binding var session: ScanSession
    @ObservedObject var scanStore: ScanStore
    @StateObject private var coordinator = ARScanCoordinator()
    @State private var showingCalibration = false
    @State private var showingReview = false
    @State private var scanCompleted = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // AR camera view
            ARScanView(coordinator: coordinator)
                .ignoresSafeArea()

            // Top instruction banner
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: coordinator.isPlacementEnabled ? "viewfinder" : "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(coordinator.isPlacementEnabled ? .blue : .green)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(coordinator.isPlacementEnabled
                             ? "Point \(coordinator.placedPoints.count + 1) of 8"
                             : "All points placed")
                            .font(.subheadline.weight(.semibold))
                        Text(coordinator.sessionMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 54)

                Spacer()

                // Bottom controls
                VStack(spacing: 10) {
                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(ScanPointLabel.allCases) { label in
                            Circle()
                                .fill(pointColor(for: label))
                                .frame(width: 10, height: 10)
                        }
                    }

                    HStack(spacing: 12) {
                        // Undo button
                        Button(action: { coordinator.undoLastPoint() }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.body.weight(.medium))
                                .foregroundColor(.white)
                                .padding(14)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .disabled(coordinator.placedPoints.isEmpty)

                        // Place point button (hidden when complete)
                        if coordinator.isPlacementEnabled {
                            Button(action: {}) {
                                Text("Place Point")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 16)
                                    .background(Color(red: 0.27, green: 0.53, blue: 1.0))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .opacity(0) // Hidden — actual tapping is on AR view
                        }

                        // Done / Continue button
                        if !coordinator.isPlacementEnabled {
                            Button(action: { showingCalibration = true }) {
                                Label("Continue", systemImage: "arrow.right")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 16)
                                    .background(Color.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    .padding(.bottom, 4)

                    Text("Tap anywhere on the AR view to place a point")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            coordinator.onPointPlaced = { point in
                session.upsertPoint(label: point.label, position: point.position.simd, source: point.source)
            }
            coordinator.onAllPointsPlaced = {
                scanCompleted = true
            }
        }
        .sheet(isPresented: $showingCalibration) {
            CalibrationView(session: $session, scanStore: scanStore, showingReview: $showingReview)
        }
        .fullScreenCover(isPresented: $showingReview) {
            ScanReviewView(scan: session, scanStore: scanStore)
        }
    }

    private func pointColor(for label: ScanPointLabel) -> Color {
        let placed = Set(session.points.map { $0.label })
        if placed.contains(label) { return .blue }
        if placeableLabels().contains(label) { return .white.opacity(0.4) }
        return .white.opacity(0.15)
    }

    private func placeableLabels() -> Set<ScanPointLabel> {
        let placed = Set(session.points.map { $0.label })
        var placeable: Set<ScanPointLabel> = []
        for label in ScanPointLabel.allCases {
            if !placed.contains(label) {
                placeable.insert(label)
                break
            }
        }
        return placeable
    }
}
