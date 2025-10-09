import SwiftUI
import HealthKit

struct HealthSettingsView: View {
    @StateObject private var healthService = HealthKitService.shared
    @AppStorage("userName") private var userName: String = ""
    @State private var showingHeightPicker = false
    @State private var showingWeightPicker = false
    @State private var showingBirthdayPicker = false
    @State private var isRequestingAuthorization = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Temporary values for pickers
    @State private var tempHeight: Double = 175.0 // cm
    @State private var tempWeight: Double = 70.0 // kg
    @State private var tempBirthDate: Date = Date()
    
    var body: some View {
        NavigationView {
            List {
                // Authorization Section
                Section("HealthKit Authorization") {
                    HStack {
                        Image(systemName: healthService.isAuthorized ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(healthService.isAuthorized ? .green : .red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Health Data Access")
                                .font(.headline)
                            Text(healthService.isAuthorized ? "Connected to Apple Health" : "Not connected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if !healthService.isAuthorized {
                            Button("Enable") {
                                requestHealthAuthorization()
                            }
                            .disabled(isRequestingAuthorization)
                        }
                    }
                    
                    if !healthService.isHealthKitAvailable() {
                        Label("HealthKit is not available on this device", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    
                    if healthService.isAuthorized {
                        Text("The app can read your heart rate variability, sleep data, steps, and other health metrics.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Personal Information Section
                Section("Personal Information") {
                    // Name
                    HStack {
                        Label("Name", systemImage: "person.fill")
                        Spacer()
                        TextField("Your name", text: $userName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    // Birthday
                    HStack {
                        Label("Birthday", systemImage: "calendar")
                        Spacer()
                        if let birthDate = healthService.userBirthDate {
                            Text(birthDate, style: .date)
                                .foregroundColor(.secondary)
                        } else {
                            Button("Set Birthday") {
                                tempBirthDate = Date()
                                showingBirthdayPicker = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // Height
                    HStack {
                        Label("Height", systemImage: "ruler")
                        Spacer()
                        if let height = healthService.userHeight {
                            Text("\(String(format: "%.0f", height)) cm")
                                .foregroundColor(.secondary)
                        } else {
                            Button("Set Height") {
                                showingHeightPicker = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // Weight
                    HStack {
                        Label("Weight", systemImage: "scalemass")
                        Spacer()
                        if let weight = healthService.userWeight {
                            Text("\(String(format: "%.1f", weight)) kg")
                                .foregroundColor(.secondary)
                        } else {
                            Button("Set Weight") {
                                showingWeightPicker = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    // Biological Sex
                    HStack {
                        Label("Sex", systemImage: "person.2")
                        Spacer()
                        if let sex = healthService.userSex {
                            Text(sex.displayName)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not set")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if healthService.isAuthorized {
                    // Data Sync Section
                    Section("Data Synchronization") {
                        Button(action: {
                            Task {
                                await refreshHealthData()
                            }
                        }) {
                            HStack {
                                Label("Refresh Health Data", systemImage: "arrow.clockwise")
                                Spacer()
                            }
                        }
                        
                        NavigationLink(destination: HealthDataDetailView()) {
                            Label("View Health Data", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                }
                
                // Privacy Section
                Section("Privacy & Data") {
                    NavigationLink(destination: HealthPrivacyView()) {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                    }
                    
                    if healthService.isAuthorized {
                        Button(action: {
                            // Open Health app to manage permissions
                            if let url = URL(string: "x-apple-health://") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Label("Manage Permissions in Health App", systemImage: "gear")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Health Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingHeightPicker) {
            HeightPickerView(height: $tempHeight) { newHeight in
                Task {
                    do {
                        try await healthService.saveHeight(newHeight)
                    } catch {
                        showError(error.localizedDescription)
                    }
                }
            }
        }
        .sheet(isPresented: $showingWeightPicker) {
            WeightPickerView(weight: $tempWeight) { newWeight in
                Task {
                    do {
                        try await healthService.saveWeight(newWeight)
                    } catch {
                        showError(error.localizedDescription)
                    }
                }
            }
        }
        .sheet(isPresented: $showingBirthdayPicker) {
            BirthdayPickerView(birthDate: $tempBirthDate)
        }
        .onAppear {
            setupInitialValues()
        }
    }
    
    private func requestHealthAuthorization() {
        isRequestingAuthorization = true
        
        Task {
            do {
                try await healthService.requestAuthorization()
            } catch {
                await MainActor.run {
                    showError("Failed to authorize HealthKit: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isRequestingAuthorization = false
            }
        }
    }
    
    private func refreshHealthData() async {
        // Trigger a refresh of all health data
        // This would typically call your app's health data refresh methods
    }
    
    private func setupInitialValues() {
        if let height = healthService.userHeight {
            tempHeight = height
        }
        if let weight = healthService.userWeight {
            tempWeight = weight
        }
        if let birthDate = healthService.userBirthDate {
            tempBirthDate = birthDate
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}

// MARK: - Height Picker
struct HeightPickerView: View {
    @Binding var height: Double
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Set Your Height")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Picker("Height", selection: $height) {
                    ForEach(120...220, id: \.self) { cm in
                        Text("\(cm) cm").tag(Double(cm))
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 200)
                
                Text("\(String(format: "%.0f", height)) cm")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(height)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Weight Picker
struct WeightPickerView: View {
    @Binding var weight: Double
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Set Your Weight")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Picker("Weight", selection: $weight) {
                    ForEach(Array(stride(from: 40.0, through: 150.0, by: 0.5)), id: \.self) { kg in
                        Text("\(String(format: "%.1f", kg)) kg").tag(kg)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(height: 200)
                
                Text("\(String(format: "%.1f", weight)) kg")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(weight)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Birthday Picker
struct BirthdayPickerView: View {
    @Binding var birthDate: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Text("Set Your Birthday")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                DatePicker(
                    "Birthday",
                    selection: $birthDate,
                    in: Date(timeIntervalSince1970: -2208988800)...Date(), // From 1900 to now
                    displayedComponents: .date
                )
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                
                Text(birthDate, style: .date)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Note: Birthday data is read-only from HealthKit")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Health Privacy View
struct HealthPrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Health Data Privacy")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 16) {
                    PrivacySection(
                        title: "Data Collection",
                        content: "We only access health data that you explicitly authorize through Apple's HealthKit. This includes heart rate variability, sleep data, steps, and other fitness metrics."
                    )
                    
                    PrivacySection(
                        title: "Data Storage",
                        content: "Your health data remains on your device and is never sent to our servers. All processing happens locally on your iPhone."
                    )
                    
                    PrivacySection(
                        title: "Data Usage",
                        content: "We use your health data solely to provide personalized insights and recommendations within the app. Your data is never shared with third parties."
                    )
                    
                    PrivacySection(
                        title: "Data Control",
                        content: "You can revoke access to your health data at any time through the iPhone Settings app or the Health app. You maintain full control over what data we can access."
                    )
                }
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacySection: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shield.fill")
                    .foregroundColor(.green)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - Health Data Detail View
struct HealthDataDetailView: View {
    @StateObject private var healthService = HealthKitService.shared
    @State private var recentHRVData: [HKQuantitySample] = []
    @State private var recentHeartRateData: [HKQuantitySample] = []
    @State private var isLoading = true
    
    var body: some View {
        List {
            Section("Recent HRV Data") {
                if isLoading {
                    ProgressView("Loading...")
                } else if recentHRVData.isEmpty {
                    Text("No HRV data available")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(recentHRVData.prefix(10), id: \.uuid) { sample in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(String(format: "%.1f", sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)))) ms")
                                    .font(.headline)
                                Text(sample.endDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(sample.endDate, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section("Recent Heart Rate Data") {
                if isLoading {
                    ProgressView("Loading...")
                } else if recentHeartRateData.isEmpty {
                    Text("No heart rate data available")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(recentHeartRateData.prefix(10), id: \.uuid) { sample in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("\(String(format: "%.0f", sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())))) BPM")
                                    .font(.headline)
                                Text(sample.endDate, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(sample.endDate, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Health Data")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadHealthData()
        }
        .refreshable {
            await loadHealthData()
        }
    }
    
    private func loadHealthData() async {
        isLoading = true
        
        async let hrvData = healthService.getRecentHRVData(days: 7)
        async let heartRateData = healthService.getRecentHeartRateData(days: 7)
        
        let (hrv, hr) = await (hrvData, heartRateData)
        
        await MainActor.run {
            recentHRVData = hrv ?? []
            recentHeartRateData = hr ?? []
            isLoading = false
        }
    }
}

// MARK: - Extensions
extension HKBiologicalSex {
    var displayName: String {
        switch self {
        case .female:
            return "Female"
        case .male:
            return "Male"
        case .other:
            return "Other"
        default:
            return "Not specified"
        }
    }
}

#Preview {
    HealthSettingsView()
}