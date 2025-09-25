import SwiftUI
import HealthKit

struct UserMetricsView: View {
    @EnvironmentObject var app: AppState
    
    // Personal Information
    @State private var fullName: String = ""
    @State private var birthDate: Date = Date()
    @State private var gender: Gender = .notSpecified
    
    // Physical Metrics
    @State private var height: Double = 170 // cm
    @State private var weight: Double = 70 // kg
    
    // Health Metrics  
    @State private var systolicBP: String = "120"
    @State private var diastolicBP: String = "80"
    @State private var restingHeartRate: String = "72"
    @State private var bloodType: BloodType = .unknown
    
    // Lifestyle
    @State private var activityLevel: ActivityLevel = .moderate
    @State private var fitnessGoals: Set<FitnessGoal> = []
    @State private var sleepHours: Double = 8.0
    
    // Medical History
    @State private var allergies: String = ""
    @State private var medications: String = ""
    @State private var medicalConditions: String = ""
    
    @State private var showingSuccessAlert = false

    var body: some View {
        NavigationView {
            Form {
                personalInfoSection
                physicalMetricsSection
                healthMetricsSection
                lifestyleSection
                medicalHistorySection
                actionButtons
            }
        }
        .navigationTitle("Health Profile")
        .background(AppTheme.background.ignoresSafeArea())
        .onAppear {
            loadUserMetrics()
        }
        .alert("Profile Saved", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text("Your health profile has been saved successfully.")
        }
    }
    
    private var personalInfoSection: some View {
        Section("Personal Information") {
            HStack {
                Text("Full Name")
                Spacer()
                TextField("Enter your name", text: $fullName)
                    .multilineTextAlignment(.trailing)
            }
            
            DatePicker("Birth Date", selection: $birthDate, displayedComponents: .date)
            
            HStack {
                Text("Age")
                Spacer()
                Text("\(age) years")
                    .foregroundStyle(.secondary)
            }
            
            Picker("Gender", selection: $gender) {
                ForEach(Gender.allCases, id: \.self) { gender in
                    Text(gender.title).tag(gender)
                }
            }
        }
    }
    
