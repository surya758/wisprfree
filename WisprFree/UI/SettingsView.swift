import SwiftUI
import ServiceManagement

// MARK: - Sidebar shell (System Settings-style)

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, insights, modes, hotkeys, models, dictionary, history, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .insights: return "Insights"
        case .modes: return "Modes"
        case .hotkeys: return "Hotkeys"
        case .models: return "Models"
        case .dictionary: return "Dictionary"
        case .history: return "History"
        case .about: return "About"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .insights: return "chart.bar.fill"
        case .modes: return "slider.horizontal.3"
        case .hotkeys: return "keyboard.fill"
        case .models: return "sparkles"
        case .dictionary: return "character.book.closed.fill"
        case .history: return "clock.fill"
        case .about: return "info.circle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .general: return .gray
        case .insights: return .teal
        case .modes: return .green
        case .hotkeys: return .indigo
        case .models: return .purple
        case .dictionary: return .orange
        case .history: return .blue
        case .about: return .pink
        }
    }
}

/// User-specified palette: floating sidebar panel over the app background.
enum SettingsColors {
    static let sidebar = Color(red: 27 / 255, green: 29 / 255, blue: 37 / 255)
    static let app = Color(red: 32 / 255, green: 34 / 255, blue: 45 / 255)
}

struct SettingsView: View {
    @State private var pane: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .background(SettingsColors.app)
        .ignoresSafeArea(.container, edges: .top)
    }

    /// Floating overlay panel, inset from the window edges; the window's
    /// traffic lights sit inside its top-left (the window has no title bar).
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Room for the traffic lights, which float over this area.
            Color.clear.frame(height: 52)
            List(SettingsPane.allCases, selection: $pane) { pane in
                Label {
                    Text(pane.title)
                } icon: {
                    Image(systemName: pane.icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 5).fill(pane.iconColor.gradient))
                }
                .tag(pane)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 212)
        .frame(maxHeight: .infinity)
        .background(SettingsColors.sidebar)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
        .padding([.leading, .top, .bottom], 12)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Opaque header layer: scrolled form cards must never paint over
            // the pane title.
            Text(pane.title)
                .font(.title2.bold())
                .padding(.top, 22)
                .padding(.leading, 26)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SettingsColors.app)
                .zIndex(1)
            Group {
                switch pane {
                case .general: GeneralSettingsView()
                case .insights: InsightsView()
                case .modes: ModesSettingsView()
                case .hotkeys: HotkeySettingsView()
                case .models: ModelSettingsView()
                case .dictionary: DictionaryView()
                case .history: HistoryView()
                case .about: AboutView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        // The app background shows through; forms hide their own (darker)
        // scroll background and their grouped cards float on top.
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @AppStorage("mode") private var mode = DictationMode.parakeetGemini.rawValue
    @AppStorage("fallbackToRaw") private var fallbackToRaw = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Dictation") {
                Picker("Mode", selection: $mode) {
                    ForEach(DictationMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
                Toggle("Insert raw transcript if the AI model is unavailable", isOn: $fallbackToRaw)
            }

            Section("App") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enable in
                        do {
                            if enable {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            PermissionsSection()
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Modes (dictation styles)

struct ModesSettingsView: View {
    @AppStorage("dictationProfile") private var profile = DictationProfile.casual.rawValue

    private var selectedProfile: DictationProfile {
        DictationProfile(rawValue: profile) ?? .casual
    }

    var body: some View {
        Form {
            Section {
                Picker("Mode", selection: $profile) {
                    ForEach(DictationProfile.allCases) { profile in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(profile.label)
                            Text(profile.summary).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(profile.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("What are you dictating?")
            } footer: {
                Text("Controls how aggressively Gemini cleans the transcript and whether your name dictionary is applied. Also switchable from the menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            PromptEditorSection(profile: selectedProfile)
                .id(selectedProfile)  // reload the editor when the mode changes
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

/// Edit the style instructions sent to Gemini for one mode. Output-format
/// rules and the dictionary are appended automatically and aren't editable.
struct PromptEditorSection: View {
    let profile: DictationProfile
    @State private var text: String
    @State private var isCustom: Bool

    init(profile: DictationProfile) {
        self.profile = profile
        let custom = AppSettings.current.customPrompt(for: profile)
        _text = State(initialValue: custom ?? PromptBuilder.defaultStyleRules(profile))
        _isCustom = State(initialValue: custom != nil)
    }

    var body: some View {
        Section {
            TextEditor(text: $text)
                .font(.system(.callout, design: .monospaced))
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .onChange(of: text) { _, newValue in
                    let isDefault = newValue == PromptBuilder.defaultStyleRules(profile)
                    AppSettings.setCustomPrompt(isDefault ? nil : newValue, for: profile)
                    isCustom = !isDefault
                }
            if isCustom {
                Button("Reset to Default") {
                    text = PromptBuilder.defaultStyleRules(profile)
                }
            }
        } header: {
            Text("Prompt for \(profile.label)\(isCustom ? " (edited)" : "")")
        } footer: {
            Text("Edits save automatically and apply to the next dictation. Output-format rules and the dictionary (Writing mode) are appended automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Hotkeys

struct HotkeySettingsView: View {
    // Bumped to force re-reading bindings after "Reset to Defaults".
    @State private var reloadToken = 0

    var body: some View {
        Form {
            Section {
                HotkeyRecorderRow(
                    title: "Push-to-talk",
                    subtitle: "Hold to record, release to insert. Tapping it also stops hands-free.",
                    defaultsKey: "holdBinding",
                    fallback: .defaultHold
                )
                HotkeyRecorderRow(
                    title: "Hands-free",
                    subtitle: "Press to start recording, press again to stop and insert.",
                    defaultsKey: "toggleBinding",
                    fallback: .defaultToggle
                )
                HotkeyRecorderRow(
                    title: "Cancel",
                    subtitle: "Discard the current recording without inserting.",
                    defaultsKey: "cancelBinding",
                    fallback: .defaultCancel
                )
            } header: {
                Text("Hotkeys")
            } footer: {
                Text("Click a key, then press the key or combination you want. Bare modifier keys (Fn, Right ⌘, …) and combinations like Fn+Space both work. Changes apply immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .id(reloadToken)

            Section {
                Button("Reset to Defaults") {
                    AppSettings.resetBindings()
                    reloadToken += 1
                }
            }

            if usesFn {
                Section {
                    Text("Using Fn: set System Settings → Keyboard → “Press 🌐 key to” = Do Nothing, so tapping Fn doesn't also open the emoji picker.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var usesFn: Bool {
        _ = reloadToken
        let settings = AppSettings.current
        return [settings.holdBinding, settings.toggleBinding, settings.cancelBinding]
            .contains { $0.flags & HotkeyBinding.fnMask != 0 || $0.keyCode == 63 }
    }
}

/// Click-to-record hotkey field: captures the next key press (or bare
/// modifier press-and-release) while active.
struct HotkeyRecorderRow: View {
    let title: String
    let subtitle: String
    let defaultsKey: String
    let fallback: HotkeyBinding

    @State private var binding: HotkeyBinding
    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var pendingModifier: Int?

    init(title: String, subtitle: String, defaultsKey: String, fallback: HotkeyBinding) {
        self.title = title
        self.subtitle = subtitle
        self.defaultsKey = defaultsKey
        self.fallback = fallback
        _binding = State(initialValue: AppSettings.current.binding(defaultsKey: defaultsKey, fallback: fallback))
    }

    var body: some View {
        LabeledContent {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Text(isRecording ? "Press keys…" : binding.label)
                    .frame(minWidth: 100)
            }
            .buttonStyle(.bordered)
            .tint(isRecording ? Color.accentColor : nil)
        } label: {
            Text(title)
            Text(subtitle)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        pendingModifier = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            handle(event)
            return nil  // swallow everything while recording
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        let keyCode = Int(event.keyCode)
        switch event.type {
        case .keyDown:
            let flags = UInt64(event.modifierFlags.rawValue)
                & (HotkeyBinding.strictMask | HotkeyBinding.fnMask)
            capture(HotkeyBinding(
                keyCode: keyCode,
                flags: flags,
                label: KeyLabel.describe(keyCode: keyCode, flags: flags, event: event)
            ))

        case .flagsChanged:
            guard let mask = HotkeyBinding.modifierMasks[keyCode] else { return }
            let down = UInt64(event.modifierFlags.rawValue) & mask != 0
            if down {
                pendingModifier = keyCode
            } else if pendingModifier == keyCode {
                // Pressed and released alone → bind the bare modifier.
                capture(HotkeyBinding(
                    keyCode: keyCode,
                    flags: mask,
                    label: KeyLabel.modifierNames[keyCode] ?? "Key \(keyCode)"
                ))
            } else {
                pendingModifier = nil
            }

        default:
            break
        }
    }

    private func capture(_ newBinding: HotkeyBinding) {
        binding = newBinding
        AppSettings.setBinding(newBinding, forKey: defaultsKey)
        stopRecording()
    }
}

/// Human-readable names for keycodes and modifier combos.
enum KeyLabel {
    static let modifierNames: [Int: String] = [
        63: "Fn", 54: "Right ⌘", 55: "⌘", 58: "⌥", 61: "Right ⌥",
        59: "⌃", 62: "Right ⌃", 56: "⇧", 60: "Right ⇧",
    ]

    static let specialNames: [Int: String] = [
        49: "Space", 53: "Esc", 36: "Return", 48: "Tab", 51: "Delete", 117: "⌦",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "Home", 119: "End", 116: "Page Up", 121: "Page Down",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
        105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19",
    ]

    /// Keys where macOS sets the fn bit implicitly — don't show "Fn +" for them.
    private static let fnImplicit: Set<Int> = [
        123, 124, 125, 126, 115, 119, 116, 121, 117,
        122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
        105, 107, 113, 106, 64, 79, 80,
    ]

    static func describe(keyCode: Int, flags: UInt64, event: NSEvent) -> String {
        var parts: [String] = []
        if flags & HotkeyBinding.fnMask != 0, !fnImplicit.contains(keyCode) { parts.append("Fn") }
        if flags & HotkeyBinding.controlMask != 0 { parts.append("⌃") }
        if flags & HotkeyBinding.optionMask != 0 { parts.append("⌥") }
        if flags & HotkeyBinding.shiftMask != 0 { parts.append("⇧") }
        if flags & HotkeyBinding.commandMask != 0 { parts.append("⌘") }

        let keyName = specialNames[keyCode]
            ?? event.charactersIgnoringModifiers?.uppercased()
            ?? "Key \(keyCode)"
        parts.append(keyName)
        return parts.joined(separator: " + ")
    }
}

// MARK: - Models

struct ModelSettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("sttModel") private var sttModel = "parakeet-v2"
    @AppStorage("geminiModel") private var model = "gemini-3.5-flash-lite"
    @AppStorage("gcpProject") private var gcpProject = ""
    @AppStorage("gcpLocation") private var gcpLocation = "global"
    @AppStorage("llmProvider") private var llmProvider = LLMProvider.vertex.rawValue
    @AppStorage("openaiModel") private var openaiModel = "gpt-5-mini"
    @AppStorage("openaiBaseURL") private var openaiBaseURL = "https://api.openai.com/v1"

    private static let customTag = "__custom__"
    @State private var customSelected = false

    private var pickerSelection: Binding<String> {
        Binding(
            get: {
                (customSelected || !ModelCatalog.known.contains(model)) ? Self.customTag : model
            },
            set: { selected in
                if selected == Self.customTag {
                    customSelected = true
                } else {
                    customSelected = false
                    model = selected
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Picker("Model", selection: $sttModel) {
                    ForEach(SttCatalog.options) { option in
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(option.label)
                                Text(option.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            // Downloading/loading state lives on the row itself.
                            if appState.phase == .loadingModel, option.id == sttModel {
                                ProgressView()
                                    .controlSize(.small)
                                    .frame(width: 16, height: 16)
                                    .offset(y: 1)
                            }
                        }
                        .tag(option.id)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: sttModel) { _, _ in
                    // Download (if needed) and load the newly selected model.
                    Task { await appState.pipeline.warmUp() }
                }
            } header: {
                Text("Speech recognition (on-device)")
            } footer: {
                Text("Models are downloaded once and cached; switching back to a downloaded model is instant.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("AI cleanup (LLM)") {
                Picker("Provider", selection: $llmProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.label).tag(provider.rawValue)
                    }
                }

                switch LLMProvider(rawValue: llmProvider) ?? .vertex {
                case .vertex:
                    geminiModelPicker
                    TextField("GCP project", text: $gcpProject, prompt: Text("your-gcp-project-id"))
                    TextField("Location", text: $gcpLocation)
                    Text("Uses your gcloud Application Default Credentials (`gcloud auth application-default login`).")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                case .geminiAPI:
                    APIKeyField(title: "Gemini API key", account: "gemini-api-key")
                    geminiModelPicker
                    Text("Free API key from aistudio.google.com → Get API key. Stored in your Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                case .openAI:
                    APIKeyField(title: "API key", account: "openai-api-key")
                    TextField("Base URL", text: $openaiBaseURL,
                              prompt: Text("https://api.openai.com/v1"))
                    TextField("Model", text: $openaiModel, prompt: Text("gpt-5-mini"))
                    Text("Works with OpenAI or any compatible endpoint (OpenRouter, Groq, local Ollama…). Key stored in your Keychain. “Audio directly to the AI model” mode needs an audio-capable model (e.g. gpt-audio).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var geminiModelPicker: some View {
        Group {
            Picker("Model", selection: pickerSelection) {
                ForEach(ModelCatalog.known, id: \.self) { name in
                    Text(name).tag(name)
                }
                Text("Custom…").tag(Self.customTag)
            }
            if pickerSelection.wrappedValue == Self.customTag {
                TextField("Custom model ID", text: $model,
                          prompt: Text("e.g. gemini-4.0-flash"))
            }
        }
    }
}

/// SecureField backed by the Keychain — loads on appear, saves on change.
struct APIKeyField: View {
    let title: String
    let account: String
    @State private var key = ""
    @State private var loaded = false

    var body: some View {
        SecureField(title, text: $key, prompt: Text("sk-…"))
            .onAppear {
                if !loaded {
                    key = KeychainStore.get(account) ?? ""
                    loaded = true
                }
            }
            .onChange(of: key) { _, newValue in
                guard loaded else { return }
                KeychainStore.set(newValue, account: account)
            }
    }
}

// MARK: - Permissions

/// Live permission status — accessibility is required for the hotkeys AND
/// for typing results into other apps, so surface its real state prominently.
struct PermissionsSection: View {
    @State private var accessibilityGranted = TextInserter.isAccessibilityTrusted
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Section("Permissions") {
            LabeledContent {
                HStack(spacing: 6) {
                    Circle()
                        .fill(accessibilityGranted ? .green : .red)
                        .frame(width: 9, height: 9)
                    Text(accessibilityGranted ? "Granted" : "Not granted")
                }
            } label: {
                Text("Accessibility")
                Text("Required for the hotkeys and for typing into other apps.")
            }
            if !accessibilityGranted {
                Button("Open Accessibility Settings…") {
                    TextInserter.ensureAccessibility()
                    NSWorkspace.shared.open(URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
                Text("Enable WisprFree in the list (remove any old entry first with the − button, then add /Applications/WisprFree.app). Takes effect within a few seconds — no relaunch needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onReceive(timer) { _ in
            accessibilityGranted = TextInserter.isAccessibilityTrusted
        }
    }
}
