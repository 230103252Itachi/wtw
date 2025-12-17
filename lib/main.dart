import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:wtw/models/wardrobe_model.dart';
import 'package:wtw/screens/home_screen.dart';
import 'package:wtw/screens/wardrobe_screen.dart';
import 'package:wtw/screens/saved_screen.dart';
import 'package:wtw/screens/profile_screen.dart';
import 'package:wtw/models/wardrobe_item.dart';
import 'package:wtw/screens/add_item_screen.dart';
import 'package:wtw/services/openai_key_store.dart';
import 'package:wtw/screens/login_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final openaiKey = dotenv.env['OPENAI_API_KEY'];
  if (openaiKey != null && openaiKey.isNotEmpty) {
    await OpenAIKeyStore.saveKey(openaiKey);
  }

  await Hive.initFlutter();
  Hive.registerAdapter(WardrobeItemAdapter());
  await Hive.openBox<WardrobeItem>('wardrobeBox');

  await Hive.openBox('settings');
  await Hive.openBox('savedOutfits');
  runApp(const WhatToWearApp());
}

class WhatToWearApp extends StatelessWidget {
  const WhatToWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsBox = Hive.box('settings');
    return ChangeNotifierProvider(
      create: (_) => WardrobeModel(),
      child: ValueListenableBuilder(
        valueListenable: settingsBox.listenable(),
        builder: (context, box, _) {
          final bool darkMode =
              settingsBox.get('darkMode', defaultValue: false) as bool;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'WhatToWear',
            theme: ThemeData(
              primarySwatch: Colors.indigo,
              scaffoldBackgroundColor: const Color(0xFFF6F8FB),
              fontFamily: 'Roboto',
              brightness: Brightness.light,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF4B4CFF),
                elevation: 1,
              ),
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              primaryColor: const Color(0xFF4B4CFF),
              primarySwatch: Colors.indigo,
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 1,
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
              ),
            ),
            themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
            home: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                
                if (snapshot.hasData && snapshot.data != null) {
                  return const MainTabs();
                }
                
                return const LoginScreen();
              },
            ),
            routes: {
              '/addItem': (ctx) => const AddItemScreen(),
              '/profile': (ctx) => const ProfileScreen(),
            },
          );
        },
      ),
    );
  }
}

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const WardrobeScreen(),
    const SavedScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Firebase listener in WardrobeModel initializes automatically
    // No need to manually load items
  }

  void _onTap(int idx) {
    setState(() {
      _currentIndex = idx;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4B4CFF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.checkroom),
            label: 'Wardrobe',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.bookmark), label: 'Saved'),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
