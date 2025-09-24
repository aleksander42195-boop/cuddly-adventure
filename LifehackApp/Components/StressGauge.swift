import SwiftUI

struct StressGauge: View {
    var stress: Double // 0..1 (hrv-based)
    var size: CGFloat = 160

    private var color: Color {
        switch stress {
        case ..<0.33: return .green
        case ..<0.66: return .yellow
        default: return .red
        }
    }

    var body: some View {
        ZStack {
            // Arc background
            GaugeBackground()
                .stroke(Color.gray.opacity(0.2), lineWidth: 14)
                .frame(width: size, height: size/2)
            // Colored arc progress
            GaugeProgress(progress: stress)
                .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .frame(width: size, height: size/2)
                .animation(AppTheme.easeFast, value: stress)
            // Needle
            Needle(progress: stress)
                .fill(color)
                .frame(width: size, height: size/2)
            // Label
            VStack {
                Spacer().frame(height: size/2 - 12)
                Text("Stress \(Int(stress * 100))")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(color)
            }
            .frame(width: size, height: size/2, alignment: .bottom)
        }
        .accessibilityLabel("Stress gauge")
        .accessibilityValue("\(Int(stress * 100)) out of 100")
    }

    private struct GaugeBackground: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width/2, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            return p
        }
    }

    private struct GaugeProgress: Shape {
        var progress: Double
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let endDeg = 180 - 180 * progress
            p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY), radius: rect.width/2, startAngle: .degrees(180), endAngle: .degrees(endDeg), clockwise: false)
            return p
        }
        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }
    }

    private struct Needle: Shape {
        var progress: Double
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let angle = .pi * (1 - progress)
            let center = CGPoint(x: rect.midX, y: rect.maxY)
            let len = rect.width/2 - 10
            let tip = CGPoint(x: center.x + CGFloat(cos(angle)) * len, y: center.y - CGFloat(sin(angle)) * len)
            p.move(to: center)
            p.addLine(to: tip)
            return p.strokedPath(StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        var animatableData: Double {
            get { progress }
            set { progress = newValue }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        StressGauge(stress: 0.2)
        StressGauge(stress: 0.5)
        StressGauge(stress: 0.9)
    }
    .padding()
}
