import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/screens/events_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:tiketi_mkononi/widgets/featured_events.dart';
import 'package:tiketi_mkononi/widgets/category_grid.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  bool _isNewVerionAvailable = false;
  int userId = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _loadCachedEvents();
    _startFetchingEvents();
    checkForUpdates(context);
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

  void refreshMethod() {
    fetchEvents();
  }

  List<Event> _getFilteredEvents() {
    return _searchQuery.isEmpty
        ? eventsList
        : eventsList.where((event) => 
            event.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();
  }


  Future<void> checkForUpdates(BuildContext context) async {
    // Get current app version
    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersion = packageInfo.version;

    // Replace with your logic (e.g., API call, Firebase Remote Config)
    String latestVersion = ""; // Hardcoded for example

    try {
      final response = await http.get(Uri.parse('${backend_url}api/application_information/$userId/${installedVersion}'));
      if (response.statusCode == 200) {
        final applicationInformation = jsonDecode(response.body);
        if (applicationInformation['app_version'] != "") {
          latestVersion = applicationInformation['app_version'];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('application_information', response.body);
        }
      }
    } catch (e) {}

    if (installedVersion.compareTo(latestVersion) < 0) {
      setState(() {
        _isNewVerionAvailable = true;
      });
    }
  }

Future<void> _launchStore() async {
  const appStoreUrl = "https://apps.apple.com/app/idYOUR_APP_ID"; // iOS
  const playStoreUrl = "https://play.google.com/store/apps/details?id=com.telabs.tiketi_mkononi"; // Android

  final Uri storeUrl = Uri.parse(
    Platform.isAndroid ? playStoreUrl : appStoreUrl,
  );

  if (!await launchUrl(storeUrl, mode: LaunchMode.externalApplication)) {
    throw Exception("Could not launch $storeUrl");
  }
}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final filteredEvents = _getFilteredEvents();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: isWideScreen
          ? null // No app bar for wide screens (we'll use our own)
          : AppBar(
              title: Text(
                'Tiketi Mkononi',
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 24,
                  color: Colors.orange[800],
                ),
              ),
              centerTitle: false,
              elevation: 0,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 240, 244, 247),
                      Color.fromARGB(255, 240, 244, 247)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              actions: [
                _isNewVerionAvailable ?
                IconButton(
                  icon: const Icon(Icons.system_update_rounded),
                  color: Colors.red,
                  onPressed: () => 
                  // New update available
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Update Available"),
                      content: const Text("A new version of the app is available. Please update to enjoy the latest features."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Later"),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _launchStore();
                          },
                          child: const Text("Update Now"),
                        ),
                      ],
                    ),
                  ),
                ) : 
                Text("")
              ],
            ),
      body: RefreshIndicator(
        onRefresh: fetchEvents,
        color: Colors.orange[800],
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (isWideScreen)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 240, 244, 247),
                        Color.fromARGB(255, 240, 244, 247)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Tiketi Mkononi',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 28,
                          color: Colors.orange[800],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 400,
                        child: _buildSearchBar(isDarkMode),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isWideScreen ? 40 : 16,
                vertical: isWideScreen ? 0 : 16,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (!isWideScreen) _buildSearchBar(isDarkMode),
                  const SizedBox(height: 24),
                  _buildFeaturedEventsSection(isDarkMode, filteredEvents, isWideScreen),
                  const SizedBox(height: 28),
                  _buildCategoriesSection(isDarkMode, filteredEvents, isWideScreen),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
          isDarkMode ? Colors.transparent : Colors.white.withOpacity(0.7),
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
          color: isDarkMode ? Colors.white70 : Colors.orange[800],
        ),
        trailing: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close,
                color: isDarkMode ? Colors.white70 : Colors.orange[800],
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
    );
  }

  Widget _buildFeaturedEventsSection(bool isDarkMode, List<Event> filteredEvents, bool isWideScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Featured Events',
                style: TextStyle(
                  fontSize: isWideScreen ? 24 : 20,
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
                    fontSize: isWideScreen ? 18 : null,
                    color: isDarkMode ? Colors.purpleAccent : Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        FeaturedEvents(
          events: filteredEvents,
          userId: userId,
          refreshMethod: refreshMethod,
          // isWideScreen: isWideScreen,
        ),
      ],
    );
  }

  Widget _buildCategoriesSection(bool isDarkMode, List<Event> filteredEvents, bool isWideScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Categories',
            style: TextStyle(
              fontSize: isWideScreen ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
        CategoryGrid(
          events: filteredEvents,
          userId: userId,
          // isWideScreen: isWideScreen,
        ),
      ],
    );
  }
}