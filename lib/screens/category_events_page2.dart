import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:tiketi_mkononi/widgets/event_card.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class CategoryEventsPage extends StatefulWidget {
  final String category;
  final int userId;

  const CategoryEventsPage({
    super.key, 
    required this.category, 
    required this.userId
  });

  @override
  State<CategoryEventsPage> createState() => _CategoryEventsPageState();
}

class _CategoryEventsPageState extends State<CategoryEventsPage> {
  int userId = 0;
  String userRole = "";
  late final StorageService _storageService;
  static const _pageSize = 30;
  final PagingController<int, Event> _pagingController = 
      PagingController(firstPageKey: 1);

  final WebSocketService _webSocketService = WebSocketService();
  bool _isWebSocketConnected = false;

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
    _init();
  }

  Future<void> _init() async {
    await _initializeServices();
    await _loadCachedEvents();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    _connectWebSocket();
  }

  void _connectWebSocket() {
    if (_isWebSocketConnected) return;
    
    try {
      _webSocketService.connect(
        userId,
        backend_ws_url,
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
      final url = Uri.parse('${backend_url}api/events/$userId?page=1&limit=$_pageSize');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
        List<Event> events = _getEventsByCategory(newItems);

        _pagingController.itemList = events;

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
      _pagingController.refresh();
    }
  }

  Future<void> _loadCachedEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cached_events');

    if (cachedData != null) {
      final List<dynamic> jsonList = jsonDecode(cachedData);
      final cachedEvents = jsonList.map((json) => Event.fromJson(json)).toList();
      List<Event> filteredCached = _getEventsByCategory(cachedEvents);

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
      final url = Uri.parse('${backend_url}api/events/$userId?page=$pageKey&limit=$_pageSize');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
        List<Event> events = _getEventsByCategory(newItems);

        if (pageKey == 1) {
          _pagingController.itemList = [];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_events', jsonEncode(jsonList));
        }

        final isLastPage = newItems.length < _pageSize;
        if (isLastPage) {
          _pagingController.appendLastPage(events);
        } else {
          final nextPageKey = pageKey + 1;
          _pagingController.appendPage(events, nextPageKey);
        }
      } else {
        _pagingController.error = 'Failed to load events';
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  List<Event> _getEventsByCategory(List<Event> events) {
    return events.where((event) => event.category == widget.category).toList();
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
        title: Text(
          widget.category,
          style: TextStyle(
            fontSize: isLargeScreen ? 24 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        elevation: 0,
        centerTitle: isLargeScreen,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isVeryLargeScreen ? 40 : 
                    isLargeScreen ? 24 : 16,
          vertical: 16,
        ),
        child: PagedGridView<int, Event>(
          pagingController: _pagingController,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getCrossAxisCount(context),
            crossAxisSpacing: isLargeScreen ? 24 : 16,
            mainAxisSpacing: isLargeScreen ? 24 : 16,
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
            noItemsFoundIndicatorBuilder: (_) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No ${widget.category.toLowerCase()} events found',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 20 : 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (isLargeScreen) 
                      const SizedBox(height: 8),
                    if (isLargeScreen)
                      Text(
                        'Check back later or try another category',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            firstPageErrorIndicatorBuilder: (_) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading events',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 20 : 16,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    _fetchPage(1);
                    _pagingController.refresh();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: isLargeScreen 
                      ? const EdgeInsets.symmetric(horizontal: 32, vertical: 16)
                      : null,
                  ),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 16 : 14,
                    ),
                  ),
                ),
              ],
            ),
            newPageErrorIndicatorBuilder: (_) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 32, color: Colors.red),
                    const SizedBox(height: 8),
                    const Text('Error loading more events'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _pagingController.retryLastFailedRequest(),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _getCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 3; // Desktop
    if (screenWidth > 800) return 2; // Tablet landscape
    return 1; // Mobile or tablet portrait
  }

  double _getChildAspectRatio(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 0.85; // Wider cards on desktop
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
    _channel.sink.close(1000);
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel.sink.add(jsonEncode(message));
  }
}