import Foundation

enum SharedKeys {
    static let coachEngineSelection = "coachEngine.selection"     // String (rawValue fra CoachEngine)
    static let coachWristTipsEnabled = "coach.wristTips.enabled"  // Bool
    static let coachBaseURL = "coach.baseURL"                      // String
    static let coachResponsesModel = "coach.responsesModel"        // String
    static let coachChatModel = "coach.chatModel"                  // String
    static let hrvLastKnownMs = "training.hrv.lastKnownMs"         // Double (milliseconds)
}
