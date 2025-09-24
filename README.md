# Lifehack (clean start)
Grunnmur med SwiftUI, “glass cards”, haptikk, HealthKit (valgfritt) og mock Coach.

## Kjøring
- Åpne i Xcode 15/16, iOS 17+
- (Valgfritt) Skru på HealthKit-capability og sett Info.plist-tekstene.
- Kopiér `Config/Secrets.example.plist` til `Config/Secrets.plist` og legg inn ev. nøkler.

## Mapper
- LifehackApp: appkode
- Config: Secrets.plist (ikke i git)

## Neste steg
- Bytt `MockChatService` til ekte OpenAI-klient.
- Legg til watchOS-target.
- Utvid Journal/Nutrition med lagring (SwiftData/Core Data/CloudKit).

---

## English README

## LifehackApp

A modular SwiftUI health & wellness companion app scaffold. Includes feature tabs for daily metrics, journaling, nutrition planning, AI coaching, and settings; plus reusable UI components, models, and service abstractions for health data, chat, and haptics.

### Project Structure
```
Config/
	Secrets.example.plist      # Copy to Secrets.plist (ignored) and fill with real keys
LifehackApp/
	LifehackApp.swift          # @main entry point
	AppState.swift             # Global observable state & service composition
	AppTheme.swift             # Design tokens (colors, metrics, modifiers)
	ContentView.swift          # Root TabView
	Components/
		GlassCard.swift
		MetricRing.swift
	Features/
		Today/TodayView.swift
		Journal/JournalView.swift
		Nutrition/NutritionView.swift
		Coach/CoachingView.swift
		Settings/SettingsView.swift
	Models/
		MetricModels.swift
		ChatModels.swift
	Services/
		HapticsManager.swift
		ChatService.swift
		HealthKitService.swift
```

### macOS Command Line Tools (Prerequisite)
Verify Apple Command Line Tools (needed for git/clang):
```bash
xcode-select -p   # should output a path
```
Interpretation:
- Outputs a path => tools installed & active.
- Errors: xcode-select: error: tool 'xcode-select' requires command line developer tools
  -> Run install command below.
- Example (your output): /Applications/Xcode.app/Contents/Developer  ✅ Ready.
- Example (only CLT installed): /Library/Developer/CommandLineTools  ✅ Ready.

Reset / switch (if path is stale or removed Xcode):
```bash
# Use Command Line Tools bundle
sudo xcode-select --switch /Library/Developer/CommandLineTools
# Or point back to full Xcode after (adjust version/path)
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
# Verify
xcode-select -p
```

Valid outputs typically:
- /Applications/Xcode.app/Contents/Developer
- /Library/Developer/CommandLineTools

If it errors or shows nothing, install:
```bash
xcode-select --install
```
Then re-run:
```bash
xcode-select -p
```

### Getting Started
1. Open `LifehackApp.xcodeproj` in Xcode (double‑click or `open LifehackApp.xcodeproj`). A minimal project file is present; you may prefer to recreate a full target via Xcode (File > New > Project) and then drag the existing `LifehackApp/` sources in for richer build settings.
2. Confirm the asset catalog colors exist (already scaffolded: `Background`, `AccentColor`). Adjust values in the color sets or modify `AppTheme`.
3. Duplicate `Config/Secrets.example.plist` to `Config/Secrets.plist` and insert real API keys (OpenAI, Firebase, etc.). Keep it untracked (already in `.gitignore`).
4. In Xcode, add `Secrets.plist` to the app target (ensure Target Membership checkbox is ticked) so it’s bundled at runtime.
5. Update the bundle identifier in the target settings (e.g. `com.yourcompany.lifehack`). Set a valid development team for code signing.
6. Enable HealthKit capability: TARGET > Signing & Capabilities > + Capability > HealthKit. Add/adjust usage description strings in `Info.plist` as you expand data types.
7. (Optional) Add Push Notifications, Background Modes (if you plan scheduled refresh), and App Groups if sharing with a Watch extension later.
8. Build & Run on a device or simulator. Current HealthKit values are stubbed until real queries are implemented.

### Running in Xcode
1. Open LifehackApp.xcodeproj
2. Select target: LifehackApp
3. Set a unique Bundle Identifier + Development Team (Signing)
4. (Optional) Attach xcconfig files:
   - Debug: Configuration/Debug.xcconfig
   - Release: Configuration/Release.xcconfig
