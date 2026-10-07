import SwiftUI

struct SettingsView: View {
    @AppStorage("displayName") private var displayName = "AppTemplate"

    var body: some View {
        Form {
            Section("General") {
                TextField("Display name", text: $displayName)
            }
            Section("About") {
                LabeledContent("Bundle ID", value: Bundle.main.bundleIdentifier ?? "com.example.apptemplate")
                LabeledContent("Version", value: versionText)
            }
        }
        .navigationTitle("Settings")
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
