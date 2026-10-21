import Testing
@testable import TutorCore

@Test(arguments: [
    ("3/4 of the pizza", TutorLanguage.english, "three quarters of the pizza"),
    ("1/2", .english, "one half"),
    ("3/4", .spanish, "tres cuartos"),
    ("5/12", .spanish, "5 sobre 12"),
    ("x² + 1 = 10", .english, "x squared plus 1 equals 10"),
    ("x^3", .spanish, "x al cubo"),
    ("3.5 × 2", .spanish, "3 punto 5 por 2"),
    ("8 ÷ 2 - 1", .english, "8 divided by 2 minus 1"),
    ("50%", .spanish, "50 por ciento"),
    ("√9", .english, "the square root of 9"),
    ("Great job!", .english, "Great job!"),
])
func speakable(_ input: String, _ lang: TutorLanguage, _ expected: String) {
    #expect(SpokenMath.speakable(input, language: lang) == expected)
}
