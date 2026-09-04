import SwiftData
import SwiftUI

struct RootView: View {
    @Query(sort: \BusinessProfile.createdAt) private var businessProfiles: [BusinessProfile]

    var body: some View {
        if let businessProfile = businessProfiles.first {
            TabView {
                JobsListView()
                    .tabItem {
                        Label("Jobs", systemImage: "list.bullet")
                    }

                SettingsView(businessProfile: businessProfile)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
        } else {
            SetupView()
        }
    }
}
