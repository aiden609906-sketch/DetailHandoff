import SwiftData
import SwiftUI

@MainActor
final class AppStartup: ObservableObject {
    enum State {
        case ready(ModelContainer)
        case failed
    }

    @Published private(set) var state: State

    private let makeContainer: () throws -> ModelContainer

    convenience init() {
        self.init {
            try ModelContainer(for: BusinessProfile.self, JobRecord.self)
        }
    }

    init(makeContainer: @escaping () throws -> ModelContainer) {
        self.makeContainer = makeContainer
        state = Self.openStore(using: makeContainer)
    }

    func retry() {
        state = Self.openStore(using: makeContainer)
    }

    private static func openStore(
        using makeContainer: () throws -> ModelContainer
    ) -> State {
        do {
            return .ready(try makeContainer())
        } catch {
            return .failed
        }
    }
}

struct AppStartupView: View {
    @ObservedObject var startup: AppStartup

    var body: some View {
        switch startup.state {
        case let .ready(container):
            RootView()
                .modelContainer(container)
        case .failed:
            StartupFailureView {
                startup.retry()
            }
        }
    }
}

private struct StartupFailureView: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.spacing16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text("Local data store unavailable")
                .font(.title2.weight(.semibold))

            Text("DetailHandoff could not open its on-device records. Your existing records were not deleted or replaced.")
                .foregroundStyle(.secondary)

            Text("Try opening the store again. If the problem continues, close the app and contact DetailHandoff support before reinstalling.")
                .foregroundStyle(.secondary)

            Button("Try Opening Again", action: retry)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .multilineTextAlignment(.center)
        .padding(AppTheme.spacing24)
    }
}
