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
import 'package:tiketi_mkononi/widgets/event_card2.dart';

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
    'Wedding',
    'My Events'
  ];

  late final StorageService _storageService;
  static const _pageSize = 30;
  final PagingController<int, Event> _pagingController = PagingController(firstPageKey: 1);

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
  }

  void _handleEventsUpdate({bool useDNS = true}) async {
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
          _handleEventsUpdate(useDNS: false); // Recursive retry
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

    // Apply visibility filter
    if (_selectedCategory != 'My Events') {
      filtered = filtered.where((event) => event.visibility == 'public').toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((event) => event.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
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
              ? colorScheme.surfaceContainerHighest.withOpacity(0.8)
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
                color: isDarkMode ? Colors.white70 : Colors.orange[800]
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

  Widget _buildCategoryChip(String category) {
    final isSelected = _selectedCategory == category || 
                      (category == 'All' && _selectedCategory == null);
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(category),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? (category == 'All' ? null : category) : null;
          });
          _pagingController.itemList = _filterEvents(fetchedEvents);
        },
        selectedColor: Colors.orange[800],
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : colorScheme.onSurface,
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: Text('Events ($numberOfActiveEvents)'),
        backgroundColor: colorScheme.surface,
        elevation: 1,
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
          if (!isLargeScreen)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.filter_list,
                color: Colors.orange[800],
              ),
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
                          Icon(
                            Icons.check,
                            color: colorScheme.primary,
                          ),
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
          // Search Bar
          if (_isSearchBarVisible) _buildSearchBar(isDarkMode, isLargeScreen),

          // Category Chips (for large screens)
          if (isLargeScreen)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _categories
                    .map((category) => _buildCategoryChip(category))
                    .toList(),
              ),
            ),

          // Event List
          if(!isLargeScreen)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _isReloading = true;
                });
                await _fetchPage(1);
              },
              color: Colors.orange[800],
              child: PagedListView<int, Event>(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                pagingController: _pagingController,
                builderDelegate: PagedChildBuilderDelegate<Event>(
                  itemBuilder: (context, event, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: EventCard(
                        event: event,
                        userId: userId,
                        refreshMethod: _handleEventsUpdate,
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
                        if (_selectedCategory != null || _searchQuery.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
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
              ),
            ),
          ),
          if(isLargeScreen)
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _isReloading = true;
                });
                await _fetchPage(1);
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = _calculateCrossAxisCount(constraints.maxWidth);
                  final aspectRatio = _calculateAspectRatio(constraints.maxWidth);

                  return PagedGridView<int, Event>(
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
                          refreshMethod: _handleEventsUpdate,
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
                            if (_selectedCategory != null || _searchQuery.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedCategory = null;
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
                },
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
                    builder: (context) => PostEventPage(
                        refreshMethod: _handleEventsUpdate),
                  ),
                );
              },
              backgroundColor: Colors.orange[800],
              child: Icon(
                Icons.add,
                color: colorScheme.onPrimary,
              ),
            )
          : null,
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
}