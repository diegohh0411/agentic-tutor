import Foundation
import HuggingFace
import MLXLMCommon
import Tokenizers

/// Resolves MLX model snapshots from the Hugging Face cache.
///
/// With `localFilesOnly` set, the snapshot is resolved from the on-disk cache and the
/// network is never contacted. Without it, `HubClient` lists the remote repository
/// first (a "main" revision cannot be matched against the cache without that call)
/// and downloads whatever is missing.
struct HubModelDownloader: MLXLMCommon.Downloader {
    let localFilesOnly: Bool
    private let client = HubClient()

    init(localFilesOnly: Bool) {
        self.localFilesOnly = localFilesOnly
    }

    func download(
        id: String,
        revision: String?,
        matching patterns: [String],
        useLatest: Bool,
        progressHandler: @Sendable @escaping (Progress) -> Void
    ) async throws -> URL {
        guard let repo = Repo.ID(rawValue: id) else {
            throw HubModelSourceError.invalidRepositoryID(id)
        }
        return try await client.downloadSnapshot(
            of: repo,
            revision: revision ?? "main",
            matching: patterns,
            localFilesOnly: localFilesOnly,
            progressHandler: { @MainActor progress in progressHandler(progress) }
        )
    }
}

/// Loads swift-transformers tokenizers behind MLXLMCommon's tokenizer protocol.
struct HubTokenizerLoader: MLXLMCommon.TokenizerLoader {
    func load(from directory: URL) async throws -> any MLXLMCommon.Tokenizer {
        let upstream = try await AutoTokenizer.from(modelFolder: directory)
        return TokenizerBridge(upstream)
    }
}

private struct TokenizerBridge: MLXLMCommon.Tokenizer {
    private let upstream: any Tokenizers.Tokenizer

    init(_ upstream: any Tokenizers.Tokenizer) {
        self.upstream = upstream
    }

    func encode(text: String, addSpecialTokens: Bool) -> [Int] {
        upstream.encode(text: text, addSpecialTokens: addSpecialTokens)
    }

    func decode(tokenIds: [Int], skipSpecialTokens: Bool) -> String {
        upstream.decode(tokens: tokenIds, skipSpecialTokens: skipSpecialTokens)
    }

    func convertTokenToId(_ token: String) -> Int? {
        upstream.convertTokenToId(token)
    }

    func convertIdToToken(_ id: Int) -> String? {
        upstream.convertIdToToken(id)
    }

    var bosToken: String? { upstream.bosToken }
    var eosToken: String? { upstream.eosToken }
    var unknownToken: String? { upstream.unknownToken }

    func applyChatTemplate(
        messages: [[String: any Sendable]],
        tools: [[String: any Sendable]]?,
        additionalContext: [String: any Sendable]?
    ) throws -> [Int] {
        do {
            return try upstream.applyChatTemplate(
                messages: messages, tools: tools, additionalContext: additionalContext)
        } catch Tokenizers.TokenizerError.missingChatTemplate {
            throw MLXLMCommon.TokenizerError.missingChatTemplate
        }
    }
}

enum HubModelSourceError: LocalizedError {
    case invalidRepositoryID(String)

    var errorDescription: String? {
        switch self {
        case .invalidRepositoryID(let id):
            "Invalid Hugging Face repository ID '\(id)'. Expected 'namespace/name'."
        }
    }
}
