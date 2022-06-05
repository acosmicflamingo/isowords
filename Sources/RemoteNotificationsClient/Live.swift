#if canImport(UIKit)
  import UIKit

  @available(iOSApplicationExtension, unavailable)
  extension RemoteNotificationsClient {
    public static let live = Self(
      isRegistered: { await UIApplication.shared.isRegisteredForRemoteNotifications },
      register: { await UIApplication.shared.registerForRemoteNotifications() },
      unregister: { await UIApplication.shared.unregisterForRemoteNotifications() }
    )
  }
#elseif canImport(AppKit)
  import AppKit

  extension RemoteNotificationsClient {
    public static let live = Self(
      isRegistered: { await NSApplication.shared.isRegisteredForRemoteNotifications },
      register: { await NSApplication.shared.registerForRemoteNotifications() },
      unregister: { await NSApplication.shared.unregisterForRemoteNotifications() }
    )
  }
#endif
