import SwiftUI

struct AdvancedSleepCard: View {
    let sleepHours: Double
    let bedtime: Date?
    let wakeTime: Date?
    let sleepEfficiency: Double // 0-1, calculated from deep sleep vs total sleep
    let zodiacSign: String
    
    @State private var animateProgress = false
    @State private var showingSleepDetails = false
    @State private var currentPhaseIndex = 0
    
    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    private var sleepQuality: SleepQuality {
        let optimalRange = 7.0...9.0
        
        if optimalRange.contains(sleepHours) && sleepEfficiency > 0.8 {
            return .excellent
        } else if optimalRange.contains(sleepHours) && sleepEfficiency > 0.6 {
            return .good
        } else if sleepHours >= 6.0 && sleepHours <= 10.0 {
            return .fair
        } else {
            return .poor
        }
    }
    
    private var sleepScore: Double {
        let durationScore = sleepDurationScore
        let efficiencyScore = sleepEfficiency
        let timingScore = sleepTimingScore
        
        return (durationScore + efficiencyScore + timingScore) / 3.0
    }
    
    private var sleepDurationScore: Double {
        let optimal = 8.0
        let deviation = abs(sleepHours - optimal)
        return max(0, 1.0 - (deviation / 4.0)) // Full penalty at 4h deviation
    }
    
    private var sleepTimingScore: Double {
        guard let bedtime = bedtime else { return 0.5 }
        
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: bedtime)
        
