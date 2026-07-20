import SwiftUI
import SceneKit

/// 3D review of a completed scan — SceneKit hexahedron with touch controls.
struct ScanReviewView: View {
    let scan: ScanSession
    @ObservedObject var scanStore: ScanStore
    @State private var scene: SCNScene?
    @State private var isSaved = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // 3D view
                    if let scene {
                        SceneView(
                            scene: scene,
                            pointOfView: nil,
                            options: [.allowsCameraControl, .autoenablesDefaultLighting],
                            preferredFramesPerSecond: 60
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(12)
                        .frame(height: UIScreen.main.bounds.height * 0.45)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(12)
                            .frame(height: UIScreen.main.bounds.height * 0.45)
                            .overlay {
                                ProgressView()
                                    .tint(.white)
                            }
                    }

                    // Dimensions card
                    if let dims = scan.dimensions {
                        VStack(spacing: 16) {
                            HStack {
                                DimBlock(label: "Length", value: UnitFormatter.formatFeetAndInches(dims.lengthMeters))
                                Divider().background(Color.white.opacity(0.1))
                                DimBlock(label: "Width", value: UnitFormatter.formatFeetAndInches(dims.widthMeters))
                                Divider().background(Color.white.opacity(0.1))
                                DimBlock(label: "Height", value: UnitFormatter.formatFeetAndInches(dims.heightMeters))
                            }

                            HStack(spacing: 20) {
                                VStack {
                                    Text("Raw Volume")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(UnitFormatter.formatCubicFeet(dims.rawVolumeCubicMeters))
                                        .font(.title3.weight(.bold))
                                        .foregroundColor(.white)
                                }
                                VStack {
                                    Text("Conservative")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                    Text(UnitFormatter.formatCubicFeet(dims.conservativeVolumeCubicMeters))
                                        .font(.title3.weight(.bold))
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                    }

                    // Confidence badge
                    if let level = scan.confidenceLevel, let score = scan.confidenceScore {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(confidenceColor)
                                .frame(width: 10, height: 10)
                            Text("\(level.displayName) confidence — \(score)%")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(confidenceColor)
                        }
                        .padding(.top, 8)

                        Text(level.description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: 10) {
                        Button(action: saveScan) {
                            Label(isSaved ? "Saved" : "Save Scan", systemImage: isSaved ? "checkmark" : "square.and.arrow.down")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isSaved ? Color.green : Color(red: 0.27, green: 0.53, blue: 1.0))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isSaved)

                        Button(action: { dismiss() }) {
                            Text("New Scan")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(scan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if !isSaved {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Discard", role: .destructive) { dismiss() }
                    }
                }
            }
            .onAppear {
                scene = HexahedronMeshBuilder.buildScene(from: scan.pointPositions(),
                                                          dimensions: scan.dimensions)
            }
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

    private func saveScan() {
        scanStore.save(scan)
        isSaved = true
    }
}

struct DimBlock: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
