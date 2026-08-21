import Foundation
import LanguageKit

public struct HesitationReport: Sendable, Equatable {
    public var hesitations: Int
    public var omissions: [AlignedSpan]
    public var substitutions: Int

    public init(hesitations: Int, omissions: [AlignedSpan], substitutions: Int) {
        self.hesitations = hesitations
        self.omissions = omissions
        self.substitutions = substitutions
    }
}

public enum HesitationDetector: Sendable {
    public static func detect(
        ops: [AlignmentOp],
        hypothesis: [String],
        language: BCP47Language,
        lexicon: FillerLexicon = FillerLexicon()
    ) -> HesitationReport {
        var hesitations = 0
        var substitutions = 0
        var omissions: [AlignedSpan] = []
        var deletionRunStart: Int?
        var deletionRunEnd: Int?

        func flushDeletions() {
            if let start = deletionRunStart, let end = deletionRunEnd {
                omissions.append(AlignedSpan(startRefIndex: start, endRefIndex: end + 1))
            }
            deletionRunStart = nil
            deletionRunEnd = nil
        }

        for op in ops {
            switch op {
            case .equal:
                flushDeletions()
            case .substitution:
                flushDeletions()
                substitutions += 1
            case .deletion(let ref):
                if let start = deletionRunStart {
                    deletionRunStart = start
                    deletionRunEnd = ref
                } else {
                    deletionRunStart = ref
                    deletionRunEnd = ref
                }
            case .insertion(let hyp):
                flushDeletions()
                let token = hypothesis[hyp]
                let repeatsNeighbor =
                    (hyp > 0 && hypothesis[hyp - 1] == token)
                    || (hyp + 1 < hypothesis.count && hypothesis[hyp + 1] == token)
                if lexicon.isFiller(token, language: language) || repeatsNeighbor {
                    hesitations += 1
                }
            }
        }
        flushDeletions()
        return HesitationReport(hesitations: hesitations, omissions: omissions, substitutions: substitutions)
    }
}
