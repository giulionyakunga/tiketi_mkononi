import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:tiketi_mkononi/widgets/ticket_card.dart';

class TicketsPage extends StatefulWidget {
  const TicketsPage({super.key});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> with WidgetsBindingObserver {
  int userId = 0;
  late final StorageService _storageService;
  List<Ticket> ticketsList = [];
  List<Ticket> activeTicketsList = [];
  List<Ticket> pastTicketsList = [];
  Timer? _timer;
  bool _isAppActive = true;

  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _loadCachedTickets(); // Load stored ticket first
    _startFetchingTickets();
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
      fetchTickets(); // Then fetch new data
    }
  }

  void _startFetchingTickets() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isAppActive) {
        fetchTickets();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isAppActive = false;
    } else if (state == AppLifecycleState.resumed) {
      _isAppActive = true;
    }
  }

  /// Load stored tickets from SharedPreferences
  Future<void> _loadCachedTickets() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cached_tickets');

    if (cachedData != null) {
      List<dynamic> dataList = jsonDecode(cachedData);
      setState(() {
        ticketsList = dataList.map((json) => Ticket.fromJson(json)).toList();
        activeTicketsList = getActiveTickets(dataList.map((json) => Ticket.fromJson(json)).toList());
        pastTicketsList = getPastTickets(dataList.map((json) => Ticket.fromJson(json)).toList());
      });
    }
  }

  /// Fetch tickets from backend and cache them
  Future<void> fetchTickets() async {
    if (!_isAppActive) return; // Prevent fetching when app is inactive

    String url = '${backend_url}api/tickets/$userId';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body);
        List<Ticket> tickets = dataList.map((json) => Ticket.fromJson(json)).toList();

        setState(() {
          ticketsList = tickets;
          activeTicketsList = getActiveTickets(tickets);
          pastTicketsList = getPastTickets(tickets);
        });

        // Cache the data locally
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_tickets', jsonEncode(dataList));
      } else {
        throw Exception('Failed to load tickets');
      }
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
    }
  }

  List<Ticket> getActiveTickets(List<Ticket> allTickets) {
    final now = DateTime.now();
    
    return allTickets.where((ticket) {
      final eventDateTime = ticket.combinedDateTime;
      return eventDateTime.isAfter(now);
    }).toList();
  }

  List<Ticket> getPastTickets(List<Ticket> allTickets) {
    final now = DateTime.now();
    
    return allTickets.where((ticket) {
      final eventDateTime = ticket.combinedDateTime;
      return eventDateTime.isBefore(now);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Tickets'),
          backgroundColor: const Color.fromARGB(255, 240, 244, 247),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: ticketsList.isEmpty
        ? const Center(child: Text('No tickets found'))
        : 
        TabBarView(
          children: [
            // Upcoming Tickets
            ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: activeTicketsList.length, // Replace with actual ticket count
              itemBuilder: (context, index) {
                return TicketCard(
                  ticket: activeTicketsList[index],
                  fetchTickets: fetchTickets,

                );
              },
            ),
            ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: pastTicketsList.length, // Replace with actual ticket count
              itemBuilder: (context, index) {
                return TicketCard(
                  ticket: pastTicketsList[index],
                  fetchTickets: fetchTickets,
                  isPast: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}