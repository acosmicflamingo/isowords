import ComposableArchitecture
import UIKit

public struct UIApplicationClient {
  public var alternateIconName: () -> String?
  public var open: (URL, [UIApplication.OpenExternalURLOptionsKey: Any]) async -> Bool
  public var openSettingsURLString: () -> String
  public var setAlternateIconName: (String?) -> Effect<Never, Error>
  public var supportsAlternateIcons: () -> Bool
}
