import Capacitor
import WebKit

final class EchoBridgeViewController: CAPBridgeViewController {
    override func webViewConfiguration(
        for instanceConfiguration: InstanceConfiguration
    ) -> WKWebViewConfiguration {
        let configuration = super.webViewConfiguration(for: instanceConfiguration)
        // Echo Cave is audio-first. Permit the bundled welcome recording to
        // begin when the native welcome screen loads, before the first tap.
        configuration.mediaTypesRequiringUserActionForPlayback = []
        return configuration
    }

    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(EchoNativePlugin())
    }
}
