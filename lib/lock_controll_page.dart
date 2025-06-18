import 'package:flutter/material.dart';
import 'package:flutter_locker_project/services/smack_lock_service.dart';

class LockControlPage extends StatefulWidget {
  const LockControlPage({super.key});

  @override
  State<LockControlPage> createState() => _LockControlPageState();
}

class _LockControlPageState extends State<LockControlPage> {
  final _supervisorKeyController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _changeNewPasswordController = TextEditingController();

  final _lockService = SmackLockService();

  String _status = 'Idle';
  bool _lockPresent = false;

  @override
  void initState() {
    super.initState();

    // Listen to native-pushed lock presence updates
    _lockService.lockPresenceStream.listen((present) {
      setState(() {
        _lockPresent = present;
      });
    });

    // Actively check for lock on init (especially for iOS)
    _lockService.checkLockPresence().then((present) {
      setState(() {
        _lockPresent = present;
      });
    });
  }

  void _updateStatus(String newStatus) {
    setState(() {
      _status = newStatus;
    });
  }

  Future<void> _setupNewLock() async {
    _updateStatus('Setting up lock...');
    final result = await _lockService.setupNewLock(
      _supervisorKeyController.text,
      _newPasswordController.text,
    );
    _updateStatus(result);
  }

  Future<void> _unlockLock() async {
    _updateStatus('Unlocking lock...');
    final result = await _lockService.unlockLock(_passwordController.text);
    _updateStatus(result);
  }

  Future<void> _lockLock() async {
    _updateStatus('Locking lock...');
    final result = await _lockService.lockLock(_passwordController.text);
    _updateStatus(result);
  }

  Future<void> _changePassword() async {
    _updateStatus('Changing password...');
    final result = await _lockService.changePassword(
      _supervisorKeyController.text,
      _changeNewPasswordController.text,
    );
    _updateStatus(result);
  }

  Future<void> _manualCheckLockPresence() async {
    final present = await _lockService.checkLockPresence();
    setState(() {
      _lockPresent = present;
    });
  }

  @override
  void dispose() {
    _supervisorKeyController.dispose();
    _newPasswordController.dispose();
    _passwordController.dispose();
    _changeNewPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('NFC Locker Control'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(_lockPresent ? '🔓 Lock detected!' : '🔒 No lock detected'),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _manualCheckLockPresence,
              child: Text('Check Lock Presence'),
            ),
            Divider(height: 32),
            Text('Setup New Lock', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _supervisorKeyController,
              decoration: InputDecoration(labelText: 'Supervisor Key'),
              obscureText: true,
            ),
            TextField(
              controller: _newPasswordController,
              decoration: InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: _setupNewLock,
              child: Text('Setup Lock'),
            ),
            Divider(height: 32),
            Text('Unlock Lock', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: _unlockLock,
              child: Text('Unlock'),
            ),
            Divider(height: 32),
            Text('Lock Lock', style: TextStyle(fontWeight: FontWeight.bold)),
            ElevatedButton(
              onPressed: _lockLock,
              child: Text('Lock'),
            ),
            Divider(height: 32),
            Text('Change Password', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _supervisorKeyController,
              decoration: InputDecoration(labelText: 'Supervisor Key'),
              obscureText: true,
            ),
            TextField(
              controller: _changeNewPasswordController,
              decoration: InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: _changePassword,
              child: Text('Change Password'),
            ),
            Divider(height: 32),
            Text('Status: $_status'),
          ],
        ),
      ),
    );
  }
}
