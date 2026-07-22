import SwiftUI
import SceneKit

/// 3D review of a completed scan — SceneKit hexahedron with touch controls.
struct ScanReviewView: View {
    let scan: ScanSession
    @ObservedObject var scanStore: ScanStore
    @EnvironmentObject private var cargoStore: CargoStore
    @State private var scene: SCNScene?
    @State private var draftName: String
    @State private var activeLoad: LoadSession?
    @State private var loadError: String?
    @Environment(\.dismiss) private var dismiss

    init(scan: ScanSession, scanStore: ScanStore) {
        self.scan = scan
        self.scanStore = scanStore
        _draftName = State(initialValue: scan.name)
    }

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
                        .frame(height: UIScreen.main.bounds.height * 0.40)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(12)
                            .frame(height: UIScreen.main.bounds.height * 0.40)
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

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Cargo space or item name")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.55))

                        TextField("e.g. Honda CR-V trunk", text: $draftName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityIdentifier("scanReview.nameField")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

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
                        if canStartLoad {
                            Button(action: startRoadieLoad) {
                                Label("Start Roadie Load", systemImage: "truck.box.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.green)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }

                        Button(action: { saveScan() }) {
                            Label(saveButtonTitle, systemImage: saveButtonIcon)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isSavedAndCurrent ? Color.green : Color(red: 0.27, green: 0.53, blue: 1.0))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSave || isSavedAndCurrent)
                        .opacity(canSave ? 1 : 0.5)
                        .accessibilityIdentifier("scanReview.saveButton")

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
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                if !isStored {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Discard", role: .destructive) { dismiss() }
                    }
                }
            }
            .onAppear {
                scene = HexahedronMeshBuilder.buildScene(from: scan.pointPositions(),
                                                          dimensions: scan.dimensions)
            }
            .fullScreenCover(item: $activeLoad) { session in
                NavigationStack {
                    LiveLoadView(sessionID: session.id, scanStore: scanStore)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { activeLoad = nil }
                            }
                        }
                }
                .environmentObject(cargoStore)
            }
            .alert("Could Not Start Load", isPresented: loadErrorIsPresented) {
                Button("OK", role: .cancel) { loadError = nil }
            } message: {
                Text(loadError ?? "Please try again.")
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

    private var normalizedDraftName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var displayName: String {
        normalizedDraftName.isEmpty ? "Scan Review" : normalizedDraftName
    }

    private var storedScan: ScanSession? {
        scanStore.scan(by: scan.id)
    }

    private var isStored: Bool {
        storedScan != nil
    }

    private var isSavedAndCurrent: Bool {
        storedScan?.name == normalizedDraftName && !normalizedDraftName.isEmpty
    }

    private var canSave: Bool {
        !normalizedDraftName.isEmpty
    }

    private var saveButtonTitle: String {
        if isSavedAndCurrent { return "Saved" }
        return isStored ? "Save Changes" : "Save Scan"
    }

    private var saveButtonIcon: String {
        isSavedAndCurrent ? "checkmark" : "square.and.arrow.down"
    }

    @discardableResult
    private func saveScan() -> ScanSession? {
        guard canSave else { return nil }

        var updatedScan = scan
        updatedScan.name = normalizedDraftName
        draftName = updatedScan.name
        scanStore.save(updatedScan)

        if cargoStore.vehicleProfiles.contains(where: { $0.sourceScanID == updatedScan.id }) {
            _ = cargoStore.saveVehicleProfile(from: updatedScan, name: updatedScan.name)
        }

        return updatedScan
    }

    private var canStartLoad: Bool {
        guard canSave, scan.isComplete, let dimensions = scan.dimensions else { return false }
        return dimensions.lengthMeters > 0
            && dimensions.widthMeters > 0
            && dimensions.heightMeters > 0
            && dimensions.conservativeVolumeCubicMeters > 0
    }

    private func startRoadieLoad() {
        guard let namedScan = saveScan() else { return }
        switch cargoStore.startLoad(from: namedScan, vehicleName: namedScan.name, loadName: "Roadie Load") {
        case .success(let session):
            activeLoad = session
        case .failure(let error):
            loadError = error.localizedDescription
        }
    }

    private var loadErrorIsPresented: Binding<Bool> {
        Binding(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )
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
