import SwiftUI
import RoomPlan

struct RoomPlanScanView: View {
    @ObservedObject var scanStore: ScanStore
    @StateObject private var controller = RoomPlanCaptureController()
    @State private var showingReview = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            if controller.isLiDARAvailable {
                RoomPlanCaptureView(controller: controller)
                    .ignoresSafeArea()

                VStack {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "cube.transparent.fill")
                                .foregroundColor(.green)
                            Text("3D Room Scan")
                                .font(.headline).foregroundColor(.white)
                            Spacer()
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2).foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        Text(controller.instructionText)
                            .font(.subheadline).foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12).background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 12).padding(.top, 48)

                    Spacer()

                    Button(action: stopCapture) {
                        Label("Stop & Process", systemImage: "stop.circle.fill")
                            .font(.headline).foregroundColor(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "sensor.tag.radiowaves.forward")
                        .font(.system(size: 48)).foregroundColor(.orange)
                    Text("LiDAR Required")
                        .font(.title2.weight(.bold)).foregroundColor(.white)
                    Text("3D Room Scan requires a LiDAR-equipped iPhone.\nUse Auto Room Scan instead for non-Pro devices.")
                        .font(.body).foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center).padding(.horizontal, 40)
                    Button(action: { dismiss() }) {
                        Text("Go Back").font(.headline).foregroundColor(.white)
                            .padding(.horizontal, 32).padding(.vertical, 14)
                            .background(Color.blue).clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.06, green: 0.06, blue: 0.14))
            }
        }
        .onReceive(controller.$finalRoom) { room in
            if room != nil { showingReview = true }
        }
        .sheet(isPresented: $showingReview) {
            if let room = controller.finalRoom {
                RoomPlanReviewView(capturedRoom: room, scanStore: scanStore)
            }
        }
        .onAppear { controller.startSession() }
        .onDisappear { controller.stopSession() }
    }

    private func stopCapture() { controller.stopSession() }
}
