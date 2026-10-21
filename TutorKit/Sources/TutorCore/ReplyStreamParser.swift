import Foundation

public enum ReplyPiece: Sendable, Equatable {
    case speech(String)
    case action(TutorAction)
}

public struct ReplyStreamParser {
    private enum State {
        case text
        case inShow
        case inThink
    }

    private let minPhraseCharacters: Int
    private var state: State = .text
    private var speechBuffer = ""
    private var tagContentBuffer = ""
    private var pendingTagBuffer = ""

    public init(minPhraseCharacters: Int = 24) {
        self.minPhraseCharacters = minPhraseCharacters
    }

    public mutating func feed(_ chunk: String) -> [ReplyPiece] {
        var pieces: [ReplyPiece] = []
        for character in chunk {
            if !pendingTagBuffer.isEmpty || character == "<" {
                pendingTagBuffer.append(character)
                consumePendingTag(into: &pieces)
            } else {
                consumeContent(character, into: &pieces)
            }
        }
        return pieces
    }

    public mutating func finish() -> [ReplyPiece] {
        var pieces: [ReplyPiece] = []
        if !pendingTagBuffer.isEmpty {
            appendPendingTagAsContent(into: &pieces)
        }

        switch state {
        case .text:
            emitSpeech(into: &pieces)
        case .inShow:
            emitShowAction(into: &pieces)
        case .inThink:
            break
        }

        state = .text
        speechBuffer = ""
        tagContentBuffer = ""
        return pieces
    }

    private mutating func consumePendingTag(into pieces: inout [ReplyPiece]) {
        let tags = ["<show>", "</show>", "<think>", "</think>"]
        guard tags.contains(where: { $0.hasPrefix(pendingTagBuffer) }) else {
            appendPendingTagAsContent(into: &pieces)
            return
        }
        guard tags.contains(pendingTagBuffer) else { return }

        let tag = pendingTagBuffer
        pendingTagBuffer = ""
        switch tag {
        case "<show>":
            if state == .text { emitSpeech(into: &pieces) }
            state = .inShow
            tagContentBuffer = ""
        case "</show>" where state == .inShow:
            emitShowAction(into: &pieces)
            state = .text
        case "<think>":
            state = .inThink
            tagContentBuffer = ""
        case "</think>" where state == .inThink:
            state = .text
            tagContentBuffer = ""
        default:
            appendStringAsContent(tag, into: &pieces)
        }
    }

    private mutating func appendPendingTagAsContent(into pieces: inout [ReplyPiece]) {
        let text = pendingTagBuffer
        pendingTagBuffer = ""
        appendStringAsContent(text, into: &pieces)
    }

    private mutating func appendStringAsContent(_ text: String, into pieces: inout [ReplyPiece]) {
        for character in text {
            consumeContent(character, into: &pieces)
        }
    }

    private mutating func consumeContent(_ character: Character, into pieces: inout [ReplyPiece]) {
        switch state {
        case .text:
            speechBuffer.append(character)
            if isPhraseBoundary(character), speechBuffer.count >= minPhraseCharacters {
                emitSpeech(into: &pieces)
            }
        case .inShow:
            tagContentBuffer.append(character)
        case .inThink:
            break
        }
    }

    private func isPhraseBoundary(_ character: Character) -> Bool {
        ".?!;:".contains(character) || character.isNewline
    }

    private mutating func emitSpeech(into pieces: inout [ReplyPiece]) {
        let speech = collapsedWhitespace(speechBuffer)
        speechBuffer = ""
        if !speech.isEmpty {
            pieces.append(.speech(speech))
        }
    }

    private mutating func emitShowAction(into pieces: inout [ReplyPiece]) {
        let expression = collapsedWhitespace(tagContentBuffer)
        tagContentBuffer = ""
        if !expression.isEmpty {
            pieces.append(.action(.show(expression)))
        }
    }

    private func collapsedWhitespace(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}
