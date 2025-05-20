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

  const CategoryEventsPage({super.key, required this.category, required this.userId});

  @override
  State<CategoryEventsPage> createState() => _CategoryEventsPageState();

}

class _CategoryEventsPageState extends State<CategoryEventsPage> {
  int userId = 0;
  String userRole = "";
  late final StorageService _storageService;
  static const _pageSize = 30;
  final PagingController<int, Event> _pagingController = PagingController(firstPageKey: 1);

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
      // Get fresh first page data
      // final url = Uri.parse('${backend_url}api/events/$userId?page=$pageKey&limit=$_pageSize');

      final url = Uri.parse('${backend_url}api/events/$userId?page=1&limit=$_pageSize');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
          List<Event> events = _getEventsByCategory(newItems);

        // Update current list silently
        _pagingController.itemList = events;

        // Cache the latest first page
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_events', jsonEncode(jsonList));

        // Show snackbar optionally
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(
        //     content: Text('New event(s) available!'),
        //     duration: Duration(seconds: 2),
        //   ),
        // );
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
      final cachedEvents = jsonList.map((json) => Event.fromJson(json)).toList();

      // Apply filter to cached events
      List<Event> filteredCached = _getEventsByCategory(cachedEvents);

      final isLastPage = filteredCached.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(filteredCached);
      } else {
        final firstPage = filteredCached.take(_pageSize).toList();
        // final remaining = filteredCached.skip(_pageSize).toList();

        _pagingController.appendPage(firstPage, 2);

        // Optionally preload remaining items in memory
        // You could store them in a list to use in subsequent pages
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
          // 👇 Clear old cached data before adding fresh page 1
          _pagingController.itemList = [];

          // Cache the latest first page
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

  @override
  void dispose() {
    _webSocketService.disconnect();
    _pagingController.dispose();
    super.dispose();
  }


 
  List<Event> _getEventsByCategory(List<Event> events) {
    return events.where((event) => event.category == widget.category).toList();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: PagedListView<int, Event>(
        padding: const EdgeInsets.all(16.0),
        pagingController: _pagingController,
        builderDelegate: PagedChildBuilderDelegate<Event>(
          itemBuilder: (context, event, index) {
            return EventCard(event: event, userId: userId, refreshMethod: _handleWebSocketUpdate);
          },
          noItemsFoundIndicatorBuilder: (_) =>
              const Center(child: Text('No events found')),
          firstPageErrorIndicatorBuilder: (_) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading events'),
              ElevatedButton(
                // onPressed: () => _pagingController.refresh(),
                onPressed: () => {
                  _fetchPage(1),
                  _pagingController.refresh()
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
    );
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
        // Implement reconnection logic here if needed
      },
      onDone: () {
        debugPrint('WebSocket connection closed');
        // Implement reconnection logic here if needed
      },
    );
  }

  void disconnect() {
    _channel.sink.close(1000); // Normal closure
    // _channel.sink.close();
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel.sink.add(jsonEncode(message));
  }
}
