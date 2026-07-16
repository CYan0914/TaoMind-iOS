# TaoMind iOS App

Ancient Wisdom for Modern Decisions — iOS native SwiftUI app.

## Quick Start

### Prerequisites
- macOS 14+ (Sonoma)
- Xcode 15.4+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build & Run

```bash
# Generate Xcode project
xcodegen generate

# Open in Xcode
open TaoMind.xcodeproj

# Or build directly
xcodebuild build \
  -project TaoMind.xcodeproj \
  -scheme TaoMind \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Project Structure

```
TaoMind-iOS/
├── TaoMindApp.swift          # App entry point
├── ContentView.swift         # Tab navigation
├── Models/                   # Data models
├── Services/                 # API client, business logic
├── Views/                    # All UI views
├── Resources/                # Assets, Info.plist, Privacy
├── project.yml               # XcodeGen project spec
└── .github/workflows/        # CI/CD
```

### Architecture

- **SwiftUI** — iOS 16+ minimum
- **MV** — stateless views, no ViewModel layer (simple enough to skip it)
- **Async/await** — URLSession async API calls
- **Offline fallback** — built-in verse cache when API is unreachable

### Deployment

```bash
# Archive for App Store
xcodebuild archive \
  -project TaoMind.xcodeproj \
  -scheme TaoMind \
  -configuration Release \
  -archivePath TaoMind.xcarchive
```

## API Backend

The app connects to a Python FastAPI backend at:

```
https://observant-prosperity-production-92d3.up.railway.app
```

For local development, change `apiBaseURL` in `TaoMindApp.swift` to `http://localhost:8000`.
