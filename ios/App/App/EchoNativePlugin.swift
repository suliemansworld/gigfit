import AVFAudio
import Capacitor
import UIKit

@objc(EchoNativePlugin)
public final class EchoNativePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "EchoNativePlugin"
    public let jsName = "EchoNative"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configureAudioSession", returnType: CAPPluginReturnPromise),
    ]

    private var observers: [NSObjectProtocol] = []

    public override func load() {
        installAudioObservers()
        installAccessibilityActions()
        try? activateAudioSession()
    }

    @objc public func configureAudioSession(_ call: CAPPluginCall) {
        do {
            try activateAudioSession()
            call.resolve()
        } catch {
            call.reject("Could not configure the Echo Cave audio session.", nil, error)
        }
    }

    private func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playback,
            mode: .default,
            options: [.allowAirPlay, .allowBluetoothA2DP]
        )
        try session.setActive(true)
    }

    private func installAudioObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        observers.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard
                let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                let type = AVAudioSession.InterruptionType(rawValue: rawType)
            else { return }

            if type == .began {
                self?.notifyListeners("audioInterruption", data: ["phase": "began"])
                return
            }

            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
            if shouldResume { try? self?.activateAudioSession() }
            self?.notifyListeners("audioInterruption", data: [
                "phase": "ended",
                "shouldResume": shouldResume,
            ])
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard
                let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason),
                reason == .oldDeviceUnavailable
            else { return }

            self?.notifyListeners("audioRouteChange", data: ["reason": "old-device-unavailable"])
        })

        observers.append(center.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            try? self?.activateAudioSession()
            self?.notifyListeners("audioInterruption", data: [
                "phase": "ended",
                "shouldResume": true,
            ])
        })
    }

    private func installAccessibilityActions() {
        webView?.accessibilityCustomActions = [
            action("Move forward", #selector(moveForward)),
            action("Move left", #selector(moveLeft)),
            action("Listen and describe room", #selector(listen)),
            action("Move right", #selector(moveRight)),
            action("Retreat", #selector(retreat)),
            action("Repeat last narration", #selector(repeatNarration)),
            action("Teleport to base", #selector(teleport)),
            action("Open menu", #selector(openMenu)),
            action("Open inventory", #selector(openInventory)),
            action("Open settings", #selector(openSettings)),
        ]
    }

    private func action(_ name: String, _ selector: Selector) -> UIAccessibilityCustomAction {
        UIAccessibilityCustomAction(name: name, target: self, selector: selector)
    }

    private func dispatchAccessibilityAction(_ action: String) -> Bool {
        notifyListeners("accessibilityAction", data: ["action": action])
        return true
    }

    @objc private func moveForward() -> Bool { dispatchAccessibilityAction("up") }
    @objc private func moveLeft() -> Bool { dispatchAccessibilityAction("left") }
    @objc private func listen() -> Bool { dispatchAccessibilityAction("listen") }
    @objc private func moveRight() -> Bool { dispatchAccessibilityAction("right") }
    @objc private func retreat() -> Bool { dispatchAccessibilityAction("down") }
    @objc private func repeatNarration() -> Bool { dispatchAccessibilityAction("repeat") }
    @objc private func teleport() -> Bool { dispatchAccessibilityAction("teleport") }
    @objc private func openMenu() -> Bool { dispatchAccessibilityAction("menu") }
    @objc private func openInventory() -> Bool { dispatchAccessibilityAction("inventory") }
    @objc private func openSettings() -> Bool { dispatchAccessibilityAction("settings") }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
