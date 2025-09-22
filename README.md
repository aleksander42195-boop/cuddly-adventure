# LifehackApp - iOS & watchOS App

A productivity-focused iOS and watchOS app that provides daily life hacks and productivity tips.

## Features

### iOS App
- 📱 Clean, modern interface
- 💡 Daily productivity tips and life hacks
- 🎯 Simple tap-to-get-tip functionality
- 🎨 iOS 17+ compatible design

### watchOS App
- ⌚ Companion watch app
- 🔔 Quick access to tips on your wrist
- 🎚️ Haptic feedback for interactions
- 🌟 Optimized for Apple Watch Series 4+

## Requirements

- Xcode 15.0 or later
- iOS 17.0+ / watchOS 10.0+
- Swift 5.0+

## Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone https://github.com/aleksander42195-boop/cuddly-adventure.git
   cd cuddly-adventure
   ```

2. **Open in Xcode:**
   ```bash
   open LifehackApp.xcodeproj
   ```

3. **Build and Run:**
   - Select your target device (iPhone or Apple Watch simulator)
   - Press `Cmd + R` to build and run
   - For Watch app: Make sure both iPhone and Watch simulators are running

## Project Structure

```
LifehackApp.xcodeproj/           # Xcode project file
├── LifehackApp/                 # iOS app target
│   ├── AppDelegate.swift        # App delegate
│   ├── SceneDelegate.swift      # Scene delegate  
│   ├── ViewController.swift     # Main view controller
│   ├── Main.storyboard         # UI storyboard
│   ├── LaunchScreen.storyboard # Launch screen
│   ├── Assets.xcassets         # App icons and images
│   └── Info.plist              # App configuration
├── LifehackApp WatchKit App/    # watchOS app target
│   ├── Interface.storyboard    # Watch UI
│   ├── Assets.xcassets         # Watch icons
│   └── Info.plist              # Watch app config
└── LifehackApp WatchKit Extension/  # watchOS extension
    ├── InterfaceController.swift    # Watch interface controller
    ├── ExtensionDelegate.swift      # Extension delegate
    └── Info.plist                   # Extension config
```

## Development

The app is structured with three targets:
- **LifehackApp**: Main iOS application
- **LifehackApp WatchKit App**: watchOS companion app  
- **LifehackApp WatchKit Extension**: watchOS extension with business logic

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is available for educational and personal use.
