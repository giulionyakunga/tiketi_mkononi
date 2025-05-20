import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/screens/auth/forgot_password_screen.dart';
import 'package:tiketi_mkononi/screens/home_page.dart';
import 'package:tiketi_mkononi/screens/events_page.dart';
import 'package:tiketi_mkononi/screens/tickets_page.dart';
import 'package:tiketi_mkononi/screens/profile_page.dart';
import 'package:tiketi_mkononi/screens/auth/login_screen.dart';
import 'package:tiketi_mkononi/screens/auth/register_screen.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';

void main() {
  runApp(
    const ProviderScope(
      child:  TicketApp()
    )
  );
}

class TicketApp extends StatelessWidget {
  const TicketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ticket App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: FutureBuilder<String>(
        future: getInitialRoute(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasData) {
            return _getScreenForRoute(snapshot.data!);
          } else {
            return const LoginScreen();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/home': (context) => const MainScreen(),
        '/events': (context) => const EventsPage(),
        '/tickets': (context) => const TicketsPage(),
      },
    );
  }

  Future<String> getInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    StorageService _storageService = StorageService(prefs);
    final profile = _storageService.getUserProfile();

    if (profile != null) {
      if(profile.id > 0){
        return '/home';
      }
    }
    return '/login';
  }

  Widget _getScreenForRoute(String route) {
    switch (route) {
      case '/home':
        return const MainScreen();
      case '/login':
      default:
        return const LoginScreen();
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomePage(),
    const EventsPage(),
    const TicketsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            selectedIcon: Icon(Icons.home, color: Colors.blue), // Selected color
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.event),
            selectedIcon: Icon(Icons.event, color: Colors.blue), // Selected color
            label: 'Events',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number),
            selectedIcon: Icon(Icons.confirmation_number, color: Colors.blue), // Selected color
            label: 'My Tickets',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            selectedIcon: Icon(Icons.person, color: Colors.blue), // Selected color
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}