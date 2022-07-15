import CasePaths
import ComposableArchitecture
import GameOverFeature
import Overture
import SharedModels
import TestHelpers
import XCTest

@testable import LocalDatabaseClient
@testable import UserDefaultsClient

@MainActor
class GameOverFeatureTests: XCTestCase {
  let mainRunLoop = RunLoop.test

  func testSubmitLeaderboardScore() async throws {
    var environment = GameOverEnvironment.failing
    environment.audioPlayer = .noop
    environment.apiClient.currentPlayerAsync = { .init(appleReceipt: .mock, player: .blob) }
    environment.apiClient.override(
      route: .games(
        .submit(
          .init(
            gameContext: .solo(.init(gameMode: .timed, language: .en, puzzle: .mock)),
            moves: [.mock]
          )
        )
      ),
      withResponse: .ok([
        "solo": [
          "ranks": [
            "lastDay": LeaderboardScoreResult.Rank(outOf: 100, rank: 1),
            "lastWeek": .init(outOf: 1000, rank: 10),
            "allTime": .init(outOf: 10000, rank: 100),
          ]
        ]
      ])
    )
    environment.database.playedGamesCountAsync = { _ in 10 }
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettingsAsync = {
      .init(authorizationStatus: .notDetermined)
    }

    let store = TestStore(
      initialState: GameOverState(
        completedGame: .init(
          cubes: .mock,
          gameContext: .solo,
          gameMode: .timed,
          gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
          language: .en,
          moves: [.mock],
          secondsPlayed: 0
        ),
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    await store.send(.onAppear)
    await store.receive(
      .userNotificationSettingsResponse(.init(authorizationStatus: .notDetermined))
    ) {
      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
    }
    await store.receive(.delayedOnAppear) {
      $0.isViewEnabled = true
    }
    await store.receive(
      .submitGameResponse(
        .success(
          .solo(
            .init(ranks: [
              .lastDay: .init(outOf: 100, rank: 1),
              .lastWeek: .init(outOf: 1000, rank: 10),
              .allTime: .init(outOf: 10000, rank: 100),
            ])
          )
        )
      )
    ) {
      $0.summary = .leaderboard([
        .lastDay: .init(outOf: 100, rank: 1),
        .lastWeek: .init(outOf: 1000, rank: 10),
        .allTime: .init(outOf: 10000, rank: 100),
      ])
    }
  }

  func testSubmitDailyChallenge() async throws {
    let dailyChallengeResponses = [
      FetchTodaysDailyChallengeResponse(
        dailyChallenge: .init(
          endsAt: .mock,
          gameMode: .timed,
          id: .init(rawValue: .dailyChallengeId),
          language: .en
        ),
        yourResult: .init(outOf: 42, rank: 1, score: 3600, started: true)
      ),
      FetchTodaysDailyChallengeResponse(
        dailyChallenge: .init(
          endsAt: .mock,
          gameMode: .unlimited,
          id: .init(rawValue: .dailyChallengeId),
          language: .en
        ),
        yourResult: .init(outOf: 42, rank: nil, score: nil)
      ),
    ]

    var environment = GameOverEnvironment.failing
    environment.audioPlayer = .noop
    environment.apiClient.currentPlayerAsync = { .init(appleReceipt: .mock, player: .blob) }
    environment.apiClient.override(
      route: .games(
        .submit(
          .init(
            gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
            moves: [.mock]
          )
        )
      ),
      withResponse: .ok([
        "dailyChallenge": ["rank": 2, "outOf": 100, "score": 1000, "started": true]
      ])
    )
    environment.apiClient.override(
      route: .dailyChallenge(.today(language: .en)),
      withResponse: .ok([
        [
          "dailyChallenge": [
            "endsAt": 1_234_567_890,
            "gameMode": "timed",
            "id": UUID.dailyChallengeId.uuidString,
            "language": "en",
          ],
          "yourResult": ["outOf": 42, "rank": 1, "score": 3600, "started": true],
        ],
        [
          "dailyChallenge": [
            "endsAt": 1_234_567_890,
            "gameMode": "unlimited",
            "id": UUID.dailyChallengeId.uuidString,
            "language": "en",
          ],
          "yourResult": ["outOf": 42, "started": false],
        ],
      ])
    )
    environment.database.playedGamesCountAsync = { _ in 10 }
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettingsAsync = {
      .init(authorizationStatus: .notDetermined)
    }

    let store = TestStore(
      initialState: GameOverState(
        completedGame: .init(
          cubes: .mock,
          gameContext: .dailyChallenge(.init(rawValue: .dailyChallengeId)),
          gameMode: .timed,
          gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
          language: .en,
          moves: [.mock],
          secondsPlayed: 0
        ),
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    await store.send(.onAppear)
    await store.receive(
      .userNotificationSettingsResponse(.init(authorizationStatus: .notDetermined))
    ) {
      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
    }
    await store.receive(.delayedOnAppear) { $0.isViewEnabled = true }
    await store.receive(
      .submitGameResponse(
        .success(
          .dailyChallenge(
            .init(outOf: 100, rank: 2, score: 1000, started: true)
          )
        )
      )
    ) {
      $0.summary = .dailyChallenge(.init(outOf: 100, rank: 2, score: 1000, started: true))
    }
    await store.receive(
      .dailyChallengeResponse(.success(dailyChallengeResponses))
    ) {
      $0.dailyChallenges = dailyChallengeResponses
    }
  }

  func testTurnBased_TrackLeaderboards() async throws {
    var environment = GameOverEnvironment.failing
    environment.audioPlayer = .noop
    environment.apiClient.currentPlayerAsync = { .init(appleReceipt: .mock, player: .blob) }
    environment.apiClient.override(
      route: .games(
        .submit(
          .init(
            gameContext: .turnBased(
              .init(
                gameMode: .unlimited,
                language: .en,
                playerIndexToId: [0: .init(rawValue: .deadbeef)],
                puzzle: .mock
              )
            ),
            moves: [.mock]
          )
        )
      ),
      withResponse: .ok(["turnBased": true])
    )
    environment.database.playedGamesCountAsync = { _ in 10 }
    environment.database.fetchStats = .init(
      value: .init(
        averageWordLength: nil,
        gamesPlayed: 1,
        highestScoringWord: nil,
        longestWord: nil,
        secondsPlayed: 1,
        wordsFound: 1
      )
    )
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.userNotifications.getNotificationSettingsAsync = {
      withUnsafeCurrentTask { $0?.cancel() }
      return .init(authorizationStatus: .notDetermined)
    }

    let store = TestStore(
      initialState: GameOverState(
        completedGame: .init(
          cubes: .mock,
          gameContext: .turnBased(playerIndexToId: [0: .init(rawValue: .deadbeef)]),
          gameMode: .unlimited,
          gameStartTime: .mock,
          language: .en,
          localPlayerIndex: 1,
          moves: [.mock],
          secondsPlayed: 0
        ),
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    await store.send(.onAppear)
    await store.receive(.delayedOnAppear) { $0.isViewEnabled = true }
    await store.receive(.submitGameResponse(.success(.turnBased)))
  }

//  func testRequestReviewOnClose() async {
//    var lastReviewRequestTimeIntervalSet: Double?
//    var requestReviewCount = 0
//
//    let completedGame = CompletedGame(
//      cubes: .mock,
//      gameContext: .solo,
//      gameMode: .unlimited,
//      gameStartTime: .mock,
//      language: .en,
//      localPlayerIndex: nil,
//      moves: [.mock],
//      secondsPlayed: 0
//    )
//
//    var environment = GameOverEnvironment.failing
//    environment.database.fetchStatsAsync = {
//      .init(
//        averageWordLength: nil,
//        gamesPlayed: 1,
//        highestScoringWord: nil,
//        longestWord: nil,
//        secondsPlayed: 1,
//        wordsFound: 1
//      )
//    }
//    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
//    environment.storeKit.requestReviewAsync = {
//      requestReviewCount += 1
//    }
//    environment.userDefaults.override(double: 0, forKey: "last-review-request-timeinterval")
//    environment.userDefaults.setDoubleAsync = { double, key in
//      if key == "last-review-request-timeinterval" {
//        lastReviewRequestTimeIntervalSet = double
//      }
//    }
//    environment.userNotifications.getNotificationSettingsAsync = {
//      .init(authorizationStatus: .notDetermined)
//    }
//
//    let store = TestStore(
//      initialState: GameOverState(completedGame: completedGame, isDemo: false, isViewEnabled: true),
//      reducer: gameOverReducer,
//      environment: environment
//    )
//
//    // Assert that the first time game over appears we do not request review
//    store.send(.closeButtonTapped)
//    await store.receive(.delegate(.close))
//    await self.mainRunLoop.advance()
//    XCTAssertNoDifference(requestReviewCount, 0)
//    XCTAssertNoDifference(lastReviewRequestTimeIntervalSet, nil)
//
//    // Assert that once the player plays enough games then a review request is made
//    store.environment.database.fetchStats = .init(
//      value: .init(
//        averageWordLength: nil,
//        gamesPlayed: 3,
//        highestScoringWord: nil,
//        longestWord: nil,
//        secondsPlayed: 1,
//        wordsFound: 1
//      )
//    )
//    store.send(.closeButtonTapped)
//    await store.receive(.delegate(.close))
//    await self.mainRunLoop.advance()
//    XCTAssertNoDifference(requestReviewCount, 1)
//    XCTAssertNoDifference(lastReviewRequestTimeIntervalSet, 0)
//
//    // Assert that when more than a week of time passes we again request review
//    await self.mainRunLoop.advance(by: .seconds(60 * 60 * 24 * 7))
//    store.send(.closeButtonTapped)
//    await store.receive(.delegate(.close))
//    await self.mainRunLoop.advance()
//    XCTAssertNoDifference(requestReviewCount, 2)
//    XCTAssertNoDifference(lastReviewRequestTimeIntervalSet, 60 * 60 * 24 * 7)
//  }

  func testAutoCloseWhenNoWordsPlayed() async throws {
    let store = TestStore(
      initialState: GameOverState(
        completedGame: .init(
          cubes: .mock,
          gameContext: .solo,
          gameMode: .timed,
          gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
          language: .en,
          moves: [.removeCube],
          secondsPlayed: 0
        ),
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: .failing
    )
//    store.environment.audioPlayer.loopAsync = { _ in }
//    store.environment.audioPlayer.playAsync = { _ in }
//    store.environment.database.playedGamesCountAsync = { _ in try await Task.never() }
    store.environment.mainRunLoop = RunLoop.test.eraseToAnyScheduler()
//    store.environment.userNotifications.getNotificationSettingsAsync = {
//      withUnsafeCurrentTask { $0?.cancel() }
//      return .init(authorizationStatus: .notDetermined)
//    }
//    // TODO: Why is this `@Sendable` necessary?
//    store.environment.apiClient.apiRequestAsync = { @Sendable _ in try await Task.never() }

    let task = await store.send(.onAppear)
    await task.cancel()
    await store.receive(.delegate(.close))
  }

  func testShowUpgradeInterstitial() async throws {
    var environment = GameOverEnvironment.failing
    environment.audioPlayer = .noop
    environment.apiClient.currentPlayerAsync = { .init(appleReceipt: nil, player: .blob) }
    environment.apiClient.override(
      routeCase: /ServerRoute.Api.Route.games .. /ServerRoute.Api.Route.Games.submit,
      withResponse: { _ in .none }
    )
    environment.database.playedGamesCountAsync = { _ in 6 }
    environment.database.fetchStats = .init(value: .init())
    environment.mainRunLoop = self.mainRunLoop.eraseToAnyScheduler()
    environment.serverConfig.config = { .init() }
    environment.userDefaults.override(
      double: self.mainRunLoop.now.date.timeIntervalSince1970,
      forKey: "last-review-request-timeinterval"
    )
    environment.userNotifications.getNotificationSettingsAsync = {
      .init(authorizationStatus: .notDetermined)
    }

    let store = TestStore(
      initialState: GameOverState(
        completedGame: .init(
          cubes: .mock,
          gameContext: .solo,
          gameMode: .timed,
          gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
          language: .en,
          moves: [.highScoringMove],
          secondsPlayed: 0
        ),
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    await store.send(.onAppear)
    await self.mainRunLoop.advance()
    await store.receive(
      .userNotificationSettingsResponse(.init(authorizationStatus: .notDetermined))
    ) {
      $0.userNotificationSettings = .init(authorizationStatus: .notDetermined)
    }
    await self.mainRunLoop.advance(by: .seconds(1))
    await store.receive(.delayedShowUpgradeInterstitial) {
      $0.upgradeInterstitial = .init()
    }
    await self.mainRunLoop.advance(by: .seconds(1))
    await store.receive(.delayedOnAppear) { $0.isViewEnabled = true }
  }

  func testSkipUpgradeIfLessThan10GamesPlayed() async throws {
    var environment = GameOverEnvironment.failing
    environment.audioPlayer = .noop
    environment.apiClient.currentPlayerAsync = { .init(appleReceipt: nil, player: .blob) }
    environment.apiClient.override(
      routeCase: (/ServerRoute.Api.Route.games).appending(path: /ServerRoute.Api.Route.Games.submit),
      withResponse: { _ in .none }
    )
    environment.database.playedGamesCountAsync = { _ in 5 }
    environment.database.fetchStatsAsync = { .init() }
    environment.mainRunLoop = .immediate
    environment.serverConfig.config = { .init() }
    environment.userDefaults.override(
      double: self.mainRunLoop.now.date.timeIntervalSince1970,
      forKey: "last-review-request-timeinterval"
    )
    environment.userNotifications.getNotificationSettings = .none

    let store = TestStore(
      initialState: GameOverState(
        completedGame: .init(
          cubes: .mock,
          gameContext: .solo,
          gameMode: .timed,
          gameStartTime: .init(timeIntervalSince1970: 1_234_567_890),
          language: .en,
          moves: [.highScoringMove],
          secondsPlayed: 0
        ),
        isDemo: false
      ),
      reducer: gameOverReducer,
      environment: environment
    )

    await store.send(.onAppear)
    await store.receive(.delayedOnAppear) { $0.isViewEnabled = true }
  }
}
