import Foundation
import ARKit

/// Manages the ARKit session configuration and state.
final class ARSessionController: ObservableObject {
    @Published var sessionState: SessionState = .initializing
    @Published var trackingMessage: String = ""

    private let session: ARSession

    enum SessionState {
        case initializing
        case ready
        case limited(reason: String)
        case failed
    }

    init(session: ARSession) {
        self.session = session
    }

    func start() {
        guard ARWorldTrackingConfiguration.isSupported else {
            sessionState = .failed
            trackingMessage = "ARKit not supported on this device"
            return
        }

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        config.environmentTexturing = .automatic

        session.run(config, options: [.resetTracking, .removeExistingAnchors])
        sessionState = .initializing
    }

    func reset() {
        start()
    }

    func resume() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        config.environmentTexturing = .automatic
        session.run(config)
    }

    func pause() {
        session.pause()
    }
}