5. Add Secrets:
   - Duplicate Config/Secrets.example.plist -> Config/Secrets.plist
   - Fill OPENAI_API_KEY (or leave blank and set later in app Settings)
   - Add file to target (Target Membership checked)
6. Capabilities:
   - HealthKit (if using real data)
   - Background Modes (if scheduling refresh later)
7. Scheme Environment (Debug only, optional):
   - LIFEHACK_VERBOSE_LOGGING=YES
8. Choose a simulator (iPhone 15 / iOS 17+) or device
9. Press Run (⌘R)

#### Optional Run Script Phase (Build Settings > + New Run Script) BEFORE “Compile Sources”
This auto‑copies a placeholder Secrets if missing (never add real keys to CI logs):
```bash
# Name: Prepare Secrets
if [ ! -f "${SRCROOT}/Config/Secrets.plist" ]; then
  echo "⚠️  Secrets.plist missing, copying example."
  cp "${SRCROOT}/Config/Secrets.example.plist" "${SRCROOT}/Config/Secrets.plist"
fi
```

#### Troubleshooting
- Build fails: Ensure Swift tools version (Xcode 15/16) and iOS deployment target ≥ 17.
- Missing API responses: Verify key saved (Settings → Coach API Key) or set in Keychain before run.
- Health data all placeholders: HealthKit not authorized or HEALTHKIT_ENABLED=false in Secrets.plist.

### Developer Mode (Future Device / iOS 26 Ready)
Enable an isolated developer configuration:
1. Add `Configuration/Development.xcconfig` to the Debug (or a new “Development”) configuration.
2. In the scheme, duplicate Debug → rename to Development and assign the xcconfig.
3. Environment flags provided:
   - LIFEHACK_DEVELOPER_MODE=YES
   - LIFEHACK_ENABLE_FAKE_HEALTHKIT=YES (synthetic metrics generator)
   - LIFEHACK_VERBOSE_LOGGING=YES
4. When active:
   - Settings shows a Developer section (toggle synthetic metrics).
   - Health metrics are generated deterministically per day if synthetic enabled.
5. Safe to run on future simulators (e.g. “iPhone 17 Pro Max (2TB)” / iOS 26) — no compile‑time device assumptions.

### Adding OpenAI (ChatGPT) API Key
Create (or edit) Config/Secrets.plist and ensure it contains (placeholder shown — DO NOT commit a real key):
```xml
<key>OPENAI_API_KEY</key>
<string>sk-proj-your-real-key-here</string>
```
Notes:
- Never commit the real key (Secrets.plist should stay ignored).
- If already pushed, revoke & rotate the key in the OpenAI dashboard.
- You may also leave it blank and enter the key inside the app Settings → Coach.
- Optional (macOS Keychain storage example):
  security add-generic-password -a "$USER" -s LIFEHACK_OPENAI_API_KEY -w "sk-proj-your-real-key-here" -U

### Secrets File Format
`Secrets.example.plist` contains placeholder keys:
```
OPENAI_API_KEY
FIREBASE_API_KEY
BACKEND_BASE_URL
HEALTHKIT_ENABLED (bool)
```
Access pattern suggestion:
```swift
final class Secrets {
		static let shared = Secrets()
		private let dict: [String: Any]
		private init() {
				if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
					 let data = try? Data(contentsOf: url),
					 let obj = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
					 let d = obj as? [String: Any] {
					dict = d
				} else { dict = [:] }
		}
		func string(_ key: String) -> String? { dict[key] as? String }
		func bool(_ key: String) -> Bool { dict[key] as? Bool ?? false }
}
```

### Secrets.plist Example
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <!-- Copy to Secrets.plist and insert real values -->
  <key>OPENAI_API_KEY</key>
  <string></string>
  <key>FIREBASE_API_KEY</key>
  <string></string>
  <key>BACKEND_BASE_URL</key>
  <string>https://api.example.com</string>
  <key>HEALTHKIT_ENABLED</key>
  <true/>
