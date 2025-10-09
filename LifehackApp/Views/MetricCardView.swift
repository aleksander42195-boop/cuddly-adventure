import SwiftUI

struct MetricCardView: View {
    let energy: Double     // 0...1
    let battery: Double    // 0...1
    let stress: Double     // 0...1
    let hrvSDNN: Double    // HRV value in ms
    let sleepHours: Double // Sleep hours from last night
    
    // HRV Status determination (traffic light system)
    private var hrvStatus: HRVStatus {
        switch hrvSDNN {
        case 0..<20: return .low     // Red
        case 20..<40: return .medium // Yellow
        default: return .high        // Green
        }
    }
    
    // Sleep score calculation (0-1 based on optimal 7-9 hours)
    private var sleepScore: Double {
        let optimalMin = 7.0
        let optimalMax = 9.0
        
        if sleepHours >= optimalMin && sleepHours <= optimalMax {
            return 1.0 // Perfect score
        } else if sleepHours < optimalMin {
            return max(0, sleepHours / optimalMin) // Penalize insufficient sleep
        } else {
            // Penalize excessive sleep (diminishing returns after 9h)
            let excess = sleepHours - optimalMax
            return max(0.5, 1.0 - (excess * 0.1))
        }
    }
    
    var body: some View {
        ZStack {
            // Space background
            LinearGradient(gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.8), Color.blue.opacity(0.7)]),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
                .cornerRadius(20)
                .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 20) {
                HStack(spacing: 15) {
                    MiniMetricRing(progress: energy, label: "Energy", ringColor: hrvStatus.energyColor)
                    MiniMetricRing(progress: battery, label: "Battery", ringColor: hrvStatus.batteryColor)
                    MiniMetricRing(progress: stress, label: "Stress", ringColor: hrvStatus.stressColor)
                    MiniMetricRing(progress: sleepScore, label: "Sleep", ringColor: hrvStatus.sleepColor)
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: 180)
    }
}

enum HRVStatus {
    case low    // Red (poor HRV)
    case medium // Yellow (moderate HRV)
    case high   // Green (good HRV)
    
    var energyColor: Color {
        switch self {
        case .low: return .red
        case .medium: return .yellow
        case .high: return .green
        }
    }
    
    var batteryColor: Color {
        switch self {
        case .low: return .red
        case .medium: return .yellow
        case .high: return .green
        }
    }
    
    var stressColor: Color {
        switch self {
        case .low: return .red      // High stress (low HRV)
        case .medium: return .yellow // Moderate stress
        case .high: return .green    // Low stress (high HRV)
        }
    }
    
    var sleepColor: Color {
        switch self {
        case .low: return .red
        case .medium: return .yellow
        case .high: return .green
        }
    }
}

struct MiniMetricRing: View {
    let progress: Double
    let label: String
    let ringColor: Color
    
    private let ringSize: CGFloat = 75  // Equal size for all rings
    private let lineWidth: CGFloat = 10
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                .frame(width: ringSize, height: ringSize)
            
            // Foreground ring
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(AngularGradient(gradient: Gradient(colors: [ringColor, .white]),
                                        center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: ringSize, height: ringSize)
                .shadow(color: ringColor.opacity(0.7), radius: 6, x: 0, y: 0)
            
            // Progress percentage
            Text("\(Int(progress * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Label below the ring
            VStack {
                Spacer()
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .offset(y: 15)
            }
        }
        .frame(width: ringSize + 20, height: ringSize + 20) // Add padding for label
    }
}

struct MetricCardView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MetricCardView(
                energy: 0.75, 
                battery: 0.55, 
                stress: 0.35,
                hrvSDNN: 45.0,  // Good HRV - should show green
                sleepHours: 8.2
            )
            
            MetricCardView(
                energy: 0.45, 
                battery: 0.25, 
                stress: 0.75,
                hrvSDNN: 15.0,  // Poor HRV - should show red
                sleepHours: 5.5
            )
            
            MetricCardView(
                energy: 0.60, 
                battery: 0.70, 
                stress: 0.50,
                hrvSDNN: 25.0,  // Moderate HRV - should show yellow
                sleepHours: 7.0
            )
        }
        .preferredColorScheme(.dark)
        .background(Color.black)
    }
}
