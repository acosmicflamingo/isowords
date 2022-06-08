import AVFoundation

extension AudioPlayerClient {
  public static func live(bundles: [Bundle]) -> Self {
    let actor = AudioActor(bundles: bundles)

    return Self(
      load: { try await actor.load(sounds: $0) },
      loop: { try await actor.play(sound: $0, loop: true) },
      play: { try await actor.play(sound: $0) },
      secondaryAudioShouldBeSilencedHint: {
        AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
      },
      setGlobalVolumeForMusic: { await actor.setMusicVolume(to: $0) },
      setGlobalVolumeForSoundEffects: { await actor.setSoundEffectsVolume(to: $0) },
      setVolume: { try await actor.setVolume(of: $0, to: $1) },
      stop: { try await actor.stop(sound: $0) }
    )
  }

  private actor AudioActor {
    enum Failure: Error {
      case bufferInitializationFailed
      case soundNotLoaded(AudioPlayerClient.Sound)
      case soundsNotLoaded([AudioPlayerClient.Sound: Error])
    }

    enum Player {
      case music(AVAudioPlayer)
      case soundEffect(AVAudioPlayerNode, AVAudioPCMBuffer)
    }

    let audioEngine: AVAudioEngine
    let bundles: [Bundle]
    var players: [Sound: Player] = [:]
    let soundEffectsNode: AVAudioMixerNode

    init(bundles: [Bundle]) {
      let audioEngine = AVAudioEngine()
      let soundEffectsNode = AVAudioMixerNode()
      audioEngine.attach(soundEffectsNode)
      audioEngine.connect(soundEffectsNode, to: audioEngine.mainMixerNode, format: nil)
      self.audioEngine = audioEngine
      self.bundles = bundles
      self.soundEffectsNode = soundEffectsNode
    }

    func load(sounds: [Sound]) throws {
      let sounds = sounds.filter { !players.keys.contains($0) }
      try AVAudioSession.sharedInstance().setCategory(.ambient)
      try AVAudioSession.sharedInstance().setActive(true, options: [])
      var errors: [Sound: Error] = [:]
      for sound in sounds {
        for bundle in self.bundles {
          do {
            guard let url = bundle.url(forResource: sound.name, withExtension: "mp3")
            else { continue }
            switch sound.category {
            case .music:
              self.players[sound] = try .music(AVAudioPlayer(contentsOf: url))
              
            case .soundEffect:
              let file = try AVAudioFile(forReading: url)
              guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
              )
              else { throw Failure.bufferInitializationFailed }
              try file.read(into: buffer)
              let node = AVAudioPlayerNode()
              audioEngine.attach(node)
              audioEngine.connect(node, to: soundEffectsNode, format: nil)
              self.players[sound] = .soundEffect(node, buffer)
            }
          } catch {
            errors[sound] = error
          }
        }
      }
      guard errors.isEmpty else { throw Failure.soundsNotLoaded(errors) }
    }

    func play(sound: Sound, loop: Bool = false) throws {
      guard let player = self.players[sound] else { throw Failure.soundNotLoaded(sound) }

      switch player {
      case let .music(player):
        player.numberOfLoops = loop ? -1 : 0
        player.play(atTime: 0)

      case let .soundEffect(node, buffer):
        if !self.audioEngine.isRunning {
          try audioEngine.start()
        }

        node.stop() // TODO: Is this needed?
        node.scheduleBuffer(
          buffer,
          at: nil,
          options: loop ? .loops : [],
          completionCallbackType: .dataPlayedBack,
          completionHandler: nil
        )
        node.play() // TODO: Is this needed?
      }
    }

    func stop(sound: Sound) throws {
      guard let player = self.players[sound] else { throw Failure.soundNotLoaded(sound) }

      switch player {
      case let .music(player):
        player.setVolume(0, fadeDuration: 2.5)
        Task {
          try await Task.sleep(nanoseconds: 2_500 * NSEC_PER_MSEC)
          player.stop()
        }

      case let .soundEffect(node, _):
        node.stop()
      }
    }

    func setVolume(of sound: Sound, to volume: Float) throws {
      guard let player = self.players[sound] else { throw Failure.soundNotLoaded(sound) }

      switch player {
      case let .music(player):
        player.volume = volume

      case let .soundEffect(node, _):
        node.volume = volume
      }
    }

    func setMusicVolume(to volume: Float) {
      for (sound, _) in self.players where sound.category == .music {
        try? self.setVolume(of: sound, to: volume)
      }
    }

    func setSoundEffectsVolume(to volume: Float) {
      self.soundEffectsNode.volume = 0.25 * volume
    }
  }
}
