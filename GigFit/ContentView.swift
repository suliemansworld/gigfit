import SwiftUI

/// Root navigation. Single view — starts at Home.
struct ContentView: View {
    @EnvironmentObject var scanStore: ScanStore

    var body: some View {
        HomeView(scanStore: scanStore)
    }
}
