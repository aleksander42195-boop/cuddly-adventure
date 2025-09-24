import UIKit
#if canImport(CoreHaptics)
import CoreHaptics
#endif

final class HapticsManager {
    static let shared = HapticsManager()
    private init() {}
    
    enum Haptic {
        case tap          // light impact
        case light
        case medium
        case heavy
        case rigid
        case soft
        case selection
        case success
        case warning
        case error
        case customWaveform([Float])  // amplitude samples 0...1 (placeholder)
    }
    
    private var lastTrigger: Date = .distantPast
    private let minInterval: TimeInterval = 0.06
    
    #if canImport(CoreHaptics)
    private var engine: CHHapticEngine?
    #endif
    
    // MARK: - Public Convenience
    
    func tap() { trigger(.tap) }
    func success() { trigger(.success) }
    func warning() { trigger(.warning) }
    func error() { trigger(.error) }
    func selection() { trigger(.selection) }
    
    func prepare() {
        UIImpactFeedbackGenerator(style: .light).prepare()
        UISelectionFeedbackGenerator().prepare()
        UINotificationFeedbackGenerator().prepare()
        #if canImport(CoreHaptics)
        prepareEngineIfNeeded()
        #endif
    }
    
    // MARK: - Core Trigger
    
    func trigger(_ haptic: Haptic) {
        guard shouldFire() else { return }
        switch haptic {
        case .tap, .light: impact(.light)
        case .medium: impact(.medium)
        case .heavy: impact(.heavy)
        case .rigid:
            if #available(iOS 13.0, *) { impact(.rigid) } else { impact(.heavy) }
        case .soft:
            if #available(iOS 13.0, *) { impact(.soft) } else { impact(.light) }
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:   UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .customWaveform(let amplitudes):
            #if canImport(CoreHaptics)
            playCustom(amplitudes: amplitudes)
            #else
            impact(.light)
            #endif
        }
    }
    
    // MARK: - Helpers
    
    private func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }
    
    private func shouldFire() -> Bool {
        let now = Date()
        guard now.timeIntervalSince(lastTrigger) >= minInterval else { return false }
        lastTrigger = now
        return true
    }
    
    #if canImport(CoreHaptics)
    private func prepareEngineIfNeeded() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if engine == nil {
            engine = try? CHHapticEngine()
            try? engine?.start()
        }
    }
    
    private func playCustom(amplitudes: [Float]) {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        prepareEngineIfNeeded()
        let steps = amplitudes.enumerated().compactMap { (idx, amp) -> CHHapticEvent? in
            let clamped = max(0, min(1, amp))
            return CHHapticEvent(eventType: .hapticTransient,
                                 parameters: [CHHapticEventParameter(parameterID: .hapticIntensity, value: clamped),
                                              CHHapticEventParameter(parameterID: .hapticSharpness, value: clamped)],
                                 relativeTime: TimeInterval(idx) * 0.012)
        }
        do {
            let pattern = try CHHapticPattern(events: steps, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            impact(.light)
        }
    }
    #endif
}
