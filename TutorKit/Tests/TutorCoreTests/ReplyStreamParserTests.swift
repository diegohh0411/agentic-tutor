import Testing
@testable import TutorCore

@Test func splitsSpeechAndActions() {
    var p = ReplyStreamParser(minPhraseCharacters: 1)
    let out = p.feed("Look at this. <show>3/4 + 1/4</show> What do you get?") + p.finish()
    #expect(out == [.speech("Look at this."), .action(.show("3/4 + 1/4")), .speech("What do you get?")])
}

@Test func tagSplitAcrossChunks() {
    var p = ReplyStreamParser(minPhraseCharacters: 1)
    let out = ["Try <sh", "ow>x²", "</sho", "w> now."].flatMap { p.feed($0) } + p.finish()
    #expect(out == [.speech("Try"), .action(.show("x²")), .speech("now.")])
}

@Test func dropsThinkBlocks() {
    var p = ReplyStreamParser(minPhraseCharacters: 1)
    let out = p.feed("<think>secret</think>Hello there.") + p.finish()
    #expect(out == [.speech("Hello there.")])
}

@Test func waitsForMinimumPhraseLength() {
    var p = ReplyStreamParser(minPhraseCharacters: 24)
    #expect(p.feed("Yes. ") == [])
    #expect(p.feed("Now multiply both sides by two.") == [.speech("Yes. Now multiply both sides by two.")])
}
