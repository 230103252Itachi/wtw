import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wtw/services/openai_key_store.dart';
import 'package:wtw/models/wardrobe_model.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

enum Gender { male, female }

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = false;
  bool _isRegister = false;
  String? _loggedInUser;
  Gender? _gender;

  // Controllers
  final TextEditingController _keyController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAuthState();
  }

  Future<void> _loadSettings() async {
    final key = await OpenAIKeyStore.getKey();
    _keyController.text = key ?? '';
    try {
      await Hive.openBox('settings');
      final box = Hive.box('settings');
      setState(() {
        _darkMode = box.get('darkMode', defaultValue: false) as bool;
      });
    } catch (_) {}
  }

  Future<void> _loadAuthState() async {
    try {
      await Hive.openBox('auth');
      final box = Hive.box('auth');

      final current = box.get('currentUser') as String?;
      final users = box.get('users', defaultValue: <String, Map>{}) as Map;

      if (current != null && users.containsKey(current)) {
        final userData = users[current] as Map;

        setState(() {
          _loggedInUser = current;
          _gender = userData['gender'] == 'male' ? Gender.male : Gender.female;
        });
      }
    } catch (_) {}
  }

  String _hash(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<bool> _register(String username, String password) async {
    final box = Hive.box('auth');
    final users = box.get('users', defaultValue: <String, Map>{}) as Map;

    if (users.containsKey(username)) return false;

    if (_gender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a gender')));
      return false;
    }

    final Map<String, dynamic> newUsers = Map<String, dynamic>.from(users);

    newUsers[username] = {
      'password': _hash(password),
      'gender': _gender!.name,
    };

    await box.put('users', newUsers);
    await box.put('currentUser', username);

    setState(() {
      _loggedInUser = username;
    });

    return true;
  }

  Future<bool> _login(String username, String password) async {
    final box = Hive.box('auth');
    final users = box.get('users', defaultValue: <String, Map>{}) as Map;

    if (!users.containsKey(username)) return false;

    final userData = users[username] as Map;
    final hashed = _hash(password);

    if (userData['password'] != hashed) return false;

    await box.put('currentUser', username);

    setState(() {
      _loggedInUser = username;
      _gender = userData['gender'] == 'male' ? Gender.male : Gender.female;
    });

    return true;
  }

  Future<void> _logout() async {
    final box = Hive.box('auth');
    await box.delete('currentUser');
    setState(() {
      _loggedInUser = null;
    });
  }

  Future<void> _clearData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text(
          'Are you sure you want to delete all items and saved outfits? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      if (Hive.isBoxOpen('wardrobeBox')) {
        await Hive.box('wardrobeBox').clear();
      } else {
        await Hive.openBox('wardrobeBox');
        await Hive.box('wardrobeBox').clear();
      }
      final wardrobe = Provider.of<WardrobeModel>(context, listen: false);
      try {
        await wardrobe.clearAll();
      } catch (_) {
        try {
          wardrobe.items.clear();
        } catch (_) {}
        try {
          wardrobe.notifyListeners();
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Data deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting data: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleDarkMode(bool v) async {
    setState(() {
      _darkMode = v;
    });
    try {
      await Hive.openBox('settings');
      final box = Hive.box('settings');
      await box.put('darkMode', v);
    } catch (_) {}
  }

  @override
  void dispose() {
    _keyController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Account',
          style: TextStyle(
            color: Color(0xFF4B4CFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 1,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _authSection(),
                  const SizedBox(height: 24),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4B4CFF),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    value: _darkMode,
                    onChanged: (v) {
                      _toggleDarkMode(v);
                    },
                  ),

                ],
              ),
            ),
    );
  }

  Widget _authSection() {
    if (_loggedInUser != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF4B4CFF),
                child: Text(
                  _loggedInUser!.isNotEmpty
                      ? _loggedInUser![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Logged in as',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    Text(
                      _loggedInUser!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (_gender != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            _gender == Gender.male ? Icons.male : Icons.female,
                            size: 20,
                            color: Colors.blueGrey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _gender == Gender.male ? "Male" : "Female",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: _logout,
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Color(0xFF4B4CFF)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _userController,
          decoration: InputDecoration(
            labelText: 'Username',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passController,
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.lock_outline),
          ),
          obscureText: true,
        ),
        if (_isRegister) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _genderButton(
                gender: Gender.male,
                selected: _gender,
                label: "Male",
                icon: Icons.male,
                onTap: () => setState(() => _gender = Gender.male),
              ),
              const SizedBox(width: 12),
              _genderButton(
                gender: Gender.female,
                selected: _gender,
                label: "Female",
                icon: Icons.female,
                onTap: () => setState(() => _gender = Gender.female),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  final user = _userController.text.trim();
                  final pass = _passController.text;
                  if (user.isEmpty || pass.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter username and password')),
                    );
                    return;
                  }
                  setState(() => _loading = true);
                  bool ok = false;
                  if (_isRegister) {
                    if (_isRegister && _gender == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select a gender'),
                        ),
                      );
                      return;
                    } else {
                      ok = await _register(user, pass);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User already exists'),
                          ),
                        );
                      }
                    }
                  } else {
                    ok = await _login(user, pass);
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid credentials'),
                        ),
                      );
                    }
                  }
                  if (mounted) setState(() => _loading = false);
                },
                child: Text(_isRegister ? 'Register' : 'Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4B4CFF),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _isRegister = !_isRegister;
                });
              },
              child: Text(_isRegister ? 'Already have an account' : 'Register'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _genderButton({
    required Gender gender,
    required Gender? selected,
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isSelected = selected == gender;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4B4CFF) : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.black54),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}