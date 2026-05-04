# Family Controls (Distribution) Entitlement — Request

**Status:** ✅ Submitted 2026-05-04 via https://developer.apple.com/contact/request/family-controls-distribution
**Apple response:** "Thank you for your submission. We'll review your request and contact you soon with a status update."
**Expected wait:** 1–5 weeks per Apple's docs.
**Watch for replies at:** asdouriana@gmail.com (the email Apple has on the developer account, not armandasdourian@gmail.com)

The current form is dramatically simpler than older docs suggest — it's just identity confirmation + Terms acknowledgment + one "Get Entitlement" button. No app description, bundle IDs, or use case writeup needed at submission time. Apple may follow up by email if they need more.

The full descriptive writeup below is kept for reference in case Apple replies asking for clarification, or for any future re-submission.

---

## App Name
Downbad

## Bundle Identifiers
- `com.voicegate.app` (main app)
- `com.voicegate.app.ShieldConfiguration` (shield configuration extension)
- `com.voicegate.app.ShieldAction` (shield action extension)
- `com.voicegate.app.DeviceActivityMonitor` (device activity monitor extension)

## Team ID
Q32TFF7K3U

## Category
Digital wellbeing / screen time management

## Audience
Adults using the app on their own personal device for self-imposed focus and digital wellbeing. Not marketed to or used by children. Authorization is requested as `.individual`, not `.child`.

## Description of the app

Downbad is a digital-wellbeing app that helps the user reduce time spent in distracting apps by adding a deliberate, embarrassing speech-recognition step to unlocking them.

The user picks the apps they want to block (e.g. Instagram, TikTok), writes a self-chosen unlock phrase for each one (e.g. "please unlock instagram I really need it"), and chooses an unlock duration (5 min — rest of day). When they try to open a blocked app, Downbad's shield overlay appears. To bypass it, they must open Downbad and say their phrase out loud, on camera, with on-device speech recognition verifying the match. The app then re-locks automatically when the unlock duration expires.

The friction of saying an embarrassing phrase aloud — to themselves, on camera — is the entire mechanism. It's slower than a passcode and slower than a willpower test, and that's the point.

## How we use Family Controls APIs

- `FamilyControls.AuthorizationCenter` — request `.individual` authorization
- `ManagedSettingsStore` — apply `shield.applications` to block user-selected apps
- `ManagedSettingsUI.ShieldConfigurationDataSource` — customize the shield overlay (icon, title, button labels)
- `ManagedSettings.ShieldActionDelegate` — handle the user tapping "Unlock with Voice" on the shield (we route them via local notification to the main app's unlock flow)
- `DeviceActivity.DeviceActivityMonitor` + `DeviceActivityCenter` — daily schedule that re-applies shields after process termination / reboot

We do **not** use `.child` authorization or any features intended for parental supervision of minors.

## Privacy

Downbad collects no data. All speech recognition runs on-device (`SFSpeechRecognizer.requiresOnDeviceRecognition = true`). No audio, video, or analytics is transmitted off the device. Application tokens stay on-device. Privacy policy: [TODO: HOSTED URL].

## App Store readiness

Project structure, entitlements, and the four bundle IDs are already in place. Build pipeline (Codemagic + xcodebuild) produces a signed development IPA today. Distribution build path is configured and ready to flip to App Store export the moment this entitlement is granted. We have not yet submitted to App Review.

## Contact

armandasdourian@gmail.com
