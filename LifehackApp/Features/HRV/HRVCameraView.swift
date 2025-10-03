import SwiftUI
import AVFoundation
import Combine

struct HRVCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ppg = PPGProcessor()
    @State private var signal: [Double] = []
    @State private var currentHR: Double = 0
    @State private var currentSDNN: Double = 0
    @State private var isRunning = false
    @State private var remainingSeconds: Int = 180
    @State private var timer: Timer? = nil
    @State private var hrSamples: [Double] = []
    @State private var sdnnSamples: [Double] = []
    @State private var showResult: Bool = false
    @State private var result: HRVResult? = nil
    @State private var startedAt: Date? = nil
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
            .onReceive(NotificationCenter.default.publisher(for: .hrvStopMeasurement)) { _ in
                // Stop or complete the measurement when app is backgrounding/interrupting
                if isRunning {
                    completeMeasurement()
                } else {
                    ppg.stop()
                    timer?.invalidate(); timer = nil
                    remainingSeconds = 180
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .appSafeShutdown)) { _ in
                if isRunning {
                    completeMeasurement()
                } else {
                    ppg.stop()
                    timer?.invalidate(); timer = nil
                    remainingSeconds = 180
                }
            }
            .sheet(isPresented: $showResult) {
                if let r = result {
                    HRVResultView(result: r, onSave: { saveLocal($0) }, onDone: { showResult = false })
                }
            }
        }
    }

    private func startIfNeeded() {
        guard !isRunning else { return }
        ppg.delegate = delegate
        do {
            try ppg.start()
            isRunning = true
            hrSamples.removeAll(); sdnnSamples.removeAll()
            startedAt = Date()
            startAutoStopTimer()
        } catch {
            // ignore
        }
    }

    private func toggleCapture() {
        if isRunning {
            completeMeasurement()
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
        onHR: { bpm in currentHR = bpm; if bpm > 0 { hrSamples.append(bpm) } },
        onSDNN: { ms in currentSDNN = ms; if ms > 0 { sdnnSamples.append(ms) } },
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
            if remainingSeconds == 0 { completeMeasurement() }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func completeMeasurement() {
        ppg.stop(); isRunning = false
        timer?.invalidate(); timer = nil
        let duration = 180 - max(0, remainingSeconds)
        remainingSeconds = 180
        let avgHR = hrSamples.isEmpty ? 0 : (hrSamples.reduce(0, +) / Double(hrSamples.count))
        let avgSDNN = sdnnSamples.isEmpty ? 0 : (sdnnSamples.reduce(0, +) / Double(sdnnSamples.count))
        result = HRVResult(
            date: startedAt ?? Date(),
            durationSeconds: max(1, duration),
            averageHRBpm: avgHR,
            averageSDNNms: avgSDNN,
            samples: max(hrSamples.count, sdnnSamples.count)
        )
        showResult = true
    }

    private func saveLocal(_ r: HRVResult) {
        let key = "hrv_results_history"
        var arr: [HRVResult] = []
        let ud = AppGroup.defaults
        if let data = ud.data(forKey: key) {
            if let decoded = try? JSONDecoder().decode([HRVResult].self, from: data) { arr = decoded }
        }
        arr.append(r)
        if let encoded = try? JSONEncoder().encode(arr) {
            ud.set(encoded, forKey: key)
        }
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
