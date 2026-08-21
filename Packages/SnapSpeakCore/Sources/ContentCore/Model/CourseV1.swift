import Foundation
import LanguageKit

public enum ItemKind: String, Codable, Sendable, Equatable {
    case shadowing
    case composition
}

public enum LessonMode: String, Codable, Sendable, Equatable {
    case shadowing
    case composition
}

public struct AudioRef: Codable, Sendable, Equatable {
    public var relativePath: String
    public var durationMs: Int
    public var checksumSha256: String

    public init(relativePath: String, durationMs: Int, checksumSha256: String) {
        self.relativePath = relativePath
        self.durationMs = durationMs
        self.checksumSha256 = checksumSha256
    }
}

public struct CaptionSegment: Codable, Sendable, Equatable {
    public var startMs: Int
    public var endMs: Int
    public var text: String

    public init(startMs: Int, endMs: Int, text: String) {
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
    }
}

public struct WordTiming: Codable, Sendable, Equatable {
    public var startMs: Int
    public var endMs: Int
    public var text: String

    public init(startMs: Int, endMs: Int, text: String) {
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
    }
}

public struct PassageV1: Codable, Sendable, Equatable {
    public var text: String
    public var captionSegments: [CaptionSegment]
    public var wordTimings: [WordTiming]?

    public init(text: String, captionSegments: [CaptionSegment], wordTimings: [WordTiming]? = nil) {
        self.text = text
        self.captionSegments = captionSegments
        self.wordTimings = wordTimings
    }
}

public struct SentencePairV1: Codable, Sendable, Equatable {
    public var l1: String
    public var acceptable: [String]

    public init(l1: String, acceptable: [String]) {
        self.l1 = l1
        self.acceptable = acceptable
    }
}

public struct ItemV1: Codable, Sendable, Equatable {
    public var id: String
    public var kind: ItemKind
    public var audio: AudioRef?
    public var passage: PassageV1?
    public var sentencePair: SentencePairV1?

    public init(
        id: String,
        kind: ItemKind,
        audio: AudioRef? = nil,
        passage: PassageV1? = nil,
        sentencePair: SentencePairV1? = nil
    ) throws {
        self.id = id
        self.kind = kind
        self.audio = audio
        self.passage = passage
        self.sentencePair = sentencePair
        try Self.validateOneOf(id: id, kind: kind, passage: passage, sentencePair: sentencePair)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        kind = try container.decode(ItemKind.self, forKey: .kind)
        audio = try container.decodeIfPresent(AudioRef.self, forKey: .audio)
        passage = try container.decodeIfPresent(PassageV1.self, forKey: .passage)
        sentencePair = try container.decodeIfPresent(SentencePairV1.self, forKey: .sentencePair)
        do {
            try Self.validateOneOf(id: id, kind: kind, passage: passage, sentencePair: sentencePair)
        } catch let error as ContentDecodingError {
            throw error
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, audio, passage, sentencePair
    }

    private static func validateOneOf(
        id: String,
        kind: ItemKind,
        passage: PassageV1?,
        sentencePair: SentencePairV1?
    ) throws {
        let hasPassage = passage != nil
        let hasPair = sentencePair != nil
        switch kind {
        case .shadowing:
            if !hasPassage || hasPair {
                throw ContentDecodingError.oneOfViolation(
                    itemId: id,
                    reason: "shadowing requires passage and forbids sentencePair"
                )
            }
        case .composition:
            if !hasPair || hasPassage {
                throw ContentDecodingError.oneOfViolation(
                    itemId: id,
                    reason: "composition requires sentencePair and forbids passage"
                )
            }
        }
        if hasPassage && hasPair {
            throw ContentDecodingError.oneOfViolation(itemId: id, reason: "both passage and sentencePair present")
        }
        if !hasPassage && !hasPair {
            throw ContentDecodingError.oneOfViolation(itemId: id, reason: "neither passage nor sentencePair present")
        }
    }
}

public struct LessonV1: Codable, Sendable, Equatable {
    public var id: String
    public var mode: LessonMode
    public var items: [ItemV1]

    public init(id: String, mode: LessonMode, items: [ItemV1]) {
        self.id = id
        self.mode = mode
        self.items = items
    }
}

public struct UnitV1: Codable, Sendable, Equatable {
    public var id: String
    public var title: [String: String]
    public var lessons: [LessonV1]

    public init(id: String, title: [String: String], lessons: [LessonV1]) {
        self.id = id
        self.title = title
        self.lessons = lessons
    }
}

public struct CourseV1: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var id: String
    public var languagePair: LanguagePair
    public var title: [String: String]
    public var units: [UnitV1]

    public init(
        schemaVersion: Int,
        id: String,
        languagePair: LanguagePair,
        title: [String: String],
        units: [UnitV1]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.languagePair = languagePair
        self.title = title
        self.units = units
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        id = try container.decode(String.self, forKey: .id)
        guard container.contains(.languagePair) else {
            throw ContentDecodingError.missingLanguagePair
        }
        languagePair = try Self.decodeNormalizedPair(from: container)
        title = try container.decode([String: String].self, forKey: .title)
        units = try container.decode([UnitV1].self, forKey: .units)
    }

    private static func decodeNormalizedPair(
        from container: KeyedDecodingContainer<CodingKeys>
    ) throws -> LanguagePair {
        let pairContainer = try container.nestedContainer(keyedBy: PairKeys.self, forKey: .languagePair)
        let sourceRaw = try pairContainer.decode(String.self, forKey: .sourceLanguage)
        let targetRaw = try pairContainer.decode(String.self, forKey: .targetLanguage)
        let source = try parseNormalized(sourceRaw)
        let target = try parseNormalized(targetRaw)
        return LanguagePair(sourceLanguage: source, targetLanguage: target)
    }

    private static func parseNormalized(_ tag: String) throws -> BCP47Language {
        let language: BCP47Language
        do {
            language = try BCP47Language(tag)
        } catch {
            throw ContentDecodingError.invalidLanguageTag(tag)
        }
        guard language.raw == tag else {
            throw ContentDecodingError.languageTagNotNormalized(tag)
        }
        return language
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, id, languagePair, title, units
    }

    private enum PairKeys: String, CodingKey {
        case sourceLanguage
        case targetLanguage
    }
}

public typealias Course = CourseV1
