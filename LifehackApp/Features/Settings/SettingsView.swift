import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var engineManager: CoachEngineManager
    @AppStorage("notificationsEnabled") private var notificationsEnabled: Bool = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @State private var selectedIconKey: String? = AppIconManager.currentKey()

    var body: some View {
        NavigationStack {
            List {
                Section("Coach") {
                    NavigationLink("Coach Engine") {
                        CoachEngineSettingsView()
                    }
                }

                Section("Appearance") {
                    Picker("App Icon", selection: Binding(
                        get: { selectedIconKey ?? "__primary__" },
                        set: { newVal in
                            let key: String? = (newVal == "__primary__") ? nil : newVal
                            selectedIconKey = key
                            AppIconManager.set(key: key)
                        }
                    )) {
                        ForEach(AppIconManager.options) { opt in
                            Text(opt.title).tag(opt.key ?? "__primary__")
                        }
                    }
                }

                Section("Preferences") {
                    Toggle("Notifications", isOn: $notificationsEnabled)
                    Toggle("Haptics", isOn: $hapticsEnabled)
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                            .foregroundStyle(.secondary)
                    }
                    if let url = URL(string: "https://example.com/privacy") {
                        Link("Privacy Policy", destination: url)
                    }
                }
            }
            .navigationTitle("Innstillinger")
            .onAppear { selectedIconKey = AppIconManager.currentKey() }
        }
    }
}

#Preview { SettingsView().environmentObject(CoachEngineManager()) }
