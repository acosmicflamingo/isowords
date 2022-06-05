import Combine
import ComposableArchitecture
import ComposableUserNotifications
import RemoteNotificationsClient

public func registerForRemoteNotifications(
  remoteNotifications: RemoteNotificationsClient,
  userNotifications: UserNotificationClient
) async {
  let settings = await userNotifications.getNotificationSettings()
  guard
    settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
  else { return }
  await remoteNotifications.register()
}
