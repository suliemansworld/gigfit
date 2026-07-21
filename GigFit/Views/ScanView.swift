import SwiftUI

/// Floor-calibrated AR volume measurement with a live expandable wireframe.
struct ScanView: View {
    @Binding var session: ScanSession
    @ObservedObject var scanStore: ScanStore
    var startMode: VolumeScanStage = .auto
    @Environment(\.dismiss) private var dismissToHome
    @StateObject private var coordinator = ARScanCoordinator()
    @State private var showingCalibration = false
    @State private var showingReview = false

    var body: some View {
        ZStack {
            ARScanView(coordinator: coordinator)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                statusPanel
                    .padding(.horizontal, 12)
                    .padding(.top, 48)

                Spacer()

                if coordinator.stage == .polygonFloor || coordinator.stage == .polygonHeight
                    || coordinator.stage.rawValue >= VolumeScanStage.depth.rawValue
                    || (coordinator.stage == .auto && coordinator.autoRoomReady) {
                    measurementPanel
                        .padding(.horizontal, 12)
                }

                controlPanel
                    .padding(.horizontal, 12)
                    .padding(.bottom, 28)
            }

            closeButton
        }
        .onAppear {
            coordinator.onPointsChanged = { session.points = $0 }
            if startMode == .polygonFloor {
                coordinator.startPolygonMode()
            }
        }
        .onChange(of: showingReview) {
            showingReview ? coordinator.pauseSession() : coordinator.startSession()
        }
        .sheet(isPresented: $showingCalibration) {
            CalibrationView(session: $session, scanStore: scanStore, showingReview: $showingReview, dismissAll: { dismissToHome() })
        }
        .sheet(isPresented: $showingReview) {
            ScanReviewView(scan: session, scanStore: scanStore)
        }
    }

    private var closeButton: some View {
        VStack {
            HStack {
                Button(action: { dismissToHome() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .accessibilityLabel("Close and return home")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: stageIcon)
                    .font(.headline)
                    .foregroundStyle(stageColor)

                Text(coordinator.stage.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                if coordinator.ceilingDetected {
                    Label("Ceiling", systemImage: "square.topthird.inset.filled")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.purple)
                }
                Label(coordinator.meshActive ? "LiDAR Active" : (coordinator.isLiDARAvailable ? "LiDAR" : "AR"), systemImage: coordinator.meshActive ? "sensor.tag.radiowaves.forward.fill" : (coordinator.isLiDARAvailable ? "sensor.tag.radiowaves.forward" : "camera.viewfinder"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(coordinator.meshActive ? Color.green : (coordinator.isLiDARAvailable ? Color.cyan : Color.secondary))
            }

            Text(coordinator.stage.instruction)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(coordinator.sessionMessage)
                .font(.caption)
                .foregroundStyle(messageColor)
                .lineLimit(2)

            if coordinator.stage != .auto && coordinator.stage != .polygonFloor && coordinator.stage != .polygonHeight {
                HStack(spacing: 6) {
                    ForEach(Array(VolumeScanStage.allCases.filter { $0 != .auto && $0 != .polygonFloor && $0 != .polygonHeight }.prefix(4))) { stage in
                        VStack(spacing: 4) {
                            Capsule()
                                .fill(progressColor(for: stage))
                                .frame(height: 4)
                            Text(stage.title.replacingOccurrences(of: "Set the ", with: ""))
                                .font(.caption2)
                                .foregroundStyle(stage.rawValue <= coordinator.stage.rawValue ? .primary : .secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var measurementPanel: some View {
        HStack(spacing: 0) {
            measurement(label: "Width", value: coordinator.liveDimensions.x)
            Divider().frame(height: 34)
            measurement(label: "Depth", value: coordinator.liveDimensions.z)
            Divider().frame(height: 34)
            measurement(label: "Height", value: coordinator.liveDimensions.y)
            Divider().frame(height: 34)
            VStack(spacing: 2) {
                Text("Volume")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(volumeText)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var controlPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(action: coordinator.undoLastPoint) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.body.weight(.semibold))
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black.opacity(0.55))
                .disabled(coordinator.stage == .floor || coordinator.stage == .auto)
                .accessibilityLabel("Undo last measurement")

                switch coordinator.stage {
                case .polygonFloor:
                    Button(action: coordinator.placeAtCrosshair) {
                        Label("Add Vertex", systemImage: "plus.square")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    Button(action: coordinator.closePolygon) {
                        Image(systemName: "checkmark.square")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .accessibilityLabel("Close polygon shape")
                case .polygonHeight:
                    Button(action: coordinator.lockHeightAtDevice) {
                        Label("Lock Height at Phone", systemImage: "arrow.up.and.down")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)

                    Button(action: coordinator.placeAtCrosshair) {
                        Image(systemName: "viewfinder")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .accessibilityLabel("Set height from targeted surface")
                case .auto:
                    Button(action: coordinator.lockAutoRoom) {
                        Label("Lock Room", systemImage: "lock.fill")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(action: coordinator.switchToManual) {
                        Image(systemName: "hand.point.up")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .accessibilityLabel("Switch to manual point placement")
                case .floor:
                    Button(action: coordinator.placeAtCrosshair) {
                        Label("Set Floor", systemImage: "viewfinder")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)

                    Button(action: coordinator.calibrateFloorAtDevice) {
                        Label("Phone on Floor", systemImage: "iphone.gen3")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                case .width, .depth:
                    Button(action: coordinator.placeAtCrosshair) {
                        Label(coordinator.stage == .width ? "Set Width" : "Set Depth", systemImage: "viewfinder")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                case .height:
                    Button(action: coordinator.lockHeightAtDevice) {
                        Label("Lock Height at Phone", systemImage: "arrow.up.and.down")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)

                    Button(action: coordinator.placeAtCrosshair) {
                        Image(systemName: "viewfinder")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .accessibilityLabel("Set height from targeted surface")
                case .complete:
                    Button(action: skipCalibrationAndReview) {
                        Label("Quick Review", systemImage: "arrow.right.circle")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button(action: { showingCalibration = true }) {
                        Image(systemName: "ruler")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .accessibilityLabel("Tape calibrate before review")
                }
            }

            Text(controlHint)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
        }
    }

    private func measurement(label: String, value: Float) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value > 0 ? UnitFormatter.formatFeetAndInches(Double(value)) : "--")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }

    private var volumeText: String {
        let dimensions = coordinator.liveDimensions
        let volume = Double(dimensions.x * dimensions.y * dimensions.z)
        return volume > 0 ? UnitFormatter.formatCubicFeet(volume) : "--"
    }

    private var stageIcon: String {
        switch coordinator.stage {
        case .auto: return "rectangle.expand.vertical"
        case .polygonFloor: return "skew"
        case .polygonHeight: return "arrow.up.and.down"
        case .floor: return "square.bottomhalf.filled"
        case .width: return "arrow.left.and.right"
        case .depth: return "arrow.up.left.and.arrow.down.right"
        case .height: return "arrow.up.and.down"
        case .complete: return "checkmark.circle.fill"
        }
    }

    private var stageColor: Color {
        switch coordinator.stage {
        case .auto: return .mint
        case .polygonFloor: return .orange
        case .polygonHeight: return .yellow
        case .floor, .width, .depth: return .cyan
        case .height: return .yellow
        case .complete: return .green
        }
    }

    private var messageColor: Color {
        if coordinator.crosshairSurfaceFound { return .green }
        return coordinator.surfaceReady ? .mint : .orange
    }

    private func progressColor(for stage: VolumeScanStage) -> Color {
        if coordinator.stage == .complete || stage.rawValue < coordinator.stage.rawValue { return .green }
        if stage == coordinator.stage { return stageColor }
        return Color.secondary.opacity(0.25)
    }

    private var controlHint: String {
        switch coordinator.stage {
        case .auto: return "Pan around the room. Walls and floor extend the box automatically."
        case .polygonFloor: return "Tap each corner of the floor shape. Snaps to detected walls. Close shape when done."
        case .polygonHeight: return "Raise the phone slowly. The wireframe grows with it, then lock the height."
        case .floor: return "For phone calibration, place the phone over the first floor corner before tapping."
        case .width, .depth: return "Use the crosshair button or tap the camera view on the floor boundary."
        case .height: return "Raise the phone slowly. The wireframe grows with it, then lock the height."
        case .complete: return "Quick Review skips calibration. Use the ruler for tape-measure accuracy."
        }
    }

    private func skipCalibrationAndReview() {
        let positions = session.pointPositions()
        let sources = session.pointSources()

        if let dims = DimensionExtractor.extract(from: positions) {
            session.dimensions = dims
        }

        let conf = ConfidenceScoring.assess(points: positions, hasCalibration: false, pointSources: sources)
        session.confidenceScore = conf.score
        session.confidenceLevel = conf.level

        if let vol = VolumeCalculator.compute(points: positions, insetPercent: SafetyInsetCalculator.insetPercent(for: conf.score)) {
            session.volumeResult = ScanSession.VolumeResultData(
                rawCubicMeters: vol.rawCubicMeters,
                conservativeCubicMeters: vol.conservativeCubicMeters,
                hasNegativeTetrahedra: vol.hasNegativeTetrahedra
            )
            if var dims = session.dimensions {
                dims.conservativeVolumeCubicMeters = vol.conservativeCubicMeters
                session.dimensions = dims
            }
        }
        showingReview = true
    }
}
