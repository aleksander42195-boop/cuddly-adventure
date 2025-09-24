import SwiftUI

struct NutritionView: View {
    @State private var kcalToday: Int = 0
    @State private var target: Int = 2000
    @Environment(\.themeTokens) private var theme

    var body: some View {
        ScrollView {
            VStack(spacing: theme.spacing) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        HStack {
                            Text("Nutrition").font(.headline)
                            Spacer()
                            MetricRing(
                                title: "Kcal",
                                value: progress,
                                systemImage: "fork.knife",
                                size: 70,
                                lineWidth: 8
                            )
                        }
                        Text("Dagens inntak: \(kcalToday) kcal / \(target)")
                            .font(.title3.monospacedDigit())
                        ProgressView(value: Double(kcalToday), total: Double(target))
                            .tint(AppTheme.accent)
                        Text("Utvid senere med makroer og logging.")
                            .foregroundStyle(.secondary)

                        HStack(spacing: AppTheme.spacingS) {
                            Button("+100")  { add(100) }.buttonStyle(.bordered)
                            Button("+250")  { add(250) }.buttonStyle(.bordered)
                            Button("+500")  { add(500) }.buttonStyle(.bordered)
                            Spacer()
                            Menu {
                                Button("Sett mål 1800") { target = 1800 }
                                Button("Sett mål 2000") { target = 2000 }
                                Button("Sett mål 2400") { target = 2400 }
                            } label: {
                                Label("Mål", systemImage: "target")
                            }
                        }
                    }
                }
                // Placeholder for future: list of logged meals / macros
                // GlassCard { /* Meal list */ }
            }
            .padding()
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Nutrition. \(kcalToday) of \(target) kilocalories. \(Int(progress * 100)) percent of target.")
        }
        .navigationTitle("Nutrition")
    }

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(Double(kcalToday) / Double(target), 1)
    }

    private func add(_ amount: Int) {
        withAnimation(AppTheme.easeFast) {
            kcalToday += amount
        }
    }
}

#Preview("NutritionView") {
    NavigationView { NutritionView().appThemeTokens(AppTheme.tokens()) }
}
