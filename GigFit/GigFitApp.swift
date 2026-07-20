import SwiftUI

@main
struct GigFitApp: App {
    @StateObject private var scanStore = ScanStore()

    var body: some Scene {
        WindowGroup {
            HomeView(scanStore: scanStore)
                .preferredColorScheme(.dark)
        }
    }
}
