import ExpoModulesCore
import Foundation

public class NativeShareReceiverModule: Module {
  private static var initialSharedText: String?

  public static func setSharedText(_ text: String) {
    initialSharedText = text
  }

  public func definition() -> ModuleDefinition {
    Name("NativeShareReceiver")

    Events("SharedText")

    Function("getInitialSharedText") { () -> String? in
      let text = NativeShareReceiverModule.initialSharedText
      NativeShareReceiverModule.initialSharedText = nil
      return text
    }
  }
}
