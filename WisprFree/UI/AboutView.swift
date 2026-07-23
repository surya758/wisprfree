import SwiftUI

struct AboutView: View {
    private var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("WisprFree").font(.title2.bold())
                        Text("Version \(version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Personal dictation for macOS — local speech recognition with LLM cleanup.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("How it works") {
                LabeledContent("Speech to text", value: "On-device (Parakeet / Whisper / Cohere)")
                LabeledContent("Cleanup", value: "Gemini (Vertex / API) or OpenAI-compatible")
                LabeledContent("Insertion", value: "Pastes into the frontmost app")
            }

            Section("Built with") {
                LabeledContent("FluidAudio", value: "Parakeet & Cohere CoreML runtimes")
                LabeledContent("WhisperKit", value: "Whisper CoreML runtime")
                LabeledContent("Google Vertex AI / Gemini API / OpenAI", value: "Cleanup models")
            }

            Section("Data") {
                LabeledContent("Dictionary, history & stats",
                               value: "~/Library/Application Support/WisprFree")
                LabeledContent("Speech models",
                               value: "~/Library/Application Support/FluidAudio")
                Button("Show Welcome Guide") {
                    OnboardingWindowController.shared.show()
                }
                Button("Open Data Folder") {
                    let url = FileManager.default
                        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("WisprFree")
                    NSWorkspace.shared.open(url)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
