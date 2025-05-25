import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:tiketi_mkononi/widgets/purchase_history_event_card.dart';

class PurchasePistoryPage extends StatefulWidget {
  const PurchasePistoryPage({super.key});

  @override
  State<PurchasePistoryPage> createState() => _PurchasePistoryPageState();
}

class _PurchasePistoryPageState extends State<PurchasePistoryPage> {
  int userId = 0;
  int numberOfEvents = 0;
  String userRole = "";
  List<Event> fetchedEvents = [];

  late final StorageService _storageService;
  static const _pageSize = 30;
  final PagingController<int, Event> _pagingController = PagingController(firstPageKey: 1);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _initializeServices();
    await _loadCachedEvents();
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
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
    String? cachedData = prefs.getString('purchased_events');

    if (cachedData != null) {
      final List<dynamic> jsonList = jsonDecode(cachedData);
      final cachedEvents = jsonList.map((json) => Event.fromJson(json)).toList();
      setState(() {
        fetchedEvents = cachedEvents;
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

  Future<void> _fetchPage(int pageKey) async {
    try {
      final url = Uri.parse('${backend_url}api/purchased_events/$userId?page=1&limit=$_pageSize');
      final response = await http.get(url);

      debugPrint(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> fetching");

      if (response.statusCode == 200) {
        debugPrint(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> response.body : ${response.body}");
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Event.fromJson(json)).toList();
        setState(() {
          fetchedEvents = newItems;
        });

        if (pageKey == 1) {
          _pagingController.itemList = [];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('purchased_events', jsonEncode(jsonList));
        }

        final isLastPage = newItems.length < _pageSize;
        if (isLastPage) {
          _pagingController.appendLastPage(newItems);
        } else {
          final nextPageKey = pageKey + 1;
          _pagingController.appendPage(newItems, nextPageKey);
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
    _pagingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {    
    return Scaffold(
      appBar: AppBar(
        title: numberOfEvents == 1 ? 
        Text(
          'Purchase History: $numberOfEvents Event',
          style: const TextStyle(
            fontSize: 15,
          )
        ) 
        : Text(
          'Purchase History: $numberOfEvents Events',
          style: const TextStyle(
            fontSize: 15,
          )
        ),

        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: Column(
        children: [
          Expanded(
            child: PagedListView<int, Event>(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              pagingController: _pagingController,
              builderDelegate: PagedChildBuilderDelegate<Event>(
                itemBuilder: (context, event, index) {
                  return PurchaseHistoryEventCard(
                    event: event, 
                    userId: userId, 
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
        ],
      ),
    );
  }
}
