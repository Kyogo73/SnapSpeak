import Foundation
import ContentCore
import Testing

@Test func unknownHighSchemaVersionIsRejected() throws {
    let data = try FixtureLoader.data("course_v2_unknown")
    #expect(throws: ContentDecodingError.self) {
        _ = try ContentDecoder.decodeCourse(from: data)
    }
    do {
        _ = try ContentDecoder.decodeCourse(from: data)
        Issue.record("expected throw")
    } catch let error as ContentDecodingError {
        guard case .unknownSchemaVersion(let found, _) = error else {
            Issue.record("wrong error \(error)")
            return
        }
        #expect(found == 2)
    }
}

@Test func oneOfShadowingWithSentencePairThrows() throws {
    let data = try FixtureLoader.data("course_oneof_violation_shadowing_sentence_pair")
    #expect(throws: ContentDecodingError.self) {
        _ = try ContentDecoder.decodeCourse(from: data)
    }
}

@Test func oneOfCompositionWithPassageThrows() throws {
    let data = try FixtureLoader.data("course_oneof_violation_composition_passage")
    #expect(throws: ContentDecodingError.self) {
        _ = try ContentDecoder.decodeCourse(from: data)
    }
}

@Test func oneOfBothThrows() throws {
    let data = try FixtureLoader.data("course_oneof_violation_both")
    #expect(throws: ContentDecodingError.self) {
        _ = try ContentDecoder.decodeCourse(from: data)
    }
}

@Test func oneOfNeitherThrows() throws {
    let data = try FixtureLoader.data("course_oneof_violation_neither")
    #expect(throws: ContentDecodingError.self) {
        _ = try ContentDecoder.decodeCourse(from: data)
    }
}

@Test func missingLanguagePairThrows() throws {
    let data = try FixtureLoader.data("course_missing_language_pair")
    do {
        _ = try ContentDecoder.decodeCourse(from: data)
        Issue.record("expected throw")
    } catch is ContentDecodingError {
        // ok
    } catch is DecodingError {
        // JSONDecoder may surface keyNotFound if peek succeeds and V1 decode misses the key
    }
}