    private var physicalMetricsSection: some View {
        Section("Physical Metrics") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Height")
                    Spacer()
                    Text("\(Int(height)) cm")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $height, in: 100...220, step: 1)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weight")
                    Spacer()
                    Text("\(Int(weight)) kg")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $weight, in: 30...200, step: 1)
            }
            
            HStack {
                Text("BMI")
                Spacer()
                Text("\(bmi, specifier: "%.1f")")
                    .foregroundStyle(bmiColor)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("BMI Category")
                Spacer()
                Text(bmiCategory)
                    .foregroundStyle(bmiColor)
                    .font(.caption)
            }
        }
    }
    
    private var healthMetricsSection: some View {
        Section("Health Metrics") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Blood Pressure")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 16) {
                    VStack {
                        Text("Systolic")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("120", text: $systolicBP)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    
                    Text("/")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    VStack {
                        Text("Diastolic")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("80", text: $diastolicBP)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                    }
                    
                    Spacer()
                    
                    Text("mmHg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Text("Resting Heart Rate")
                Spacer()
                TextField("72", text: $restingHeartRate)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .frame(width: 80)
                Text("bpm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Picker("Blood Type", selection: $bloodType) {
                ForEach(BloodType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
        }
    }
    
    private var lifestyleSection: some View {
        Section("Lifestyle") {
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
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Average Sleep")
                    Spacer()
                    Text("\(sleepHours, specifier: "%.1f") hours")
                        .foregroundStyle(.secondary)
                }
                Slider(value: $sleepHours, in: 4...12, step: 0.5)
            }
            
            NavigationLink("Fitness Goals") {
                FitnessGoalsSelectionView(selectedGoals: $fitnessGoals)
            }
        }
    }
    
    private var medicalHistorySection: some View {
        Section("Medical History") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Allergies")
                    .font(.subheadline)
                TextField("Any known allergies...", text: $allergies, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Medications")
                    .font(.subheadline)
                TextField("List current medications...", text: $medications, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Medical Conditions")
                    .font(.subheadline)
                TextField("Any medical conditions...", text: $medicalConditions, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    private var actionButtons: some View {
        Section {
            Button("Save Profile") {
                saveUserMetrics()
                showingSuccessAlert = true
                app.tapHaptic()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(AppTheme.LiquidGlassButtonStyle())
            
            if app.isHealthAuthorized {
                Button("Sync with HealthKit") {
                    Task {
                        await syncWithHealthKit()
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(AppTheme.LiquidGlassButtonStyle())
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var age: Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        return ageComponents.year ?? 0
    }
    
    private var bmi: Double {
        let heightInMeters = height / 100
        return weight / (heightInMeters * heightInMeters)
    }
    
    private var bmiCategory: String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }
    
    private var bmiColor: Color {
        switch bmi {
        case ..<18.5: return .blue
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }
    
    // MARK: - Functions
    
    private func loadUserMetrics() {
        fullName = UserDefaults.standard.string(forKey: "user_full_name") ?? ""
        
        if let birthDateData = UserDefaults.standard.data(forKey: "user_birth_date"),
           let savedBirthDate = try? JSONDecoder().decode(Date.self, from: birthDateData) {
            birthDate = savedBirthDate
        }
        
        if let genderRaw = UserDefaults.standard.string(forKey: "user_gender"),
           let savedGender = Gender(rawValue: genderRaw) {
            gender = savedGender
        }
        
        height = UserDefaults.standard.object(forKey: "user_height") as? Double ?? 170
        weight = UserDefaults.standard.object(forKey: "user_weight") as? Double ?? 70
        
        systolicBP = UserDefaults.standard.string(forKey: "user_systolic_bp") ?? "120"
        diastolicBP = UserDefaults.standard.string(forKey: "user_diastolic_bp") ?? "80"
        restingHeartRate = UserDefaults.standard.string(forKey: "user_resting_hr") ?? "72"
        
        if let bloodTypeRaw = UserDefaults.standard.string(forKey: "user_blood_type"),
           let savedBloodType = BloodType(rawValue: bloodTypeRaw) {
            bloodType = savedBloodType
        }
        
        if let activityLevelRaw = UserDefaults.standard.string(forKey: "user_activity_level"),
           let savedActivityLevel = ActivityLevel(rawValue: activityLevelRaw) {
            activityLevel = savedActivityLevel
        }
        
        sleepHours = UserDefaults.standard.object(forKey: "user_sleep_hours") as? Double ?? 8.0
        
        if let goalsData = UserDefaults.standard.data(forKey: "user_fitness_goals"),
           let savedGoals = try? JSONDecoder().decode(Set<FitnessGoal>.self, from: goalsData) {
            fitnessGoals = savedGoals
        }
        
        allergies = UserDefaults.standard.string(forKey: "user_allergies") ?? ""
        medications = UserDefaults.standard.string(forKey: "user_medications") ?? ""
        medicalConditions = UserDefaults.standard.string(forKey: "user_medical_conditions") ?? ""
    }
    
    private func saveUserMetrics() {
        UserDefaults.standard.set(fullName, forKey: "user_full_name")
        
        if let birthDateData = try? JSONEncoder().encode(birthDate) {
            UserDefaults.standard.set(birthDateData, forKey: "user_birth_date")
        }
        
        UserDefaults.standard.set(gender.rawValue, forKey: "user_gender")
        UserDefaults.standard.set(height, forKey: "user_height")
        UserDefaults.standard.set(weight, forKey: "user_weight")
        
        UserDefaults.standard.set(systolicBP, forKey: "user_systolic_bp")
        UserDefaults.standard.set(diastolicBP, forKey: "user_diastolic_bp")
        UserDefaults.standard.set(restingHeartRate, forKey: "user_resting_hr")
        UserDefaults.standard.set(bloodType.rawValue, forKey: "user_blood_type")
        
        UserDefaults.standard.set(activityLevel.rawValue, forKey: "user_activity_level")
        UserDefaults.standard.set(sleepHours, forKey: "user_sleep_hours")
        
        if let goalsData = try? JSONEncoder().encode(fitnessGoals) {
            UserDefaults.standard.set(goalsData, forKey: "user_fitness_goals")
        }
        
        UserDefaults.standard.set(allergies, forKey: "user_allergies")
        UserDefaults.standard.set(medications, forKey: "user_medications")
        UserDefaults.standard.set(medicalConditions, forKey: "user_medical_conditions")
    }
    
    private func syncWithHealthKit() async {
        // Sync with HealthKit if available
        await app.refreshFromHealthIfAvailable()
        
        // TODO: Write user data to HealthKit if permissions allow
        if app.isHealthAuthorized {
            // This could be expanded to write user data back to HealthKit
            print("Syncing with HealthKit...")
        }
    }
}

// MARK: - Supporting Views

struct FitnessGoalsSelectionView: View {
    @Binding var selectedGoals: Set<FitnessGoal>
    
    var body: some View {
        List {
            ForEach(FitnessGoal.allCases, id: \.self) { goal in
                HStack {
                    Text(goal.title)
                    Spacer()
                    if selectedGoals.contains(goal) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedGoals.contains(goal) {
                        selectedGoals.remove(goal)
                    } else {
                        selectedGoals.insert(goal)
                    }
                }
            }
        }
        .navigationTitle("Fitness Goals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Enums

enum Gender: String, CaseIterable, Codable {
    case male = "male"
    case female = "female"
    case notSpecified = "not_specified"
    
    var title: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .notSpecified: return "Prefer not to say"
        }
    }
}

enum BloodType: String, CaseIterable, Codable {
    case aPositive = "A+"
    case aNegative = "A-"
    case bPositive = "B+"
    case bNegative = "B-"
    case abPositive = "AB+"
    case abNegative = "AB-"
    case oPositive = "O+"
    case oNegative = "O-"
    case unknown = "unknown"
    
    var title: String {
        switch self {
        case .unknown: return "Unknown"
        default: return rawValue
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