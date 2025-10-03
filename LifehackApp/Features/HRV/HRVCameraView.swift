import SwiftUI
import AVFoundation

struct HRVCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ppg = PPGProcessor()
    @State private var signal: [Double] = []
    @State private var currentHR: Double = 0
    @State private var currentSDNN: Double = 0
    @State private var isRunning = false
    @State private var remainingSeconds: Int = 180
    @State private var timer: Timer? = nil
    @AppStorage("ppgTorchEnabled") private var torchEnabled: Bool = true

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacing) {
                Text("HRV via Camera")
                    .font(.title2).bold()
                Text("Place three or more fingertips over the rear camera and flash, and keep still. We’ll analyze PPG to estimate HRV.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                CameraPreview(session: ppg.captureSession)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .accessibilityLabel("Live camera preview")

                signalView
                    .frame(height: 140)
                    .accessibilityHidden(true)

                HStack(spacing: 16) {
                    metric(title: "HR", value: currentHR > 0 ? String(format: "%.0f bpm", currentHR) : "--")
                    metric(title: "SDNN", value: currentSDNN > 0 ? String(format: "%.0f ms", currentSDNN) : "--")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Heart rate \(Int(currentHR)) beats per minute. SDNN \(Int(currentSDNN)) milliseconds.")

                if isRunning {
                    Text("Time left: \(timeString(remainingSeconds))")
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    Text("Measurement duration: 3:00")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
                HStack(spacing: 12) {
                    Button(isRunning ? "Stop" : "Start") { toggleCapture() }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    Toggle(isOn: $torchEnabled) { Image(systemName: torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill") }
                        .toggleStyle(.button)
                        .labelStyle(.iconOnly)
                        .onChange(of: torchEnabled) { _, newVal in ppg.setTorch(enabled: newVal) }
                    Button("Close") { stopAndClose() }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                }
            }
            .padding()
            .navigationTitle("Camera HRV")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.background.ignoresSafeArea())
            .onAppear { startIfNeeded() }
            .onDisappear { ppg.stop(); timer?.invalidate(); timer = nil }
        }
    }

    private func startIfNeeded() {
        guard !isRunning else { return }
        ppg.delegate = delegate
        do {
            try ppg.start()
            isRunning = true
            startAutoStopTimer()
        } catch {
            // ignore
        }
    }

    private func toggleCapture() {
        if isRunning {
            ppg.stop(); isRunning = false; timer?.invalidate(); timer = nil; remainingSeconds = 180
        } else {
            startIfNeeded()
        }
    }

    private func stopAndClose() {
        ppg.stop(); isRunning = false; timer?.invalidate(); timer = nil; remainingSeconds = 180; dismiss()
    }

    private var delegate: PPGProcessorDelegateAdapter { .init(
        onSignal: { val in
            signal.append(val)
            if signal.count > 300 { signal.removeFirst(signal.count - 300) }
        },
        onHR: { bpm in currentHR = bpm },
        onSDNN: { ms in currentSDNN = ms },
        wantsTorch: { torchEnabled }
    ) }

    private func metric(title: String, value: String) -> some View {
        VStack {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var signalView: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let path = Path { p in
                guard signal.count > 1 else { return }
                let maxAbs = max(signal.map { abs($0) }.max() ?? 1, 0.1)
                let scaleY = 0.4 * h / maxAbs
                let stepX = w / CGFloat(max(signal.count - 1, 1))
                p.move(to: CGPoint(x: 0, y: h/2 - CGFloat(signal[0]) * scaleY))
                for i in 1..<signal.count {
                    p.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: h/2 - CGFloat(signal[i]) * scaleY))
                }
            }
            path.stroke(Color.cyan, lineWidth: 2)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.15), lineWidth: 1))
        )
    }

    private func startAutoStopTimer() {
        timer?.invalidate()
        remainingSeconds = 180
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            }
            if remainingSeconds == 0 {
                timer?.invalidate(); timer = nil
                ppg.stop(); isRunning = false
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview { HRVCameraView() }

// MARK: - Camera Preview Layer Wrapper
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.videoPreviewLayer.session = session
        v.videoPreviewLayer.videoGravity = .resizeAspectFill
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
