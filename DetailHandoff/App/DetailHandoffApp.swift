import SwiftUI

@main
struct DetailHandoffApp: App {
    @StateObject private var startup = AppStartup()

    var body: some Scene {
        WindowGroup {
            AppStartupView(startup: startup)
        }
    }
}
