import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:tiketi_mkononi/widgets/event_card.dart';
import 'package:tiketi_mkononi/widgets/event_card2.dart';
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
    required this.userId,
  });

  @override
  State<CategoryEventsPage> createState() => _CategoryEventsPageState();
}

class _CategoryEventsPageState extends State<CategoryEventsPage> {
  int userId = 0;
  String userRole = "";
  late final StorageService _storageService;
  static const _pageSize = 30;
  final PagingController<int, Event> _pagingController = PagingController(firstPageKey: 1);
  bool useDNS_2 = true;
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isReloading = false;
  int numberOfActiveEvents = 0;
  List<Event> fetchedEvents = [];
  bool _isSearchBarVisible = false;

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
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    useDNS_2 = await prefs.getBool('use_dns') ?? true;

    await _initializeServices();
    await _loadCachedEvents();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    _connectWebSocket();
    setState(() => _isLoading = false);
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
      final Uri uri = useDNS 
          ? Uri.parse('${backend_url}api/events/$userId?page=1&limit=$_pageSize')
          : Uri.parse('${backend_url_with_fallback_ip}api/events/$userId?page=1&limit=$_pageSize');
        
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
        List<Event> events = _getEventsByCategory(newItems);
        fetchedEvents = events;
        _pagingController.itemList = events;

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_events', jsonEncode(jsonList));
      }
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 7 && useDNS) {
        _handleWebSocketUpdate(useDNS: false);
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
      fetchedEvents = filteredCached;

      setState(() {
        numberOfActiveEvents = filteredCached.where((event) => event.status == "active").length;
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
      final Uri uri = useDNS 
          ? Uri.parse('${backend_url}api/events/$userId?page=$pageKey&limit=$_pageSize')
          : Uri.parse('${backend_url_with_fallback_ip}api/events/$userId?page=$pageKey&limit=$_pageSize');
        
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
        List<Event> events = _getEventsByCategory(newItems);
        fetchedEvents = events;

        setState(() {
          numberOfActiveEvents = events.where((event) => event.status == "active").length;
        });

        if (pageKey == 1) {
          _pagingController.itemList = [];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_events', jsonEncode(jsonList));
        }

        final isLastPage = newItems.length < _pageSize;
        if (isLastPage) {
          _pagingController.appendLastPage(events);
        } else {
          _pagingController.appendPage(events, pageKey + 1);
        }
      } else if (response.statusCode == 302) {
        if(_isReloading){
          _handleHTTPRedirect();
        }
      } else {
        _pagingController.error = 'Failed to load events';
      }
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 7 && useDNS) {
        await _fetchPage(pageKey, useDNS: false);
      } else {
        _pagingController.error = e;
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

  Widget _buildSearchBar(bool isDarkMode, bool isLargeScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isLargeScreen ? 200 : 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDarkMode
              ? colorScheme.surfaceVariant.withOpacity(0.8)
              : colorScheme.surface.withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.1),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDarkMode
                ? colorScheme.outline.withOpacity(0.3)
                : colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search events...',
            hintStyle: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            border: InputBorder.none,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 16, right: 8),
              child: Icon(
                Icons.search_rounded,
                size: isLargeScreen ? 24 : 20,
                color: colorScheme.primary,
              ),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: isLargeScreen ? 24 : 20,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              vertical: isLargeScreen ? 18 : 14,
              horizontal: 16,
            ),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: isLargeScreen ? 16 : 14,
            color: colorScheme.onSurface,
          ),
          cursorColor: colorScheme.primary,
          cursorWidth: 1.5,
          cursorHeight: isLargeScreen ? 20 : 18,
          onChanged: (value) => _onSearchChanged(),
        ),
      ),
    );
  }

  List<Event> _getEventsByCategory(List<Event> events) {
    return events.where((event) => event.category == widget.category).toList();
  }

  // Update the _buildAppBar method to return AppBar (which implements PreferredSizeWidget)
