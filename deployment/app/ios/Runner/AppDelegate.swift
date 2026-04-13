import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Register Apple Vision OCR channel. This replaces google_mlkit_text_recognition
    // which has no arm64 iOS simulator slice and prevents targeting iOS 26+ simulators.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OcrVisionPlugin") {
      OcrVisionPlugin.register(with: registrar)
    }
  }
}
