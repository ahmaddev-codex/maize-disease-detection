import Flutter
import UIKit
import Vision

/// On-device OCR using Apple's Vision framework (VNRecognizeTextRequest).
///
/// Replaces google_mlkit_text_recognition which lacks arm64 iOS simulator
/// slices and therefore prevents targeting iOS 26+ simulators on Apple Silicon.
/// Vision is built into iOS 13+ and supports arm64 on both device and simulator.
@objc class OcrVisionPlugin: NSObject, FlutterPlugin {

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.maizedetector.ocr/vision",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(OcrVisionPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognizeText" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let imagePath = args["imagePath"] as? String
    else {
      result(FlutterError(code: "INVALID_ARGS", message: "imagePath is required", details: nil))
      return
    }
    OcrVisionPlugin.recognizeText(imagePath: imagePath, result: result)
  }

  private static func recognizeText(imagePath: String, result: @escaping FlutterResult) {
    DispatchQueue.global(qos: .userInitiated).async {
      guard
        let image = UIImage(contentsOfFile: imagePath),
        let cgImage = image.cgImage
      else {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "INVALID_IMAGE",
            message: "Cannot load image at: \(imagePath)",
            details: nil
          ))
        }
        return
      }

      var lines: [String] = []
      let request = VNRecognizeTextRequest { req, error in
        guard error == nil else {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "OCR_ERROR",
              message: error!.localizedDescription,
              details: nil
            ))
          }
          return
        }
        lines = (req.results as? [VNRecognizedTextObservation] ?? [])
          .compactMap { $0.topCandidates(1).first?.string }
      }
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      request.recognitionLanguages = ["en-US"]

      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      do {
        try handler.perform([request])
        let text = lines.joined(separator: "\n")
        DispatchQueue.main.async { result(text) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "OCR_ERROR",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }
}
