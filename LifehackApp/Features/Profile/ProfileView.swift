import SwiftUI

struct ProfileView: View {
    var body: some View {
        VStack(spacing: AppTheme.spacing) {
            Image(systemName: "person.circle.fill").font(.system(size: 72))
            Text("Your Profile")
                .font(.title.bold())
            Text("Manage personal details and health permissions")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Profile")
        .background(AppTheme.background.ignoresSafeArea())
    }
}

#Preview { NavigationStack { ProfileView() } }
