import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    setUpActivationPolicyChannel(with: flutterViewController)

    super.awakeFromNib()
  }

  /// Lets the Dart side switch NSApp's activation policy dynamically:
  /// `.regular` while the window is visible (Dock icon, Cmd+Tab, minimizable),
  /// `.accessory` while hidden (menubar-only, matching LSUIElement's default).
  private func setUpActivationPolicyChannel(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "pro_orc/activation_policy",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "setRegular":
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        result(nil)
      case "setAccessory":
        NSApp.setActivationPolicy(.accessory)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
