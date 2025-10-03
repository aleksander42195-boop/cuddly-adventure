import SwiftUI

struct HRVResult: Codable, Equatable, Sendable {
    let date: Date
    let durationSeconds: Int
    let averageHRBpm: Double
    let averageSDNNms: Double
    let samples: Int
}

struct HRVResultView: View {
    let result: HRVResult
    var onSave: ((HRVResult) -> Void)?
    var onDone: (() -> Void)?

    @State private var saved = false

    var body: some View {
        VStack(spacing: AppTheme.spacingL) {
            Text("HRV Measurement Result").font(.title2).bold()
            VStack(spacing: 12) {
                metric(title: "Average HR", value: String(format: "%.0f bpm", result.averageHRBpm))
                metric(title: "Average SDNN", value: String(format: "%.0f ms", result.averageSDNNms))
                Text("Duration: \(timeString(result.durationSeconds))  •  Samples: \(result.samples)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

            HStack(spacing: AppTheme.spacing) {
                Button(saved ? "Saved" : "Save") {
                    onSave?(result)
                    saved = true
                }
                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                .disabled(saved)

                Button("Done") { onDone?() }
                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
            }
        }
        .padding()
        .background(AppTheme.background.ignoresSafeArea())
    }

    private func metric(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    HRVResultView(
        result: HRVResult(date: .now, durationSeconds: 180, averageHRBpm: 64, averageSDNNms: 72, samples: 120),
        onSave: { _ in },
        onDone: {}
    )
}
