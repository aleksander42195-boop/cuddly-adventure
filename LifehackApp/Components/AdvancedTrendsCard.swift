import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct AdvancedTrendsCard: View {
    let weeklyEnergyData: [DailyMetric]
    let weeklyStressData: [DailyMetric]
    let weeklyHRVData: [DailyMetric]
    
    @State private var selectedMetric: TrendMetric = .energy
    @State private var showingTrendDetails = false
    
    enum TrendMetric: String, CaseIterable {
        case energy = "Energy"
        case stress = "Stress"
        case hrv = "HRV"
        
        var color: Color {
            switch self {
            case .energy: return .green
            case .stress: return .red
            case .hrv: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .energy: return "bolt.fill"
            case .stress: return "exclamationmark.triangle.fill"
            case .hrv: return "heart.fill"
            }
        }
    }
    
    private var currentData: [DailyMetric] {
        switch selectedMetric {
        case .energy: return weeklyEnergyData
        case .stress: return weeklyStressData
        case .hrv: return weeklyHRVData
        }
    }
    
    private var trendDirection: TrendDirection {
        guard currentData.count >= 2 else { return .stable }
        
        let recent = Array(currentData.suffix(3))
        let earlier = Array(currentData.prefix(3))
        
        let recentAvg = recent.map { $0.value }.reduce(0, +) / Double(recent.count)
        let earlierAvg = earlier.map { $0.value }.reduce(0, +) / Double(earlier.count)
        
        let percentChange = (recentAvg - earlierAvg) / earlierAvg
        
        if abs(percentChange) < 0.05 {
            return .stable
        } else if percentChange > 0 {
            return selectedMetric == .stress ? .declining : .improving
        } else {
            return selectedMetric == .stress ? .improving : .declining
        }
    }
    
    private var weekOverWeekChange: Double {
        guard currentData.count >= 7 else { return 0 }
        
        let thisWeek = Array(currentData.suffix(7))
        let lastWeek = Array(currentData.dropLast(7).suffix(7))
        
        let thisWeekAvg = thisWeek.map { $0.value }.reduce(0, +) / Double(thisWeek.count)
        let lastWeekAvg = lastWeek.map { $0.value }.reduce(0, +) / Double(lastWeek.count)
        
        return ((thisWeekAvg - lastWeekAvg) / lastWeekAvg) * 100
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            chartSection
            insightsSection
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.9),
                            selectedMetric.color.opacity(0.2),
                            Color.black.opacity(0.9)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(selectedMetric.color.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: selectedMetric.color.opacity(0.3), radius: 15, x: 0, y: 8)
        )
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Trends")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("7-day analysis")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Button(action: { showingTrendDetails.toggle() }) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.title3)
                }
            }
            
            // Metric selection tabs
            HStack(spacing: 12) {
                ForEach(TrendMetric.allCases, id: \.self) { metric in
                    MetricTab(
                        metric: metric,
                        isSelected: selectedMetric == metric,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedMetric = metric
                            }
                        }
                    )
                }
            }
        }
        .padding(20)
    }
    
    private var chartSection: some View {
        VStack(spacing: 16) {
            #if canImport(Charts)
            Chart(currentData) { item in
                AreaMark(
                    x: .value("Day", item.date),
                    y: .value(selectedMetric.rawValue, item.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            selectedMetric.color.opacity(0.6),
                            selectedMetric.color.opacity(0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                LineMark(
                    x: .value("Day", item.date),
                    y: .value(selectedMetric.rawValue, item.value)
                )
                .foregroundStyle(selectedMetric.color)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                
                PointMark(
                    x: .value("Day", item.date),
                    y: .value(selectedMetric.rawValue, item.value)
                )
                .foregroundStyle(selectedMetric.color)
                .symbolSize(50)
            }
            .frame(height: 180)
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.white.opacity(0.3))
                    AxisTick(stroke: StrokeStyle(lineWidth: 0))
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.white.opacity(0.3))
                    AxisTick(stroke: StrokeStyle(lineWidth: 0))
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.caption2)
                }
            }
            .chartBackground { chartProxy in
                Color.clear
            }
            #else
            // Fallback for when Charts is not available
            VStack {
                Text("Chart functionality requires iOS 16+")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
                    .padding()
                
                // Simple visual representation
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(currentData.indices, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(selectedMetric.color)
                            .frame(width: 20, height: CGFloat(currentData[index].value * 80))
                    }
                }
                .frame(height: 100)
            }
            #endif
        }
        .padding(.horizontal, 20)
    }
    
    private var insightsSection: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack(spacing: 20) {
                // Trend indicator
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: trendDirection.icon)
                            .foregroundColor(trendDirection.color)
                            .font(.title3)
                        
                        Text(trendDirection.description)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    
                    Text("\(weekOverWeekChange >= 0 ? "+" : "")\(String(format: "%.1f", weekOverWeekChange))% from last week")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Average for period
                VStack(alignment: .trailing, spacing: 4) {
                    Text("7-Day Average")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    let average = currentData.map { $0.value }.reduce(0, +) / Double(currentData.count)
                    Text(String(format: "%.1f", average * 100) + "%")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(selectedMetric.color)
                }
            }
            
            // Quick insights
            VStack(alignment: .leading, spacing: 8) {
                Text("Insights")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(getInsightText())
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(20)
    }
    
    private func getInsightText() -> String {
        let average = currentData.map { $0.value }.reduce(0, +) / Double(currentData.count)
        
        switch selectedMetric {
        case .energy:
            if average > 0.8 {
                return "Excellent energy levels! You're maintaining great vitality throughout the week."
            } else if average > 0.6 {
                return "Good energy levels. Consider optimizing sleep and nutrition for even better performance."
            } else {
                return "Energy levels could be improved. Focus on consistent sleep, hydration, and stress management."
            }
            
        case .stress:
            if average < 0.3 {
                return "Great stress management! Your current strategies are working well."
            } else if average < 0.6 {
                return "Moderate stress levels. Consider incorporating relaxation techniques into your routine."
            } else {
                return "High stress detected. Prioritize stress reduction activities and consider professional support."
            }
            
        case .hrv:
            if average > 0.8 {
                return "Excellent recovery status! Your body is adapting well to training and stress."
            } else if average > 0.6 {
                return "Good recovery levels. Monitor training intensity and prioritize quality sleep."
            } else {
                return "Recovery could be improved. Focus on sleep quality, stress reduction, and lighter training."
            }
        }
    }
}

