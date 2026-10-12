import SwiftUI

/// The text being read, one sentence per row. The current sentence is highlighted.
/// Clicking a sentence plays from there. The buttons go back, pause and go forward.
struct NowReadingView: View {
    @ObservedObject var speaker: Speaker
    @ObservedObject var reading: Reading

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            controls
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(reading.sentences) { sentence in
                            row(sentence).id(sentence.id)
                        }
                    }
                    .padding(4)
                }
                .frame(height: 170)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: reading.current) { _, current in
                    guard let current else { return }
                    withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(current, anchor: .center) }
                }
                .onAppear {
                    if let current = reading.current { proxy.scrollTo(current, anchor: .center) }
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button { speaker.back() } label: { Image(systemName: "backward.end.fill") }
                .help("Back one sentence (⌥⇧esc)")
            Button { speaker.togglePause() } label: {
                Image(systemName: speaker.isSpeaking && !speaker.isPaused ? "pause.fill" : "play.fill")
                    .frame(width: 16)
            }
            .help(speaker.isSpeaking ? "Pause" : "Play again")
            Button { speaker.forward() } label: { Image(systemName: "forward.end.fill") }
                .help("Forward one sentence")
            Spacer()
            Text(position)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .font(.system(size: 13))
    }

    private var position: String {
        guard let current = reading.current else { return "\(reading.count) sentences" }
        return "\(current + 1) of \(reading.count)"
    }

    private func row(_ sentence: Reading.Sentence) -> some View {
        let isCurrent = sentence.id == reading.current
        let isAhead = sentence.id > (reading.current ?? -1)
        return Text(sentence.text)
            .font(.callout)
            .foregroundStyle(isCurrent ? Color.primary : isAhead ? Color.secondary : Color.primary.opacity(0.75))
            .fontWeight(isCurrent ? .medium : .regular)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(isCurrent ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
            .opacity(sentence.canPlay ? 1 : 0.45)
            .onTapGesture { speaker.jump(to: sentence.id) }
    }
}
