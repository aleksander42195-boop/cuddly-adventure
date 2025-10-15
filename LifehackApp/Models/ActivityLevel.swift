import SwiftUI

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary = "sedentary"
    case light = "light"
    case moderate = "moderate"
    case active = "active"
    case veryActive = "very_active"
    
    var id: String { rawValue }
    
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
        case .sedentary: return "Sedentary"
        case .light: return "Light Activity"
        case .moderate: return "Moderate Activity"
        case .active: return "Active"
        case .veryActive: return "Very Active"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .sedentary: return "Desk job, little exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .active: return "Heavy exercise 6-7 days/week"
        case .veryActive: return "Very heavy physical work"
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
    
    static func from(metHours: Double) -> ActivityLevel {
        switch metHours {
        case 0..<3: return .sedentary
        case 3..<6: return .light
        case 6..<12: return .moderate
        case 12..<20: return .active
        default: return .veryActive
        }
    }
}