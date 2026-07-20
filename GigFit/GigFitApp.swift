import SwiftUI

@main
struct GigFitApp: App {
    @StateObject private var scanStore = ScanStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(scanStore)
                .preferredColorScheme(.dark)
        }
    }
}
