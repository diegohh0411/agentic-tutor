/// Model identifiers and voices selected during the offline-model listening gates.
public enum ModelCatalog {
    /// The MLX Qwen model used for local tutoring replies.
    public static let tutorModelId = "mlx-community/Qwen3.5-4B-4bit"

    /// Returns the tutoring model selected for the available physical memory.
    ///
    /// All tiers use the four-billion-parameter model until the later memory
    /// selection gate evaluates a larger model for machines with at least 32 GB.
    public static func tutorModelId(physicalMemory: UInt64) -> String {
        _ = physicalMemory
        return tutorModelId
    }

    /// The English Phonon voice selected by the listening gate.
    public static var phononVoiceEnglish = "NbpkqMVS3CJeq2j8"

    /// The Mexican Spanish Phonon voice selected by the listening gate.
    public static var phononVoiceSpanish = "Sx8m6WdXBG06zwZT"
}
