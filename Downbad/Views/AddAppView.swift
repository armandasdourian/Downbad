import SwiftUI
import FamilyControls

struct AddAppView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var blockManager = AppBlockManager.shared

    @State private var activitySelection = FamilyActivitySelection()
    @State private var showPicker = false
    @State private var displayName = ""
    @State private var selectedPreset: PhrasePreset = .pleadingShort
    @State private var customPhrase = ""
    @State private var selectedDuration: UnlockDuration

    init() {
        _selectedDuration = State(initialValue: SharedDefaults.shared.defaultUnlockDuration)
    }

    private var selectedToken: ApplicationToken? {
        activitySelection.applicationTokens.first
    }

    private var finalPhrase: String {
        if selectedPreset == .custom {
            return customPhrase.trimmingCharacters(in: .whitespaces)
        }
        return selectedPreset.render(for: displayName)?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    private var isValid: Bool {
        guard selectedToken != nil else { return false }
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return !finalPhrase.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: App Selection
                Section {
                    Button {
                        showPicker = true
                    } label: {
                        if selectedToken != nil {
                            Label("App selected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Choose an app to block", systemImage: "apps.iphone")
                        }
                    }
                    .familyActivityPicker(
                        isPresented: $showPicker,
                        selection: $activitySelection
                    )
                } header: {
                    Text("App")
                } footer: {
                    Text("Select one app at a time. You can add more later.")
                }

                // MARK: Display Name
                Section("Display Name") {
                    TextField("e.g. Instagram", text: $displayName)
                        .textInputAutocapitalization(.words)
                }

                // MARK: Unlock Phrase
                Section {
                    Picker("Phrase", selection: $selectedPreset) {
                        ForEach(PhrasePreset.allCases) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    if selectedPreset == .custom {
                        TextField("type your own awkward phrase", text: $customPhrase, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .lineLimit(2...4)
                    }
                } header: {
                    Text("Unlock Phrase")
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if !finalPhrase.isEmpty {
                            Text("You'll say: \u{201C}\(finalPhrase)\u{201D}")
                                .italic()
                                .foregroundStyle(.primary)
                        }
                        Text("You must say this phrase to your camera to unlock the app. Make it awkward enough that you'll think twice.")
                    }
                }

                // MARK: Duration
                Section {
                    Picker("Unlock Duration", selection: $selectedDuration) {
                        ForEach(UnlockDuration.allCases) { duration in
                            Text(duration.displayName).tag(duration)
                        }
                    }
                } header: {
                    Text("How Long to Unlock")
                } footer: {
                    Text("After this time, the app re-locks automatically.")
                }
            }
            .navigationTitle("Block an App")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Block") {
                        guard let token = selectedToken else { return }
                        blockManager.addBlockedApp(
                            displayName: displayName.trimmingCharacters(in: .whitespaces),
                            unlockPhrase: finalPhrase,
                            unlockDuration: selectedDuration,
                            token: token
                        )
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}
