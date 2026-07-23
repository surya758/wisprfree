import SwiftUI
import AVFoundation

/// First-run guided setup: welcome → permissions → AI provider → try it.
/// Shown when "onboardingDone" is unset; also reachable from About.
struct OnboardingView: View {
    let finish: () -> Void
    @State private var step = 0
    private let stepCount = 4

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case 0: WelcomeStep()
                case 1: PermissionsStep()
                case 2: ProviderStep()
                default: TryItStep()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<stepCount, id: \.self) { index in
                        Circle()
                            .fill(index == step ? Color.accentColor : Color.white.opacity(0.2))
                            .frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                Button(step == stepCount - 1 ? "Start Dictating" : "Continue") {
                    if step == stepCount - 1 {
                        finish()
                    } else {
                        step += 1
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 620, height: 560)
        .background(SettingsColors.app)
    }
}

private struct StepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.title.bold())
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 20)
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .padding(.top, 20)
            StepHeader(
                title: "Welcome to WisprFree",
                subtitle: "Speak anywhere on your Mac — clean, polished text is typed right where your cursor is."
            )
            VStack(alignment: .leading, spacing: 14) {
                bullet("mic.fill", "Hold a key and talk",
                       "Your voice is transcribed on-device — fast, free, private.")
                bullet("sparkles", "AI cleanup",
                       "Grammar fixed, filler words gone, names spelled right — tuned to what you're writing.")
                bullet("keyboard.fill", "Types into any app",
                       "Notes, browsers, writing apps — wherever the cursor lives.")
            }
            .padding(.horizontal, 40)
        }
    }

    private func bullet(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Step 2: Permissions

private struct PermissionsStep: View {
    @State private var micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    @State private var axGranted = TextInserter.isAccessibilityTrusted
    private let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            StepHeader(
                title: "Two Permissions",
                subtitle: "WisprFree needs your mic to hear you, and Accessibility to type the result into other apps."
            )
            permissionRow(
                granted: micGranted,
                icon: "mic.fill",
                title: "Microphone",
                detail: "Audio never leaves your Mac unless you choose a cloud mode.",
                buttonTitle: "Allow Microphone"
            ) {
                AVCaptureDevice.requestAccess(for: .audio) { _ in }
            }
            permissionRow(
                granted: axGranted,
                icon: "accessibility",
                title: "Accessibility",
                detail: "Powers the global hotkeys and typing into the frontmost app.",
                buttonTitle: "Open Accessibility Settings"
            ) {
                TextInserter.ensureAccessibility()
                NSWorkspace.shared.open(URL(
                    string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
            Text("Both take effect immediately — no restart needed.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .onReceive(timer) { _ in
            micGranted = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
            axGranted = TextInserter.isAccessibilityTrusted
        }
    }

    private func permissionRow(
        granted: Bool, icon: String, title: String, detail: String,
        buttonTitle: String, action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 30)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 12, weight: .medium))
            } else {
                Button(buttonTitle, action: action)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.05)))
        .padding(.horizontal, 20)
    }
}

// MARK: - Step 3: AI provider

private struct ProviderStep: View {
    @AppStorage("llmProvider") private var llmProvider = LLMProvider.vertex.rawValue
    @AppStorage("gcpProject") private var gcpProject = ""
    @AppStorage("openaiModel") private var openaiModel = "gpt-5-mini"
    @AppStorage("openaiBaseURL") private var openaiBaseURL = "https://api.openai.com/v1"

    var body: some View {
        VStack(spacing: 16) {
            StepHeader(
                title: "Pick Your AI",
                subtitle: "The cleanup step runs on a model of your choice. Local transcription works either way — you can skip this and stay fully offline."
            )
            Form {
                Picker("Provider", selection: $llmProvider) {
                    ForEach(LLMProvider.allCases) { provider in
                        Text(provider.label).tag(provider.rawValue)
                    }
                }
                switch LLMProvider(rawValue: llmProvider) ?? .vertex {
                case .vertex:
                    TextField("GCP project", text: $gcpProject, prompt: Text("your-gcp-project-id"))
                    Text("Requires `gcloud auth application-default login` on this Mac.")
                        .font(.caption).foregroundStyle(.secondary)
                case .geminiAPI:
                    APIKeyField(title: "Gemini API key", account: "gemini-api-key")
                    Text("Free key from aistudio.google.com → Get API key. Stored in your Keychain.")
                        .font(.caption).foregroundStyle(.secondary)
                case .openAI:
                    APIKeyField(title: "API key", account: "openai-api-key")
                    TextField("Base URL", text: $openaiBaseURL)
                    TextField("Model", text: $openaiModel)
                    Text("OpenAI or any compatible endpoint (OpenRouter, Groq, Ollama…). Stored in your Keychain.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(maxHeight: 240)
            Text("All of this can be changed later in Settings → Models.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Step 4: Hotkeys + test

private struct TryItStep: View {
    @State private var testText = ""

    var body: some View {
        VStack(spacing: 14) {
            StepHeader(
                title: "Try It",
                subtitle: "Click the box below, then dictate. That's the whole app."
            )
            VStack(alignment: .leading, spacing: 8) {
                keyRow("Hold Fn", "record while held, release to insert")
                keyRow("Fn + Space", "hands-free — tap Fn to stop")
                keyRow("Esc", "cancel a recording")
            }
            .padding(.horizontal, 40)

            TextEditor(text: $testText)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(height: 110)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.06)))
                .overlay(alignment: .topLeading) {
                    if testText.isEmpty {
                        Text("Click here, hold Fn, and say something…")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 13))
                            .padding(.top, 12)
                            .padding(.leading, 14)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 20)

            Text("Tip: set System Settings → Keyboard → “Press 🌐 key to” = Do Nothing, so tapping Fn doesn't open the emoji picker. Hotkeys are remappable in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }

    private func keyRow(_ key: String, _ action: String) -> some View {
        HStack(spacing: 10) {
            Text(key)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.1)))
            Text(action).font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Window

@MainActor
final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Welcome to WisprFree"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.isReleasedWhenClosed = false
            window.contentViewController = NSHostingController(
                rootView: OnboardingView { [weak self] in
                    UserDefaults.standard.set(true, forKey: "onboardingDone")
                    self?.window?.close()
                    MainWindowController.shared.show()
                }
            )
            window.setContentSize(NSSize(width: 620, height: 560))
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
