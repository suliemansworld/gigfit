import SwiftUI

struct ScanInstructionsView: View {
    @ObservedObject var scanStore: ScanStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingScan = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    // Step cards
                    VStack(spacing: 20) {
                        instructionCard(
                            number: 1,
                            title: "Position your device",
                            description: "Stand facing the cargo area. Keep the phone steady at eye level.",
                            icon: "figure.stand"
                        )
                        instructionCard(
                            number: 2,
                            title: "Place floor corners",
                            description: "Tap the screen to place 4 points at the floor boundaries of your cargo space.",
                            icon: "square.grid.3x3.topleft.filled"
                        )
                        instructionCard(
                            number: 3,
                            title: "Place upper corners",
                            description: "Place the 4 upper boundary points to define the full 3D volume.",
                            icon: "square.grid.3x3.topright.filled"
                        )
                        instructionCard(
                            number: 4,
                            title: "Review & save",
                            description: "After all 8 points, review the 3D model, dimensions, and volume.",
                            icon: "checkmark.circle"
                        )
                    }
                    .padding(.horizontal, 24)

                    Spacer()

                    // Tips
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Move slowly for best surface detection. Tap crosshair to place points.")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // Start button
                    Button(action: { showingScan = true }) {
                        Text("Start Scan")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color(red: 0.27, green: 0.53, blue: 1.0))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("New Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showingScan) {
                ScanView(scanStore: scanStore)
            }
        }
    }

    private func instructionCard(number: Int, title: String, description: String, icon: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.27, green: 0.53, blue: 1.0).opacity(0.2))
                    .frame(width: 36, height: 36)
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color(red: 0.27, green: 0.53, blue: 1.0))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white.opacity(0.3))
                .frame(width: 28)
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
