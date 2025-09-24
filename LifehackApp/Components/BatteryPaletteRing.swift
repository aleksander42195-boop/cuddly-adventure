import SwiftUI

struct BatteryPaletteRing: View {
    var value: Double // 0...1
    var size: CGFloat = 90
    var lineWidth: CGFloat = 10

    private var color: Color {
        switch value {
        case ..<0.2: return .red
        case ..<0.6: return .yellow
        default: return .green
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .foregroundStyle(color.opacity(0.2))
            Circle()
                .trim(from: 0, to: value.clamped)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(AppTheme.easeFast, value: value)
            Image(systemName: "battery.100")
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Battery")
        .accessibilityValue("\(Int(value.clamped * 100)) percent")
    }
}

private extension Double { var clamped: CGFloat { CGFloat(min(max(self, 0), 1)) } }

#Preview {
    HStack(spacing: 16) {
        BatteryPaletteRing(value: 0.15)
        BatteryPaletteRing(value: 0.4)
        BatteryPaletteRing(value: 0.85)
    }
    .padding()
}
