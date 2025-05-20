import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:tiketi_mkononi/widgets/event_card.dart';
import 'package:tiketi_mkononi/screens/post_event_page.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  String? _selectedCategory;
  int userId = 0;
  String userRole = "";

  final List<String> _categories = [
    'All',
    'Comedy',
    'Bars & Grills',
    'Fun',
    'Concerts',
    'Theater',
    'Sports',
    'Training',
    'My Events'
  ];

  late final StorageService _storageService;
  static const _pageSize = 30;
  final PagingController<int, Event> _pagingController =
      PagingController(firstPageKey: 1);

  final WebSocketService _webSocketService = WebSocketService();
  bool _isWebSocketConnected = false;

  @override
  void initState() {
    super.initState();
    _init(); // Call the async method
  }

  Future<void> _init() async {
    await _initializeServices();
    await _loadCachedEvents();

    // Add the listener only after everything is ready
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    _connectWebSocket();
  }

  void _connectWebSocket() {
    if (_isWebSocketConnected) return;

    try {
      final String url = backend_ws_url;
      _webSocketService.connect(
        userId,
        url,
        onUpdate: _handleWebSocketUpdate,
      );
      _isWebSocketConnected = true;
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
    }
  }

  void _handleWebSocketUpdate() async {
    if (!mounted) return;

    try {
      final url =
          Uri.parse('${backend_url}api/events/$userId?page=1&limit=$_pageSize');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
        List<Event> filteredItems = _filterEvents(newItems);

        // Update current list silently
        _pagingController.itemList = filteredItems;

        // Cache the latest first page
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_events', jsonEncode(jsonList));
      } else {
        debugPrint('Failed to load events silently');
      }
    } catch (e) {
      debugPrint('Silent update error: $e');
    }
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
        userRole = profile.role;
      });
      _pagingController.refresh(); // trigger load
    }
  }

  /// Load stored events from SharedPreferences
  Future<void> _loadCachedEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cached_events');

    if (cachedData != null) {
      final List<dynamic> jsonList = jsonDecode(cachedData);
      final cachedEvents =
          jsonList.map((json) => Event.fromJson(json)).toList();

      // Apply filter to cached events
      List<Event> filteredCached = _filterEvents(cachedEvents);

      final isLastPage = filteredCached.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(filteredCached);
      } else {
        final firstPage = filteredCached.take(_pageSize).toList();
        _pagingController.appendPage(firstPage, 2);
      }
    }
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final url = Uri.parse(
          '${backend_url}api/events/$userId?page=$pageKey&limit=$_pageSize');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
        List<Event> filteredItems = _filterEvents(newItems);

        if (pageKey == 1) {
          // Clear old cached data before adding fresh page 1
          _pagingController.itemList = [];

          // Cache the latest first page
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_events', jsonEncode(jsonList));
        }

        final isLastPage = newItems.length < _pageSize;
        if (isLastPage) {
          _pagingController.appendLastPage(filteredItems);
        } else {
          final nextPageKey = pageKey + 1;
          _pagingController.appendPage(filteredItems, nextPageKey);
        }
      } else {
        _pagingController.error = 'Failed to load events';
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  List<Event> _filterEvents(List<Event> events) {
    if (_selectedCategory == null || _selectedCategory == 'All') {
      return events;
    } else if (_selectedCategory == 'My Events') {
      return events.where((event) => event.userId == userId).toList();
    } else {
      return events.where((event) => event.category == _selectedCategory).toList();
    }
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600; // Tablet or desktop
    final isVeryLargeScreen = screenWidth > 1200; // Desktop

    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          if (isLargeScreen) 
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: _buildCategoryChips(),
              ),
            ),
          if (!isLargeScreen)
            PopupMenuButton<String>(
              icon: Icon(Icons.filter_list, color: Colors.orange[800]),
              onSelected: (String category) {
                setState(() {
                  _selectedCategory = category == 'All' ? null : category;
                });
                _pagingController.refresh();
              },
              itemBuilder: (BuildContext context) {
                return _categories.map((String category) {
                  return PopupMenuItem<String>(
                    value: category,
                    child: Row(
                      children: [
                        if (category == _selectedCategory ||
                            (category == 'All' && _selectedCategory == null))
                          Icon(Icons.check, color: Colors.orange[800]),
                        const SizedBox(width: 8),
                        Text(category),
                      ],
                    ),
                  );
                }).toList();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (isLargeScreen && !isVeryLargeScreen)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _buildCategoryChips(),
              ),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isVeryLargeScreen ? 24.0 : 16.0,
                vertical: 8.0,
              ),
              child: PagedGridView<int, Event>(
                pagingController: _pagingController,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getCrossAxisCount(context),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: _getChildAspectRatio(context),
                ),
                builderDelegate: PagedChildBuilderDelegate<Event>(
                  itemBuilder: (context, event, index) {
                    return EventCard(
                      event: event,
                      userId: userId,
                      refreshMethod: _handleWebSocketUpdate,
                      // isLargeScreen: isLargeScreen,
                    );
                  },
                  noItemsFoundIndicatorBuilder: (_) =>
                      const Center(child: Text('No events found')),
                  firstPageErrorIndicatorBuilder: (_) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Error loading events'),
                      ElevatedButton(
                        onPressed: () {
                          _fetchPage(1);
                          _pagingController.refresh();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  newPageErrorIndicatorBuilder: (_) => const Center(
                    child: Text('Error loading more events'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ((userRole == "admin") || (userRole == "organiser"))
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostEventPage(
                        refreshMethod: _handleWebSocketUpdate),
                  ),
                );
              },
              backgroundColor: Colors.orange[800],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  List<Widget> _buildCategoryChips() {
    return _categories.map((category) {
      final isSelected = _selectedCategory == category ||
          (category == 'All' && _selectedCategory == null);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ChoiceChip(
          label: Text(category),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedCategory = selected ? (category == 'All' ? null : category) : null;
            });
            _pagingController.refresh();
          },
          selectedColor: Colors.orange[800],
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
          ),
        ),
      );
    }).toList();
  }

  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 3; // Desktop
    if (screenWidth > 800) return 2; // Tablet landscape or large tablet
    return 1; // Mobile or tablet portrait
  }

  double _getChildAspectRatio(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 0.9; // Wider cards on desktop
    if (screenWidth > 800) return 0.8; // Slightly wider on tablets
    return 0.75; // Default for mobile
  }
}

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  late WebSocketChannel _channel;
  Function()? _onUpdateCallback;

  factory WebSocketService() {
    return _instance;
  }

  WebSocketService._internal();

  void connect(int userId, String url, {required Function() onUpdate}) {
    _onUpdateCallback = onUpdate;
    _channel = WebSocketChannel.connect(Uri.parse(url));

    // Send subscription message
    final subscriptionMessage = jsonEncode({
      "user_id": userId,
      "type": "subscribe",
      "data": "events_update"
    });

    debugPrint("[WebSocket] Sending subscription: $subscriptionMessage");
    _channel.sink.add(subscriptionMessage);

    _channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        debugPrint('Message: $message');

        if (data['type'] == 'events_updated') {
          debugPrint('Message 2: $message');
          _onUpdateCallback?.call();
        }
      },
      onError: (error) {
        debugPrint('WebSocket error: $error');
      },
      onDone: () {
        debugPrint('WebSocket connection closed');
      },
    );
  }

  void disconnect() {
    _channel.sink.close(1000); // Normal closure
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel.sink.add(jsonEncode(message));
  }
}