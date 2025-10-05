import SwiftUI
import UIKit
import AVFoundation
import Combine
import QuartzCore
import OSLog

struct HRVCameraView: View {
    private static let logger = Logger(subsystem: "com.lifehack.LifehackApp", category: "HRV")
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
    @State private var showCameraError: Bool = false
    @State private var cameraErrorMessage: String = ""
    @State private var startWatchdog: Timer? = nil
    @State private var attemptedSoftRestart: Bool = false
    @AppStorage("ppgTorchEnabled") private var torchEnabled: Bool = true
    @AppStorage("ppgTorchLevel") private var torchLevel: Double = 0.25 // 0..1
    // UI throttling
    @State private var lastSignalStamp: CFTimeInterval = 0
    private let signalUpdateInterval: CFTimeInterval = 0.1
    @State private var lastHRStamp: CFTimeInterval = 0
    @State private var lastSDNNStamp: CFTimeInterval = 0
    private let hrUpdateInterval: CFTimeInterval = 0.5
    private let sdnnUpdateInterval: CFTimeInterval = 0.5

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacing) {
                Text("HRV via Camera").font(.title2).bold()
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
                    Text("Time left: \(timeString(remainingSeconds))").font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                } else {
                    Text("Measurement duration: 3:00").font(.footnote).foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
                HStack(spacing: 12) {
                    Button(isRunning ? "Stop" : "Start") { toggleCapture() }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    Toggle(isOn: $torchEnabled) { Image(systemName: torchEnabled ? "flashlight.on.fill" : "flashlight.off.fill") }
                        .toggleStyle(.button)
                        .labelStyle(.iconOnly)
                        .onChange(of: torchEnabled) { _, newVal in ppg.setTorch(enabled: newVal) }
                    Menu {
                        Button("Flash Low") { torchLevel = 0.25; ppg.setTorch(enabled: torchEnabled) }
                        Button("Flash Medium") { torchLevel = 0.5; ppg.setTorch(enabled: torchEnabled) }
                        Button("Flash High") { torchLevel = 0.8; ppg.setTorch(enabled: torchEnabled) }
                    } label: { Image(systemName: "sun.max.fill") }
                    Button("Close") { stopAndClose() }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                }
            }
            .padding()
            .navigationTitle("Camera HRV")
            .navigationBarTitleDisplayMode(.inline)
            .background(AppTheme.background.ignoresSafeArea())
            .onAppear { }
            .onDisappear { ppg.stop(); timer?.invalidate(); timer = nil; startWatchdog?.invalidate(); startWatchdog = nil }
            .onReceive(NotificationCenter.default.publisher(for: .hrvStopMeasurement)) { _ in
                Self.logger.notice("Received .hrvStopMeasurement; isRunning=\(self.isRunning, privacy: .public)")
                if isRunning { completeMeasurement() } else { ppg.stop(); timer?.invalidate(); timer = nil; remainingSeconds = 180 }
            }
            .onReceive(NotificationCenter.default.publisher(for: .appSafeShutdown)) { _ in
                Self.logger.notice("Received .appSafeShutdown; isRunning=\(self.isRunning, privacy: .public)")
                if isRunning { completeMeasurement() } else { ppg.stop(); timer?.invalidate(); timer = nil; remainingSeconds = 180 }
            }
            .sheet(isPresented: $showResult) {
                if let r = result { HRVResultView(result: r, onSave: { saveLocal($0) }, onDone: { showResult = false }) }
            }
            .alert("Camera Error", isPresented: $showCameraError) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    dismissIfStopped()
                }
                Button("OK", role: .cancel) { dismissIfStopped() }
            } message: { Text(cameraErrorMessage) }
        }
    }

    private func startIfNeeded() {
        guard !isRunning else { return }
        Self.logger.notice("HRV startIfNeeded invoked")
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            beginStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted { self.beginStart() }
                    else {
                        self.cameraErrorMessage = "Camera access was denied. Enable Camera in Settings → Privacy → Camera, then try again."
                        self.showCameraError = true
                        Self.logger.error("HRV start blocked: camera permission denied")
                    }
                }
            }
        case .denied, .restricted:
            cameraErrorMessage = "Camera access is not allowed. Enable Camera in Settings → Privacy → Camera, then try again."
            showCameraError = true
            Self.logger.error("HRV start blocked: camera permission denied/restricted")
        @unknown default:
            beginStart()
        }
    }

    private func beginStart() {
        ppg.delegate = delegate
        do {
            try ppg.start()
            isRunning = true
            hrSamples.removeAll(); sdnnSamples.removeAll()
            startedAt = Date()
            Self.logger.notice("HRV session started at \(self.startedAt?.timeIntervalSince1970 ?? 0, privacy: .public); torchEnabled=\(self.torchEnabled, privacy: .public)")
            startAutoStopTimer()
            startWatchdog?.invalidate()
            attemptedSoftRestart = false
            startWatchdog = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
                if !showResult && isRunning && signal.isEmpty {
                    if !attemptedSoftRestart {
                        Self.logger.notice("HRV watchdog: no frames; attempting soft conservative restart")
                        attemptedSoftRestart = true
                        ppg.softRestartConservative()
                        // Schedule a final check after a shorter delay
                        startWatchdog = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { _ in
                            if !showResult && isRunning && signal.isEmpty {
                                Self.logger.error("HRV watchdog: still no frames after soft restart; stopping session")
                                ppg.stop(); isRunning = false
                                timer?.invalidate(); timer = nil
                                remainingSeconds = 180
                                cameraErrorMessage = "Camera stream didn't start. Please ensure camera and flashlight access are allowed, then try again."
                                showCameraError = true
                            }
                        }
                        if let wd2 = startWatchdog { RunLoop.main.add(wd2, forMode: .common) }
                    } else {
                        Self.logger.error("HRV watchdog: no frames within 8s; stopping session")
                        ppg.stop(); isRunning = false
                        timer?.invalidate(); timer = nil
                        remainingSeconds = 180
                        cameraErrorMessage = "Camera stream didn't start. Please ensure camera and flashlight access are allowed, then try again."
                        showCameraError = true
                    }
                }
            }
            if let wd = startWatchdog { RunLoop.main.add(wd, forMode: .common) }
        } catch {
            cameraErrorMessage = (error as NSError).localizedDescription
            showCameraError = true
            Self.logger.error("HRV start failed: \(self.cameraErrorMessage, privacy: .public)")
        }
    }

    private func toggleCapture() {
        if isRunning { Self.logger.notice("HRV manual stop requested"); completeMeasurement() }
        else { Self.logger.notice("HRV manual start requested"); startIfNeeded() }
    }

    private func stopAndClose() {
        Self.logger.notice("HRV stopAndClose invoked")
        ppg.stop(); isRunning = false; timer?.invalidate(); timer = nil; remainingSeconds = 180; startWatchdog?.invalidate(); startWatchdog = nil; dismiss()
    }

    private func dismissIfStopped() { if !isRunning { dismiss() } }

    private var delegate: PPGProcessorDelegateAdapter { .init(
        onSignal: { val in
            let now = CACurrentMediaTime()
            if now - lastSignalStamp >= signalUpdateInterval {
                lastSignalStamp = now
                signal.append(val)
                if signal.count > 300 { signal.removeFirst(signal.count - 300) }
                startWatchdog?.invalidate(); startWatchdog = nil
            }
        },
        onHR: { bpm in
            let now = CACurrentMediaTime()
            if now - lastHRStamp >= hrUpdateInterval {
                lastHRStamp = now
                currentHR = bpm
                if bpm > 0 { hrSamples.append(bpm) }
            }
        },
        onSDNN: { ms in
            let now = CACurrentMediaTime()
            if now - lastSDNNStamp >= sdnnUpdateInterval {
                lastSDNNStamp = now
                currentSDNN = ms
                if ms > 0 { sdnnSamples.append(ms) }
            }
        },
        wantsTorch: { torchEnabled },
        onStarted: {
            if !isRunning {
                isRunning = true
                hrSamples.removeAll(); sdnnSamples.removeAll();
                startedAt = Date()
                startAutoStopTimer()
                Self.logger.notice("HRV timer started on first stream frame; torchEnabled=\(self.torchEnabled, privacy: .public)")
            }
            // Apply torch only after first frame and ramp it to reduce thermal spike on startup
            ppg.setTorch(enabled: torchEnabled, ramp: true)
            startWatchdog?.invalidate(); startWatchdog = nil
        }
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
            if remainingSeconds > 0 { remainingSeconds -= 1 }
            if remainingSeconds == 0 { completeMeasurement() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        Self.logger.notice("HRV countdown timer started: 180s")
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func completeMeasurement() {
        let duration = 180 - max(0, remainingSeconds)
        Self.logger.notice("HRV completeMeasurement invoked; elapsed=\(duration, privacy: .public)s")
        ppg.stop(); isRunning = false
        timer?.invalidate(); timer = nil
        remainingSeconds = 180
        let avgHR = hrSamples.isEmpty ? 0 : (hrSamples.reduce(0, +) / Double(hrSamples.count))
        let avgSDNN = sdnnSamples.isEmpty ? 0 : (sdnnSamples.reduce(0, +) / Double(sdnnSamples.count))
        Self.logger.notice("HRV results: avgHR=\(avgHR, privacy: .public) bpm, avgSDNN=\(avgSDNN, privacy: .public) ms, hrSamples=\(self.hrSamples.count, privacy: .public), sdnnSamples=\(self.sdnnSamples.count, privacy: .public)")
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
        if let encoded = try? JSONEncoder().encode(arr) { ud.set(encoded, forKey: key) }
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
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