PreferredSizeWidget _buildAppBar(BuildContext context) {
  final theme = Theme.of(context);
  return AppBar(
    title: Text(
      '${widget.category} ($numberOfActiveEvents)',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    ),
    backgroundColor: theme.colorScheme.surface,
    elevation: 1,
    iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
    centerTitle: true,
    actions: [
      IconButton(
        icon: Icon(
          Icons.search,
          color: Colors.orange[800],
        ),
        onPressed: () {
          setState(() {
            _isSearchBarVisible = !_isSearchBarVisible;
            _searchController.clear();
            _onSearchChanged();
          });
        },
      ),
    ]
    // Add any additional AppBar properties you need
  );
}

  int _calculateCrossAxisCount(double screenWidth) {
    if (screenWidth > 1000) return 4;
    if (screenWidth > 768) return 3;
    if (screenWidth > 480) return 2;
    return 2;
  }

  double _calculateAspectRatio(double screenWidth) {
    if (screenWidth > 1000) return 0.65;
    if (screenWidth > 768) return 0.6;
    return 0.8;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 768;
    
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
          children: [
            // Search Bar
            if (_isSearchBarVisible) _buildSearchBar(isDarkMode, isLargeScreen),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _isReloading = true;
                  });
                  await _fetchPage(1);
                },
                child:
                  (!isLargeScreen) ?
                  PagedListView<int, Event>(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    pagingController: _pagingController,
                    builderDelegate: PagedChildBuilderDelegate<Event>(
                      itemBuilder: (context, event, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: EventCard(
                            event: event,
                            userId: userId,
                            refreshMethod: _handleWebSocketUpdate,
                            useDNS: useDNS_2,
                          ),
                        );
                      },
                      noItemsFoundIndicatorBuilder: (_) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 48,
                              color: colorScheme.primary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No events found',
                              style: TextStyle(
                                fontSize: 18,
                                color: colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  });
                                  _pagingController.refresh();
                                },
                                child: const Text('Clear filters'),
                              ),
                          ],
                        ),
                      ),
                      firstPageErrorIndicatorBuilder: (_) => Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading events',
                              style: TextStyle(
                                fontSize: 18,
                                color: theme.colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isReloading = true;
                                });
                                _fetchPage(1);
                                _pagingController.refresh();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      newPageErrorIndicatorBuilder: (_) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Error loading more events',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  :
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = _calculateCrossAxisCount(constraints.maxWidth);
                      final aspectRatio = _calculateAspectRatio(constraints.maxWidth);
                      return
                        PagedGridView<int, Event>(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          pagingController: _pagingController,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: aspectRatio,
                          ),
                          builderDelegate: PagedChildBuilderDelegate<Event>(
                            itemBuilder: (context, event, index) {
                              return EventCard2(
                                event: event,
                                userId: userId,
                                refreshMethod: _handleWebSocketUpdate,
                                useDNS: useDNS_2,
                              );
                            },
                            noItemsFoundIndicatorBuilder: (_) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    size: 48,
                                    color: colorScheme.primary.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No events found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty)
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _searchQuery = '';
                                          _searchController.clear();
                                        });
                                        _pagingController.refresh();
                                      },
                                      child: const Text('Clear filters'),
                                    ),
                                ],
                              ),
                            ),
                            firstPageErrorIndicatorBuilder: (_) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: colorScheme.error,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Error loading events',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: colorScheme.error,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                    ),
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
                            ),
                            newPageErrorIndicatorBuilder: (_) => Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: colorScheme.error,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Error loading more events',
                                    style: TextStyle(color: colorScheme.error),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                    }
                  )
              ),
            ),
          ]
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

    final subscriptionMessage = jsonEncode({
      "user_id": userId,
      "type": "subscribe",
      "data": "events_update"
    });
    
    _channel.sink.add(subscriptionMessage);
    
    _channel.stream.listen(
      (message) {
        final data = jsonDecode(message);
        if (data['type'] == 'events_updated') {
          _onUpdateCallback?.call();
        }
      },
      onError: (error) => debugPrint('WebSocket error: $error'),
      onDone: () => debugPrint('WebSocket connection closed'),
    );
  }

  void disconnect() {
    _channel.sink.close(1000);
  }

  void sendMessage(Map<String, dynamic> message) {
    _channel.sink.add(jsonEncode(message));
  }
}
