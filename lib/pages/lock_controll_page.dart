import 'package:flutter/material.dart';
import 'package:flutter_locker_project/providers/lock_provider.dart';
import 'package:provider/provider.dart';

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
  final _userNameController = TextEditingController();

  @override
  void dispose() {
    _supervisorKeyController.dispose();
    _newPasswordController.dispose();
    _passwordController.dispose();
    _changeNewPasswordController.dispose();
    _userNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lockControlProvider = Provider.of<LockControlProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Locker Control'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(lockControlProvider.lockPresent
                ? '🔓 Lock detected!'
                : '🔒 No lock detected'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: lockControlProvider.checkLockPresence,
              child: const Text('Check Lock Presence'),
            ),
            const Divider(height: 32),
            const Text('Setup New Lock',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _userNameController,
              decoration: const InputDecoration(labelText: 'User Name'),
            ),
            TextField(
              controller: _supervisorKeyController,
              decoration: const InputDecoration(labelText: 'Supervisor Key'),
              obscureText: true,
            ),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () => lockControlProvider.setupNewLock(
                _userNameController.text,
                _supervisorKeyController.text,
                _newPasswordController.text,
              ),
              child: const Text('Setup Lock'),
            ),
            const Divider(height: 32),
            const Text('Unlock Lock',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () => lockControlProvider.unlockLock(
                  _userNameController.text, _passwordController.text),
              child: const Text('Unlock'),
            ),
            const Divider(height: 32),
            const Text('Lock Lock',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ElevatedButton(
              onPressed: () => lockControlProvider.lockLock(
                  _userNameController.text, _passwordController.text),
              child: const Text('Lock'),
            ),
            const Divider(height: 32),
            const Text('Change Password',
                style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              controller: _supervisorKeyController,
              decoration: const InputDecoration(labelText: 'Supervisor Key'),
              obscureText: true,
            ),
            TextField(
              controller: _changeNewPasswordController,
              decoration: const InputDecoration(labelText: 'New Password'),
              obscureText: true,
            ),
            ElevatedButton(
              onPressed: () => lockControlProvider.changePassword(
                _userNameController.text,
                _supervisorKeyController.text,
                _changeNewPasswordController.text,
              ),
              child: const Text('Change Password'),
            ),
            const Divider(height: 32),
            Text('Status: ${lockControlProvider.status}'),
          ],
        ),
      ),
    );
  }
}
