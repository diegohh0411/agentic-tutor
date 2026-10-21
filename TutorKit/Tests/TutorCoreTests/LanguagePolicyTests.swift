import Testing
@testable import TutorCore

@Test func detectsSpanish() { #expect(LanguagePolicy.replyLanguage(for: "¿cuánto es siete por ocho, maestro?", setting: .english) == .spanish) }
@Test func detectsEnglish() { #expect(LanguagePolicy.replyLanguage(for: "what is seven times eight please", setting: .spanish) == .english) }
@Test func shortUtteranceFallsBackToSetting() {
    #expect(LanguagePolicy.replyLanguage(for: "sí", setting: .english) == .english)
    #expect(LanguagePolicy.replyLanguage(for: "5", setting: .spanish) == .spanish)
}
@Test func mixedTurnFallsBackToSetting() { #expect(LanguagePolicy.replyLanguage(for: "is it tres cuartos or not", setting: .spanish) == .spanish) }
