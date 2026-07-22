import SwiftUI

struct HomeView: View {
    @ObservedObject var scanStore: ScanStore
    @EnvironmentObject private var cargoStore: CargoStore
    @State private var showingNewScan = false
    @State private var showingPolygon = false
    @State private var showingRoomPlan = false
    @State private var showingStartLoad = false
    @State private var activeLoad: LoadSession?
    @State private var loadError: String?
    @State private var polygonSession = ScanSession(name: "Polygon Scan")

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()

                if scanStore.scans.isEmpty && cargoStore.loadSessions.isEmpty {
                    emptyState
                } else {
                    scanList
                }
            }
            .navigationTitle("Scan Space")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewScan = true }) {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .fullScreenCover(isPresented: $showingNewScan) {
                ScanInstructionsView(
                    scanStore: scanStore,
                    onExit: { showingNewScan = false }
                )
            }
            .fullScreenCover(isPresented: $showingPolygon) {
                ScanView(
                    session: $polygonSession,
                    scanStore: scanStore,
                    startMode: .polygonFloor,
                    onExit: { showingPolygon = false }
                )
            }
            .fullScreenCover(isPresented: $showingRoomPlan) {
                RoomPlanScanView(scanStore: scanStore)
            }
            .sheet(isPresented: $showingStartLoad) {
                StartLoadView(scans: scanStore.scans) { session in
                    showingStartLoad = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeLoad = session
                    }
                }
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
            .alert("Could Not Delete Load", isPresented: loadErrorIsPresented) {
                Button("OK", role: .cancel) { loadError = nil }
            } message: {
                Text(loadError ?? "Please try again.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 64))
                .foregroundColor(Color(red: 0.27, green: 0.53, blue: 1.0).opacity(0.6))

            Text("No scans yet")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)

            Text("Measure any cargo space with your camera.\nTap to start your first scan.")
                .font(.body)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button(action: { showingNewScan = true }) {
                Label("New Scan", systemImage: "plus")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.27, green: 0.53, blue: 1.0))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Text("After you save a cargo-space scan, use it to start a live Roadie load and track space left package by package.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.42))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Button(action: { showingPolygon = true }) {
                Label("Polygon Scan", systemImage: "skew")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Button(action: { showingRoomPlan = true }) {
                Label("3D Room Scan", systemImage: "cube.transparent.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.20, green: 0.70, blue: 0.40))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Spacer()
        }
    }

    private var scanList: some View {
        List {
            Section {
                Button(action: { showingStartLoad = true }) {
                    HStack(spacing: 12) {
                        Image(systemName: "truck.box.fill")
                            .font(.title2)
                            .foregroundStyle(.green)
                            .frame(width: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Start Roadie Load")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Add packages and track live space left")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .padding(.vertical, 4)
                }

                ForEach(cargoStore.loadSessions) { session in
                    NavigationLink(
                        destination: LiveLoadView(sessionID: session.id, scanStore: scanStore)
                    ) {
                        LiveLoadRow(session: session)
                    }
                }
                .onDelete(perform: deleteLoads)
            } header: {
                Text("Live Loads")
            }

            Section("Cargo Spaces & Item Scans") {
                ForEach(scanStore.scans) { scan in
                    NavigationLink(destination: ScanReviewView(scan: scan, scanStore: scanStore)) {
                        ScanRow(scan: scan)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .onDelete { indexSet in
                    for idx in indexSet {
                        scanStore.delete(scanStore.scans[idx])
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(action: { showingPolygon = true }) {
                    Label("Polygon", systemImage: "skew")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button(action: { showingRoomPlan = true }) {
                    Label("3D Room", systemImage: "cube.transparent.fill")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.20, green: 0.70, blue: 0.40))
            }
        }
    }

    private func deleteLoads(at offsets: IndexSet) {
        let sessions = cargoStore.loadSessions
        for index in offsets where sessions.indices.contains(index) {
            if case .failure(let error) = cargoStore.deleteLoadSession(id: sessions[index].id) {
                loadError = error.localizedDescription
            }
        }
    }

    private var loadErrorIsPresented: Binding<Bool> {
        Binding(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )
    }
}

private struct LiveLoadRow: View {
    let session: LoadSession

    var body: some View {
        let snapshot = CapacityCalculator.calculate(for: session)

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: max(0.001, min(1, snapshot.remainingPercent / 100)))
                    .stroke(statusColor(snapshot), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(snapshot.remainingPercent.rounded()))%")
                    .font(.caption2.weight(.bold).monospacedDigit())
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.name)
                    .font(.body.weight(.semibold))
                Text("\(session.vehicle.name) • \(session.items.reduce(0) { $0 + $1.quantity }) packages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(session.status == .active ? "ACTIVE" : "DONE")
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background((session.status == .active ? Color.blue : Color.green).opacity(0.18))
                .foregroundStyle(session.status == .active ? Color.blue : Color.green)
                .clipShape(Capsule())
        }
        .padding(.vertical, 3)
    }

    private func statusColor(_ snapshot: CapacitySnapshot) -> Color {
        if snapshot.isOverCapacity || snapshot.remainingPercent < 10 { return .red }
        if snapshot.remainingPercent < 30 { return .orange }
        return .green
    }
}

struct ScanRow: View {
    let scan: ScanSession

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(confidenceColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(scan.name)
                    .font(.body.weight(.medium))
                    .foregroundColor(.white)
                Text(scan.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            if let dims = scan.dimensions {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(UnitFormatter.formatCubicFeet(dims.conservativeVolumeCubicMeters))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    if let level = scan.confidenceLevel {
                        Text(level.displayName)
                            .font(.caption2)
                            .foregroundColor(confidenceColor)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var confidenceColor: Color {
        guard let level = scan.confidenceLevel else { return .gray }
        switch level {
        case .high:   return .green
        case .medium: return .orange
        case .low:    return .red
        }
    }
}
