import SwiftUI
import UserNotifications

// MARK: - SettingsView
//
// Translation of design_handoff_downbad/app/Settings.jsx. Cream-paper sections,
// real diagnostics from SharedDefaults (NOT the design's hardcoded mock values),
// "made with mild concern" winking judge in the footer.

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var defaultDuration: UnlockDuration
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var diagTick = 0
    @State private var showDurationPicker = false
    @State private var showRelockConfirm = false
    @State private var showResetOnboardingConfirm = false

    @StateObject private var blockManager = AppBlockManager.shared

    init() {
        _defaultDuration = State(initialValue: SharedDefaults.shared.defaultUnlockDuration)
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Button { dismiss() } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PressScale())

                    Text("settings")
                        .font(.serifItalic(28))
                        .tracking(-0.56)
                        .foregroundStyle(Theme.ink)

                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 8)

                ScrollView {
                    VStack(spacing: 22) {
                        defaultsSection
                        actionsSection
                        notificationsSection
                        diagnosticsSection
                        aboutSection

                        // Footer
                        VStack(spacing: 12) {
                            Mascot(mood: .wink, size: 64)
                            Text("made with mild concern")
                                .font(.serifItalic(14))
                                .foregroundStyle(Theme.inkMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
        }
        .task { await refreshNotificationStatus() }
        .sheet(isPresented: $showRelockConfirm) {
            ConfirmRelockSheet(
                count: blockManager.blockedApps.filter { $0.isUnlocked }.count,
                onConfirm: {
                    for app in blockManager.blockedApps where app.isUnlocked {
                        blockManager.relockApp(id: app.id)
                    }
                    showRelockConfirm = false
                },
                onCancel: { showRelockConfirm = false }
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: Sections

    private var defaultsSection: some View {
        SettingsSection(title: "defaults") {
            SettingsRow(
                label: "default unlock duration",
                trailing: defaultDuration.displayName.lowercased(),
                onTap: { showDurationPicker.toggle() }
            )
            if showDurationPicker {
                Divider().background(Theme.creamDeep)
                VStack(spacing: 4) {
                    ForEach(UnlockDuration.allCases) { d in
                        Button {
                            defaultDuration = d
                            SharedDefaults.shared.defaultUnlockDuration = d
                            showDurationPicker = false
                        } label: {
                            HStack {
                                Text(d.displayName.lowercased())
                                    .font(.sans(14, weight: .medium))
                                Spacer()
                                if d == defaultDuration {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(d == defaultDuration ? Theme.cream : Theme.ink)
                            .background(d == defaultDuration ? Theme.ink : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(PressScale())
                    }
                }
                .padding(8)
            }
        }
    }

    private var actionsSection: some View {
        SettingsSection(title: "actions") {
            SettingsRow(
                label: "re-lock all apps now",
                trailing: "\(blockManager.blockedApps.count) blocked",
                danger: true,
                onTap: { showRelockConfirm = true }
            )
        }
    }

    private var notificationsSection: some View {
        SettingsSection(title: "notifications",
                        footer: "required so the shield's \u{201C}unlock with voice\u{201D} button can open downbad.") {
            SettingsRow(
                label: "permission",
                trailingView: AnyView(
                    HStack(spacing: 6) {
                        Circle()
                            .fill(notifColor)
                            .frame(width: 8, height: 8)
                        Text(notifText)
                            .font(.sans(13))
                            .foregroundStyle(Theme.inkMuted)
                    }
                ),
                onTap: notificationStatus != .authorized ? {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } : nil
            )
        }
    }

    private var diagnosticsSection: some View {
        let _ = diagTick
        return SettingsSection(
            title: "diagnostics",
            footer: "if 'shield ui shown' stays at 0 after opening a blocked app, ios isn't loading the custom shield. fully delete downbad, reboot, reinstall."
        ) {
            SettingsRow(label: "shield ui shown",
                        trailing: "\(SharedDefaults.shared.shieldConfigInvocations)x",
                        mono: true)
            if let last = SharedDefaults.shared.shieldConfigLastAt {
                SettingsRow(label: "last shown",
                            trailingView: AnyView(
                                Text(last, style: .relative)
                                    .font(.mono(13))
                                    .foregroundStyle(Theme.inkMuted)
                            ),
                            onTap: nil)
            }
            SettingsRow(label: "unlock button tapped",
                        trailing: "\(SharedDefaults.shared.shieldButtonTaps)x",
                        mono: true)
            if let last = SharedDefaults.shared.shieldButtonLastAt {
                SettingsRow(label: "last tap",
                            trailingView: AnyView(
                                Text(last, style: .relative)
                                    .font(.mono(13))
                                    .foregroundStyle(Theme.inkMuted)
                            ),
                            onTap: nil)
            }
            SettingsRow(label: "refresh",
                        trailing: "↻",
                        mono: true,
                        onTap: { diagTick += 1 })
        }
    }

    private var aboutSection: some View {
        SettingsSection(title: "about") {
            SettingsRow(label: "version",
                        trailing: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                        mono: true)
            SettingsRow(label: "reset onboarding",
                        trailing: "↺",
                        onTap: {
                            SharedDefaults.shared.hasOnboarded = false
                            dismiss()
                        })
        }
    }

    // MARK: Notification status

    private var notifColor: Color {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return Theme.sageDeep
        default:                                    return Color.orange
        }
    }
    private var notifText: String {
        switch notificationStatus {
        case .authorized:    return "authorized"
        case .denied:        return "denied"
        case .notDetermined: return "not asked yet"
        case .provisional:   return "provisional"
        case .ephemeral:     return "ephemeral"
        @unknown default:    return "unknown"
        }
    }

    private func refreshNotificationStatus() async {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run { notificationStatus = s.authorizationStatus }
    }
}

// MARK: - SettingsSection

private struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .captionMono()
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            VStack(spacing: 0) { content }
                .background(Theme.creamSoft)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.creamDeep, lineWidth: 1)
                )

            if let footer {
                Text(footer)
                    .font(.sans(12))
                    .foregroundStyle(Theme.inkFaint)
                    .lineSpacing(3)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
            }
        }
    }
}

// MARK: - SettingsRow

private struct SettingsRow: View {
    let label: String
    var trailing: String? = nil
    var trailingView: AnyView? = nil
    var danger: Bool = false
    var mono: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.sans(15, weight: .medium))
                    .foregroundStyle(danger ? Color.red.opacity(0.8) : Theme.ink)

                Spacer()

                if let trailingView {
                    trailingView
                } else if let trailing {
                    Text(trailing)
                        .font(mono ? .mono(13) : .sans(13))
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
        .disabled(onTap == nil)
    }
}

// MARK: - ConfirmRelockSheet (bottom sheet)

struct ConfirmRelockSheet: View {
    let count: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Theme.creamDeep)
                .frame(width: 36, height: 4)

            HStack(spacing: 14) {
                Mascot(mood: .judging, size: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("re-lock everything?")
                        .font(.serifItalic(24))
                        .tracking(-0.48)
                        .foregroundStyle(Theme.ink)
                    Text("\(count) app\(count == 1 ? "" : "s") will be locked again.")
                        .font(.sans(13))
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button(action: onCancel) {
                    Text("nah")
                        .font(.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.creamSoft)
                        .clipShape(Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Theme.creamDeep, lineWidth: 1.5)
                        )
                }
                .buttonStyle(PressScale())

                Button(action: onConfirm) {
                    Text("do it")
                        .font(.sans(15, weight: .semibold))
                        .foregroundStyle(Theme.cream)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.ink)
                        .clipShape(Capsule(style: .continuous))
                }
                .buttonStyle(PressScale())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, 8)
    }
}

