import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var app: AppState
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing) {
                GlassCard {
                    HStack(alignment: .center, spacing: AppTheme.spacing) {
                        Image(systemName: "person.circle.fill").font(.system(size: 72))
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your Profile").font(.title.bold())
                            Text("Manage personal details and health preferences")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Birthdate").font(.headline)
                        DatePicker("Select birthdate", selection: $app.birthdate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                        Text("Zodiac: \(Zodiac.from(date: app.birthdate).rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Profile")
        .background(AppTheme.background.ignoresSafeArea())
    }
}

#Preview { NavigationStack { ProfileView() } }
