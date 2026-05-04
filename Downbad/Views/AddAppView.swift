import SwiftUI
import FamilyControls
import ManagedSettings

// MARK: - AddAppView
//
// 4-step add flow: pick app (FamilyActivityPicker) → name → phrase → duration.
// The mascot reacts at each step:
//   - name length grows → smirk → unimpressed
//   - phrase preset chosen → mood reflects severity (cry, shocked, etc.)
//   - duration grows → wink → smirk → unimpressed → disappointed → shocked
//
// Note on step 1: the design's React prototype shows a "popular picks" grid
// because you can hardcode app icons in HTML. Real iOS Family Controls uses
// FamilyActivityPicker — Apple's own UI — so we can't show our own list. The
// "pick app" step is therefore a single tap that opens the system picker.

struct AddAppView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var blockManager = AppBlockManager.shared

    @State private var step: Step = .pick
    @State private var activitySelection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var displayName = ""
    @State private var selectedPreset: PhrasePreset = .pleadingShort
    @State private var customPhrase = ""
    @State private var selectedDuration: UnlockDuration

    init() {
        _selectedDuration = State(initialValue: SharedDefaults.shared.defaultUnlockDuration)
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                AddHeader(step: stepIndex, total: 4, onBack: handleBack)

                Group {
                    switch step {
                    case .pick:     pickStep
                    case .name:     nameStep
                    case .phrase:   phraseStep
                    case .duration: durationStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(step)
            }
        }
        .animation(.easeOut(duration: 0.3), value: step)
    }

    // MARK: Steps

    enum Step: Int, CaseIterable, Hashable {
        case pick, name, phrase, duration
    }
    private var stepIndex: Int { step.rawValue + 1 }

    private var token: ApplicationToken? { activitySelection.applicationTokens.first }

    private var finalPhrase: String {
        if selectedPreset == .custom {
            return customPhrase.trimmingCharacters(in: .whitespaces)
        }
        return selectedPreset.render(for: displayName)?
            .trimmingCharacters(in: .whitespaces) ?? ""
    }

    private func handleBack() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            step = prev
        } else {
            dismiss()
        }
    }

    // MARK: Step 1 — Pick app

    private var pickStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("which app are\nwe breaking up with?")
                    .font(.serifItalic(36))
                    .tracking(-0.72)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(-2)
                Text("ios will pop up its picker. just pick one. (you can add more later.)")
                    .font(.sans(14))
                    .foregroundStyle(Theme.inkMuted)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)

            Spacer().frame(height: 32)

            // Big call-to-tap card.
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: token == nil ? "apps.iphone" : "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(token == nil ? Theme.inkSoft : Theme.sageDeep)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(token == nil ? "tap to pick an app" : "1 app selected")
                            .font(.sans(17, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        Text(token == nil ? "opens the screen time picker" : "tap to change")
                            .font(.sans(13))
                            .foregroundStyle(Theme.inkMuted)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.inkMuted)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.creamSoft)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(token == nil ? Theme.creamDeep : Theme.sageDeep.opacity(0.6), lineWidth: 1.5)
                )
            }
            .buttonStyle(PressScale())
            .padding(.horizontal, 20)
            .familyActivityPicker(isPresented: $showPicker, selection: $activitySelection)

            Spacer()

            PrimaryButton(title: "next", disabled: token == nil) {
                if displayName.isEmpty,
                   let app = token,
                   let inferred = inferDisplayName(for: app) {
                    displayName = inferred
                }
                step = .name
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    /// Family Controls returns opaque tokens — we can't read the localizedDisplayName from
    /// an `ApplicationToken` directly outside of UI contexts. Leave empty so user types it.
    private func inferDisplayName(for token: ApplicationToken) -> String? { nil }

    // MARK: Step 2 — Name

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("what should\nwe call it?")
                        .font(.serifItalic(36))
                        .tracking(-0.72)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(-2)
                    Text("the name shows up in your phrase, so keep it short.")
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkMuted)
                        .lineSpacing(3)
                }
                Spacer()
                Mascot(mood: nameMood, size: 72)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)

            Spacer().frame(height: 24)

            TextField("instagram", text: $displayName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(.sans(22, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(Theme.creamSoft)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.creamDeep, lineWidth: 1.5)
                )
                .padding(.horizontal, 28)

            Spacer()

            PrimaryButton(title: "next",
                          disabled: displayName.trimmingCharacters(in: .whitespaces).isEmpty) {
                step = .phrase
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    private var nameMood: MascotMood {
        let n = displayName.trimmingCharacters(in: .whitespaces).count
        if n > 14 { return .unimpressed }
        if n > 0  { return .smirk }
        return .idle
    }

    // MARK: Step 3 — Phrase

    private var phraseStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("pick your\nshame phrase.")
                        .font(.serifItalic(36))
                        .tracking(-0.72)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(-2)
                    Text("you'll say this out loud. choose with care.")
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkMuted)
                        .lineSpacing(3)
                }
                Spacer()
                Mascot(mood: phraseMood, size: 72)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)

            Spacer().frame(height: 16)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(PhrasePreset.allCases) { preset in
                        let selected = selectedPreset == preset
                        Button {
                            selectedPreset = preset
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.displayName)
                                    .captionMono()
                                    .foregroundStyle(selected ? Color.white.opacity(0.65) : Theme.inkFaint)

                                Text(previewFor(preset))
                                    .font(.serifItalic(16))
                                    .foregroundStyle(selected ? Theme.cream : Theme.ink)
                                    .lineSpacing(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selected ? Theme.ink : Theme.creamSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(selected ? Theme.ink : Theme.creamDeep, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(PressScale())
                    }

                    if selectedPreset == .custom {
                        TextField("type your own awkward phrase…", text: $customPhrase, axis: .vertical)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled()
                            .lineLimit(3...6)
                            .font(.serifItalic(16))
                            .foregroundStyle(Theme.ink)
                            .padding(14)
                            .background(Theme.cream)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Theme.ink, lineWidth: 1.5)
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            PrimaryButton(title: "next", disabled: finalPhrase.isEmpty) {
                step = .duration
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    private var phraseMood: MascotMood {
        switch selectedPreset {
        case .pleadingShort:       return .smirk
        case .pleadingLong:        return .unimpressed
        case .embarrassingAdmit:   return .sideeye
        case .beggingRepeat:       return .disappointed
        case .desperateConfession: return .shocked
        case .custom:              return .judging
        }
    }

    private func previewFor(_ p: PhrasePreset) -> String {
        if let rendered = p.render(for: displayName), !rendered.isEmpty {
            return "\u{201C}\(rendered)\u{201D}"
        }
        return p == .custom ? "(write your own)" : "\u{201C}…\u{201D}"
    }

    // MARK: Step 4 — Duration

    private var durationStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("how long does\neach unlock last?")
                        .font(.serifItalic(36))
                        .tracking(-0.72)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(-2)
                    Text("after this, it re-locks automatically.")
                        .font(.sans(14))
                        .foregroundStyle(Theme.inkMuted)
                        .lineSpacing(3)
                }
                Spacer()
                Mascot(mood: durationMood, size: 72)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)

            Spacer().frame(height: 16)

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(UnlockDuration.allCases) { duration in
                        DurationRow(
                            duration: duration,
                            selected: selectedDuration == duration,
                            onTap: { selectedDuration = duration }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            PrimaryButton(title: "block it", disabled: token == nil || finalPhrase.isEmpty) {
                guard let token else { return }
                blockManager.addBlockedApp(
                    displayName: displayName.trimmingCharacters(in: .whitespaces),
                    unlockPhrase: finalPhrase,
                    unlockDuration: selectedDuration,
                    token: token
                )
                dismiss()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
    }

    private var durationMood: MascotMood {
        switch selectedDuration {
        case .fiveMinutes:    return .wink
        case .fifteenMinutes: return .smirk
        case .thirtyMinutes:  return .unimpressed
        case .oneHour:        return .disappointed
        case .twoHours:       return .disappointed
        case .fourHours:      return .shocked
        case .restOfDay:      return .shocked
        }
    }
}

// MARK: - AddHeader

private struct AddHeader: View {
    let step: Int
    let total: Int
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PressScale())

            Text("step \(step) of \(total)")
                .font(.sans(13, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
                .frame(maxWidth: .infinity)

            Spacer().frame(width: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }
}

// MARK: - DurationRow

private struct DurationRow: View {
    let duration: UnlockDuration
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .firstTextBaseline) {
                Text(duration.displayName.lowercased())
                    .font(.sans(17, weight: .semibold))
                    .tracking(-0.17)
                    .foregroundStyle(selected ? Theme.cream : Theme.ink)

                Spacer()

                Text(subLabel)
                    .font(.serifItalic(14))
                    .foregroundStyle(selected ? Color.white.opacity(0.7) : Theme.inkMuted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(selected ? Theme.ink : Theme.creamSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Theme.ink : Theme.creamDeep, lineWidth: 1.5)
            )
        }
        .buttonStyle(PressScale())
    }

    private var subLabel: String {
        switch duration {
        case .fiveMinutes:    return "quick peek"
        case .fifteenMinutes: return "casual scroll"
        case .thirtyMinutes:  return "we both know"
        case .oneHour:        return "real commitment"
        case .twoHours:       return "oof"
        case .fourHours:      return "see you tomorrow"
        case .restOfDay:      return "all bets are off"
        }
    }
}

#if DEBUG
#Preview { AddAppView() }
#endif
