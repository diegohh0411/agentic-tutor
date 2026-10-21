import Testing
@testable import TutorCore

@Test func detectsSpanish() { #expect(LanguagePolicy.replyLanguage(for: "¿cuánto es siete por ocho, maestro?", setting: .english) == .spanish) }
@Test func detectsEnglish() { #expect(LanguagePolicy.replyLanguage(for: "what is seven times eight please", setting: .spanish) == .english) }
@Test func shortUtteranceFallsBackToSetting() {
    #expect(LanguagePolicy.replyLanguage(for: "sí", setting: .english) == .english)
    #expect(LanguagePolicy.replyLanguage(for: "5", setting: .spanish) == .spanish)
}
@Test func mixedTurnFallsBackToSetting() { #expect(LanguagePolicy.replyLanguage(for: "is it tres cuartos or not", setting: .spanish) == .spanish) }
@Test func mixedTurnVariantsFallBackToSetting() {
    #expect(LanguagePolicy.replyLanguage(for: "can you help me with las fracciones please", setting: .english) == .english)
    #expect(LanguagePolicy.replyLanguage(for: "what is the área of this triangle", setting: .english) == .english)
    #expect(LanguagePolicy.replyLanguage(for: "so the answer is cinco right", setting: .spanish) == .spanish)
}
@Test func pureSpanishLongTurnIsSpanish() {
    #expect(LanguagePolicy.replyLanguage(for: "la maestra dijo que tres cuartos es más que un medio", setting: .english) == .spanish)
}
