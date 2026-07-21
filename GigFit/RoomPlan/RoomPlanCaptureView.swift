import SwiftUI
import RoomPlan

/// SwiftUI wrapper around RoomPlan's RoomCaptureView.
struct RoomPlanCaptureView: UIViewRepresentable {
    @ObservedObject var controller: RoomPlanCaptureController

    func makeUIView(context: Context) -> RoomCaptureView {
        let captureView = RoomCaptureView(frame: .zero)
        captureView.delegate = context.coordinator
        return captureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}

    func makeCoordinator() -> RoomCaptureCoordinator {
        RoomCaptureCoordinator(controller: controller)
    }
}

final class RoomCaptureCoordinator: NSObject, RoomCaptureViewDelegate, NSCoding {
    let controller: RoomPlanCaptureController

    init(controller: RoomPlanCaptureController) {
        self.controller = controller
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func encode(with coder: NSCoder) {}

    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData) -> Bool {
        true
    }

    func captureView(didPresent processedResult: CapturedRoom, error: (any Error)?) {
        DispatchQueue.main.async {
            if let error {
                self.controller.errorMessage = error.localizedDescription
            }
            self.controller.isScanning = false
        }
    }
}
