import Combine
import CombineHelpers
import ComposableArchitecture
import Foundation

public struct FileClient {
  public var delete: (String) async throws -> Void
  public var load: (String) async throws -> Data
  public var save: (String, Data) async throws -> Void

  public func load<A: Decodable>(_ type: A.Type, from fileName: String) async throws -> A {
    try await JSONDecoder().decode(A.self, from: self.load(fileName))
  }

  public func save<A: Encodable>(_ data: A, to fileName: String) async throws {
    try await self.save(fileName, JSONEncoder().encode(data))
  }
}
