import AppKit
import ServiceManagement
import SwiftUI

/// The panel that opens from the menu bar icon.
struct MenuPanel: View {
    @ObservedObject var speaker: Speaker
    @ObservedObject var reading: Reading
    @AppStorage(Settings.voice) private var voice = Settings.defaultVoice
    @AppStorage(Settings.language) private var language = SpokenLanguage.auto.rawValue
    @AppStorage(Settings.speed) private var speed = 1.0
    @AppStorage(Settings.smartReading) private var smartReading = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasAccessibility = Selection.hasAccessibilityPermission

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            readButton
            if let error = speaker.lastError { errorBanner(error) }
            if !reading.isEmpty {
                NowReadingView(speaker: speaker, reading: reading)
            }
            settings
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .onAppear { hasAccessibility = Selection.hasAccessibilityPermission }
    }

    private var header: some View {
        HStack {
            Image(nsImage: MenuBarIcon.image())
            Text("Lugbara").font(.headline)
            Spacer()
            HStack(spacing: 5) {
                Circle()
                    .fill(speaker.isSpeaking ? Color.accentColor : speaker.lastError != nil ? .orange : .green)
                    .frame(width: 7, height: 7)
                Text(speaker.isSpeaking ? "Reading" : speaker.lastError != nil ? "Problem" : "Ready")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var readButton: some View {
        Button(action: readOrStop) {
            HStack(spacing: 10) {
                Image(systemName: speaker.isSpeaking ? "stop.fill" : "play.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(speaker.isSpeaking ? "Stop" : "Read selection")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if speaker.isSpeaking {
                    Image(systemName: "waveform")
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: true)
                }
                Text("⌥ esc")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(speaker.isSpeaking ? Color.red.opacity(0.85) : Color.accentColor,
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(message).font(.callout).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { speaker.lastError = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var settings: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow {
                label("Language")
                Picker("", selection: $language) {
                    ForEach(SpokenLanguage.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            GridRow {
                label("Voice")
                Picker("", selection: $voice) {
                    ForEach(OpenAISpeech.voices, id: \.self) { Text($0.capitalized).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            GridRow {
                label("Speed")
                HStack {
                    Slider(value: $speed, in: 0.75...2.0)
                        .onChange(of: speed) { _, newValue in
                            let rounded = (newValue * 20).rounded() / 20
                            if rounded != newValue { speed = rounded }
                            speaker.speed = Float(rounded)
                        }
                    Text(String(format: "%.2f×", speed))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
            }
            GridRow {
                label("Code")
                Toggle(isOn: $smartReading) {
                    Text(smartReading ? "Described by GPT-6 Luna" : "Skipped as “Code block”")
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: speaker.hasAPIKey ? "key.fill" : "key")
                    .foregroundStyle(speaker.hasAPIKey ? Color.secondary : Color.orange)
                    .frame(width: 18)
                Text(speaker.hasAPIKey ? "API key saved" : "No API key")
                Spacer()
                Button(speaker.hasAPIKey ? "Change…" : "Add…") { closePanel(); APIKeyPrompt.show() }
            }
            if !hasAccessibility {
                HStack {
                    Image(systemName: "hand.raised.fill").foregroundStyle(.orange).frame(width: 18)
                    Text("Accessibility not allowed")
                    Spacer()
                    Button("Allow…") { closePanel(); Selection.requestAccessibilityPermission() }
                }
            }
            HStack {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
        }
        .font(.callout)
    }

    private func label(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
    }

    /// Closes the panel first, so the app with the selected text has focus again.
    private func readOrStop() {
        if speaker.isSpeaking {
            speaker.stop()
            return
        }
        closePanel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { speaker.toggle() }
    }

    private func closePanel() {
        NSApp.keyWindow?.close()
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            speaker.lastError = "Open at login: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