        // Optimal bedtime: 22:00-23:30 (10 PM - 11:30 PM)
        if hour >= 22 || hour <= 1 {
            return 1.0
        } else if hour >= 20 || hour <= 3 {
            return 0.7
        } else {
            return 0.3
        }
    }
    
    private var sleepGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.indigo.opacity(0.9),
                sleepQuality.primaryColor.opacity(0.7),
                Color.black.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            sleepMetricsSection
            sleepPhasesSection
            zodiacSection
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(sleepGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(sleepQuality.primaryColor.opacity(0.4), lineWidth: 2)
                )
                .shadow(color: sleepQuality.primaryColor.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .onReceive(timer) { _ in
            rotateSleepPhases()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animateProgress = true
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.indigo.opacity(0.8),
                                        Color.purple.opacity(0.4)
                                    ]),
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                            .scaleEffect(animateProgress ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: animateProgress)
                        
                        Image(systemName: "moon.zzz.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sleep Analysis")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(sleepQuality.primaryColor)
                                .frame(width: 8, height: 8)
                                .scaleEffect(animateProgress ? 1.2 : 1.0)
                            
                            Text(sleepQuality.description)
                                .font(.caption)
                                .foregroundColor(sleepQuality.primaryColor)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: { showingSleepDetails.toggle() }) {
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.title3)
            }
        }
        .padding(20)
    }
    
    private var sleepMetricsSection: some View {
        VStack(spacing: 16) {
            // Central Sleep Score Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: animateProgress ? sleepScore : 0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.indigo,
                                Color.purple,
                                Color.blue,
                                Color.indigo
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                    .animation(.easeInOut(duration: 2.0), value: animateProgress)
                
                VStack(spacing: 4) {
                    Text("\(Int(sleepScore * 100))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Sleep Score")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Sleep metrics row
            HStack(spacing: 20) {
                SleepMetric(
                    icon: "clock.fill",
                    title: "Duration",
                    value: String(format: "%.1fh", sleepHours),
                    progress: animateProgress ? sleepDurationScore : 0,
                    color: sleepQuality.primaryColor
                )
                
                SleepMetric(
                    icon: "waveform.path.ecg",
                    title: "Quality",
                    value: "\(Int(sleepEfficiency * 100))%",
                    progress: animateProgress ? sleepEfficiency : 0,
                    color: .cyan
                )
                
                SleepMetric(
                    icon: "timer",
                    title: "Timing",
                    value: getTimingText(),
                    progress: animateProgress ? sleepTimingScore : 0,
                    color: .mint
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var sleepPhasesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sleep Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(currentPhaseIndex + 1)/3")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                let insights = getSleepInsights()
                let currentInsight = insights[currentPhaseIndex]
                
                HStack(spacing: 12) {
                    Image(systemName: currentInsight.icon)
                        .font(.title3)
                        .foregroundColor(currentInsight.color)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(currentInsight.color.opacity(0.2))
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentInsight.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text(currentInsight.description)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                
                // Recommendation
                if !currentInsight.recommendation.isEmpty {
                    Text("💡 " + currentInsight.recommendation)
                        .font(.caption)
                        .foregroundColor(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cyan.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                
                // Progress indicators
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPhaseIndex ? Color.indigo : Color.white.opacity(0.3))
                            .frame(width: index == currentPhaseIndex ? 20 : 6, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentPhaseIndex)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.indigo.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private var zodiacSection: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Zodiac Influence")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Your \(zodiacSign) energy today")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Text(getZodiacEmoji())
                        .font(.title2)
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(zodiacSign)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(getZodiacSleepTip())
                            .font(.caption)
                            .foregroundColor(.purple)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            
            // Quick stats
            HStack {
                if let bedtime = bedtime {
                    Text("Bedtime: \(bedtime, formatter: timeFormatter)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                if let wakeTime = wakeTime {
                    Text("Wake: \(wakeTime, formatter: timeFormatter)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(20)
    }
    
    private func rotateSleepPhases() {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentPhaseIndex = (currentPhaseIndex + 1) % 3
        }
    }
    
    private func getTimingText() -> String {
        guard let bedtime = bedtime else { return "Unknown" }
        let hour = Calendar.current.component(.hour, from: bedtime)
        
        if hour >= 22 || hour <= 1 {
            return "Optimal"
        } else if hour >= 20 || hour <= 3 {
            return "Good"
        } else {
            return "Poor"
        }
    }
    
    private func getSleepInsights() -> [SleepInsight] {
        var insights: [SleepInsight] = []
        
        // Duration insight
        if sleepHours >= 7.0 && sleepHours <= 9.0 {
            insights.append(SleepInsight(
                title: "Optimal Sleep Duration",
                description: "You slept within the recommended 7-9 hour range for adults.",
                recommendation: "Keep maintaining this healthy sleep schedule",
                icon: "checkmark.circle.fill",
                color: .green
            ))
        } else if sleepHours < 7.0 {
            insights.append(SleepInsight(
                title: "Insufficient Sleep",
                description: "You slept less than the recommended 7-9 hours for optimal health.",
                recommendation: "Try going to bed 30-60 minutes earlier tonight",
                icon: "exclamationmark.triangle.fill",
                color: .orange
            ))
        } else {
            insights.append(SleepInsight(
                title: "Extended Sleep",
                description: "You slept longer than the typical 7-9 hour recommendation.",
                recommendation: "Monitor if you feel refreshed or consider sleep quality factors",
                icon: "clock.badge.exclamationmark.fill",
                color: .yellow
            ))
        }
        
        // Quality insight
        if sleepEfficiency >= 0.8 {
            insights.append(SleepInsight(
                title: "High Sleep Efficiency",
                description: "Excellent sleep quality with minimal interruptions.",
                recommendation: "Your sleep environment and habits are working well",
                icon: "star.fill",
                color: .green
            ))
        } else if sleepEfficiency >= 0.6 {
            insights.append(SleepInsight(
                title: "Moderate Sleep Quality",
                description: "Good sleep efficiency with some room for improvement.",
                recommendation: "Consider optimizing your sleep environment",
                icon: "moon.fill",
                color: .yellow
            ))
        } else {
            insights.append(SleepInsight(
                title: "Fragmented Sleep",
                description: "Your sleep was frequently interrupted or restless.",
                recommendation: "Focus on sleep hygiene and reducing disruptions",
                icon: "waveform.path.ecg",
                color: .red
            ))
        }
        
        // Timing insight
        if sleepTimingScore >= 0.8 {
            insights.append(SleepInsight(
                title: "Perfect Sleep Timing",
                description: "You went to bed at an optimal time for natural circadian rhythms.",
                recommendation: "Continue this excellent bedtime routine",
                icon: "clock.fill",
                color: .green
            ))
        } else {
            insights.append(SleepInsight(
                title: "Suboptimal Timing",
                description: "Your bedtime could be better aligned with natural sleep cycles.",
                recommendation: "Try going to bed between 10-11:30 PM for better alignment",
                icon: "clock.badge.exclamationmark",
                color: .orange
            ))
        }
        
        return insights
    }
    
    private func getZodiacEmoji() -> String {
        switch zodiacSign.lowercased() {
        case "aries": return "♈️"
        case "taurus": return "♉️"
        case "gemini": return "♊️"
        case "cancer": return "♋️"
        case "leo": return "♌️"
        case "virgo": return "♍️"
        case "libra": return "♎️"
        case "scorpio": return "♏️"
        case "sagittarius": return "♐️"
        case "capricorn": return "♑️"
        case "aquarius": return "♒️"
        case "pisces": return "♓️"
        default: return "🌟"
        }
    }
    
    private func getZodiacSleepTip() -> String {
        switch zodiacSign.lowercased() {
        case "aries": return "Channel your energy into evening workouts"
        case "taurus": return "Create a luxurious sleep environment"
        case "gemini": return "Journal thoughts before bed"
        case "cancer": return "Keep your bedroom cool and cozy"
        case "leo": return "Maintain a dramatic bedtime routine"
        case "virgo": return "Stick to your precise sleep schedule"
        case "libra": return "Balance work and rest equally"
        case "scorpio": return "Embrace the transformative power of sleep"
        case "sagittarius": return "Adventure in your dreams"
        case "capricorn": return "Discipline leads to better rest"
        case "aquarius": return "Try innovative sleep techniques"
        case "pisces": return "Let your dreams guide you"
        default: return "Rest well under the stars"
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

struct SleepMetric: View {
    let icon: String
    let title: String
    let value: String
    let progress: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 50, height: 50)
                    .animation(.easeInOut(duration: 1.5), value: progress)
                
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
    }
}

enum SleepQuality {
    case excellent
    case good
    case fair
    case poor
    
    var description: String {
        switch self {
        case .excellent: return "Excellent Sleep"
        case .good: return "Good Sleep"
        case .fair: return "Fair Sleep"
        case .poor: return "Poor Sleep"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .excellent: return .green
        case .good: return .cyan
        case .fair: return .yellow
        case .poor: return .red
        }
    }
}

struct SleepInsight {
    let title: String
    let description: String
    let recommendation: String
    let icon: String
    let color: Color
}

// Preview
struct AdvancedSleepCard_Previews: PreviewProvider {
    static var previews: some View {
        let bedtime = Calendar.current.date(bySettingHour: 22, minute: 30, second: 0, of: Date()) ?? Date()
        let wakeTime = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
        
        VStack(spacing: 20) {
            AdvancedSleepCard(
                sleepHours: 8.5,
                bedtime: bedtime,
                wakeTime: wakeTime,
                sleepEfficiency: 0.85,
                zodiacSign: "Leo"
            )
            
            AdvancedSleepCard(
                sleepHours: 5.2,
                bedtime: Calendar.current.date(bySettingHour: 1, minute: 30, second: 0, of: Date()),
                wakeTime: Calendar.current.date(bySettingHour: 6, minute: 42, second: 0, of: Date()),
                sleepEfficiency: 0.45,
                zodiacSign: "Gemini"
            )
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}