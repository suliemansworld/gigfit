import SwiftUI

/// Pre-scan instructions — guides the user through the 8-point process.
struct ScanInstructionsView: View {
    @ObservedObject var scanStore: ScanStore
    @State private var currentStep = 0
    @State private var session = ScanSession(name: "Cargo Scan")
    @State private var showingScan = false
    @State private var showingCalibration = false

    private let steps: [(icon: String, title: String, detail: String)] = [
        ("1.circle", "Find your cargo area",
         "Open all doors and clear the space. You'll need a clear view of all corners."),
        ("2.circle", "Place 4 floor corners",
         "Tap on each floor corner of your cargo area. Aim the crosshair at the boundary where floor meets wall."),
        ("3.circle", "Place 4 upper corners",
         "Now tap on the upper corners — the ceiling of your cargo area at each corner."),
        ("4.circle", "Optional calibration",
         "Measure one known distance with a tape measure to improve accuracy, or skip for an approximate result."),
        ("5.circle", "Review & save",
         "See your 3D model, check the volume, and save for later reference."),
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

                        Button(action: {
                            session.name = "Cargo Scan — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
                            showingScan = true
                        }) {
                            Text("Skip calibration & start")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.4))
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