// MARK: - PermissionDeniedView

struct PermissionDeniedView: View {
    enum Kind { case screentime, camera, mic, notif }

    let kind: Kind
    let onOpenSettings: () -> Void
    let onSkip: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                Mascot(mood: .disappointed,
                       size: 150,
                       variant: .letterhead,
                       caption: "permission required")
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.title)
                        .font(.serifItalic(36))
                        .tracking(-0.72)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(-2)

                    Text(copy.body)
                        .font(.sans(15))
                        .foregroundStyle(Theme.inkMuted)
                        .lineSpacing(3)
                }

                Text(copy.footnote)
                    .font(.mono(11))
                    .foregroundStyle(Theme.inkFaint)
                    .lineSpacing(3)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.creamSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.creamDeep, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer()

            VStack(spacing: 6) {
                PrimaryButton(title: "open settings", action: onOpenSettings)
                if let onSkip {
                    GhostButton(title: "not now", action: onSkip)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream)
    }

    private var copy: (title: String, body: String, footnote: String) {
        switch kind {
        case .screentime: return ("we need screen time.",
            "without it, we can't actually block anything. it's the whole gig.",
            "open settings → screen time → allow downbad")
        case .camera: return ("we need to see you.",
            "the camera makes the moment land. it's how the whole bit works.",
            "settings → downbad → camera")
        case .mic: return ("we need to hear you.",
            "speech recognition runs on-device. nothing leaves your phone.",
            "settings → downbad → microphone")
        case .notif: return ("we need notifications.",
            "the shield's unlock button sends a notification — without that, tapping it does nothing.",
            "settings → downbad → notifications")
        }
    }
}

#if DEBUG
#Preview { SettingsView() }
#Preview("Permission denied") {
    PermissionDeniedView(kind: .camera, onOpenSettings: {}, onSkip: {})
}
#Preview("Confirm relock") {
    ConfirmRelockSheet(count: 3, onConfirm: {}, onCancel: {})
        .background(Color.gray.opacity(0.3))
}
#endif
