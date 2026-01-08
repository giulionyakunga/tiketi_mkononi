import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:tiketi_mkononi/widgets/favorite_event_card.dart';

class FavoriteEventsPage extends StatefulWidget {
  final int userId;
  const FavoriteEventsPage({super.key, required this.userId});

  @override
  State<FavoriteEventsPage> createState() => _FavoriteEventsPageState();
}

class _FavoriteEventsPageState extends State<FavoriteEventsPage> {
  int numberOfEvents = 0;
  List<Event> fetchedEvents = [];

  static const _pageSize = 30;
  final PagingController<int, Event> _pagingController = PagingController(firstPageKey: 1);

  @override
  void initState() {
    super.initState();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
    _init();
  }

  Future<void> _init() async {
    await _loadCachedEvents();
    // Trigger the first page load
    _pagingController.refresh();
  }

  Future<void> _loadCachedEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('favorite_events');

    if (cachedData != null) {
      final List<dynamic> jsonList = jsonDecode(cachedData);
      final cachedEvents = jsonList.map((json) => Event.fromJson(json)).toList();
      setState(() {
        fetchedEvents = cachedEvents;
        numberOfEvents = cachedEvents.length;
      });

      final isLastPage = cachedEvents.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(cachedEvents);
      } else {
        final firstPage = cachedEvents.take(_pageSize).toList();
        _pagingController.appendPage(firstPage, 2);
      }
    }
  }

  Future<void> _fetchPage(int pageKey, {bool useDNS = true}) async {

    try {
      if (widget.userId == 0) return; // Don't fetch if we don't have a user ID yet

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/favorite_events/${widget.userId}?page=$pageKey&limit=$_pageSize') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}favorite_events/${widget.userId}?page=$pageKey&limit=$_pageSize'); // Use IP

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
        setState(() {
          fetchedEvents = newItems;
          numberOfEvents = newItems.length;
        });

        if (pageKey == 1) {
          // Clear existing items when refreshing
          _pagingController.itemList = null;
          // Cache the new data
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('favorite_events', jsonEncode(jsonList));
        }

        final isLastPage = newItems.length < _pageSize;
        if (isLastPage) {
          _pagingController.appendLastPage(newItems);
        } else {
          final nextPageKey = pageKey + 1;
          _pagingController.appendPage(newItems, nextPageKey);
        }
      } else {
        _pagingController.error = 'Failed to load history';
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _fetchPage(pageKey, useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (error) {
      _pagingController.error = error;
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _handleSocketException(SocketException e) {
    if (e.osError?.errorCode == 7 || e.osError?.errorCode == 101 || e.osError?.errorCode == 111) {
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
    } else {
      _showSnackBar('Connection Error: ${e.message}');
    }
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {    
    return Scaffold(
      appBar: AppBar(
        title: numberOfEvents == 1 ? 
        Text(
          'Favorite Events: $numberOfEvents Event',
          style: const TextStyle(
            fontSize: 17,
          )
        ) 
        : Text(
          'Favorite Events: $numberOfEvents Events',
          style: const TextStyle(
            fontSize: 17,
          )
        ),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                _pagingController.refresh();
                return Future.value(); // Explicitly return a completed future
              },
              child: PagedListView<int, Event>(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                pagingController: _pagingController,
                builderDelegate: PagedChildBuilderDelegate<Event>(
                  itemBuilder: (context, event, index) {
                    return FavoriteEventCard(
                      event: event, 
                      userId: widget.userId, 
                    );
                  },
                  noItemsFoundIndicatorBuilder: (_) =>
                      const Center(child: Text('No record found')),
                  firstPageErrorIndicatorBuilder: (_) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Error loading history'),
                      ElevatedButton(
                        onPressed: () => _pagingController.refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  newPageErrorIndicatorBuilder: (_) => const Center(
                    child: Text('Error loading more history'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}