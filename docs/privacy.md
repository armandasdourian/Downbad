---
title: Privacy Policy
layout: default
permalink: /privacy/
---

# Privacy Policy

_Last updated: 2026-05-04_

Downbad is built around a single principle: **your data never leaves your device.**

## What we collect

**Nothing.** Downbad does not collect, transmit, store, sell, or share any personal data with us or any third party. We have no servers. We have no analytics. We have no tracking SDKs.

## How the app uses sensitive permissions

| Permission | Purpose | Where it goes |
|---|---|---|
| **Camera** | Shows your face live while you say your unlock phrase, so the moment is intentional and visible. | Frames are shown on screen and discarded. Nothing is recorded, saved, or transmitted. |
| **Microphone** | Captures your voice for the unlock phrase. | Audio buffers are streamed to Apple's on-device speech recognizer and discarded. No audio is recorded, saved, or transmitted. |
| **Speech Recognition** | Converts your spoken phrase to text so it can be matched against your saved unlock phrase. | Runs **on-device only** (`requiresOnDeviceRecognition = true`). No audio or transcript leaves your device. |
| **Screen Time / Family Controls** | Lets the app shield and unshield the apps you choose to block. | All Screen Time tokens stay on your device. Apple's Family Controls APIs do not share app identity with developers. |
| **Notifications** | Used as a bridge to open Downbad from the shield overlay when you tap "Unlock with Voice." | Local notifications only. |

## Data storage

The list of apps you've blocked, your unlock phrases, and your unlock duration preferences are stored on your device using iOS's standard `UserDefaults` mechanism within an app group shared between Downbad and its extensions. This data is never transmitted off-device and is removed when you delete the app.

## Children

Downbad uses Apple's Family Controls framework but is intended for self-use by individuals 13 and older. We do not knowingly collect any data from children.

## Third parties

There are no third-party services in Downbad. No advertising, no analytics, no crash reporters, no SDKs.

## Contact

Questions? Email: [armandasdourian@gmail.com](mailto:armandasdourian@gmail.com)

## Changes to this policy

If this policy ever changes, the updated version will be posted at this URL with the new "Last updated" date. Material changes will also be reflected in App Store Connect.
