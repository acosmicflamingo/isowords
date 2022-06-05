public struct FeedbackGeneratorClient {
  public var prepare: @MainActor () -> Void
  public var selectionChanged: @MainActor () -> Void
}
