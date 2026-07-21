import SwiftUI
import RoomPlan
import QuickLook

/// Shows the captured 3D room model with dimensions.
struct RoomPlanReviewView: View {
    let capturedRoom: CapturedRoom
    @ObservedObject var scanStore: ScanStore
    @State private var usdzURL: URL?
    @State private var isSaved = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.14)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if let usdzURL {
                        QuickLookPreview(url: usdzURL)
                            .frame(height: UIScreen.main.bounds.height * 0.45)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(12)
                    } else {
                        Rectangle()
                            .fill(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(12)
                            .frame(height: UIScreen.main.bounds.height * 0.45)
                            .overlay {
                                ProgressView("Exporting 3D model...")
                                    .tint(.white)
                            }
                    }

                    Spacer()

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
                            Text("Done")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("3D Room Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear { exportToUSDZ() }
        }
    }

    private func exportToUSDZ() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let fileURL = tempDir.appendingPathComponent("room_\(UUID().uuidString.prefix(8)).usdz")
                try capturedRoom.export(to: fileURL)
                DispatchQueue.main.async { self.usdzURL = fileURL }
            } catch {
                print("Failed to export USDZ: \(error)")
            }
        }
    }

    private func saveScan() {
        var session = ScanSession(name: "3D Room — \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))")
        session.dimensions = ScanDimensions(lengthMeters: 0, widthMeters: 0, heightMeters: 0, rawVolumeCubicMeters: 0, conservativeVolumeCubicMeters: 0)
        scanStore.save(session)
        isSaved = true
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> QLPreviewControllerWrapper {
        let vc = QLPreviewControllerWrapper()
        vc.url = url
        return vc
    }
    func updateUIViewController(_ uiViewController: QLPreviewControllerWrapper, context: Context) {}
}

final class QLPreviewControllerWrapper: UIViewController, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    var url: URL?
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard url != nil else { return }
        let preview = QLPreviewController()
        preview.dataSource = self
        preview.delegate = self
        present(preview, animated: false)
    }
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        url! as QLPreviewItem
    }
}
