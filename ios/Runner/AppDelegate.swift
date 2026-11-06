import UIKit
import Flutter
import Photos
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "farm.qr_download_service"
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      methodChannel?.setMethodCallHandler(handle)
      let voice = FlutterMethodChannel(name: "farm.mkulima_voice", binaryMessenger: controller.binaryMessenger)
      let command = MPRemoteCommandCenter.shared()
      let fire: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { _ in
        voice.invokeMethod("headset", arguments: nil)
        return .success
      }
      command.togglePlayPauseCommand.addTarget(handler: fire)
      command.playCommand.addTarget(handler: fire)
      UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "downloadQr":
      guard let args = call.arguments as? [String: Any],
            let typedData = args["bytes"] as? FlutterStandardTypedData,
            let fileName = args["fileName"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing bytes or fileName.", details: nil))
        return
      }
      saveQrImage(data: typedData.data, fileName: fileName, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func saveQrImage(data: Data, fileName: String, result: @escaping FlutterResult) {
    func writeImage() {
      PHPhotoLibrary.shared().performChanges({
        let creationRequest = PHAssetCreationRequest.forAsset()
        let options = PHAssetResourceCreationOptions()
        options.uniformTypeIdentifier = "public.png"
        creationRequest.addResource(with: .photo, data: data, options: options)
      }) { success, error in
        DispatchQueue.main.async {
          if let error = error {
            result(FlutterError(code: "SAVE_FAILED", message: "Save failed: \(error.localizedDescription)", details: nil))
            return
          }
          if success {
            result(["success": true, "message": "Saved to Photos", "fileUri": fileName, "destination": "photos"])
          } else {
            result(FlutterError(code: "SAVE_FAILED", message: "Unable to save image.", details: nil))
          }
        }
      }
    }

    let status = PHPhotoLibrary.authorizationStatus()
    switch status {
    case .authorized, .limited:
      writeImage()
    case .notDetermined:
      PHPhotoLibrary.requestAuthorization { newStatus in
        DispatchQueue.main.async {
          if newStatus == .authorized || newStatus == .limited {
            writeImage()
          } else {
            result(FlutterError(code: "PERMISSION_DENIED", message: "Photos permission denied.", details: nil))
          }
        }
      }
    default:
      result(FlutterError(code: "PERMISSION_DENIED", message: "Photos permission denied.", details: nil))
    }
  }
}
