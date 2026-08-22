import Foundation

/// 設定の読み書き。失敗注入用の最小シーム（実装の差し替えはしない）。
public protocol SettingsStoring: Sendable {
    func loadOrCreateSettings() async throws -> UserSettingsDTO
    func saveSettings(_ dto: UserSettingsDTO) async throws -> UserSettingsDTO
}

extension PersistenceActor: SettingsStoring {}
