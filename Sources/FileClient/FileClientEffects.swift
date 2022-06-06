import ClientModels
import Combine
import ComposableArchitecture

extension FileClient {
  public func loadSavedGames() async throws -> SavedGamesState {
    try await self.load(SavedGamesState.self, from: savedGamesFileName)
  }

  public func saveGames(_ games: SavedGamesState) async throws {
    try await self.save(games, to: savedGamesFileName)
  }
}

public let savedGamesFileName = "saved-games"
