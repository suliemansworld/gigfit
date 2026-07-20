import SwiftUI
import ARKit
import SceneKit

/// SwiftUI wrapper around ARSCNView for the scanning screen.
struct ARScanView: UIViewRepresentable {

    @ObservedObject var coordinator: ARScanCoordinator

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.contentMode = .scaleAspectFill
        coordinator.attach(to: view)
        coordinator.startSession()

        // Tap gesture
        let tapGesture = UITapGestureRecognizer(target: context.coordinator,
                                                  action: #selector(ContextCoordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)

        // Crosshair overlay
        addCrosshair(to: view)

        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ()) {
        uiView.session.pause()
    }

    // MARK: — Context Coordinator (tap handling) —

    func makeCoordinator() -> ContextCoordinator {
        ContextCoordinator(scanCoordinator: coordinator)
    }

    class ContextCoordinator: NSObject {
        let scanCoordinator: ARScanCoordinator

        init(scanCoordinator: ARScanCoordinator) {
            self.scanCoordinator = scanCoordinator
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended else { return }
            let point = gesture.location(in: gesture.view)
            scanCoordinator.handleTap(at: point)
        }
    }

    // MARK: — Crosshair —

    private func addCrosshair(to view: ARSCNView) {
        let size: CGFloat = 60
        let crosshair = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        crosshair.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY - 80)
        crosshair.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin,
                                       .flexibleTopMargin, .flexibleBottomMargin]
        crosshair.backgroundColor = .clear
        crosshair.isUserInteractionEnabled = false

        let path = UIBezierPath()
        let c = size / 2
        let gap: CGFloat = 18
        let outer: CGFloat = size / 2

        // Horizontal
        path.move(to: CGPoint(x: c - outer, y: c))
        path.addLine(to: CGPoint(x: c - gap, y: c))
        path.move(to: CGPoint(x: c + gap, y: c))
        path.addLine(to: CGPoint(x: c + outer, y: c))

        // Vertical
        path.move(to: CGPoint(x: c, y: c - outer))
        path.addLine(to: CGPoint(x: c, y: c - gap))
        path.move(to: CGPoint(x: c, y: c + gap))
        path.addLine(to: CGPoint(x: c, y: c + outer))

        let shape = CAShapeLayer()
        shape.path = path.cgPath
        shape.strokeColor = UIColor.white.withAlphaComponent(0.7).cgColor
        shape.lineWidth = 2
        shape.lineCap = .round

        crosshair.layer.addSublayer(shape)
        view.addSubview(crosshair)
    }
}
