import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:tiketi_mkononi/widgets/ticket_card.dart';

class TicketsPage extends StatefulWidget {
  final int eventId;
  const TicketsPage({super.key, required this.eventId});

  @override
  State<TicketsPage> createState() => _TicketsPageState();
}

class _TicketsPageState extends State<TicketsPage> with WidgetsBindingObserver {
  int userId = 0;
  late final StorageService _storageService;
  List<Ticket> ticketsList = [];
  List<Ticket> activeTicketsList = [];
  List<Ticket> pastTicketsList = [];
  bool _isAppActive = true;
  bool _isReloading = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _loadCachedTickets(); // Load stored ticket first
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        _isLoading = false;
      });
    }
  } 

  /// Fetch tickets from backend and cache them
  Future<void> fetchTickets({bool useDNS = true}) async {
    if (!_isAppActive) return; // Prevent fetching when app is inactive

    setState(() {
      _isLoading = true;
    });

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/tickets/$userId') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}tickets/$userId'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body);
        List<Ticket> tickets = dataList.map((json) => Ticket.fromJson(json)).toList();

        setState(() {
          ticketsList = tickets;
          activeTicketsList = getActiveTickets(tickets);
          pastTicketsList = getPastTickets(tickets);
          _isLoading = false;
        });

        // Cache the data locally
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_tickets', jsonEncode(dataList));
      } else if (response.statusCode == 302) {
        if(_isReloading){
          _handleHTTPRedirect();
        }
      } else {
        throw Exception('Failed to load tickets');
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
          await fetchTickets(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);

      if(_isReloading){
        _handleSocketException(e);
        setState(() {
          _isReloading = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('An error occurred: $e');
      _showSnackBar('An error occurred: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Ticket> getActiveTickets(List<Ticket> allTickets) {
    final now = DateTime.now();

    if(widget.eventId != 0){
      return allTickets.where((ticket) {
        final eventDateTime = ticket.combinedDateTime;
        final eventId = ticket.eventId;
        return ((eventDateTime.isAfter(now)) && (eventId == widget.eventId));
      }).toList();
    }
    
    return allTickets.where((ticket) {
      final eventDateTime = ticket.combinedDateTime;
      return eventDateTime.isAfter(now);
    }).toList();
  }

  void _handleSocketException(SocketException e) {
    if (e.osError?.errorCode == 7 || e.osError?.errorCode == 101 || e.osError?.errorCode == 111 || e.osError?.errorCode == 10057) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: const Text('Could not connect to the server. Please check your internet connection.'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      _showSnackBar('Connection Error: ${e.message}');
    }
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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

  List<Ticket> getPastTickets(List<Ticket> allTickets) {
    final now = DateTime.now();

    if(widget.eventId != 0){
      return allTickets.where((ticket) {
        final eventDateTime = ticket.combinedDateTime;
        final eventId = ticket.eventId;
        return ((eventDateTime.isBefore(now)) && (eventId == widget.eventId));
      }).toList();
    }
    
    return allTickets.where((ticket) {
      final eventDateTime = ticket.combinedDateTime;
      return eventDateTime.isBefore(now);
    }).toList();
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.confirmation_num_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          if (_isReloading)
            const CircularProgressIndicator()
          else
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isReloading = true;
                });
                fetchTickets();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Reload Tickets'),
            ),
        ],
      ),
    );
  }

  Widget _buildTicketList(List<Ticket> tickets, {bool isPast = false}) {
    if (tickets.isEmpty) {
      return _buildEmptyState(
        isPast ? 'No past tickets found' : 'No upcoming tickets found'
      );
    }

    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    if (isLargeScreen) {
      // Grid view for tablets and desktops
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _calculateCrossAxisCount(context),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
          ),
          itemCount: tickets.length,
          itemBuilder: (context, index) {
            return TicketCard(
              ticket: tickets[index],
              fetchTickets: fetchTickets,
              isPast: isPast,
            );
          },
        ),
      );
    } else {
      // List view for mobile
      return ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: tickets.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: TicketCard(
              ticket: tickets[index],
              fetchTickets: fetchTickets,
              isPast: isPast,
            ),
          );
        },
      );
    }
  }

  int _calculateCrossAxisCount(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) {
      return 3;
    } else if (screenWidth > 800) {
      return 2;
    } else {
      return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.myTickets),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
            indicatorColor: Theme.of(context).primaryColor,
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: ticketsList.isEmpty ? const Center(child: CircularProgressIndicator())
          : ticketsList.isEmpty
            ? _buildEmptyState('No tick1ets found')
            : TabBarView(
                children: [
                  // Upcoming Tickets
                  _buildTicketList(activeTicketsList),
                  
                  // Past Tickets
                  _buildTicketList(pastTicketsList, isPast: true),
                ],
              ),
      ),
    );
  }
}