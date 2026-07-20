import SwiftUI
import SceneKit

struct ScanReviewView: View {
    let scan: ScanSession
    @ObservedObject var scanStore: ScanStore
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 3D Scene View
                    SceneReview3DView(scan: scan)
                        .frame(maxHeight: UIScreen.main.bounds.height * 0.45)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 12)
                        .padding(.top, 12)

                    // Dimensions card
                    dimensionsCard
                        .padding(.horizontal, 12)
                        .padding(.top, 12)

                    // Confidence badge
                    confidenceBadge
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    Spacer()

                    // Action buttons
                    actionButtons
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                }
            }
            .navigationTitle(saved ? "Scan Saved" : "Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: — Components —

    private var dimensionsCard: some View {
        VStack(spacing: 0) {
            Text("Dimensions")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)

            if let dims = scan.dimensions {
                HStack(spacing: 0) {
                    dimColumn(label: "Length", value: UnitFormatter.formatFeetAndInches(dims.lengthMeters),
                              metric: UnitFormatter.formatMeters(dims.lengthMeters))
                    Divider().background(Color.white.opacity(0.15)).frame(height: 40)
                    dimColumn(label: "Width", value: UnitFormatter.formatFeetAndInches(dims.widthMeters),
                              metric: UnitFormatter.formatMeters(dims.widthMeters))
                    Divider().background(Color.white.opacity(0.15)).frame(height: 40)
                    dimColumn(label: "Height", value: UnitFormatter.formatFeetAndInches(dims.heightMeters),
                              metric: UnitFormatter.formatMeters(dims.heightMeters))
                }

                Divider().background(Color.white.opacity(0.1)).padding(.vertical, 10)

                HStack(spacing: 0) {
                    dimColumn(label: "Raw Volume",
                              value: UnitFormatter.formatCubicFeet(dims.rawVolumeCubicMeters),
                              metric: UnitFormatter.formatCubicMeters(dims.rawVolumeCubicMeters))
                    Divider().background(Color.white.opacity(0.15)).frame(height: 40)
                    dimColumn(label: "Conservative",
                              value: UnitFormatter.formatCubicFeet(dims.conservativeVolumeCubicMeters),
                              metric: UnitFormatter.formatCubicMeters(dims.conservativeVolumeCubicMeters))
                }
            } else {
                Text("No dimensions computed")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func dimColumn(label: String, value: String, metric: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundColor(.white)
            Text(metric)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private var confidenceBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(confidenceColor)
                .frame(width: 8, height: 8)
            if let level = scan.confidenceLevel {
                Text("\(level.displayName) Confidence")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(confidenceColor)
            }
            if let score = scan.confidenceScore {
                Text("• \(score)%")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            if let level = scan.confidenceLevel {
                Text(level.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Text("Rescan")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button(action: { saveAndDismiss() }) {
                Text(saved ? "Saved" : "Save Scan")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(saved ? Color.green : Color(red: 0.27, green: 0.53, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(saved)
        }
    }

    private var confidenceColor: Color {
        guard let level = scan.confidenceLevel else { return .gray }
        switch level {
        case .high:   return .green
        case .medium: return .orange
        case .low:    return .red
        }
    }

    private func saveAndDismiss() {
        scanStore.save(scan)
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
}

// MARK: — SceneKit 3D Review View —

struct SceneReview3DView: UIViewRepresentable {
    let scan: ScanSession

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = UIColor(red: 0.06, green: 0.06, blue: 0.14, alpha: 1)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X

        let positions = scan.pointPositions()
        if !positions.isEmpty {
            let scene = HexahedronMeshBuilder.buildScene(from: positions,
                                                           dimensions: scan.dimensions)
            view.scene = scene
        }

        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}
