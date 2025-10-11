import SwiftUI

struct AdvancedActivityCard: View {
    let metHours: Double
    let steps: Int
    let activeMinutes: Double
    let walkingDistance: Double
    
    @State private var animateProgress = false
    @State private var showingDetailView = false
    @State private var currentMetricIndex = 0
    
    private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    
    private var activityLevel: ActivityLevel {
        switch metHours {
        case 0..<3: return .sedentary
        case 3..<6: return .light
        case 6..<12: return .moderate
        case 12..<20: return .active
        default: return .veryActive
        }
    }
    
    private var stepGoalProgress: Double {
        min(1.0, Double(steps) / 10000.0)
    }
    
    private var activeMinutesProgress: Double {
        min(1.0, activeMinutes / 30.0) // WHO recommends 30min daily
    }
    
    private var distanceProgress: Double {
        min(1.0, walkingDistance / 5.0) // 5km as a good daily target
    }
    
    private var activityGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                activityLevel.primaryColor.opacity(0.9),
                activityLevel.secondaryColor.opacity(0.7),
                Color.black.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerSection
            metricsOverview
            rotatingInsights
            actionSection
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(activityGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(activityLevel.primaryColor.opacity(0.4), lineWidth: 2)
                )
                .shadow(color: activityLevel.primaryColor.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .onReceive(timer) { _ in
            rotateMetrics()
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
                                        activityLevel.primaryColor.opacity(0.8),
                                        activityLevel.secondaryColor.opacity(0.4)
                                    ]),
                                    center: .center,
                                    startRadius: 5,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                            .scaleEffect(animateProgress ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animateProgress)
                        
                        Image(systemName: "figure.run")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily Activity")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 8) {
                            Circle()
                                .fill(activityLevel.primaryColor)
                                .frame(width: 8, height: 8)
                                .scaleEffect(animateProgress ? 1.2 : 1.0)
                            
                            Text(activityLevel.description)
                                .font(.caption)
                                .foregroundColor(activityLevel.primaryColor)
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: { showingDetailView.toggle() }) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.title3)
            }
        }
        .padding(20)
    }
    
    private var metricsOverview: some View {
        VStack(spacing: 16) {
            // Central MET Hours Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: animateProgress ? min(1.0, metHours / 20.0) : 0)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                activityLevel.primaryColor,
                                activityLevel.secondaryColor,
                                activityLevel.primaryColor
                            ]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 120, height: 120)
                    .animation(.easeInOut(duration: 2.0), value: animateProgress)
                
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", metHours))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("MET-h")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Quick metrics row
            HStack(spacing: 20) {
                ActivityMetric(
                    icon: "figure.walk",
                    title: "Steps",
                    value: "\(steps)",
                    progress: animateProgress ? stepGoalProgress : 0,
                    color: activityLevel.primaryColor
                )
                
                ActivityMetric(
                    icon: "timer",
                    title: "Active",
                    value: "\(Int(activeMinutes))m",
                    progress: animateProgress ? activeMinutesProgress : 0,
                    color: activityLevel.secondaryColor
                )
                
                ActivityMetric(
                    icon: "location",
                    title: "Distance",
                    value: String(format: "%.1fkm", walkingDistance),
                    progress: animateProgress ? distanceProgress : 0,
                    color: .cyan
                )
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var rotatingInsights: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(currentMetricIndex + 1)/3")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                let insights = getActivityInsights()
                let currentInsight = insights[currentMetricIndex]
                
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
                
                // Progress indicators
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == currentMetricIndex ? activityLevel.primaryColor : Color.white.opacity(0.3))
                            .frame(width: index == currentMetricIndex ? 20 : 6, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentMetricIndex)
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
                        .stroke(activityLevel.primaryColor.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }
    
    private var actionSection: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.3))
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Goal Progress")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("\(Int(stepGoalProgress * 100))% of daily step goal")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Calories Burned")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("\(Int(metHours * 70))") // Rough estimate: MET-h * avg body weight
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(activityLevel.primaryColor)
                }
            }
            
            // Quick stats
            HStack {
                Text("Data from Apple Health")
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
    
    private func rotateMetrics() {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentMetricIndex = (currentMetricIndex + 1) % 3
        }
    }
    
    private func getActivityInsights() -> [ActivityInsight] {
        var insights: [ActivityInsight] = []
        
        // Steps insight
        if steps >= 10000 {
            insights.append(ActivityInsight(
                title: "Excellent Step Count!",
                description: "You've exceeded the recommended 10,000 daily steps. Great job staying active!",
                icon: "star.fill",
                color: .green
            ))
        } else if steps >= 7500 {
            insights.append(ActivityInsight(
                title: "Good Activity Level",
                description: "You're close to your step goal. Try adding a short walk to reach 10,000 steps.",
                icon: "checkmark.circle.fill",
                color: .yellow
            ))
        } else {
            insights.append(ActivityInsight(
                title: "Room for Improvement",
                description: "Consider taking the stairs or a short walk to boost your daily step count.",
                icon: "arrow.up.circle.fill",
                color: .orange
            ))
        }
        
        // Active minutes insight
        if activeMinutes >= 30 {
            insights.append(ActivityInsight(
                title: "WHO Guidelines Met",
                description: "You've achieved the recommended 30 minutes of daily physical activity.",
                icon: "heart.fill",
                color: .green
            ))
        } else {
            insights.append(ActivityInsight(
                title: "Boost Active Time",
                description: "Try to reach 30 minutes of active time daily for optimal health benefits.",
                icon: "timer",
                color: .orange
            ))
        }
        
        // MET hours insight
        if metHours >= 12 {
            insights.append(ActivityInsight(
                title: "High Energy Expenditure",
                description: "Excellent metabolic activity today! Your body is burning energy efficiently.",
                icon: "bolt.fill",
                color: .green
            ))
        } else if metHours >= 6 {
            insights.append(ActivityInsight(
                title: "Moderate Activity Level",
                description: "Good energy expenditure. Consider adding some high-intensity activities.",
                icon: "flame.fill",
                color: .yellow
            ))
        } else {
            insights.append(ActivityInsight(
                title: "Low Activity Day",
                description: "Your metabolic activity is low. Try incorporating more movement throughout the day.",
                icon: "exclamationmark.triangle.fill",
                color: .red
            ))
        }
        
        return insights
    }
}

struct ActivityMetric: View {
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

enum ActivityLevel {
    case sedentary
    case light
    case moderate
    case active
    case veryActive
    
    var description: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Light Activity"
        case .moderate: return "Moderate Activity"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .sedentary: return .red
        case .light: return .orange
        case .moderate: return .yellow
        case .active: return .green
        case .veryActive: return .cyan
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .sedentary: return .pink
        case .light: return .yellow
        case .moderate: return .green
        case .active: return .mint
        case .veryActive: return .blue
        }
    }
}

struct ActivityInsight {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

// Preview
struct AdvancedActivityCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AdvancedActivityCard(
                metHours: 8.5,
                steps: 12500,
                activeMinutes: 45,
                walkingDistance: 6.2
            )
            
            AdvancedActivityCard(
                metHours: 3.2,
                steps: 4200,
                activeMinutes: 15,
                walkingDistance: 2.1
            )
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}