import SwiftUI

struct HomeView: View {
    @ObservedObject var scanStore: ScanStore
    @State private var showingNewScan = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()

                if scanStore.scans.isEmpty {
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
                ScanInstructionsView(scanStore: scanStore)
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

            Spacer()
        }
    }

    private var scanList: some View {
        List {
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
        .scrollContentBackground(.hidden)
    }
}

struct ScanRow: View {
    let scan: ScanSession

    var body: some View {
        HStack(spacing: 12) {
            // Confidence indicator
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
