import SwiftUI

struct AdvancedAICoachCard: View {
    let energyLevel: Double
    let stressLevel: Double
    let sleepHours: Double
    let recentTrend: String
    let onStartCoaching: () -> Void
    
    @State private var isAnimating = false
    @State private var currentInsightIndex = 0
    @State private var showingCoachDetails = false
    
    private let insights: [CoachInsight]
    
    init(energyLevel: Double, stressLevel: Double, sleepHours: Double, recentTrend: String, onStartCoaching: @escaping () -> Void) {
        self.energyLevel = energyLevel
        self.stressLevel = stressLevel
        self.sleepHours = sleepHours
        self.recentTrend = recentTrend
        self.onStartCoaching = onStartCoaching
        
        // Generate personalized insights based on health data
        self.insights = Self.generateInsights(energy: energyLevel, stress: stressLevel, sleep: sleepHours)
    }
    
    private let timer = Timer.publish(every: 6, on: .main, in: .common).autoconnect()
    
    private var coachStatus: CoachStatus {
        let overallHealth = (energyLevel + (1.0 - stressLevel) + sleepOptimalityScore) / 3.0
        
        if overallHealth >= 0.8 {
            return .excellent
        } else if overallHealth >= 0.6 {
            return .good
        } else if overallHealth >= 0.4 {
            return .needsAttention
        } else {
            return .critical
        }
    }
    
    private var sleepOptimalityScore: Double {
        let optimalMin = 7.0
        let optimalMax = 9.0
        
        if sleepHours >= optimalMin && sleepHours <= optimalMax {
            return 1.0
        } else if sleepHours < optimalMin {
            return max(0, sleepHours / optimalMin)
        } else {
            let excess = sleepHours - optimalMax
            return max(0.5, 1.0 - (excess * 0.1))
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            aiPersonalitySection
            currentInsightSection
            actionSection
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.purple.opacity(0.9),
                            Color.blue.opacity(0.7),
                            Color.indigo.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.cyan.opacity(0.6), Color.purple.opacity(0.6)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .purple.opacity(0.4), radius: 20, x: 0, y: 10)
        )
        .onReceive(timer) { _ in
            rotateInsights()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    // AI Brain Icon with pulsing animation
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [Color.cyan.opacity(0.8), Color.purple.opacity(0.4)]),
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .opacity(isAnimating ? 0.8 : 1.0)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Health Coach")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(coachStatus.color)
                                .frame(width: 8, height: 8)
                                .scaleEffect(isAnimating ? 1.2 : 1.0)
                            
