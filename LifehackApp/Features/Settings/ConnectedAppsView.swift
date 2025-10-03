import SwiftUI

struct ConnectedAppsView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        List {
            Section(header: Text("Health")) {
                HStack {
                    Image(systemName: "heart.fill").foregroundStyle(.pink)
                    VStack(alignment: .leading) {
                        Text("Apple Health")
                        Text(app.isHealthAuthorized ? "Connected" : "Not Connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if app.isHealthAuthorized {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    } else {
                        Button("Connect") { Task { await app.requestHealthAuthorization() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
                HStack {
                    Spacer()
                    Button {
                        app.openHealthApp()
                    } label: {
                        Label("Open Apple Health", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section(header: Text("Music")) {
                HStack {
                    Image(systemName: "music.note").foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("Spotify")
                        Text("Not Connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Connect") {
                        // TODO: Implement Spotify OAuth flow
                        // Placeholder: open Spotify app or settings when available
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Connected Apps")
    }
}

#Preview {
    ConnectedAppsView().environmentObject(AppState())
}
