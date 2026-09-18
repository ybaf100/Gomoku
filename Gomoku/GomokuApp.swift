import SwiftUI

@main
struct GomokuApp: App {
    init() {
        #if DEBUG
        UITestSupport.prepareIfRequested()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
