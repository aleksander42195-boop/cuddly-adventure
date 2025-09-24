// WatchApp/Views/WatchCoachSettingsView.swift
import SwiftUI

struct WatchCoachSettingsView: View {
    @State private var engineRaw: String = AppGroup.defaults.string(forKey: SharedKeys.coachEngineSelection)
        ?? CoachEngine.openAIResponses.rawValue
    @State private var wristTipsEnabled: Bool = AppGroup.defaults.bool(forKey: SharedKeys.coachWristTipsEnabled)

    var body: some View {
        Form {
            Picker("Motor", selection: $engineRaw) {
                ForEach(CoachEngine.allCases) { eng in
                    Text(eng.rawValue).tag(eng.rawValue)
                }
            }
            Toggle("Coach-tips på håndleddet", isOn: $wristTipsEnabled)
        }
        .onChange(of: engineRaw) { newValue in
            AppGroup.defaults.set(newValue, forKey: SharedKeys.coachEngineSelection)
        }
        .onChange(of: wristTipsEnabled) { newValue in
            AppGroup.defaults.set(newValue, forKey: SharedKeys.coachWristTipsEnabled)
        }
        .navigationTitle("Coach Engine")
    }
}

#Preview("WatchCoachSettingsView") {
    WatchCoachSettingsView()
}
