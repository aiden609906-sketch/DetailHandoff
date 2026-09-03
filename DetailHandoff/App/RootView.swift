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

private struct SettingsView: View {
    let businessProfile: BusinessProfile

    var body: some View {
        NavigationStack {
            Form {
                Section("Business") {
                    Text(businessProfile.businessName)

                    if !businessProfile.phone.isEmpty {
                        Text(businessProfile.phone)
                    }

                    if !businessProfile.email.isEmpty {
                        Text(businessProfile.email)
                    }
                }

                Section {
                    Text("Records stay on this device.")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// Temporary placeholder until the Jobs feature supplies the production view.
private struct JobsListView: View {
    var body: some View {
        NavigationStack {
            Text("Jobs")
                .navigationTitle("Jobs")
        }
    }
}
