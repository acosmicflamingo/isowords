import Combine
import ComposableArchitecture
import ComposableUserNotifications
import Overture
import UserNotifications
import XCTest

@testable import AppFeature

@MainActor
class UserNotificationsTests: XCTestCase {
  func testReceiveBackgroundNotification() async {
    let delegate = PassthroughSubject<UserNotificationClient.DelegateEvent, Never>()
    let response = UserNotificationClient.Notification.Response(
      notification: UserNotificationClient.Notification(
        date: .mock,
        request: UNNotificationRequest(
          identifier: "deadbeef",
          content: UNNotificationContent(),
          trigger: nil
        )
      )
    )
    var didCallback = false
    let completionHandler = { didCallback = true }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: update(.didFinishLaunching) {
        $0.userNotifications.delegate = delegate.eraseToEffect()
        $0.userNotifications.requestAuthorization = { _ in true }
      }
    )

    store.send(.appDelegate(.didFinishLaunching))

    delegate.send(.didReceiveResponse(response, completionHandler: { completionHandler() }))
    await store.receive(
      .appDelegate(
        .userNotifications(
          .didReceiveResponse(response, completionHandler: { completionHandler() })
        )
      )
    )

    XCTAssertTrue(didCallback)

    delegate.send(completion: .finished)
  }

  func testReceiveForegroundNotification() async {
    let delegate = PassthroughSubject<UserNotificationClient.DelegateEvent, Never>()
    let notification = UserNotificationClient.Notification(
      date: .mock,
      request: UNNotificationRequest(
        identifier: "deadbeef",
        content: UNNotificationContent(),
        trigger: nil
      )
    )
    var didCallbackWithOptions: UNNotificationPresentationOptions?
    let completionHandler = { didCallbackWithOptions = $0 }

    let store = TestStore(
      initialState: .init(),
      reducer: appReducer,
      environment: update(.didFinishLaunching) {
        $0.userNotifications.delegate = delegate.eraseToEffect()
        $0.userNotifications.requestAuthorization = { _ in true }
      }
    )

    store.send(.appDelegate(.didFinishLaunching))

    delegate.send(
      .willPresentNotification(notification, completionHandler: { completionHandler($0) })
    )

    await store.receive(
      .appDelegate(
        .userNotifications(
          .willPresentNotification(notification, completionHandler: { completionHandler($0) })
        )
      )
    )

    XCTAssertNoDifference(didCallbackWithOptions, .banner)

    delegate.send(completion: .finished)
  }
}
