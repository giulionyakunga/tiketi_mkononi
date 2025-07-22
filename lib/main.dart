import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:tiketi_mkononi/screens/auth/forgot_password_screen.dart';
import 'package:tiketi_mkononi/screens/auth/login_screen.dart';
import 'package:tiketi_mkononi/screens/auth/register_screen.dart';
import 'package:tiketi_mkononi/screens/event_details_wrapper.dart';
import 'package:tiketi_mkononi/screens/events_page.dart';
import 'package:tiketi_mkononi/screens/home_page.dart';
import 'package:tiketi_mkononi/screens/onboarding_screen.dart';
import 'package:tiketi_mkononi/screens/profile_page.dart';
import 'package:tiketi_mkononi/screens/tickets_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'web_setup_stub.dart'
if (dart.library.html) 'web_setup_web.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('first_launch') ?? true;
  final storageService = StorageService(prefs);
  final profile = storageService.getUserProfile();

  configureApp(); // Calls setUrlStrategy() only on web

  runApp(
    ProviderScope(
      child: TiketiMkononiApp(
        isFirstLaunch: isFirstLaunch,
        isLoggedIn: profile != null && profile.id > 0,
      ),
    ),
  );
}

class TiketiMkononiApp extends StatelessWidget {
  final bool isFirstLaunch;
  final bool isLoggedIn;

  TiketiMkononiApp({
    super.key,
    required this.isFirstLaunch,
    required this.isLoggedIn,
  });

  late final GoRouter _router = GoRouter(
    initialLocation: isFirstLaunch
        ? '/onboarding'
        : (isLoggedIn ? '/home' : '/login'),
    routes: [
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
      GoRoute(path: '/home', builder: (context, state) => const MainScreen(initialIndex: 0)),
      GoRoute(path: '/events', builder: (context, state) => const MainScreen(initialIndex: 1)),
      GoRoute(path: '/tickets', builder: (context, state) => const MainScreen(initialIndex: 2)),
      GoRoute(path: '/profile', builder: (context, state) => const MainScreen(initialIndex: 3)),
      GoRoute(
        path: '/event/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return EventDetailsWrapper(eventId: id);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Tiketi Mkononi',
      theme: ThemeData(
        primarySwatch: Colors.orange, // Still use the full MaterialColor
        primaryColor: Colors.orange[800], // But override the primary color
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;

  const MainScreen({super.key, required this.initialIndex});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _selectedIndex;

  final List<Widget> _screens = [
    const HomePage(),
    const EventsPage(),
    const TicketsPage(eventId: 0),
    const ProfilePage(),
  ];

  final List<String> _routes = [
    '/home',
    '/events',
    '/tickets',
    '/profile',
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() => _selectedIndex = index);
          if (kIsWeb) context.go(_routes[index]); // ✅ URL will update
        },
        // This makes the selected icon color change to orange
        indicatorColor: Colors.orange.withOpacity(0.2), // Optional: adds an orange highlight
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow, // Optional: always show labels
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home, color: _selectedIndex == 0 ?Colors.orange[800] : Colors.grey),
            selectedIcon: Icon(Icons.home, color:Colors.orange[800]),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.event),
            selectedIcon: Icon(Icons.event, color: Colors.orange[800]),
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number),
            selectedIcon: Icon(Icons.confirmation_number, color: Colors.orange[800]),
            label: 'My Tickets',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            selectedIcon: Icon(Icons.person, color: Colors.orange[800]),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
