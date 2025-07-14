import 'package:flutter/material.dart';
import 'package:flutter_locker_project/services/smack_lock_service.dart';

class LockControlProvider extends ChangeNotifier {
  final SmackLockService _lockService = SmackLockService();

  String _status = 'Idle';
  bool _lockPresent = false;

  String get status => _status;
  bool get lockPresent => _lockPresent;

  LockControlProvider() {
    _lockService.lockPresenceStream.listen((present) {
      _lockPresent = present;
      notifyListeners();
    });
    checkLockPresence();
  }

  void _updateStatus(String newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  Future<void> checkLockPresence() async {
    final present = await _lockService.checkLockPresence();
    _lockPresent = present;
    notifyListeners();
  }

  Future<void> setupNewLock(
      String userName, String supervisorKey, String newPassword) async {
    _updateStatus('Setting up lock...');
    final result =
        await _lockService.setupNewLock(userName, supervisorKey, newPassword);
    _updateStatus(result);
  }

  Future<void> unlockLock(String userName, String password) async {
    _updateStatus('Unlocking lock...');
    final result = await _lockService.unlockLock(userName, password);
    _updateStatus(result);
  }

  Future<void> lockLock(String userName, String password) async {
    _updateStatus('Locking lock...');
    final result = await _lockService.lockLock(userName, password);
    _updateStatus(result);
  }

  Future<void> changePassword(
      String userName, String supervisorKey, String newPassword) async {
    _updateStatus('Changing password...');
    final result =
        await _lockService.changePassword(userName, supervisorKey, newPassword);
    _updateStatus(result);
  }

  @override
  void dispose() {
    _lockService.dispose();
    super.dispose();
  }
}
