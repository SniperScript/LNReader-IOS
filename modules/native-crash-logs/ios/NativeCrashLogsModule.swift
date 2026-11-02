import ExpoModulesCore
import Foundation
import UIKit

public class NativeCrashLogsModule: Module {
  private static let crashLogKey = "LNReader_PendingCrashLog"

  public func definition() -> ModuleDefinition {
    Name("NativeCrashLogs")

    AsyncFunction("shareCrashLogs") { (report: String, logLevel: String) in
      DispatchQueue.main.async {
        let activityVC = UIActivityViewController(activityItems: [report], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
          var presenter = rootVC
          while let presented = presenter.presentedViewController {
            presenter = presented
          }
          if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
          }
          presenter.present(activityVC, animated: true)
        }
      }
    }

    Function("recordJsCrash") { (stackTrace: String) in
      UserDefaults.standard.set(stackTrace, forKey: Self.crashLogKey)
    }

    AsyncFunction("getPendingCrash") { () -> String? in
      UserDefaults.standard.string(forKey: Self.crashLogKey)
    }

    AsyncFunction("clearPendingCrash") {
      UserDefaults.standard.removeObject(forKey: Self.crashLogKey)
    }

    AsyncFunction("getDebugInfo") { () -> [String: Any?] in
      return [
        "webViewVersion": "WebKit"
      ]
    }

    Function("restartApp") {
      exit(0)
    }
  }
}

