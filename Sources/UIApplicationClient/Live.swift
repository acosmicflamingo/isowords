import Combine
import UIKit

@available(iOSApplicationExtension, unavailable)
extension UIApplicationClient {
  public static let live = Self(
    alternateIconName: { UIApplication.shared.alternateIconName },
    open: { url, options in await UIApplication.shared.open(url, options: options) },
    openSettingsURLString: { UIApplication.openSettingsURLString },
    setAlternateIconName: { iconName in
      .run { subscriber in
        UIApplication.shared.setAlternateIconName(iconName) { error in
          if let error = error {
            subscriber.send(completion: .failure(error))
          } else {
            subscriber.send(completion: .finished)
          }
        }
        return AnyCancellable {}
      }
    },
    supportsAlternateIcons: { UIApplication.shared.supportsAlternateIcons }
  )
}
