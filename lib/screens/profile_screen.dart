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

  // Preferences
  bool _compactList = false;

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
        _compactList = box.get('compactList', defaultValue: false) as bool;
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
      ).showSnackBar(const SnackBar(content: Text('Пожалуйста, выберите пол')));
      return false;
    }

    final Map<String, dynamic> newUsers = Map<String, dynamic>.from(users);

    newUsers[username] = {
      'password': _hash(password),
      'gender': _gender!.name, // male / female
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
        title: const Text('Подтвердите'),
        content: const Text(
          'Вы уверены, что хотите удалить все вещи и сохранённые образы? Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
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
          // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
          wardrobe.notifyListeners();
        } catch (_) {}
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Данные удалены')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка при удалении: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleCompact(bool v) async {
    setState(() {
      _compactList = v;
    });
    try {
      await Hive.openBox('settings');
      final box = Hive.box('settings');
      await box.put('compactList', v);
    } catch (_) {}
  }

  @override
  void dispose() {
    _keyController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
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
                      'Вошли как',
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
                            _gender == Gender.male ? "Мужчина" : "Женщина",
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
                  'Выйти',
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
            labelText: 'Имя пользователя',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passController,
          decoration: InputDecoration(
            labelText: 'Пароль',
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
                label: "Мужчина",
                icon: Icons.male,
                onTap: () => setState(() => _gender = Gender.male),
              ),
              const SizedBox(width: 12),
              _genderButton(
                gender: Gender.female,
                selected: _gender,
                label: "Женщина",
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
                      const SnackBar(content: Text('Введите логин и пароль')),
                    );
                    return;
                  }
                  setState(() => _loading = true);
                  bool ok = false;
                  if (_isRegister) {
                    if (_isRegister && _gender == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Пожалуйста, выберите пол'),
                        ),
                      );
                      return;
                    } else {
                      ok = await _register(user, pass);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Пользователь уже существует'),
                          ),
                        );
                      }
                    }
                  } else {
                    ok = await _login(user, pass);
                    if (!ok && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Неверные учётные данные'),
                        ),
                      );
                    }
                  }
                  if (mounted) setState(() => _loading = false);
                },
                child: Text(_isRegister ? 'Зарегистрироваться' : 'Войти'),
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
              child: Text(_isRegister ? 'Уже есть аккаунт' : 'Регистрация'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль и настройки'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 1,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AUTH
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Учётная запись',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _authSection(),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Предпочтения',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: _compactList,
                          onChanged: _toggleCompact,
                          title: const Text('Компактный список'),
                          subtitle: const Text(
                            'Показывать более плотный список в гардеробе',
                          ),
                          activeColor: const Color(0xFF4B4CFF),
                        ),
                        const SizedBox(height: 6),
                        FutureBuilder(
                          future: Hive.openBox('settings'),
                          builder: (context, snap) {
                            final box = Hive.box('settings');
                            final dark =
                                box.get('darkMode', defaultValue: false)
                                    as bool;
                            return SwitchListTile(
                              value: dark,
                              onChanged: (v) async {
                                await box.put('darkMode', v);
                                setState(() {});
                              },
                              title: const Text('Тёмная тема'),
                              subtitle: const Text(
                                'Включить тёмный режим приложения',
                              ),
                              activeColor: const Color(0xFF4B4CFF),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const Icon(
                            Icons.info_outline,
                            color: Color(0xFF4B4CFF),
                          ),
                          title: const Text('О приложении'),
                          subtitle: const Text('Версия: 1.0.0'),
                          onTap: () {
                            showAboutDialog(
                              context: context,
                              applicationName: 'WhatToWear',
                              applicationVersion: '1.0.0',
                              children: [
                                const Text('AI-powered wardrobe helper'),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _loading ? null : _clearData,
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Очистить все данные'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            if (_loggedInUser != null) {
                              _logout();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Вы не вошли')),
                              );
                            }
                          },
                          icon: const Icon(Icons.logout),
                          label: const Text('Выйти'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
