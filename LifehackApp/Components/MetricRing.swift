import SwiftUI

struct MetricRing: View {
    var title: String
    var value: Double          // 0...1
    var systemImage: String
    var size: CGFloat = 90
    var lineWidth: CGFloat = 10
    var showPercent: Bool = true

    var body: some View {
        VStack(spacing: AppTheme.spacingS) {
            ZStack {
                Circle()
                    .stroke(lineWidth: lineWidth)
                    .foregroundStyle(AppTheme.accent.opacity(0.15))

                Circle()
                    .trim(from: 0, to: value.clamped)
                    .stroke(
                        AppTheme.accentGradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(AppTheme.easeFast, value: value)

                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: size, height: size)

            Text(title)
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if showPercent {
                Text(percentString)
                    .font(.headline.monospacedDigit())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(Int(value.clamped * 100)) percent"))
        .accessibilityAdjustableAction { direction in
            // Placeholder: external binding could be added later
        }
    }

    private var percentString: String {
        "\(Int(value.clamped * 100))%"
    }
}

private extension Double {
    var clamped: CGFloat { CGFloat(min(max(self, 0), 1)) }
}

#Preview {
    VStack(spacing: 24) {
        MetricRing(title: "Metric 1", value: 0.33, systemImage: "star.fill", size: 80, lineWidth: 8)
        MetricRing(title: "Metric 2", value: 0.8, systemImage: "heart.fill", size: 80, lineWidth: 8)
    }
    .padding()
}

#Preview("MetricRing") {
    MetricRing(title: "Stress", value: 0.42, systemImage: "bolt.heart")
        .padding()
        .background(AppTheme.background)
        .appThemeTokens(AppTheme.tokens())
}