                            Text(coachStatus.description)
                                .font(.caption)
                                .foregroundColor(coachStatus.color)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: { showingCoachDetails.toggle() }) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.title3)
            }
        }
        .padding(20)
    }
    
    private var aiPersonalitySection: some View {
        VStack(spacing: 16) {
            // Health status visualization
            HStack(spacing: 20) {
                HealthIndicator(
                    title: "Energy",
                    value: energyLevel,
                    color: .green,
                    icon: "bolt.fill"
                )
                
                HealthIndicator(
                    title: "Stress",
                    value: stressLevel,
                    color: .red,
                    icon: "exclamationmark.triangle.fill"
                )
                
                HealthIndicator(
                    title: "Recovery",
                    value: sleepOptimalityScore,
                    color: .blue,
                    icon: "moon.fill"
                )
            }
            
            // AI personality message
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("🤖")
                        .font(.title3)
                    
                    Text(getPersonalityMessage())
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var currentInsightSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Personalized Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(currentInsightIndex + 1)/\(insights.count)")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            if !insights.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    let currentInsight = insights[currentInsightIndex]
                    
                    HStack(spacing: 12) {
                        Image(systemName: currentInsight.icon)
                            .font(.title3)
                            .foregroundColor(currentInsight.priority.color)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(currentInsight.priority.color.opacity(0.2))
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
                    
                    // Action recommendation
                    if !currentInsight.actionRecommendation.isEmpty {
                        Text("💡 " + currentInsight.actionRecommendation)
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
                    
                    // Progress indicator
                    HStack(spacing: 4) {
                        ForEach(0..<insights.count, id: \.self) { index in
                            Capsule()
                                .fill(index == currentInsightIndex ? Color.cyan : Color.white.opacity(0.3))
                                .frame(width: index == currentInsightIndex ? 20 : 6, height: 4)
                                .animation(.easeInOut(duration: 0.3), value: currentInsightIndex)
                        }
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
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack(spacing: 16) {
                Button(action: onStartCoaching) {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start AI Session")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            
                            Text("Get personalized coaching")
                                .font(.caption2)
                                .opacity(0.8)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                    }
                    .foregroundColor(.white)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.cyan, Color.purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .cyan.opacity(0.5), radius: 12, x: 0, y: 6)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Quick stats
            HStack {
                Text("AI powered by OpenAI GPT-4")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer()
                
                Text("Updated continuously")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(20)
    }
    
    private func getPersonalityMessage() -> String {
        switch coachStatus {
        case .excellent:
            return "Great job! Your health metrics are excellent. I'm here to help you maintain this momentum."
        case .good:
            return "You're doing well! I notice some areas where we can optimize your health further."
        case .needsAttention:
            return "I see some patterns that need attention. Let's work together to improve your wellness."
        case .critical:
            return "Your health needs immediate focus. I'm here to guide you through evidence-based improvements."
        }
    }
    
    private func rotateInsights() {
        guard !insights.isEmpty else { return }
        
        withAnimation(.easeInOut(duration: 0.5)) {
            currentInsightIndex = (currentInsightIndex + 1) % insights.count
        }
    }
    
    static private func generateInsights(energy: Double, stress: Double, sleep: Double) -> [CoachInsight] {
        var insights: [CoachInsight] = []
        
        // Energy insights
        if energy < 0.4 {
            insights.append(CoachInsight(
                title: "Low Energy Detected",
                description: "Your energy levels are below optimal. This could impact your daily performance.",
                actionRecommendation: "Try a 10-minute walk or light stretching to boost energy",
                icon: "bolt.slash.fill",
                priority: .high
            ))
        } else if energy > 0.8 {
            insights.append(CoachInsight(
                title: "Excellent Energy Levels",
                description: "Your energy is fantastic! This is perfect for tackling challenging tasks.",
                actionRecommendation: "Great time for a workout or important project",
                icon: "bolt.fill",
                priority: .low
            ))
        }
        
        // Stress insights
        if stress > 0.7 {
            insights.append(CoachInsight(
                title: "High Stress Alert",
                description: "Your stress levels are elevated. This could affect your sleep and recovery.",
                actionRecommendation: "Try deep breathing exercises or meditation for 5-10 minutes",
                icon: "exclamationmark.triangle.fill",
                priority: .high
            ))
        }
        
        // Sleep insights
        if sleep < 6.0 {
            insights.append(CoachInsight(
                title: "Sleep Deficit",
                description: "You're not getting enough restorative sleep. This affects all aspects of health.",
                actionRecommendation: "Aim for an earlier bedtime tonight and avoid screens 1 hour before bed",
                icon: "moon.zzz.fill",
                priority: .high
            ))
        } else if sleep > 9.5 {
            insights.append(CoachInsight(
                title: "Excessive Sleep",
                description: "You might be sleeping too much, which can affect energy and mood.",
                actionRecommendation: "Try establishing a consistent sleep schedule",
                icon: "clock.badge.exclamationmark.fill",
                priority: .medium
            ))
        }
        
        // Default positive insight if no issues
        if insights.isEmpty {
            insights.append(CoachInsight(
                title: "Balanced Health Profile",
                description: "Your metrics show a good balance. Consistency is key to long-term wellness.",
                actionRecommendation: "Keep up your current routine and consider small optimizations",
                icon: "checkmark.circle.fill",
                priority: .low
            ))
        }
        
        return insights
    }
}

struct HealthIndicator: View {
    let title: String
    let value: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 4)
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: value)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
    }
}

enum CoachStatus {
    case excellent
    case good
    case needsAttention
    case critical
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .yellow
        case .needsAttention: return .orange
        case .critical: return .red
        }
    }
    
    var description: String {
        switch self {
        case .excellent: return "Excellent Health"
        case .good: return "Good Health"
        case .needsAttention: return "Needs Attention"
        case .critical: return "Critical"
        }
    }
}

struct CoachInsight {
    let title: String
    let description: String
    let actionRecommendation: String
    let icon: String
    let priority: InsightPriority
    
    enum InsightPriority {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .red
            }
        }
    }
}

// Preview
struct AdvancedAICoachCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AdvancedAICoachCard(
                energyLevel: 0.75,
                stressLevel: 0.45,
                sleepHours: 8.2,
                recentTrend: "improving",
                onStartCoaching: {}
            )
            
            AdvancedAICoachCard(
                energyLevel: 0.25,
                stressLevel: 0.85,
                sleepHours: 5.2,
                recentTrend: "declining",
                onStartCoaching: {}
            )
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}