import Foundation

/// The text being read, one sentence at a time, with the audio OpenAI has sent for each sentence.
/// The audio is kept until the next reading starts, so the listener can go back without a new request.
@MainActor
final class Reading: ObservableObject {
    struct Sentence: Identifiable {
        let id: Int
        let text: String
        let language: SpokenLanguage
        /// True once some audio has arrived, so the sentence can be played.
        var canPlay = false
    }

    @Published private(set) var sentences: [Sentence] = []
    /// The sentence the listener hears now, or heard last.
    @Published var current: Int?

    // Kept outside `sentences`, so new audio does not redraw the panel ten times a second.
    private(set) var audio: [Data] = []
    private var complete: [Bool] = []

    var count: Int { sentences.count }
    var isEmpty: Bool { sentences.isEmpty }
    var allAudioArrived: Bool { !complete.contains(false) }

    func reset() {
        sentences = []
        audio = []
        complete = []
        current = nil
    }

    func add(_ text: String, language: SpokenLanguage) -> Int {
        let index = sentences.count
        sentences.append(Sentence(id: index, text: text, language: language))
        audio.append(Data())
        complete.append(false)
        return index
    }

    func addAudio(_ pcm: Data, to index: Int) {
        guard audio.indices.contains(index) else { return }
        audio[index].append(pcm)
        if !sentences[index].canPlay { sentences[index].canPlay = true }
    }

    func isComplete(_ index: Int) -> Bool { complete.indices.contains(index) && complete[index] }

    func markComplete(_ index: Int) {
        guard complete.indices.contains(index) else { return }
        complete[index] = true
    }

    /// After a stop: keeps the sentences that have audio, so they can still be replayed, and drops the rest.
    func keepWhatArrived() {
        let kept = sentences.prefix { $0.canPlay }.count
        sentences.removeSubrange(kept...)
        audio.removeSubrange(kept...)
        complete = Array(repeating: true, count: kept)
        if let c = current, c >= kept { current = kept > 0 ? kept - 1 : nil }
    }
}
