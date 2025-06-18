import Flutter
import SmackSDK
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var lockApi: LockApi?
  private let channelName = "com.example.flutter_locker_project/smack"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    let methodChannel = FlutterMethodChannel(
      name: channelName, binaryMessenger: controller.binaryMessenger)

    let config = SmackConfig(logging: CombinedLogger(debugPrinter: DebugPrinter()))
    let client = SmackClient(config: config)
    let target = SmackTarget.device(client: client)
    lockApi = LockApi(target: target, config: config)

    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }

      switch call.method {
      case "lockPresent":
        print("🔄 Reaching native lockPresent method")

        self.lockApi?.getLock(cancelIfNotSetup: false) { lockResult in
          switch lockResult {
          case .success:
            print("✅ Lock detected")
            result(true)  // <-- This sends the result back to Flutter
          case .failure(let error):
            print("❌ Lock detection failed: \(error)")
            result(false)  // <-- Still respond back to avoid hanging
          }
        }

      case "setupNewLock":
        guard let args = call.arguments as? [String: String],
          let supervisorKey = args["supervisorKey"],
          let newPassword = args["newPassword"]
        else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
          return
        }
        self.setupNewLock(supervisorKey: supervisorKey, newPassword: newPassword, result: result)

      case "changePassword":
        guard let args = call.arguments as? [String: String],
          let supervisorKey = args["supervisorKey"],
          let newPassword = args["newPassword"]
        else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
          return
        }
        self.changePassword(supervisorKey: supervisorKey, newPassword: newPassword, result: result)

      case "unlockLock":
        guard let args = call.arguments as? [String: String],
          let password = args["password"]
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS",
              message: "Missing arguments",
              details: nil))
          return
        }
        let info = LockActionInformation(
          userName: "MyUserName",
          date: Date(),
          key: Array(password.utf8)
        )
        self.lockApi?.unlock(information: info) { unlockResult in
          switch unlockResult {
          case .success:
            result("Unlocked")
          case .failure(let err):
            print("Unlock error: \(err)")
            result("Failed to unlock")
          }
        }

      case "lockLock":
        guard let args = call.arguments as? [String: String],
          let password = args["password"]
        else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
          return
        }
        self.lockLock(password: password, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupNewLock(
    supervisorKey: String, newPassword: String, result: @escaping FlutterResult
  ) {
    lockApi?.getLock(cancelIfNotSetup: false) { lockResult in
      switch lockResult {
      case .success:
        let setupInfo = LockSetupInformation(
          userName: "MyUserName",
          date: Date(),
          supervisorKey: supervisorKey,
          password: newPassword
        )

        self.lockApi?.setLockKey(setupInformation: setupInfo) { setKeyResult in
          switch setKeyResult {
          case .success:
            let actionInfo = LockActionInformation(
              userName: "MyUserName",
              date: Date(),
              key: Array(newPassword.utf8)
            )
            self.lockApi?.unlock(information: actionInfo) { unlockResult in
              switch unlockResult {
              case .success:
                result("Password changed and lock initialized")
              case .failure(let err):
                print("Unlock error: \(err)")
                result("Failed to unlock")
              }
            }
          case .failure(let err):
            print("Set lock key error: \(err)")
            result("Failed to set lock key")
          }
        }

      case .failure(let error):
        print("Lock error: \(error)")
        result("Failed to setup lock")
      }
    }
  }

  private func changePassword(
    supervisorKey: String, newPassword: String, result: @escaping FlutterResult
  ) {
    let setupInfo = LockSetupInformation(
      userName: "MyUserName",
      date: Date(),
      supervisorKey: supervisorKey,
      password: newPassword
    )

    self.lockApi?.setLockKey(setupInformation: setupInfo) { setKeyResult in
      switch setKeyResult {
      case .success:
        result("Password changed")
      case .failure(let err):
        print("Change password error: \(err)")
        result("Failed to change password")
      }
    }
  }

  private func unlockLock(password: String, result: @escaping FlutterResult) {
   
    let actionInfo = LockActionInformation(
      userName: "MyUserName",
      date: Date(),
      key: Array(password.utf8)
    )

    self.lockApi?.unlock(information: actionInfo) { unlockResult in
      switch unlockResult {
      case .success:
        result("Unlocked")
      case .failure(let err):
        print("Unlock error: \(err)")
        result("Failed to unlock")
      }
    }
  }

  private func lockLock(password: String, result: @escaping FlutterResult) {
    let actionInfo = LockActionInformation(
      userName: "MyUserName",
      date: Date(),
      key: Array(password.utf8)
    )

    self.lockApi?.lock(information: actionInfo) { lockResult in
      switch lockResult {
      case .success:
        result("Locked")
      case .failure(let err):
        print("Lock error: \(err)")
        result("Failed to lock")
      }
    }
  }
}
