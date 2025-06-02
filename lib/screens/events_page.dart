import 'dart:convert';
import 'dart:io';
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
  int numberOfActiveEvents = 0;
  String userRole = "";
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Event> fetchedEvents = [];
  bool _isSearchBarVisible = false;
  bool _isReloading = false;
  bool useDNS_2 = true;

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
  final PagingController<int, Event> _pagingController = PagingController(firstPageKey: 1);

  final WebSocketService _webSocketService = WebSocketService();
  bool _isWebSocketConnected = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _pagingController.itemList = _filterEvents(fetchedEvents);
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    useDNS_2 = await prefs.getBool('use_dns') ?? true;

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

  void _handleWebSocketUpdate({bool useDNS = true}) async {
    if (!mounted) return;
    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/events/$userId?page=1&limit=$_pageSize') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/events/$userId?page=1&limit=$_pageSize'); // Use IP
        
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
        List<Event> filteredItems = _filterEvents(newItems);
        setState(() {
          fetchedEvents = newItems;
        });

        _pagingController.itemList = filteredItems;

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_events', jsonEncode(jsonList));
      } else {
        debugPrint('Failed to load events silently');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          _handleWebSocketUpdate(useDNS: false); // Recursive retry
          return;
        }
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
      List<Event> filteredCached = _filterEvents(cachedEvents);
      setState(() {
        fetchedEvents = cachedEvents;
      });

      final isLastPage = filteredCached.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(filteredCached);
      } else {
        final firstPage = filteredCached.take(_pageSize).toList();
        _pagingController.appendPage(firstPage, 2);
      }
    }
  }

  Future<void> _fetchPage(int pageKey, {bool useDNS = true}) async {
    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/events/$userId?page=$pageKey&limit=$_pageSize') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/events/$userId?page=$pageKey&limit=$_pageSize'); // Use IP
        
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
        List<Event> filteredItems = _filterEvents(newItems);
        setState(() {
          fetchedEvents = newItems;
        });

        if (pageKey == 1) {
          _pagingController.itemList = [];
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
      } else if (response.statusCode == 302) {
        if(_isReloading){
          _handleHTTPRedirect();
        }
      } else {
        _pagingController.error = 'Failed to load events';
      }
    }  on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _fetchPage(pageKey, useDNS: false); // Recursive retry
          return;
        }
      }
    } catch (error) {
      _pagingController.error = error;
    } finally {
      setState(() {
        _isReloading = false;
      });
    }
  }

  List<Event> _filterEvents(List<Event> events) {
    List<Event> filtered = events;
    
    // Apply category filter
    if (_selectedCategory != null && _selectedCategory != 'All') {
      filtered = _selectedCategory == 'My Events'
          ? filtered.where((event) => event.userId == userId).toList()
          : filtered.where((event) => event.category == _selectedCategory).toList();
    }
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((event) => 
          event.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    setState(() {
      numberOfActiveEvents = filtered.where((event) => event.status == "active").length;
    });
    return filtered;
  }



  void _handleHTTPRedirect() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: const Text('Could not connect to the server. Please check your internet connection.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _webSocketService.disconnect();
    _pagingController.dispose();
    _searchController.dispose();
    super.dispose();
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
                _searchController.clear();
                _onSearchChanged();
              },
            ),
        ],
        onChanged: (value) => _onSearchChanged(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Events($numberOfActiveEvents)'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            color: isDarkMode ? Colors.white70 : Colors.orange[800],
            onPressed: () {
              setState(() {
                _isSearchBarVisible = !_isSearchBarVisible;
                _searchController.clear();
                _onSearchChanged();
              });
            },
          ),

          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list, color: Colors.orange[800]),
            onSelected: (String category) {
              setState(() {
                _selectedCategory = category == 'All' ? null : category;
              });
              _pagingController.itemList = _filterEvents(fetchedEvents);
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
          _isSearchBarVisible ?
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: _buildSearchBar(isDarkMode),
          ) : 
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          ),
          Expanded(
            child: PagedListView<int, Event>(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              pagingController: _pagingController,
              builderDelegate: PagedChildBuilderDelegate<Event>(
                itemBuilder: (context, event, index) {
                  return EventCard(
                    event: event, 
                    userId: userId, 
                    refreshMethod: _handleWebSocketUpdate,
                    useDNS: useDNS_2,
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
                        setState(() {
                          _isReloading = true;
                        });
                        _fetchPage(1);
                        _pagingController.refresh();
                      },
                      child: const Text('Reload'),
                    ),
                  ],
                ),
                newPageErrorIndicatorBuilder: (_) => const Center(
                  child: Text('Error loading more events'),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ((userRole == "admin") || (userRole == "organizer"))
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PostEventPage(refreshMethod: _handleWebSocketUpdate),
                  ),
                );
              },
              backgroundColor: Colors.orange[800],
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
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