struct MetricTab: View {
    let metric: AdvancedTrendsCard.TrendMetric
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: metric.icon)
                    .font(.caption)
                
                Text(metric.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? metric.color : Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(metric.color.opacity(0.5), lineWidth: 1)
                    )
            )
        }
    }
}

enum TrendDirection {
    case improving
    case declining
    case stable
    
    var icon: String {
        switch self {
        case .improving: return "arrow.up.right.circle.fill"
        case .declining: return "arrow.down.right.circle.fill"
        case .stable: return "minus.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .improving: return .green
        case .declining: return .red
        case .stable: return .yellow
        }
    }
    
    var description: String {
        switch self {
        case .improving: return "Improving"
        case .declining: return "Declining"
        case .stable: return "Stable"
        }
    }
}

struct DailyMetric: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// Preview
struct AdvancedTrendsCard_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEnergyData = (0..<7).map { days in
            DailyMetric(
                date: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date(),
                value: Double.random(in: 0.4...0.9)
            )
        }.reversed()
        
        let sampleStressData = (0..<7).map { days in
            DailyMetric(
                date: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date(),
                value: Double.random(in: 0.2...0.8)
            )
        }.reversed()
        
        let sampleHRVData = (0..<7).map { days in
            DailyMetric(
                date: Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date(),
                value: Double.random(in: 0.3...0.9)
            )
        }.reversed()
        
        VStack {
            AdvancedTrendsCard(
                weeklyEnergyData: Array(sampleEnergyData),
                weeklyStressData: Array(sampleStressData),
                weeklyHRVData: Array(sampleHRVData)
            )
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}