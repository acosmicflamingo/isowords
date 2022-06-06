import ComposableArchitecture
import FileClient

extension FileClient {
  public func loadUserSettings() async throws -> UserSettings {
    try await self.load(UserSettings.self, from: userSettingsFileName)
  }

  public func saveUserSettings(_ userSettings: UserSettings) async throws {
    try await self.save(userSettings, to: userSettingsFileName)
  }
}

public let userSettingsFileName = "user-settings"
