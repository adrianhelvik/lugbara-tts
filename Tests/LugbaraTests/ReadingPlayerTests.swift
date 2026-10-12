import XCTest
@testable import Lugbara

/// Plays silent audio through the real audio engine, so nothing is heard during the tests.
@MainActor
final class ReadingPlayerTests: XCTestCase {
    /// `seconds` of silence as 24 kHz 16-bit PCM.
    private func silence(_ seconds: Double) -> Data {
        Data(count: Int(24_000 * seconds) * 2)
    }

    private func readingWithThreeSentences(complete: Bool = true) -> Reading {
        let reading = Reading()
        for text in ["One.", "Two.", "Three."] {
            let index = reading.add(text, language: .english)
            reading.addAudio(silence(0.2), to: index)
            if complete { reading.markComplete(index) }
        }
        return reading
    }

    private func waitUntil(_ condition: () -> Bool, timeout: Double = 3) async throws {
        let end = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > end { return XCTFail("Timed out") }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    func testPlaysEverySentenceAndFinishes() async throws {
        let reading = readingWithThreeSentences()
        let player = ReadingPlayer(reading: reading)
        try player.start()
        XCTAssertEqual(reading.current, 0)
        try await waitUntil { player.isFinished }
        XCTAssertEqual(reading.current, 2)
        player.stop()
    }

    func testJumpingBackPlaysFromThatSentence() async throws {
        let reading = readingWithThreeSentences()
        let player = ReadingPlayer(reading: reading)
        try player.start(at: 2)
        XCTAssertEqual(reading.current, 2)
        player.seek(to: 0)
        XCTAssertEqual(reading.current, 0)
        XCTAssertFalse(player.isFinished)
        try await waitUntil { player.isFinished }
        XCTAssertEqual(reading.current, 2)
        player.stop()
    }

    func testWaitsForAudioThatHasNotArrived() async throws {
        let reading = Reading()
        let player = ReadingPlayer(reading: reading)
        try player.start()
        let index = reading.add("Later.", language: .english)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertFalse(player.isFinished)

        reading.addAudio(silence(0.1), to: index)
        reading.markComplete(index)
        player.feed()
        try await waitUntil { player.isFinished }
        XCTAssertEqual(reading.current, 0)
        player.stop()
    }

    func testPausedPlayerDoesNotFinish() async throws {
        let reading = readingWithThreeSentences()
        let player = ReadingPlayer(reading: reading)
        try player.start()
        player.setPaused(true)
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertFalse(player.isFinished)
        player.setPaused(false)
        try await waitUntil { player.isFinished }
        player.stop()
    }

    func testStopKeepsOnlySentencesWithAudio() {
        let reading = Reading()
        _ = reading.add("Heard.", language: .english)
        reading.addAudio(silence(0.1), to: 0)
        _ = reading.add("Never arrived.", language: .english)
        reading.current = 1
        reading.keepWhatArrived()
        XCTAssertEqual(reading.sentences.map(\.text), ["Heard."])
        XCTAssertEqual(reading.current, 0)
        XCTAssertTrue(reading.allAudioArrived)
    }

    func testTextIsSplitIntoSentences() {
        XCTAssertEqual(TextChunker.sentences("First one. Second one!\nThird?"),
                       ["First one.", "Second one!", "Third?"])
    }
}
