import Testing
@testable import TutorCore

@Test func spanishPromptUsesMexicanConventions() {
    let prompt = TutorPrompt.system(for: .spanish)
    #expect(prompt.contains("<show>") && prompt.contains("punto") && prompt.contains("por"))
}

@Test func promptsDemandShortSpokenTurns() {
    for language in TutorLanguage.allCases {
        #expect(TutorPrompt.system(for: language).contains("<show>"))
    }
    #expect(!TutorPrompt.system(for: .english).localizedCaseInsensitiveContains("child"))
}
