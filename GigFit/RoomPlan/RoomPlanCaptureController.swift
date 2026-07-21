import Foundation
import RoomPlan
import SwiftUI

/// Wraps RoomPlan's RoomCaptureSession, producing a CapturedRoom on completion.
final class RoomPlanCaptureController: ObservableObject {
    @Published var isScanning = false
    @Published var finalRoom: CapturedRoom?
    @Published var errorMessage: String?
    @Published var instructionText = "Pan the phone slowly around the entire room."

    var captureSession: RoomCaptureSession?

    var isLiDARAvailable: Bool {
        RoomCaptureSession.isSupported
    }

    func startSession() {
        guard RoomCaptureSession.isSupported else {
            errorMessage = "RoomPlan requires a LiDAR-equipped iPhone (Pro model, iPhone 12 or later)."
            return
        }
        let session = RoomCaptureSession()
        session.delegate = self
        captureSession = session
        isScanning = true
        let config = RoomCaptureSession.Configuration()
        session.run(configuration: config)
    }

    func stopSession() {
        captureSession?.stop()
        isScanning = false
    }

    func reset() {
        finalRoom = nil
        errorMessage = nil
        instructionText = "Pan the phone slowly around the entire room."
        captureSession = nil
    }
}

extension RoomPlanCaptureController: RoomCaptureSessionDelegate {
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {}

    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: (any Error)?) {
        DispatchQueue.main.async {
            if !self.isScanning { return } // already stopped by user
            if let error {
                self.errorMessage = error.localizedDescription
                self.isScanning = false
                return
            }
            // Reconstruct CapturedRoom from data via encode/decode
            do {
                let encoder = JSONEncoder()
                let encoded = try encoder.encode(data)
                let room = try JSONDecoder().decode(CapturedRoom.self, from: encoded)
                self.finalRoom = room
            } catch {
                self.errorMessage = "Failed to process room: \(error.localizedDescription)"
            }
            self.isScanning = false
        }
    }

    func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction) {
        DispatchQueue.main.async {
            self.instructionText = instruction.displayString
        }
    }
}

extension RoomCaptureSession.Instruction {
    var displayString: String {
        switch self {
        case .moveCloseToWall: return "Move closer to the wall."
        case .moveAwayFromWall: return "Move away from the wall."
        case .slowDown: return "Slow down your movement."
        case .turnOnLight: return "Turn on more light in the room."
        case .lowTexture: return "Point at textured surfaces."
        case .normal: return "Pan the phone slowly around the room."
        @unknown default: return "Pan the phone slowly around the room."
        }
    }
}
