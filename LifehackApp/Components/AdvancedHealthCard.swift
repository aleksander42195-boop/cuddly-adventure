import SwiftUI

struct AdvancedHealthCard: View {
    let energy: Double
    let battery: Double
    let stress: Double
    let hrvSDNN: Double
    let sleepHours: Double
    let steps: Int
    
    @State private var animateRings = false
    @State private var showDetailView = false
    
    private var healthScore: Double {
        let energyScore = energy
        let batteryScore = battery
        let stressScore = 1.0 - stress // Invert stress (lower is better)
        let hrvScore = min(1.0, hrvSDNN / 50.0) // Normalize HRV
        let sleepScore = sleepOptimalityScore
        
        return (energyScore + batteryScore + stressScore + hrvScore + sleepScore) / 5.0
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
    
    private var healthGradient: LinearGradient {
        let colors: [Color] = {
            switch healthScore {
            case 0.8...1.0:
                return [.green.opacity(0.8), .mint.opacity(0.6), .cyan.opacity(0.4)]
            case 0.6..<0.8:
                return [.yellow.opacity(0.8), .orange.opacity(0.6), .green.opacity(0.4)]
            case 0.4..<0.6:
                return [.orange.opacity(0.8), .yellow.opacity(0.6), .red.opacity(0.4)]
            default:
                return [.red.opacity(0.8), .pink.opacity(0.6), .purple.opacity(0.4)]
            }
        }()
        
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Health Score Card
            mainHealthCard
            
            // Detailed Metrics Grid
            detailsGrid
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(healthGradient)
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animateRings = true
            }
        }
    }
    
    private var mainHealthCard: some View {
        VStack(spacing: 20) {
            // Header with overall score
            VStack(spacing: 8) {
                HStack {
                    Text("Health Overview")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: { showDetailView.toggle() }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.title3)
                    }
                }
                
                // Central Health Score Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: animateRings ? healthScore : 0)
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(colors: [.white, .cyan, .white]),
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 120, height: 120)
                        .animation(.easeInOut(duration: 2.0), value: animateRings)
                    
                    VStack(spacing: 4) {
                        Text("\(Int(healthScore * 100))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Health Score")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            
            // Quick metrics row
            HStack(spacing: 20) {
                QuickMetric(
                    title: "Energy",
                    value: "\(Int(energy * 100))%",
                    color: .green,
                    progress: animateRings ? energy : 0
                )
                
                QuickMetric(
                    title: "Stress",
                    value: "\(Int(stress * 100))%",
                    color: .red,
                    progress: animateRings ? stress : 0
                )
                
                QuickMetric(
                    title: "Recovery",
                    value: "\(Int(hrvSDNN))ms",
                    color: .blue,
                    progress: animateRings ? min(1.0, hrvSDNN / 50.0) : 0
                )
            }
        }
        .padding(24)
    }
    
    private var detailsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            DetailMetricCard(
                icon: "bolt.fill",
                title: "Battery",
                value: "\(Int(battery * 100))%",
                subtitle: batteryStatus,
                color: batteryColor,
                progress: animateRings ? battery : 0
            )
            
            DetailMetricCard(
                icon: "moon.fill",
                title: "Sleep",
                value: "\(String(format: "%.1f", sleepHours))h",
                subtitle: sleepStatus,
                color: sleepColor,
                progress: animateRings ? sleepOptimalityScore : 0
            )
            
            DetailMetricCard(
                icon: "figure.walk",
                title: "Steps",
                value: "\(steps)",
                subtitle: stepsStatus,
                color: stepsColor,
                progress: animateRings ? min(1.0, Double(steps) / 10000.0) : 0
            )
            
            DetailMetricCard(
                icon: "heart.fill",
                title: "HRV",
                value: "\(Int(hrvSDNN))ms",
                subtitle: hrvStatus,
                color: hrvColor,
                progress: animateRings ? min(1.0, hrvSDNN / 50.0) : 0
            )
        }
        .padding(20)
        .background(
            Color.black.opacity(0.2)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }
    
    // Computed properties for status texts and colors
    private var batteryStatus: String {
        switch battery {
        case 0.8...1.0: return "Excellent"
        case 0.6..<0.8: return "Good"
        case 0.4..<0.6: return "Fair"
        default: return "Low"
        }
    }
    
    private var batteryColor: Color {
        switch battery {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
    
    private var sleepStatus: String {
        switch sleepHours {
        case 7.0...9.0: return "Optimal"
        case 6.0..<7.0, 9.0..<10.0: return "Good"
        case 5.0..<6.0, 10.0..<11.0: return "Fair"
        default: return "Poor"
        }
    }
    
    private var sleepColor: Color {
        switch sleepHours {
        case 7.0...9.0: return .green
        case 6.0..<7.0, 9.0..<10.0: return .yellow
        case 5.0..<6.0, 10.0..<11.0: return .orange
        default: return .red
        }
    }
    
    private var stepsStatus: String {
        switch steps {
        case 10000...: return "Great"
        case 7500..<10000: return "Good"
        case 5000..<7500: return "Fair"
        default: return "Low"
        }
    }
    
    private var stepsColor: Color {
        switch steps {
        case 10000...: return .green
        case 7500..<10000: return .yellow
        case 5000..<7500: return .orange
        default: return .red
        }
    }
    
    private var hrvStatus: String {
        switch hrvSDNN {
        case 40...: return "Excellent"
        case 25..<40: return "Good"
        case 15..<25: return "Fair"
        default: return "Low"
        }
    }
    
    private var hrvColor: Color {
        switch hrvSDNN {
        case 40...: return .green
        case 25..<40: return .yellow
        case 15..<25: return .orange
        default: return .red
        }
    }
}

struct QuickMetric: View {
    let title: String
    let value: String
    let color: Color
    let progress: Double
    
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

struct DetailMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    let progress: Double
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(value)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(color)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 6)
                            .cornerRadius(3)
                        
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [color.opacity(0.6), color]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * progress, height: 6)
                            .cornerRadius(3)
                            .animation(.easeInOut(duration: 1.5), value: progress)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// Preview
struct AdvancedHealthCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            AdvancedHealthCard(
                energy: 0.75,
                battery: 0.85,
                stress: 0.25,
                hrvSDNN: 45.0,
                sleepHours: 8.2,
                steps: 8500
            )
        }
        .padding()
        .background(Color.black)
        .preferredColorScheme(.dark)
    }
}