import Foundation

public struct RlamusTask: Decodable, Equatable, Sendable {
    public var id: UUID
    public var url: URL
    public var state: RlamusTaskState

    public init(id: UUID, url: URL, state: RlamusTaskState = .`init`) {
        self.id = id
        self.url = url
        self.state = state
    }
}

public enum RlamusTaskState: Equatable, Sendable {
    case `init`
    case scraping
    case summarizing(title: String?)
    case embedding(title: String?, summary: String)
    case done(title: String?, summary: String, embedding: [Float32], embeddingModel: String)
    case failed(reason: String)
}

extension RlamusTaskState: Decodable {
    enum CodingKeys: CodingKey {
        case `init`
        case scraping
        case summarizing
        case embedding
        case done
        case failed
    }

    enum SummarizingCodingKeys: CodingKey {
        case title
    }

    enum EmbeddingCodingKeys: CodingKey {
        case title
        case summary
    }

    enum DoneCodingKeys: CodingKey {
        case title
        case summary
        case embedding
        case embedding_model
    }

    public init(from decoder: any Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            var allKeys = ArraySlice(container.allKeys)
            guard let onlyKey = allKeys.popFirst(), allKeys.isEmpty else {
                throw DecodingError.typeMismatch(RlamusTaskState.self, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Invalid number of keys found, expected one.", underlyingError: nil))
            }
            switch onlyKey {
            case .`init`:
                self = RlamusTaskState.`init`
            case .scraping:
                self = RlamusTaskState.scraping
            case .summarizing:
                let nested = try container.nestedContainer(keyedBy: SummarizingCodingKeys.self, forKey: CodingKeys.summarizing)
                self = RlamusTaskState.summarizing(title: try? nested.decode(Optional<String>.self, forKey: .title))
            case .embedding:
                let nested = try container.nestedContainer(keyedBy: EmbeddingCodingKeys.self, forKey: CodingKeys.embedding)
                self = RlamusTaskState.embedding(
                    title: try? nested.decode(Optional<String>.self, forKey: EmbeddingCodingKeys.title),
                    summary: try nested.decode(String.self, forKey: EmbeddingCodingKeys.summary)
                )
            case .done:
                let nested = try container.nestedContainer(keyedBy: DoneCodingKeys.self, forKey: CodingKeys.done)
                self = RlamusTaskState.done(
                    title: try? nested.decode(Optional<String>.self, forKey: DoneCodingKeys.title),
                    summary: try nested.decode(String.self, forKey: DoneCodingKeys.summary),
                    embedding: try nested.decode(Array<Float32>.self, forKey: DoneCodingKeys.embedding),
                    embeddingModel: try nested.decode(String.self, forKey: DoneCodingKeys.embedding_model)
                )
            case .failed:
                self = RlamusTaskState.failed(reason: try container.decode(String.self, forKey: CodingKeys.failed))
            }
        } else {
            let state = try decoder.singleValueContainer()
            switch try state.decode(String.self) {
            case "init":
                self = RlamusTaskState.`init`
            case "scraping":
                self = RlamusTaskState.scraping
            default:
                throw DecodingError.dataCorruptedError(in: state, debugDescription: "Known state, expected \"init\", \"scraping\" or \"summarizing\"")
            }
        }
    }
}

public extension RlamusTask {
    var summary: String? {
        switch state {
        case let .embedding(_, summary):
            summary
        case let .done(_, summary, _, _):
            summary
        default:
            nil
        }
    }

    var title: String? {
        switch state {
        case let .summarizing(title):
            title
        case let .embedding(title, _):
            title
        case let .done(title, _, _, _):
            title
        default:
            nil
        }
    }
}
