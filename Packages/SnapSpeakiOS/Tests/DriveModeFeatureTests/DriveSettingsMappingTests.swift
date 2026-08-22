import DriveKit
import DriveModeFeature
import Persistence
import Testing

@Suite("DriveSettingsMapping")
struct DriveSettingsMappingTests {
    @Test("保存値から script settings へ写像する")
    func mapsDTOToScriptSettings() {
        var dto = UserSettingsDTO.phase1Default
        dto.driveSessionMinutes = 20
        dto.drivePausePreset = "long"
        dto.driveShadowingRepeats = 3
        let settings = DriveSettingsMapping.scriptSettings(from: dto)
        #expect(settings.sessionLength == .minutes20)
        #expect(settings.pauseMultiplier == 1.3)
        #expect(settings.shadowingRepeats == 3)
        #expect(settings.lengthCode == "20")
    }

    @Test("不明プリセットと 0 分は standard / endless")
    func unknownPresetAndZeroMinutes() {
        var dto = UserSettingsDTO.phase1Default
        dto.driveSessionMinutes = 0
        dto.drivePausePreset = "mystery"
        let settings = DriveSettingsMapping.scriptSettings(from: dto)
        #expect(settings.sessionLength == .endless)
        #expect(settings.pauseMultiplier == 1.0)
        #expect(settings.lengthCode == "endless")
    }

    @Test("applying は長さ・ポーズ・反復を永続フィールドへ書く")
    func applyingWritesFields() async throws {
        let container = try PersistenceActor.makeContainer(inMemory: true)
        let persistence = PersistenceActor(modelContainer: container)
        var dto = try await persistence.loadOrCreateSettings()
        dto = DriveSettingsMapping.applying(
            length: .minutes5,
            pause: .short,
            repeats: 1,
            to: dto
        )
        let saved = try await persistence.saveSettings(dto)
        #expect(saved.driveSessionMinutes == 5)
        #expect(saved.drivePausePreset == "short")
        #expect(saved.driveShadowingRepeats == 1)
        let loaded = try await persistence.loadOrCreateSettings()
        #expect(loaded == saved)
    }
}
