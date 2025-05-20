import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/screens/events_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:tiketi_mkononi/widgets/featured_events.dart';
import 'package:tiketi_mkononi/widgets/category_grid.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:http/http.dart' as http;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String _searchQuery = '';
  List<Event> eventsList = [];
  late final StorageService _storageService;
  Timer? _timer;
  bool _isAppActive = true;
  int userId = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _loadCachedEvents();
    _startFetchingEvents();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final profile = _storageService.getUserProfile();
    if (profile != null) {
      setState(() {
        userId = profile.id;
      });
      fetchEvents();
    }
  }

  void _startFetchingEvents() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isAppActive) {
        fetchEvents();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isAppActive = state == AppLifecycleState.resumed;
    });
  }

  Future<void> _loadCachedEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cached_events');

    if (cachedData != null) {
      List<dynamic> dataList = jsonDecode(cachedData);
      setState(() {
        eventsList = dataList.map((json) => Event.fromJson(json)).toList();
      });
    }
  }

  Future<void> fetchEvents() async {
    if (!_isAppActive) return;

    try {
      final response = await http.get(Uri.parse('${backend_url}api/events/$userId'));

      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body);
        List<Event> events = dataList.map((json) => Event.fromJson(json)).toList();

        setState(() => eventsList = events);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_events', jsonEncode(dataList));
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
    }
  }

  void refreshMethod (){
    fetchEvents();
  }



  List<Event> _getFilteredEvents() {
    return _searchQuery.isEmpty
        ? eventsList
        : eventsList.where((event) => 
            event.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final filteredEvents = _getFilteredEvents();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tiketi Mkononi',
          style: TextStyle(
            fontWeight: FontWeight.normal,
            fontSize: 24,
            color: Colors.blue
          ),
        ),
        centerTitle: false,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color.fromARGB(255, 240, 244, 247), Color.fromARGB(255, 240, 244, 247)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: fetchEvents,
        color: Colors.blue,
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Bar with Glassmorphism Effect
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: isDarkMode
                        ? Colors.black.withOpacity(0.3)
                        : Colors.white.withOpacity(0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.2)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: SearchBar(
                    controller: _searchController,
                    hintText: 'Search events...',
                    hintStyle: WidgetStateTextStyle.resolveWith(
                      (states) => TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.grey[600],
                      ),
                    ),
                    backgroundColor: WidgetStateProperty.all(
                      isDarkMode
                          ? Colors.transparent
                          : Colors.white.withOpacity(0.7),
                    ),
                    elevation: WidgetStateProperty.all(0),
                    side: WidgetStateProperty.all(BorderSide.none),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    leading: Icon(
                      Icons.search,
                      color: isDarkMode ? Colors.white70 : Colors.blue,
                    ),
                    trailing: [
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            Icons.close,
                            color: isDarkMode ? Colors.white70 : Colors.grey[500],
                          ),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                    ],
                    onChanged: (value) => setState(() => _searchQuery = value),
                  ),
                ),

                const SizedBox(height: 24),
                
                // Featured Events Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Featured Events',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const EventsPage(),
                            ),
                          );
                        },
                        child: Text(
                          'See All',
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.purpleAccent
                                : Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FeaturedEvents(events: filteredEvents, userId: userId, refreshMethod: refreshMethod),
                
                const SizedBox(height: 28),
                
                // Categories Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                CategoryGrid(events: filteredEvents, userId: userId),
                
                const SizedBox(height: 20),
                
                // Trending Events Section (Optional)
                // Padding(
                //   padding: const EdgeInsets.symmetric(horizontal: 8),
                //   child: Row(
                //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //     children: [
                //       Text(
                //         'Trending Near You',
                //         style: TextStyle(
                //           fontSize: 20,
                //           fontWeight: FontWeight.bold,
                //           color: isDarkMode ? Colors.white : Colors.black87,
                //         ),
                //       ),
                //       TextButton(
                //         onPressed: () {},
                //         child: Text(
                //           'See All',
                //           style: TextStyle(
                //             color: isDarkMode
                //                 ? Colors.purpleAccent
                //                 : Colors.deepPurple,
                //           ),
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
                // const SizedBox(height: 8),
                // You would add a TrendingEvents widget here
              ],
            ),
          ),
        ),
      ),
    );
  }
}