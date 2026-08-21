import Foundation

public enum DelayGranularity: String, Codable, Sendable, Equatable {
    case word
    case sentenceApproximate
    case unavailable
}

public struct AudioRouteSnapshot: Codable, Sendable, Equatable {
    public var inputPortName: String
    public var outputPortName: String
    public var isHFP: Bool
    public var voiceProcessingEnabled: Bool

    public init(
        inputPortName: String,
        outputPortName: String,
        isHFP: Bool,
        voiceProcessingEnabled: Bool
    ) {
        self.inputPortName = inputPortName
        self.outputPortName = outputPortName
        self.isHFP = isHFP
        self.voiceProcessingEnabled = voiceProcessingEnabled
    }
}

public struct ShadowingScore: Codable, Sendable, Equatable {
    public var payloadSchemaVersion: Int
    public var scriptMatchRate: Double
    public var precision: Double
    public var recall: Double
    public var omissions: [AlignedSpan]
    public var hesitations: Int
    public var substitutions: Int
    public var wpm: Double
    public var delayMsMedian: Int?
    public var delayGranularity: DelayGranularity
    public var asrOnDevice: Bool
    public var meanConfidence: Double?
    public var minConfidence: Double?
    public var audioRoute: AudioRouteSnapshot
    public var playbackRate: Float
    public var simultaneousPlayAndRecord: Bool

    public init(
        payloadSchemaVersion: Int = 1,
        scriptMatchRate: Double,
        precision: Double,
        recall: Double,
        omissions: [AlignedSpan],
        hesitations: Int,
        substitutions: Int,
        wpm: Double,
        delayMsMedian: Int?,
        delayGranularity: DelayGranularity,
        asrOnDevice: Bool = true,
        meanConfidence: Double?,
        minConfidence: Double?,
        audioRoute: AudioRouteSnapshot,
        playbackRate: Float,
        simultaneousPlayAndRecord: Bool
    ) {
        self.payloadSchemaVersion = payloadSchemaVersion
        self.scriptMatchRate = scriptMatchRate
        self.precision = precision
        self.recall = recall
        self.omissions = omissions
        self.hesitations = hesitations
        self.substitutions = substitutions
        self.wpm = wpm
        self.delayMsMedian = delayMsMedian
        self.delayGranularity = delayGranularity
        self.asrOnDevice = true
        self.meanConfidence = meanConfidence
        self.minConfidence = minConfidence
        self.audioRoute = audioRoute
        self.playbackRate = playbackRate
        self.simultaneousPlayAndRecord = simultaneousPlayAndRecord
        _ = asrOnDevice
    }
}
