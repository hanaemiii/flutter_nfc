import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

class SmackLockService {
  static const platform =
      MethodChannel('com.example.flutter_locker_project/smack');

  final StreamController<bool> _lockPresenceController =
      StreamController<bool>.broadcast();

  SmackLockService() {
    if (Platform.isIOS) {
      platform.setMethodCallHandler(_handleNativeCalls);
    }
  }

  Stream<bool> get lockPresenceStream => _lockPresenceController.stream;

  Future<void> _handleNativeCalls(MethodCall call) async {
    print(
        'Received native method call: ${call.method} with arguments: ${call.arguments}');
    if (call.method == 'lockPresent') {
      final bool present = call.arguments as bool;
      _lockPresenceController.add(present);
    }
  }

  Future<bool> checkLockPresence() async {
    if (!Platform.isIOS) {
      print("checkLockPresence is only supported on iOS for now.");
      return false;
    }

    try {
      final bool result = await platform.invokeMethod('lockPresent');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check lock presence: '${e.message}'.");
      return false;
    }
  }

  Future<String> setupNewLock(
      String? supervisorKey, String? newPassword) async {
    if (supervisorKey == null || newPassword == null) {
      return "Supervisor key or password is null.";
    }

    try {
      final String? result = await platform.invokeMethod('setupNewLock', {
        'supervisorKey': supervisorKey,
        'newPassword': newPassword,
      });
      return result ?? "Lock setup failed, no result returned.";
    } on PlatformException catch (e) {
      return "Failed to setup lock: '${e.message}'.";
    }
  }

  Future<String> unlockLock(String password) async {
    try {
      final String? result = await platform.invokeMethod('unlockLock', {
        'password': password,
      });
      return result ?? "Unlock failed, no result returned.";
    } on PlatformException catch (e) {
      return "Failed to unlock lock: '${e.message}'.";
    }
  }

  Future<String> lockLock(String password) async {
    try {
      final String result = await platform.invokeMethod('lockLock', {
        'password': password,
      });
      return result;
    } on PlatformException catch (e) {
      return "Failed to lock lock: '${e.message}'.";
    }
  }

  Future<String> changePassword(
      String supervisorKey, String newPassword) async {
    try {
      final String result = await platform.invokeMethod('changePassword', {
        'supervisorKey': supervisorKey,
        'newPassword': newPassword,
      });
      return result;
    } on PlatformException catch (e) {
      return "Failed to change password: '${e.message}'.";
    }
  }

  void dispose() {
    _lockPresenceController.close();
  }
}
