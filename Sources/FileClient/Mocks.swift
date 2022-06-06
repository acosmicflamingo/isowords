import ComposableArchitecture
import Foundation
import XCTestDebugSupport
import XCTestDynamicOverlay

extension FileClient {
  public static let noop = Self(
    delete: { _ in .none },
    load: { _ in .init() },
    save: { _, _ in .none }
  )

  #if DEBUG
    public static let failing = Self(
      delete: { .failing("\(Self.self).delete(\($0)) is unimplemented") },
      load: {
        XCTFail("\(Self.self).load(\($0)) is unimplemented")
        return .init()
      },
      save: { file, _ in .failing("\(Self.self).save(\(file)) is unimplemented") }
    )
  #endif

  public mutating func override<A>(
    load file: String, _ data: Effect<A, Error>
  )
  where A: Encodable {
    let fulfill = expectation(description: "FileClient.load(\(file))")
    self.load = { [self] in
      if $0 == file {
        fulfill()
        return try JSONEncoder().encode($0)
      } else {
        return try await self.load($0)
      }
    }
  }
}
