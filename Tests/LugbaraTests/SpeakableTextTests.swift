import XCTest
@testable import Lugbara

/// Text copied from a Claude Code session in iTerm, with its indentation and line wrapping.
private let terminalText = """
⏺ The theme refactor is rebased onto staging, checked, and ready to push. Type check, 121 web integration tests and 76 theme unit tests pass on
  the rebased code. Here's the walkthrough first.

  1. One rule for a new slide's theme. packages/document-react/src/theme/new-slide-theme.ts

  export function newSlideTheme(input: NewSlideThemeInput): SlideTheme {
    if (input.chosen) return input.chosen;            // chosen in the picker, by import, by the assistant
    const { neighbour, deck } = input;
    if (input.kind === 'content') {
      if (neighbour && !neighbour.exercise && neighbour.theme) {
        return neighbour.theme;                       // the content slide it's inserted after
      }
      return deck.content ?? studio().content;
    }

    if (deck.exercise) return deck.exercise;          // the deck's default exercise theme
    return deck.content ?? studio().exercise;
  }

  These all go through this function now:
  - the layout picker
  - a blank slide

  2. A slide is drawn from its own theme, never the deck's. packages/document-react/src/theme/slide-theme.ts

  -export function resolveSlideTheme(slide, deckTheme: UnifiedTheme): UnifiedTheme {
  -  if (!slideTheme) return deckTheme;
  +export function resolveSlideTheme(slide: { readonly theme?: SlideTheme | null }): UnifiedTheme {
  +  // no usable theme → Studio

  A content slide now also stores the exercise colours.
"""

final class SpeakableTextTests: XCTestCase {
    func testCodeBlockBecomesOneMarker() {
        let spoken = SpeakableText.prepare(terminalText, codeMarker: "Code block.")
        XCTAssertEqual(spoken.components(separatedBy: "Code block.").count - 1, 2, spoken)
        XCTAssertFalse(spoken.contains("return"), spoken)
        XCTAssertFalse(spoken.contains("{"), spoken)
        XCTAssertFalse(spoken.contains("//"), spoken)
    }

    func testProseIsKept() {
        let spoken = SpeakableText.prepare(terminalText, codeMarker: "Code block.")
        XCTAssertTrue(spoken.contains("These all go through this function now:"), spoken)
        XCTAssertTrue(spoken.contains("the layout picker"), spoken)
        XCTAssertTrue(spoken.contains("A content slide now also stores the exercise colours."), spoken)
    }

    func testPathIsReadAsFileName() {
        let spoken = SpeakableText.prepare(terminalText, codeMarker: "Code block.")
        XCTAssertTrue(spoken.contains("One rule for a new slide's theme. new-slide-theme"), spoken)
        XCTAssertFalse(spoken.contains("packages"), spoken)
    }

    func testDecorationsAreRemoved() {
        let spoken = SpeakableText.prepare(terminalText, codeMarker: "Code block.")
        XCTAssertFalse(spoken.contains("⏺"), spoken)
        XCTAssertFalse(spoken.contains("- the layout picker"), spoken)
    }

    func testHeadingAndListItemsEndAsSentences() {
        let text = """
        Ikke testet, trenger nøkkelen din

          - Om Luna-kallet virker i det hele tatt
          - Hvor rask Luna er. Hvis den bruker mer enn 5 sekunder,
            får du de faste reglene
        """
        let spoken = SpeakableText.prepare(text, codeMarker: "Kodeblokk.")
        XCTAssertEqual(spoken, """
        Ikke testet, trenger nøkkelen din.

        Om Luna-kallet virker i det hele tatt.
        Hvor rask Luna er. Hvis den bruker mer enn 5 sekunder,
        får du de faste reglene.
        """)
    }

    func testIdentifiersAreSplitIntoWords() {
        let spoken = SpeakableText.prepare("Call `resolveSlideTheme` or slide_theme.", codeMarker: "Code block.")
        XCTAssertEqual(spoken, "Call resolve Slide Theme or slide theme.")
    }

    @MainActor
    func testFirstParagraphIsReadBeforeLuna() {
        let (head, tail) = ReadingPieces.splitFirstParagraph(terminalText)
        XCTAssertTrue(head.hasPrefix("⏺ The theme refactor"), head)
        XCTAssertTrue(head.hasSuffix("Here's the walkthrough first."), head)
        XCTAssertTrue(tail.hasPrefix("1. One rule"), tail)
    }

    @MainActor
    func testCodeFirstGoesStraightToLuna() {
        let (head, tail) = ReadingPieces.splitFirstParagraph("const a = 1;\nlet b = 2;\n\nSome text.")
        XCTAssertEqual(head, "")
        XCTAssertTrue(tail.hasPrefix("const a"))
    }
}
