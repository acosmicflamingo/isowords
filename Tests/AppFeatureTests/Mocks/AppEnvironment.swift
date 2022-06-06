import AppFeature
import ClientModels
import ComposableArchitecture
import FileClient
import Foundation
import Overture
import SettingsFeature
import UserDefaultsClient

extension AppEnvironment {
  static let didFinishLaunching = update(failing) {
    $0.audioPlayer.load = { _ in }
    $0.backgroundQueue = .immediate
    $0.database.migrate = .none
    $0.dictionary.load = { _ in false }
    let fileClient = $0.fileClient
    $0.fileClient.load = {
      try await [savedGamesFileName, userSettingsFileName].contains($0)
      ? .init()
      : fileClient.load($0)
    }
    $0.fileClient.override(load: userSettingsFileName, Effect<UserSettings, Error>.none)
    $0.gameCenter.localPlayer.authenticate = .none
    $0.mainQueue = .immediate
    $0.mainRunLoop = .immediate
    $0.serverConfig.refresh = { .none }
    $0.storeKit.observer = .none
    $0.userDefaults.override(bool: true, forKey: "hasShownFirstLaunchOnboardingKey")
    $0.userDefaults.override(double: 0, forKey: "installationTimeKey")
    let defaults = $0.userDefaults
    $0.userDefaults.setDouble = {
      $1 == "installationTimeKey" ? .none : defaults.setDouble($0, $1)
    }
    $0.userNotifications.delegate = .none
    $0.userNotifications.getNotificationSettings = { .init(authorizationStatus: .notDetermined) }
    $0.userNotifications.requestAuthorization = { _ in false }
  }
}
