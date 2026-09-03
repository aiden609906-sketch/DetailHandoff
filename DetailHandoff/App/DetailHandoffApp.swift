import SwiftUI
import SwiftData

@main
struct DetailHandoffApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: BusinessProfile.self, JobRecord.self)
        } catch {
            fatalError("Unable to create the local data store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
        }
    }
}
