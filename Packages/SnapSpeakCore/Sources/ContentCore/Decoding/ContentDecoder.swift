import Foundation

public enum ContentDecoder {
    private struct SchemaPeek: Decodable {
        var schemaVersion: Int
    }

    public static func decodeCourse(from data: Data) throws -> CourseV1 {
        let peekDecoder = JSONDecoder()
        let peek: SchemaPeek
        do {
            peek = try peekDecoder.decode(SchemaPeek.self, from: data)
        } catch {
            throw error
        }
        guard KnownContentSchemaVersions.contains(peek.schemaVersion) else {
            throw ContentDecodingError.unknownSchemaVersion(
                found: peek.schemaVersion,
                known: KnownContentSchemaVersions
            )
        }
        switch peek.schemaVersion {
        case 1:
            return try ContentDecoderV1.decode(data)
        default:
            throw ContentDecodingError.unknownSchemaVersion(
                found: peek.schemaVersion,
                known: KnownContentSchemaVersions
            )
        }
    }
}
