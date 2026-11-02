import ExpoModulesCore
import Foundation

public class NativeVolumeButtonListenerModule: Module {
  private static var isActive = false

  public func definition() -> ModuleDefinition {
    Name("NativeVolumeButtonListener")

    Events("VolumeUp", "VolumeDown")

    Function("setActive") { (active: Bool) in
      Self.isActive = active
    }
  }
}
