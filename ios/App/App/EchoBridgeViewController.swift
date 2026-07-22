import Capacitor

final class EchoBridgeViewController: CAPBridgeViewController {
    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(EchoNativePlugin())
    }
}
