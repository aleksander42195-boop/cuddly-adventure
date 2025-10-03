import SwiftUI
import AVFoundation

struct HRVMeasureIntroView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var navigateToMeasure = false
    @State private var showDeniedAlert = false

    private let measurementSeconds: Int = 180

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacing) {
                VStack(spacing: 8) {
                    Text("Measure HRV with Camera").font(.title2).bold()
                    Text("Cover the rear camera and flash with three or more fingertips. Keep still and relaxed. The measurement takes about \(measurementSeconds/60) minutes for higher accuracy.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Wash and warm your hands for good blood flow", systemImage: "drop.fill")
                    Label("Use 3+ fingers to fully cover the camera and flash", systemImage: "camera.fill")
                    Label("Don't press too hard; keep your hand still", systemImage: "hand.raised.fill")
                    Label("Sit and breathe normally during the test", systemImage: "lungs.fill")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

                Spacer(minLength: 8)

                // Push HRVCameraView using modern NavigationStack API without deprecated isActive link

                Button {
                    requestCameraPermissionThenNavigate()
                } label: {
                    Label("Measure", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(AppTheme.LiquidGlassButtonStyle())

                Button("Close") { dismiss() }
                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    .tint(.gray)
            }
            .padding()
            .navigationTitle("HRV Camera")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.background.ignoresSafeArea())
            .navigationDestination(isPresented: $navigateToMeasure) {
                HRVCameraView()
            }
            .alert("Camera Access Needed", isPresented: $showDeniedAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please allow camera access to measure HRV using your fingertip over the camera.")
            }
        }
    }

    private func requestCameraPermissionThenNavigate() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            navigateToMeasure = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { granted ? (navigateToMeasure = true) : (showDeniedAlert = true) }
            }
        case .denied, .restricted:
            showDeniedAlert = true
        @unknown default:
            showDeniedAlert = true
        }
    }
}

#Preview { HRVMeasureIntroView() }
