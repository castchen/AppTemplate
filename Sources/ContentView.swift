import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Hello")
                    .font(.largeTitle.bold())
                Text("AppTemplate")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                NavigationLink("Settings") {
                    SettingsView()
                }
            }
            .padding()
            .navigationTitle("AppTemplate")
        }
    }
}

#Preview {
    ContentView()
}
