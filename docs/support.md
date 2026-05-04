---
title: Support
layout: default
permalink: /support/
---

# Downbad — Support

The fastest way to get a reply is email. There's only one of me, but I read everything.

📧 **[armandasdourian@gmail.com](mailto:armandasdourian@gmail.com)**

Please include your iOS version and a sentence about what went wrong.

## Frequently asked

### "An app I blocked stopped getting blocked. What do I do?"

iOS occasionally regenerates the internal tokens it uses to identify apps. If an app stops being shielded, **remove it from Downbad and re-add it.** That's an Apple-side limitation, not something the app can fix automatically.

### "The shield overlay disappeared / the unlock screen won't open."

1. Make sure you've granted **Notification** permissions to Downbad in iOS Settings → Notifications → Downbad. The shield uses a notification to bridge back to the main app.
2. Make sure **Screen Time** access is still granted in iOS Settings → Screen Time → See All App & Website Activity → Downbad. iOS lets you revoke this at any time, and there's no way for the app to prevent that — it's a system-level control.

### "Speech recognition isn't matching my phrase."

The matcher is permissive — it looks for your phrase as a substring of what was heard, lowercased, with whitespace trimmed. If it still doesn't catch you:
- Speak clearly and at a normal pace
- Make sure you're in a quiet enough room
- Re-set the phrase to something simpler (long phrases are harder to recognize end-to-end)

### "Can someone else unlock my apps?"

Yes — anyone holding your unlocked phone could speak your phrase. Downbad is a friction tool, not a security tool. If you need real lockdown, use iOS's built-in Screen Time passcode in addition to Downbad.

### "Does this work on iPad / Mac?"

Currently iOS only (iPhone, iOS 16+). iPad support is on the roadmap.

### "How do I delete all my data?"

Delete the app. There is no other data — nothing on any server, no account, nothing to clean up.
