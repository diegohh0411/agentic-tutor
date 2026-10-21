import Testing
@testable import TutorCore

@Test func localesAndCodes() {
    #expect(TutorLanguage.english.rawValue == "en")
    #expect(TutorLanguage.spanish.asrLocale == "es-US")
    #expect(TutorLanguage.english.asrLocale == "en-US")
}
