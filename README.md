# Downbad

An iOS app that locks you out of distracting apps. To unlock, you must say a specific phrase to your camera — adding a layer of social friction that makes you think twice.

## How It Works

1. **Select apps** you want to block (Instagram, TikTok, etc.)
2. **Set a phrase** for each app (e.g., "please unlock instagram I need it please")
3. **Set an unlock duration** (5 min to rest of day — configurable per-app)
4. When you try to open a blocked app, a **shield overlay** appears
5. Tap "Unlock with Voice" → a notification opens Downbad
6. **Say the phrase to your camera** → speech recognition verifies it
7. App unlocks for the configured duration, then re-locks automatically

## Tech Stack

- **Swift / SwiftUI** (iOS 16+)
- **Screen Time API**: FamilyControls, ManagedSettings, DeviceActivity
- **Speech**: SFSpeechRecognizer (on-device, no network needed)
- **Camera**: AVCaptureSession (front camera)
- **Notifications**: UNUserNotificationCenter

## Project Structure

```
Downbad/
├── Shared/
│   └── SharedData.swift                 # Models, App Group storage, constants
├── Downbad/
│   ├── App/
│   │   └── DownbadApp.swift           # Entry point, notification + activity monitoring
│   ├── Models/
│   │   ├── AppBlockManager.swift        # Shield/unshield logic via ManagedSettingsStore
│   │   └── SpeechRecognitionManager.swift  # On-device speech-to-text + phrase matching
│   └── Views/
│       ├── HomeView.swift               # Main dashboard, app list
│       ├── AddAppView.swift             # Add app + configure phrase/duration
│       ├── UnlockView.swift             # Camera + speech unlock screen
│       ├── SettingsView.swift           # Global settings
│       └── CameraPreviewView.swift      # Live camera preview
├── Extensions/
│   ├── DeviceActivityMonitorExtension/
│   │   └── DeviceActivityMonitorExtension.swift  # Re-shields apps on schedule
│   ├── ShieldConfigurationExtension/
│   │   └── ShieldConfigurationExtension.swift    # Customizes shield overlay appearance
│   └── ShieldActionExtension/
│       └── ShieldActionExtension.swift           # Handles shield button taps
└── README.md
```

## Xcode Setup (Required for Building)

You need **Xcode on macOS** to build this project. The code can be written/edited on any OS, but compilation requires Xcode.

### Options for Mac access:
- **MacInCloud** (~$20/mo) — Remote Mac desktop with Xcode
- **Codemagic** (free tier: 500 min/mo) — CI/CD, push to GitHub and it builds
- **Used Mac Mini M1** (~$300 on eBay) — Cheapest permanent option

### Step-by-step Xcode setup:

#### 1. Create the Xcode Project
1. Open Xcode → File → New → Project
2. Choose **App** (iOS) → Next
3. Product Name: `Downbad`
4. Team: Your Apple Developer account (paid, $99/year)
5. Organization Identifier: `com.voicegate` (or your own)
6. Interface: **SwiftUI**, Language: **Swift**
7. Create

#### 2. Add Extension Targets
For each extension, go to File → New → Target:

**a) Shield Configuration Extension**
- Search "Shield Configuration" → select it → Next
- Product Name: `ShieldConfigurationExtension`
- Activate the scheme when prompted

**b) Shield Action Extension**  
- Search "Shield Action" → select it → Next
- Product Name: `ShieldActionExtension`

**c) Device Activity Monitor Extension**
- Search "Device Activity Monitor" → select it → Next
- Product Name: `DeviceActivityMonitorExtension`

#### 3. Configure App Groups
1. Select the **Downbad** target → Signing & Capabilities → + Capability → App Groups
2. Add group: `group.com.voicegate.app`
3. **Repeat for all 3 extension targets** — they must share the same App Group

#### 4. Configure Family Controls
1. Select the **Downbad** target → Signing & Capabilities → + Capability → Family Controls
2. **Repeat for all 3 extension targets**

#### 5. Add Info.plist Keys
Add these to the **main app** target's Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>Downbad needs camera access so you can say your unlock phrase on camera.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Downbad needs microphone access to hear your unlock phrase.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Downbad uses speech recognition to verify your unlock phrase.</string>
```

#### 6. Copy Source Files
1. Drag the `Shared/` folder into the Xcode project — add to **all targets**
2. Drag `Downbad/` source files into the main app target
3. Replace the auto-generated extension `.swift` files with the ones from `Extensions/`

#### 7. Build & Run
- **Must use a physical iPhone** (iOS 16+) — Screen Time APIs don't work in Simulator
- Select your device → Build & Run (Cmd+R)
- On first launch, grant Screen Time access when prompted

## Permissions Required

| Permission | Why |
|---|---|
| Screen Time (FamilyControls) | Block/unblock apps |
| Camera | Show your face while saying the phrase |
| Microphone | Capture your voice for speech recognition |
| Speech Recognition | Convert speech to text for phrase matching |
| Notifications | Alert you to open Downbad from the shield |

## Known Limitations

- **Users can revoke Screen Time access** in Settings → Screen Time. All app blockers have this limitation — Apple provides no way to lock it.
- **Shield UI is fixed** — Apple's template allows icon/title/subtitle/buttons only, no custom views.
- **Token instability** — iOS occasionally regenerates app tokens. If an app stops being blocked, remove and re-add it.
- **Cannot deep-link from shield** — uses a notification as a bridge to open the main app.
- **Testing requires a physical iPhone** — no Simulator support for Screen Time APIs.

## Distribution

To publish on the App Store:
1. Request the **Family Controls distribution entitlement** at:
   https://developer.apple.com/contact/request/family-controls-distribution
2. Explain the app's purpose (digital wellbeing / screen time management)
3. Approval typically takes 1-5 weeks
4. Once approved, archive and submit via App Store Connect
