import XCTest
@testable import Lugbara

/// A fake OpenAI. Each request takes the next answer from `answers`: either audio, or silence forever.
final class FakeOpenAI: URLProtocol {
    enum Answer { case audio(Data), silence }
    nonisolated(unsafe) static var answers: [Answer] = []
    nonisolated(unsafe) static var requestCount = 0

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestCount += 1
        let answer = Self.answers.isEmpty ? .silence : Self.answers.removeFirst()
        guard case .audio(let data) = answer else { return }
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class OpenAISpeechTests: XCTestCase {
    private func speech() -> OpenAISpeech {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FakeOpenAI.self]
        var speech = OpenAISpeech(apiKey: "test")
        speech.session = URLSession(configuration: config)
        speech.firstAudioTimeout = .milliseconds(300)
        return speech
    }

    private final class Collected: @unchecked Sendable {
        var bytes = 0
    }

    override func setUp() {
        FakeOpenAI.answers = []
        FakeOpenAI.requestCount = 0
    }

    func testSendsTheRequestAgainWhenOpenAIStaysSilent() async throws {
        FakeOpenAI.answers = [.silence, .audio(Data(count: 9_600))]
        let collected = Collected()
        try await speech().stream(text: "Hi.", voice: "marin", instructions: "") { collected.bytes += $0.count }
        XCTAssertEqual(FakeOpenAI.requestCount, 2)
        XCTAssertEqual(collected.bytes, 9_600)
    }

    func testGivesUpAfterThreeSilentAttempts() async {
        FakeOpenAI.answers = [.silence, .silence, .silence]
        do {
            try await speech().stream(text: "Hi.", voice: "marin", instructions: "") { _ in }
            XCTFail("Expected an error")
        } catch SpeechError.noAudio {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(FakeOpenAI.requestCount, 3)
    }

    func testFastAnswerDoesNotWaitForTheTimer() async throws {
        FakeOpenAI.answers = [.audio(Data(count: 4_800))]
        var speech = speech()
        speech.firstAudioTimeout = .seconds(5)
        let start = Date()
        try await speech.stream(text: "Hi.", voice: "marin", instructions: "") { _ in }
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        XCTAssertEqual(FakeOpenAI.requestCount, 1)
    }
}
