//
//  ChatGPTLoginView.swift
//  LifehackApp
//
//  Created for ChatGPT login and subscription options
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ChatGPTLoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var engineManager: CoachEngineManager
    @EnvironmentObject private var app: AppState
    @State private var apiKeyInput: String = ""
    @State private var showingSubscriptionInfo = false
    @State private var selectedPlan: SubscriptionPlan = .basic
    
    private var hasAPIKey: Bool { Secrets.shared.openAIAPIKey != nil }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.spacingL) {
                    // Header
                    VStack(spacing: AppTheme.spacingS) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("AI Health Coach")
                            .font(.title2)
                            .bold()
                        
                        Text("Connect with ChatGPT for personalized health insights and coaching")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)
                    
                    if !hasAPIKey {
                        // API Key Setup Section
                        GlassCard {
                            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                                HStack {
                                    Image(systemName: "key.fill")
                                        .foregroundStyle(.orange)
                                    Text("Connect Your Account")
                                        .font(.headline)
                                }
                                
                                Text("Enter your OpenAI API key to enable AI coaching features")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                SecureField("sk-proj-...", text: $apiKeyInput)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                
                                HStack {
                                    Button("Get API Key") {
                                        if let url = URL(string: "https://platform.openai.com/api-keys") {
                                            #if canImport(UIKit)
                                            UIApplication.shared.open(url)
                                            #endif
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                    
                                    Spacer()
                                    
                                    Button("Save Key") { saveAPIKey() }
                                    .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            }
                        }
                    }
                    
                    // Subscription Plans
                    VStack(alignment: .leading, spacing: AppTheme.spacing) {
                        Text("Choose Your Plan")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        // Basic Plan
                        SubscriptionPlanCard(
                            plan: .basic,
                            isSelected: selectedPlan == .basic,
                            onSelect: { selectedPlan = .basic }
                        )
                        
                        // Pro Plan with Memory
                        SubscriptionPlanCard(
                            plan: .pro,
                            isSelected: selectedPlan == .pro,
                            onSelect: { selectedPlan = .pro }
                        )
                        
                        // Premium Plan
                        SubscriptionPlanCard(
                            plan: .premium,
                            isSelected: selectedPlan == .premium,
                            onSelect: { selectedPlan = .premium }
                        )
                    }
                    
                    // Action Buttons
                    VStack(spacing: AppTheme.spacingS) {
                        if hasAPIKey {
                            NavigationLink(destination: CoachView()) {
                                HStack {
                                    Image(systemName: "message.fill")
                                    Text("Start Coaching")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                            .onTapGesture { 
                                app.tapHaptic()
                                dismiss() 
                            }
                        }
                        
                        Button("Learn More") {
                            showingSubscriptionInfo = true
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("AI Coach Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingSubscriptionInfo) {
                SubscriptionInfoView()
            }
        }
    }
    
    private func saveAPIKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }
        
        Secrets.shared.setOpenAIOverride(trimmedKey)
        app.tapHaptic()
        // Optionally dismiss or show success message
    }
}

enum SubscriptionPlan: CaseIterable {
    case basic, pro, premium
    
    var title: String {
        switch self {
        case .basic: return "Basic"
        case .pro: return "Pro + Memory"
        case .premium: return "Premium"
        }
    }
    
    var price: String {
        switch self {
        case .basic: return "Free"
        case .pro: return "$9.99/month"
        case .premium: return "$19.99/month"
        }
    }
    
    var features: [String] {
        switch self {
        case .basic:
            return [
                "Basic health insights",
                "Standard response time",
                "Limited daily queries"
            ]
        case .pro:
            return [
                "Everything in Basic",
                "📚 Memory features",
                "Personalized coaching",
                "Unlimited queries",
                "Priority responses"
            ]
        case .premium:
            return [
                "Everything in Pro",
                "🧠 Advanced AI models",
                "Custom health plans",
                "Integration with wearables",
                "24/7 priority support"
            ]
        }
    }
    
    var color: Color {
        switch self {
        case .basic: return .gray
        case .pro: return .purple
        case .premium: return .gold
        }
    }
}

private extension Color {
    static let gold = Color(red: 0.8, green: 0.6, blue: 0.2)
}

struct SubscriptionPlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundStyle(plan.color)
                        Text(plan.price)
                            .font(.subheadline)
                            .bold()
                    }
                    
                    Spacer()
                    
                    if plan == .pro {
                        HStack {
                            Image(systemName: "brain.head.profile.fill")
                                .foregroundStyle(.purple)
                            Text("MEMORY")
                                .font(.caption)
                                .bold()
                                .foregroundStyle(.purple)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? plan.color : .secondary)
                        .font(.title2)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(plan.features, id: \.self) { feature in
                        HStack {
                            Image(systemName: "checkmark")
                                .foregroundStyle(plan.color)
                                .font(.caption)
                            Text(feature)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.corner)
                .stroke(isSelected ? plan.color : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

struct SubscriptionInfoView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.spacing) {
                    Text("Memory Features")
                        .font(.title2)
                        .bold()
                    
                    Text("With Pro + Memory, your AI coach remembers:")
                        .font(.body)
                    
                    VStack(alignment: .leading, spacing: AppTheme.spacingS) {
                        FeatureRow(icon: "brain", text: "Your health goals and preferences")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Your progress over time")
                        FeatureRow(icon: "heart.text.square", text: "Your health patterns and trends")
                        FeatureRow(icon: "message.badge.circle", text: "Context from previous conversations")
                    }
                    
                    Text("Privacy & Security")
                        .font(.title2)
                        .bold()
                        .padding(.top)
                    
                    Text("Your data is encrypted and stored securely. You can delete your memory data at any time.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Subscription Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.purple)
                .frame(width: 20)
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    ChatGPTLoginView()
        .environmentObject(CoachEngineManager())
        .environmentObject(AppState())
}