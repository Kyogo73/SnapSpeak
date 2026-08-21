import Foundation

public enum ContentDecoderV1 {
    public static func decode(_ data: Data) throws -> CourseV1 {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(CourseV1.self, from: data)
        } catch let error as ContentDecodingError {
            throw error
        } catch let decoding as DecodingError {
            if case .keyNotFound(let key, _) = decoding, key.stringValue == "languagePair" {
                throw ContentDecodingError.missingLanguagePair
            }
            throw decoding
        }
    }
}
