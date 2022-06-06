import Combine
import CombineHelpers
import ComposableArchitecture
import Foundation

public struct FileClient {
  public var delete: (String) -> Effect<Never, Error>
  public var load: (String) async throws -> Data
  public var save: (String, Data) -> Effect<Never, Error>

  public func load<A: Decodable>(_ type: A.Type, from fileName: String) async throws -> A {
    try await JSONDecoder().decode(A.self, from: self.load(fileName))
  }

  public func save<A: Encodable>(
    _ data: A, to fileName: String, on queue: AnySchedulerOf<DispatchQueue>
  ) -> Effect<Never, Never> {
    Just(data)
      .subscribe(on: queue)
      .encode(encoder: JSONEncoder())
      .flatMap { data in self.save(fileName, data) }
      .ignoreFailure()
      .eraseToEffect()
  }
}
