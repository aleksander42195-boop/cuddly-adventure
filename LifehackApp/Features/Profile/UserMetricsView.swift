import SwiftUI
import HealthKit

struct UserMetricsView: View {
    @EnvironmentObject var app: AppState
    @State private var height: Double = 170 // cm
    @State private var weight: Double = 70 // kg
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var fitnessGoals: Set<FitnessGoal> = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacing) {
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Physical Metrics").font(.headline)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Height: \(Int(height)) cm")
                            Slider(value: $height, in: 100...220, step: 1)
                            
                            Text("Weight: \(Int(weight)) kg")
                            Slider(value: $weight, in: 30...200, step: 1)
                            
                            Text("BMI: \(bmi, specifier: "%.1f")")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Activity Level").font(.headline)
                        
                        Picker("Activity Level", selection: $activityLevel) {
                            ForEach(ActivityLevel.allCases, id: \.self) { level in
                                VStack(alignment: .leading) {
                                    Text(level.title)
                                    Text(level.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Fitness Goals").font(.headline)
                        
                        ForEach(FitnessGoal.allCases, id: \.self) { goal in
                            Toggle(goal.title, isOn: Binding(
                                get: { fitnessGoals.contains(goal) },
                                set: { isOn in
                                    if isOn {
                                        fitnessGoals.insert(goal)
                                    } else {
                                        fitnessGoals.remove(goal)
                                    }
                                }
                            ))
                        }
                    }
                }
                
                GlassCard {
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        Text("Health Data").font(.headline)
                        
                        if app.isHealthAuthorized {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Current HRV")
                                    Spacer()
                                    Text(app.today.hrvLabel)
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Text("Resting Heart Rate")
                                    Spacer()
                                    Text("\(Int(app.today.restingHR)) bpm")
                                        .fontWeight(.semibold)
                                }
                                
                                HStack {
                                    Text("Today's Steps")
                                    Spacer()
                                    Text("\(app.today.steps)")
                                        .fontWeight(.semibold)
                                }
                                
                                Divider()
                                
                                Button("Sync with Health App") {
                                    Task {
                                        await app.refreshFromHealthIfAvailable()
                                    }
                                }
                                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Connect to HealthKit for personalized insights")
                                    .foregroundStyle(.secondary)
                                
                                Button("Enable Health Access") {
                                    Task {
                                        await app.requestHealthAuthorization()
                                    }
                                }
                                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("User Metrics")
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            loadUserMetrics()
        }
        .onDisappear {
            saveUserMetrics()
        }
    }
    
    private var bmi: Double {
        let heightInMeters = height / 100
        return weight / (heightInMeters * heightInMeters)
    }
    
    private func loadUserMetrics() {
        height = UserDefaults.standard.object(forKey: "user_height") as? Double ?? 170
        weight = UserDefaults.standard.object(forKey: "user_weight") as? Double ?? 70
        
        if let activityLevelRaw = UserDefaults.standard.object(forKey: "user_activity_level") as? String,
           let savedActivityLevel = ActivityLevel(rawValue: activityLevelRaw) {
            activityLevel = savedActivityLevel
        }
        
        if let goalsData = UserDefaults.standard.data(forKey: "user_fitness_goals"),
           let savedGoals = try? JSONDecoder().decode(Set<FitnessGoal>.self, from: goalsData) {
            fitnessGoals = savedGoals
        }
    }
    
    private func saveUserMetrics() {
        UserDefaults.standard.set(height, forKey: "user_height")
        UserDefaults.standard.set(weight, forKey: "user_weight")
        UserDefaults.standard.set(activityLevel.rawValue, forKey: "user_activity_level")
        
        if let goalsData = try? JSONEncoder().encode(fitnessGoals) {
            UserDefaults.standard.set(goalsData, forKey: "user_fitness_goals")
        }
    }
}

enum ActivityLevel: String, CaseIterable, Codable {
    case sedentary = "sedentary"
    case light = "light"
    case moderate = "moderate"
    case active = "active"
    case veryActive = "very_active"
    
    var title: String {
        switch self {
        case .sedentary: return "Sedentary"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }
    
    var description: String {
        switch self {
        case .sedentary: return "Desk job, little exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .active: return "Heavy exercise 6-7 days/week"
        case .veryActive: return "Very heavy physical work"
        }
    }
}

enum FitnessGoal: String, CaseIterable, Codable {
    case weightLoss = "weight_loss"
    case weightGain = "weight_gain"
    case muscleGain = "muscle_gain"
    case cardiovascularHealth = "cardiovascular_health"
    case stressReduction = "stress_reduction"
    case betterSleep = "better_sleep"
    case increaseEnergy = "increase_energy"
    
    var title: String {
        switch self {
        case .weightLoss: return "Weight Loss"
        case .weightGain: return "Weight Gain"
        case .muscleGain: return "Muscle Gain"
        case .cardiovascularHealth: return "Cardiovascular Health"
        case .stressReduction: return "Stress Reduction"
        case .betterSleep: return "Better Sleep"
        case .increaseEnergy: return "Increase Energy"
        }
    }
}

#Preview {
    NavigationStack {
        UserMetricsView()
            .environmentObject(AppState())
    }
}