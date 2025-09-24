import SwiftUI

struct StarrySleepCard: View {
    var zodiac: Zodiac
    var hours: Double

    var body: some View {
        ZStack {
            // Simple star field
            LinearGradient(colors: [.black, .indigo], startPoint: .top, endPoint: .bottom)
                .overlay(StarsLayer())
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.radius))
            VStack(alignment: .leading, spacing: 8) {
                Text("Sleep")
                    .font(.headline)
                    .foregroundColor(.white)
                Text("Last night: \(String(format: "%.1f", hours)) h")
                    .font(.title3.monospacedDigit())
                    .foregroundColor(.white)
                Text("Zodiac: \(zodiac.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 140)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.radius).stroke(.white.opacity(0.1)))
        .accessibilityLabel("Sleep card. Last night \(Int(hours)) hours. Zodiac \(zodiac.rawValue)")
    }

    private struct StarsLayer: View {
        var body: some View {
            Canvas { ctx, size in
                let starCount = 120
                for i in 0..<starCount {
                    let x = CGFloat(Int.random(in: 0..<Int(size.width)))
                    let y = CGFloat(Int.random(in: 0..<Int(size.height)))
                    let r = CGFloat.random(in: 0.5...1.8)
                    let opacity = Double.random(in: 0.4...1.0)
                    let rect = CGRect(x: x, y: y, width: r, height: r)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                    if i % 17 == 0 {
                        // occasional twinkle
                        ctx.stroke(Path(ellipseIn: rect.insetBy(dx: -r, dy: -r)), with: .color(.white.opacity(0.08)))
                    }
                }
            }
            .blendMode(.screen)
        }
    }
}

#Preview {
    StarrySleepCard(zodiac: .leo, hours: 7.6)
        .padding()
}
