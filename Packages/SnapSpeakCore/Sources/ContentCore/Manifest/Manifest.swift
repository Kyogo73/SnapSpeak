import Foundation
import LanguageKit

public struct Manifest: Codable, Sendable, Equatable {
    public var manifestSchemaVersion: Int
    public var generatedAt: Date
    public var courses: [ManifestCourse]

    public init(manifestSchemaVersion: Int, generatedAt: Date, courses: [ManifestCourse]) {
        self.manifestSchemaVersion = manifestSchemaVersion
        self.generatedAt = generatedAt
        self.courses = courses
    }

    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func decode(from data: Data) throws -> Manifest {
        let manifest = try decoder().decode(Manifest.self, from: data)
        guard KnownManifestSchemaVersions.contains(manifest.manifestSchemaVersion) else {
            throw ContentDecodingError.unknownSchemaVersion(
                found: manifest.manifestSchemaVersion,
                known: KnownManifestSchemaVersions
            )
        }
        return manifest
    }
}

public struct ManifestCourse: Codable, Sendable, Equatable {
    public var id: String
    public var languagePair: LanguagePair
    public var releases: [CourseRelease]

    public init(id: String, languagePair: LanguagePair, releases: [CourseRelease]) {
        self.id = id
        self.languagePair = languagePair
        self.releases = releases
    }
}

public struct CourseRelease: Codable, Sendable, Equatable {
    public var releaseId: String
    public var revision: Int
    public var schemaVersion: Int
    public var minAppVersion: AppVersion
    public var maxAppVersion: AppVersion?
    public var contentUrl: String
    public var bytes: Int
    public var checksumSha256: String
    public var inheritSRS: Bool

    public init(
        releaseId: String,
        revision: Int,
        schemaVersion: Int,
        minAppVersion: AppVersion,
        maxAppVersion: AppVersion?,
        contentUrl: String,
        bytes: Int,
        checksumSha256: String,
        inheritSRS: Bool
    ) {
        self.releaseId = releaseId
        self.revision = revision
        self.schemaVersion = schemaVersion
        self.minAppVersion = minAppVersion
        self.maxAppVersion = maxAppVersion
        self.contentUrl = contentUrl
        self.bytes = bytes
        self.checksumSha256 = checksumSha256
        self.inheritSRS = inheritSRS
    }
}
