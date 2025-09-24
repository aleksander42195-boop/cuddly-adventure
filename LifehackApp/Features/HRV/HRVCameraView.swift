import SwiftUI
import AVFoundation

struct HRVCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ppg = PPGProcessor()
    @State private var signal: [Double] = []
    @State private var currentHR: Double = 0
    @State private var currentSDNN: Double = 0
    @State private var isRunning = false
    @AppStorage("ppgTorchEnabled") private var torchEnabled: Bool = true

    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacing) {
                Text("HRV via Camera")
                    .font(.title2).bold()
                Text("Place your fingertip gently over the camera lens and keep still. We’ll analyze PPG to estimate HRV.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                signalView
                    .frame(height: 140)
                    .accessibilityHidden(true)

                HStack(spacing: 16) {
                    metric(title: "HR", value: currentHR > 0 ? String(format: "%.0f bpm", currentHR) : "--")
                    metric(title: "SDNN", value: currentSDNN > 0 ? String(format: "%.0f ms", currentSDNN) : "--")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Heart rate \(Int(currentHR)) beats per minute. SDNN \(Int(currentSDNN)) milliseconds.")

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
            .onDisappear { ppg.stop() }
        }
    }

    private func startIfNeeded() {
        guard !isRunning else { return }
        ppg.delegate = delegate
        do {
            try ppg.start()
            isRunning = true
        } catch {
            // ignore
        }
    }

    private func toggleCapture() {
        if isRunning {
            ppg.stop(); isRunning = false
        } else {
            startIfNeeded()
        }
    }

    private func stopAndClose() {
        ppg.stop(); isRunning = false; dismiss()
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
}

#Preview { HRVCameraView() }