</dict>
</plist>
```

### Services Overview
- `ChatService`: Actor stub simulating an async AI completion. Replace with real networking (URLSession / async streaming) later.
- `HealthKitService`: Provides parallel stub metric fetch; replace stub methods with real HK queries (sample aggregation, category analysis).
- `HapticsManager`: Basic light wrapper over UIKit feedback & (optionally) CoreHaptics.

### Extending HealthKit Queries
Replace stubs like `stepsToday()` with something like:
```swift
private func stepsToday() async throws -> Double {
		guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
		let startOfDay = Calendar.current.startOfDay(for: Date())
		let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date())
		return try await withCheckedThrowingContinuation { cont in
				let sumQuery = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
					if let e = error { cont.resume(throwing: e); return }
					let value = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
					cont.resume(returning: value)
				}
				healthStore.execute(sumQuery)
		}
}
```

### UI Components
- `GlassCard`: Frosted translucent container with subtle border & shadow.
- `MetricRing`: Animated circular progress with gradient stroke.

### Planned Enhancements
- Watch app companion (extension target)
- Persistent journal storage (Core Data or SwiftData)
- Real AI coach streaming responses
- Swift Package modularization (Features, Core, Services)
- Snapshot & unit tests

### Contributing / Next Steps
Open an issue or iterate locally:
- Implement real HealthKit queries
- Add persistence for chat & journaling
- Integrate push notifications & scheduling

### Contributing
1. Fork & branch: feat/short-description
2. Run formatting (SwiftFormat / swiftlint if added later).
3. Add/adjust tests under `LifehackAppTests/`.
4. Keep features modular (no massive god files).
5. Secrets: never commit real keys. Use `Secrets.example.plist` & runtime overrides.
6. PR checklist:
   - [ ] Builds clean (Debug)
   - [ ] No new warnings
   - [ ] Tests added/updated (if logic)
   - [ ] Screenshots for major UI changes (attach in PR)

### Development Notes
- OpenAI integration: implement `OpenAIClient` (see stub).
- Persistence: `PersistenceController` placeholder (swap SwiftData/CoreData).
- HealthKit: app will gracefully fall back to placeholder metrics if disabled or unauthorized.

### License
Add a license file if you plan to open source.

---
Generated scaffold date: 2025-09-22

### App Icons (Primary + Alternate “Dark”)
Two icon sets are included in the asset catalog:
- Primary: `Assets.xcassets/AppIcon.appiconset`
- Alternate: `Assets.xcassets/AppIcon-Dark.appiconset` (switchable at runtime)

A helper script generates all required sizes from 1024×1024 artwork using macOS `sips`:

Usage (examples):
```bash
# Primary only
python3 scripts/generate_app_icons.py --primary /absolute/path/to/primary_1024.png

# Alternate (Dark) only
python3 scripts/generate_app_icons.py --dark /absolute/path/to/dark_1024.png

# Both at once
python3 scripts/generate_app_icons.py \
	--primary /absolute/path/to/primary_1024.png \
	--dark /absolute/path/to/dark_1024.png
```

Notes:
- Provide true 1024×1024, square, non-transparent artwork. PNG preferred (JPEG also supported).
- The script preserves existing `Contents.json` and writes exactly the filenames listed there.
- After generation, build in Xcode to preview.
- The app includes a simple runtime icon picker in Settings to toggle the alternate icon (if the device supports alternate icons).

Troubleshooting:
- If icons don’t change on device, ensure app was launched at least once after install, and try killing/relaunching. Alternate icon changes are sandboxed by iOS and may not reflect immediately on the SpringBoard.
- App Store submission typically expects no transparency and correct pixel sizes; the script produces exact sizes for all iPhone/iPad slots and iOS‑marketing (1024×1024).

### Chat API Modes
The Coach tab supports two OpenAI API styles (toggle after you add an API key):
- Completions (/v1/chat/completions) classic messages format.
- Responses (/v1/responses) newer items-based format.
Selection is persisted (UserDefaults) via `AppState.chatAPI`.

### Git & CI (Push Cheatsheet)
Typical flow:
```bash
git status
git add -A
git commit -m "feat: describe change"
git pull --rebase origin main   # keep linear history
git push origin main
```
First remote push (if branch not on origin):
```bash
git push -u origin main
```
Amend last commit (small fix):
```bash
git add path/to/file
git commit --amend --no-edit
git push --force-with-lease
```
Create feature branch:
```bash
git checkout -b feat/new-module
# work...
git push -u origin feat/new-module
```
CI runs on push & pull_request (see .github/workflows/ci.yml).
