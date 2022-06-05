public struct RemoteNotificationsClient {
  public var isRegistered: @Sendable () async -> Bool
  public var register: @Sendable () async -> Void
  public var unregister: @Sendable () async -> Void
}

extension RemoteNotificationsClient {
  public static let noop = Self(
    isRegistered: { true },
    register: {},
    unregister: {}
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension RemoteNotificationsClient {
    public static let failing = Self(
      isRegistered: {
        XCTFail("\(Self.self).isRegistered is unimplemented")
        return false
      },
      register: { XCTFail("\(Self.self).register is unimplemented") },
      unregister: { XCTFail("\(Self.self).unregister is unimplemented") }
    )
  }
#endif
