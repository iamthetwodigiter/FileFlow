import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let NOTIFICATIONS_CHANNEL = "com.fileflow/notifications"
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Request notification permissions
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      if granted {
        print("✅ Notification permission granted")
      } else {
        print("⚠️ Notification permission denied")
      }
    }
    
    // Setup notification channel
    let controller = window?.rootViewController as! FlutterViewController
    let notificationChannel = FlutterMethodChannel(name: NOTIFICATIONS_CHANNEL, binaryMessenger: controller.binaryMessenger)
    
    notificationChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.handleNotificationCall(call: call, result: result)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func handleNotificationCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "showConnectionEstablished":
      if let args = call.arguments as? [String: Any],
         let deviceName = args["deviceName"] as? String {
        showNotification(title: "Connected", body: "Connected to \(deviceName)")
      }
      result(nil)
      
    case "showConnectionRequest":
      if let args = call.arguments as? [String: Any],
         let deviceName = args["deviceName"] as? String {
        showNotification(title: "Connection Request", body: "\(deviceName) wants to connect")
      }
      result(nil)
      
    case "showConnectionRejected":
      if let args = call.arguments as? [String: Any],
         let deviceName = args["deviceName"] as? String {
        let reason = args["reason"] as? String ?? "Connection rejected"
        showNotification(title: "Connection Rejected", body: "\(deviceName): \(reason)")
      }
      result(nil)
      
    case "showTransferRequest":
      if let args = call.arguments as? [String: Any],
         let deviceName = args["deviceName"] as? String,
         let fileName = args["fileName"] as? String {
        showNotification(title: "Transfer Request", body: "\(deviceName) wants to send \(fileName)")
      }
      result(nil)
      
    case "showTransferStarted":
      if let args = call.arguments as? [String: Any],
         let fileName = args["fileName"] as? String {
        let isSending = args["isSending"] as? Bool ?? false
        let action = isSending ? "Sending" : "Receiving"
        showNotification(title: "\(action) File", body: fileName)
      }
      result(nil)
      
    case "updateTransferProgress":
      if let args = call.arguments as? [String: Any],
         let fileName = args["fileName"] as? String,
         let progress = args["progress"] as? Int {
        let speedMBps = args["speedMBps"] as? Double ?? 0.0
        showNotification(title: "Transfer Progress", body: "\(fileName) - \(progress)% (\(String(format: "%.2f", speedMBps)) MB/s)")
      }
      result(nil)
      
    case "showTransferPaused":
      if let args = call.arguments as? [String: Any],
         let fileName = args["fileName"] as? String {
        showNotification(title: "Transfer Paused", body: fileName)
      }
      result(nil)
      
    case "showTransferResumed":
      if let args = call.arguments as? [String: Any],
         let fileName = args["fileName"] as? String {
        showNotification(title: "Transfer Resumed", body: fileName)
      }
      result(nil)
      
    case "showTransferCompleted":
      if let args = call.arguments as? [String: Any],
         let fileName = args["fileName"] as? String {
        let isSending = args["isSending"] as? Bool ?? false
        let action = isSending ? "Sent" : "Received"
        showNotification(title: "Transfer Complete", body: "\(action): \(fileName)")
      }
      result(nil)
      
    case "showTransferCancelled":
      if let args = call.arguments as? [String: Any],
         let fileName = args["fileName"] as? String {
        let reason = args["reason"] as? String ?? "Cancelled"
        showNotification(title: "Transfer Cancelled", body: "\(fileName) - \(reason)")
      }
      result(nil)
      
    case "showError":
      if let args = call.arguments as? [String: Any],
         let title = args["title"] as? String,
         let message = args["message"] as? String {
        showNotification(title: title, body: message)
      }
      result(nil)
      
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func showNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("❌ Error showing notification: \(error)")
      }
    }
  }
}
