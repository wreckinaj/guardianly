import UIKit
import Flutter
import Firebase

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("🚀 AppDelegate: application didFinishLaunchingWithOptions - START")
    
    // Configure Firebase with error handling
    print("🔥 Attempting to configure Firebase...")
    
    // Check if GoogleService-Info.plist exists in bundle
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
        print("✅ GoogleService-Info.plist found at: \(path)")
    } else {
        print("❌ GoogleService-Info.plist NOT found in bundle!")
    }
    
    // Configure Firebase
    FirebaseApp.configure()
    print("✅ Firebase.configure() completed")
    
    // Check if Firebase app was created
    if FirebaseApp.app() != nil {
        print("✅ Firebase app instance exists with name: \(FirebaseApp.app()?.name ?? "unknown")")
    } else {
        print("❌ Firebase app instance is nil after configure!")
    }
    
    GeneratedPluginRegistrant.register(with: self)
    print("✅ GeneratedPluginRegistrant registered")
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    print("🚀 AppDelegate: application didFinishLaunchingWithOptions - END (result: \(result))")
    
    return result
  }
}
