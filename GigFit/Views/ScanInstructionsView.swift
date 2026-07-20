import SwiftUI

/// Pre-scan instructions for floor-calibrated volume measurement.
struct ScanInstructionsView: View {
    @ObservedObject var scanStore: ScanStore
    @State private var currentStep = 0
    @State private var session = ScanSession(name: "Cargo Scan")
    @State private var showingScan = false

    private let steps: [(icon: String, title: String, detail: String)] = [
        ("1.circle", "Find your cargo area",
         "Open all doors and clear the space. You'll need a clear view of all corners."),
        ("2.circle", "Calibrate the floor",
         "Put the phone over the first floor corner, or aim the crosshair at the floor and tap Set Floor."),
        ("3.circle", "Set the base",
         "Aim along the floor to set the width and depth. GigFit creates a rectangular base."),
        ("4.circle", "Raise for height",
         "Raise the phone to the top of the space. Watch the wireframe expand, then lock the height."),
        ("5.circle", "Review & save",
         "Check dimensions and volume. You can optionally tape-calibrate one edge before saving."),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Step cards
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(0..<steps.count, id: \.self) { i in
                                StepCard(
                                    step: i + 1,
                                    icon: steps[i].icon,
                                    title: steps[i].title,
                                    detail: steps[i].detail,
                                    isActive: i == currentStep
                                )
                                .onTapGesture { currentStep = i }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }

                    // Bottom bar
                    VStack(spacing: 12) {
                        Button(action: { showingScan = true }) {
                            Label("Start Scanning", systemImage: "camera.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(red: 0.27, green: 0.53, blue: 1.0))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(red: 0.06, green: 0.06, blue: 0.14))
                }
            }
            .navigationTitle("New Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingScan = false }
                }
            }
            .fullScreenCover(isPresented: $showingScan) {
                ScanView(session: $session, scanStore: scanStore)
            }
        }
    }
}

struct StepCard: View {
    let step: Int
    let icon, title, detail: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? Color(red: 0.27, green: 0.53, blue: 1.0) : .white.opacity(0.25))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isActive ? .white : .white.opacity(0.4))
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(16)
        .background(isActive ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
