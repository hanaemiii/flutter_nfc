import CommonCrypto
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
      guard let self = self else {
        result(
          FlutterError(code: "UNAVAILABLE", message: "AppDelegate instance is nil", details: nil))
        return
      }

      switch call.method {
      case "lockPresent":
        self.getLock { lockResult in
          switch lockResult {
          case .success:
            result(true)
          case .failure:
            result(false)
          }
        }

      case "setupNewLock":
        guard let args = call.arguments as? [String: String],
          let userName = args["userName"],
          let supervisorKey = args["supervisorKey"],
          let newPassword = args["newPassword"]
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS",
              message: "Missing arguments: userName, supervisorKey or newPassword",
              details: nil))
          return
        }
        self.setupNewLock(
          userName: userName, supervisorKey: supervisorKey, newPassword: newPassword,
          result: result)

      case "changePassword":
        guard let args = call.arguments as? [String: String],
          let userName = args["userName"],  // Extract userName
          let supervisorKey = args["supervisorKey"],
          let newPassword = args["newPassword"]
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS",
              message: "Missing arguments: userName, supervisorKey or newPassword",
              details: nil))
          return
        }
        self.changePassword(
          userName: userName, supervisorKey: supervisorKey, newPassword: newPassword,
          result: result)

      case "unlockLock":
        guard let args = call.arguments as? [String: String],
          let userName = args["userName"],  // Extract userName
          let password = args["password"]
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS", message: "Missing userName or password for unlockLock",
              details: nil))
          return
        }
        self.unlockLock(userName: userName, password: password, result: result)

      case "lockLock":
        guard let args = call.arguments as? [String: String],
          let userName = args["userName"],  // Extract userName
          let password = args["password"]
        else {
          result(
            FlutterError(
              code: "INVALID_ARGS", message: "Missing userName or password for lockLock",
              details: nil))
          return
        }
        self.lockLock(userName: userName, password: password, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Fetches the lock state from the SmackSDK.
  private func getLock(completion: @escaping (Result<Lock, Error>) -> Void) {
    lockApi?.getLock(cancelIfNotSetup: false) { result in
      switch result {
      case .success(let lock):
        print("Successfully got lock: \(lock)")
        completion(.success(lock))
      case .failure(let error):
        print("Get lock error: \(error.localizedDescription)")
        completion(.failure(error))
      }
    }
  }

  /// Sets up a new lock with a supervisor key and a new password.
  private func setupNewLock(
    userName: String,  // Pass userName
    supervisorKey: String, newPassword: String, result: @escaping FlutterResult
  ) {
    self.lockApi?.getLock(cancelIfNotSetup: true) { [weak self] lockResult in
      guard let self = self else { return }

      switch lockResult {
      case .success(let lock):
        let keyGenerator = KeyGenerator()
        let generatedKeyResult = keyGenerator.generateKey(lockId: lock.id, password: newPassword)

        switch generatedKeyResult {
        case .success(let generatedLockKey):
          let setupInfo = LockSetupInformation(
            userName: userName,
            date: Date(),
            supervisorKey: supervisorKey,
            password: newPassword
          )

          self.lockApi?.setLockKey(setupInformation: setupInfo) { setKeyResult in
            switch setKeyResult {
            case .success(let lockState):
              if case .completed(let retrievedLockKey) = lockState {
                print(
                  "Successfully set lock key during setup. Retrieved LockKey: \(retrievedLockKey.hex)"
                )
                let info = LockActionInformation(
                  userName: userName,
                  date: Date(),
                  key: generatedLockKey
                )

                self.lockApi?.unlock(information: info) { unlockResult in
                  switch unlockResult {
                  case .success:
                    print("Successfully unlocked after setup.")
                    result("Password changed and lock initialized")
                  case .failure(let err):
                    print("Unlock error after setup: \(err.localizedDescription)")
                    result(
                      FlutterError(
                        code: "UNLOCK_FAILED_AFTER_SETUP", message: "Failed to unlock after setup",
                        details: err.localizedDescription))
                  }
                }
              } else {
                print("Set lock key succeeded but did not return completed state with LockKey.")
                result(
                  FlutterError(
                    code: "SET_KEY_NO_LOCKKEY",
                    message: "Set lock key succeeded but did not return LockKey",
                    details: nil))
              }

            case .failure(let err):
              print("Set lock key error during setup: \(err.localizedDescription)")
              result(
                FlutterError(
                  code: "SET_KEY_FAILED", message: "Failed to set lock key",
                  details: err.localizedDescription))
            }
          }
        case .failure(let err):
          print("Key generation failed: \(err.localizedDescription)")
          result(
            FlutterError(
              code: "KEY_GEN_FAILED", message: "Failed to generate lock key",
              details: err.localizedDescription))
        }

      case .failure(let error):
        print("Lock error during setup (getLock failed): \(error.localizedDescription)")
        result(
          FlutterError(
            code: "GET_LOCK_FAILED_SETUP", message: "Failed to get lock before setup",
            details: error.localizedDescription))
      }
    }
  }

  private func changePassword(
    userName: String,
    supervisorKey: String, newPassword: String, result: @escaping FlutterResult
  ) {
    self.lockApi?.getLock(cancelIfNotSetup: false) { [weak self] lockResult in
      guard let self = self else { return }
      switch lockResult {
      case .success(let lock):
        let keyGenerator = KeyGenerator()
        let generatedKeyResult = keyGenerator.generateKey(lockId: lock.id, password: newPassword)

        switch generatedKeyResult {
        case .success(let generatedLockKey):
          let setupInfo = LockSetupInformation(
            userName: userName,
            date: Date(),
            supervisorKey: supervisorKey,
            password: newPassword
          )

          self.lockApi?.setLockKey(setupInformation: setupInfo) { setKeyResult in
            switch setKeyResult {
            case .success:
              print("Password changed successfully.")
              result("Password changed")
            case .failure(let err):
              print("Change password error: \(err.localizedDescription)")
              result(
                FlutterError(
                  code: "CHANGE_PASSWORD_FAILED", message: "Failed to change password",
                  details: err.localizedDescription))
            }
          }
        case .failure(let err):
          print("Key generation failed during password change: \(err.localizedDescription)")
          result(
            FlutterError(
              code: "KEY_GEN_FAILED_CHANGE_PASSWORD",
              message: "Failed to generate lock key for password change",
              details: err.localizedDescription))
        }
      case .failure(let err):
        print("Get lock error during password change: \(err.localizedDescription)")
        result(
          FlutterError(
            code: "GET_LOCK_FAILED_CHANGE_PASSWORD",
            message: "Failed to get lock before changing password",
            details: err.localizedDescription
          ))
      }
    }
  }

  private func unlockLock(userName: String, password: String, result: @escaping FlutterResult) {
    getLock { [weak self] res in
      guard let self = self else { return }
      switch res {
      case .success(let lock):
        let keyGenerator = KeyGenerator()
        let generatedKeyResult = keyGenerator.generateKey(lockId: lock.id, password: password)

        switch generatedKeyResult {
        case .success(let generatedLockKey):
          self.continueWithSession(
            lock: lock, userName: userName, lockKey: generatedLockKey, action: .unlock,
            result: result)
        case .failure(let err):
          print("Key generation failed for unlock: \(err.localizedDescription)")
          result(
            FlutterError(
              code: "KEY_GEN_FAILED_UNLOCK", message: "Failed to generate lock key for unlock",
              details: err.localizedDescription))
        }

      case .failure(let err):
        print("Unlock getLock error: \(err.localizedDescription)")
        result(
          FlutterError(
            code: "GET_LOCK_FAILED_UNLOCK", message: "Failed to unlock (getLock failed)",
            details: err.localizedDescription))
      }
    }
  }

  private func lockLock(userName: String, password: String, result: @escaping FlutterResult) {
    getLock { [weak self] res in
      guard let self = self else { return }
      switch res {
      case .success(let lock):
        let keyGenerator = KeyGenerator()
        let generatedKeyResult = keyGenerator.generateKey(lockId: lock.id, password: password)

        switch generatedKeyResult {
        case .success(let generatedLockKey):
          self.continueWithSession(
            lock: lock, userName: userName, lockKey: generatedLockKey, action: .lock,
            result: result)
        case .failure(let err):
          print("Key generation failed for lock: \(err.localizedDescription)")
          result(
            FlutterError(
              code: "KEY_GEN_FAILED_LOCK", message: "Failed to generate lock key for lock",
              details: err.localizedDescription))
        }

      case .failure(let err):
        print("Lock getLock error: \(err.localizedDescription)")
        result(
          FlutterError(
            code: "GET_LOCK_FAILED_LOCK", message: "Failed to lock (getLock failed)",
            details: err.localizedDescription))
      }
    }
  }

  private enum LockAction {
    case unlock, lock
  }

  private func continueWithSession(
    lock: Lock, userName: String, lockKey: [UInt8], action: LockAction,
    result: @escaping FlutterResult
  ) {
    // Create LockActionInformation with the generated LockKey.
    let info = LockActionInformation(
      userName: userName, 
      date: Date(),
      key: lockKey
    )

    switch action {
    case .unlock:
      self.lockApi?.unlock(information: info) { unlockResult in
        switch unlockResult {
        case .success:
          print("Lock successfully unlocked.")
          result("Unlocked")
        case .failure(let err):
          print("Unlock error: \(err.localizedDescription)")
          result(
            FlutterError(
              code: "UNLOCK_FAILED", message: "Failed to unlock", details: err.localizedDescription)
          )
        }
      }

    case .lock:
      self.lockApi?.lock(information: info) { lockResult in
        switch lockResult {
        case .success:
          print("Lock successfully locked.")
          result("Locked")
        case .failure(let err):
          print("Lock error: \(err.localizedDescription)")
          result(
            FlutterError(
              code: "LOCK_FAILED", message: "Failed to lock", details: err.localizedDescription))
        }
      }
    }
  }

  func passwordToRawBytes(from password: String) -> [UInt8] {
    let hashed = password.sha256()
    let data = Data(hex: hashed)
    return Array(data.prefix(16))
  }
}
