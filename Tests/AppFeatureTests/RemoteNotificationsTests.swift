import ClientModels
import Combine
import ComposableArchitecture
import ComposableUserNotifications
import GameFeature
import Overture
import UserNotifications
import XCTest

@testable import AppFeature

@MainActor
class RemoteNotificationsTests: XCTestCase {
  func testRegisterForRemoteNotifications_OnActivate_Authorized() async {
    let didRegisterForRemoteNotifications = SendableState<Bool>(false)
    let requestedAuthorizationOptions = SendableState<UNAuthorizationOptions?>(nil)

    var environment = AppEnvironment.didFinishLaunching
    environment.build.number = { 80 }
    environment.remoteNotifications.register = {
      await didRegisterForRemoteNotifications.set(true)
    }
    environment.userNotifications.getNotificationSettings = {
      .init(authorizationStatus: .authorized)
    }
    environment.userNotifications.requestAuthorization = { options in
      await requestedAuthorizationOptions.set(options)
      return true
    }

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )

    // Register remote notifications on .didFinishLaunching

    await store.send(.appDelegate(.didFinishLaunching)).finish()
    let options = await requestedAuthorizationOptions.value
    XCTAssertNoDifference(options, [.alert, .sound])
    var didRegister = await didRegisterForRemoteNotifications.value
    XCTAssertTrue(didRegister)

    store.environment.apiClient.override(
      route: .push(
        .register(.init(authorizationStatus: .authorized, build: 80, token: "6465616462656566"))
      ),
      withResponse: .init(value: (Data(), URLResponse()))
    )
    store.send(.appDelegate(.didRegisterForRemoteNotifications(.success(Data("deadbeef".utf8)))))

    // Register remote notifications on .didChangeScenePhase(.active)

    await didRegisterForRemoteNotifications.set(false)

    store.environment.audioPlayer.secondaryAudioShouldBeSilencedHint = { false }
    store.environment.audioPlayer.setGlobalVolumeForMusic = { _ in .none }

    await store.send(.didChangeScenePhase(.active)).finish()
    didRegister = await didRegisterForRemoteNotifications.value
    XCTAssertTrue(didRegister)

    store.environment.apiClient.override(
      route: .push(
        .register(.init(authorizationStatus: .authorized, build: 80, token: "6261616462656566"))
      ),
      withResponse: .init(value: (Data(), URLResponse()))
    )
    await store
      .send(.appDelegate(.didRegisterForRemoteNotifications(.success(Data("baadbeef".utf8)))))
      .finish()
  }

  func testRegisterForRemoteNotifications_NotAuthorized() async {
    var environment = AppEnvironment.didFinishLaunching
    environment.remoteNotifications = .failing

    let store = TestStore(
      initialState: AppState(),
      reducer: appReducer,
      environment: environment
    )

    await store.send(.appDelegate(.didFinishLaunching)).finish()

    store.environment.audioPlayer.secondaryAudioShouldBeSilencedHint = { false }
    store.environment.audioPlayer.setGlobalVolumeForMusic = { _ in .none }

    await store.send(.didChangeScenePhase(.active)).finish()
  }

  func testReceiveNotification_dailyChallengeEndsSoon() async {
    let userNotificationsDelegate = PassthroughSubject<
      UserNotificationClient.DelegateEvent, Never
    >()

    var environment = AppEnvironment.didFinishLaunching
    environment.fileClient.save = { _, _ in .none }
    environment.userNotifications.delegate = userNotificationsDelegate.eraseToEffect()

    let inProgressGame = InProgressGame.mock

    let store = TestStore(
      initialState: update(AppState()) {
        $0.home.savedGames.dailyChallengeUnlimited = inProgressGame
      },
      reducer: appReducer,
      environment: environment
    )

    let notification = UserNotificationClient.Notification(
      date: .mock,
      request: .init(
        identifier: "deadbeef",
        content: updateObject(UNMutableNotificationContent()) {
          $0.userInfo = [
            "dailyChallengeEndsSoon": true
          ]
        },
        trigger: nil
      )
    )
    let response = UserNotificationClient.Notification.Response(notification: notification)

    var notificationPresentationOptions: UNNotificationPresentationOptions?
    let willPresentNotificationCompletionHandler = { notificationPresentationOptions = $0 }

    var didReceiveResponseCompletionHandlerCalled = false
    let didReceiveResponseCompletionHandler = { didReceiveResponseCompletionHandlerCalled = true }

    let task = store.send(.appDelegate(.didFinishLaunching))

    userNotificationsDelegate.send(
      .willPresentNotification(
        notification,
        completionHandler: { willPresentNotificationCompletionHandler($0) }
      )
    )

    await store.receive(
      .appDelegate(
        .userNotifications(
          .willPresentNotification(
            notification,
            completionHandler: { willPresentNotificationCompletionHandler($0) }
          )
        )
      )
    )
    XCTAssertNoDifference(notificationPresentationOptions, .banner)

    userNotificationsDelegate.send(
      .didReceiveResponse(response, completionHandler: { didReceiveResponseCompletionHandler() })
    )

    await store.receive(
      .appDelegate(
        .userNotifications(
          .didReceiveResponse(
            response,
            completionHandler: { didReceiveResponseCompletionHandler() }
          )
        )
      )
    ) {
      $0.game = GameState(inProgressGame: inProgressGame)
      $0.home.savedGames.unlimited = inProgressGame
    }
    XCTAssert(didReceiveResponseCompletionHandlerCalled)

    userNotificationsDelegate.send(completion: .finished)

    await task.finish()
  }
}
