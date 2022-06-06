import ComposableArchitecture

public struct AudioPlayerClient {
  public var load: @Sendable ([Sound]) async -> Void
  public var loop: @Sendable (Sound) async -> Void
  public var play: @Sendable (Sound) async -> Void
  public var secondaryAudioShouldBeSilencedHint: () -> Bool
  public var setGlobalVolumeForMusic: (Float) -> Effect<Never, Never>
  public var setGlobalVolumeForSoundEffects: (Float) -> Effect<Never, Never>
  public var setVolume: (Sound, Float) -> Effect<Never, Never>
  public var stop: (Sound) -> Effect<Never, Never>

  public struct Sound: Hashable {
    public let category: Category
    public let name: String

    public init(category: Category, name: String) {
      self.category = category
      self.name = name
    }

    public enum Category: Hashable {
      case music
      case soundEffect
    }
  }

  public func filteredSounds(doNotInclude doNotIncludeSounds: [AudioPlayerClient.Sound]) -> Self {
    var client = self
    client.play = { sound in
      guard doNotIncludeSounds.contains(sound)
      else { return await self.play(sound) }
    }
    return client
  }
}

extension AudioPlayerClient {
  public static let noop = Self(
    load: { _ in },
    loop: { _ in },
    play: { _ in },
    secondaryAudioShouldBeSilencedHint: { false },
    setGlobalVolumeForMusic: { _ in .none },
    setGlobalVolumeForSoundEffects: { _ in .none },
    setVolume: { _, _ in .none },
    stop: { _ in .none }
  )
}

#if DEBUG
  import XCTestDynamicOverlay

  extension AudioPlayerClient {
    public static let failing = Self(
      load: { _ in XCTFail("\(Self.self).load is unimplemented") },
      loop: { _ in XCTFail("\(Self.self).loop is unimplemented") },
      play: { _ in XCTFail("\(Self.self).play is unimplemented") },
      secondaryAudioShouldBeSilencedHint: {
        XCTFail("\(Self.self).secondaryAudioShouldBeSilencedHint is unimplemented")
        return false
      },
      setGlobalVolumeForMusic: { _ in
        .failing("\(Self.self).setGlobalVolumeForMusic is unimplemented")
      },
      setGlobalVolumeForSoundEffects: { _ in
        .failing("\(Self.self).setGlobalVolumeForSoundEffects is unimplemented")
      },
      setVolume: { _, _ in .failing("\(Self.self).setVolume is unimplemented") },
      stop: { _ in .failing("\(Self.self).stop is unimplemented") }
    )
  }
#endif
