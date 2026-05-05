import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "coathematchmaker/maps",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "openLocation" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let rawLocation = args["location"] as? String
      else {
        result(nil)
        return
      }

      let location = rawLocation.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !location.isEmpty else {
        result(nil)
        return
      }

      let encoded = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location
      let googleMapsUrl = URL(string: "comgooglemaps://?q=\(encoded)")!
      let webMapsUrl = URL(string: "https://www.google.com/maps/search/?api=1&query=\(encoded)")!
      let targetUrl = UIApplication.shared.canOpenURL(googleMapsUrl) ? googleMapsUrl : webMapsUrl

      UIApplication.shared.open(targetUrl)
      result(nil)
    }
  }
}
