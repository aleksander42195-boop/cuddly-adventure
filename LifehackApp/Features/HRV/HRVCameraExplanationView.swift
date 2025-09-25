//
//  HRVCameraExplanationView.swift
//  LifehackApp
//
//  Created for HRV Camera explanation popup
//

import SwiftUI

struct HRVCameraExplanationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
    private let steps = [
        ExplanationStep(
            title: "What is HRV?",
            description: "Heart Rate Variability (HRV) measures the variation in time between heartbeats. Higher HRV generally indicates better cardiovascular health and stress resilience.",
            icon: "heart.text.square",
            color: .red
        ),
        ExplanationStep(
            title: "Camera Setup",
            description: "Gently place your fingertip over the rear camera lens. Make sure your finger covers the camera completely but don't press too hard.",
            icon: "camera.fill",
            color: .blue
        ),
        ExplanationStep(
            title: "Stay Still",
            description: "Keep your finger steady and avoid moving. The app analyzes color changes in your fingertip to detect blood flow patterns.",
            icon: "hand.raised.fill",
            color: .orange
        ),
        ExplanationStep(
            title: "Measure Time",
            description: "Keep measuring for at least 60 seconds for accurate results. The app will calculate your heart rate and SDNN (HRV metric).",
            icon: "timer",
            color: .green
        )
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: AppTheme.spacing) {
                // Progress indicator
                HStack {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? steps[index].color : Color.gray.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .scaleEffect(index == currentStep ? 1.2 : 1.0)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.top)
                
                Spacer()
                
                // Current step content
                VStack(spacing: AppTheme.spacingL) {
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 60))
                        .foregroundStyle(steps[currentStep].color)
                        .symbolEffect(.bounce, value: currentStep)
                    
                    Text(steps[currentStep].title)
                        .font(.title2)
                        .bold()
                    
                    Text(steps[currentStep].description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Navigation buttons
                HStack(spacing: AppTheme.spacing) {
                    if currentStep > 0 {
                        Button("Previous") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    }
                    
                    Spacer()
                    
                    if currentStep < steps.count - 1 {
                        Button("Next") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                    } else {
                        NavigationLink(destination: HRVCameraView()) {
                            HStack {
                                Image(systemName: "camera.fill")
                                Text("Start Measuring")
                            }
                        }
                        .buttonStyle(AppTheme.LiquidGlassButtonStyle())
                        .onTapGesture { dismiss() }
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("How to Use HRV Camera")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ExplanationStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
}

#Preview {
    HRVCameraExplanationView()
}