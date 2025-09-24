import SwiftUI

struct HRVCameraView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacing) {
                Text("HRV via Camera")
                    .font(.title2).bold()
                Text("Place your fingertip gently over the camera lens and keep still. We’ll analyze PPG to estimate HRV.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
            }
            .padding()
            .navigationTitle("Camera HRV")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.background.ignoresSafeArea())
        }
    }
}

#Preview { HRVCameraView() }
