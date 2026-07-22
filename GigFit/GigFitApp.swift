import SwiftUI

@main
struct GigFitApp: App {
    @StateObject private var scanStore = ScanStore()
    @StateObject private var cargoStore = CargoStore()

    var body: some Scene {
        WindowGroup {
            HomeView(scanStore: scanStore)
                .environmentObject(cargoStore)
                .preferredColorScheme(.dark)
        }
    }
}
