import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/bus_ticket.dart';
import 'package:tiketi_mkononi/models/bus_route.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:tiketi_mkononi/widgets/bus_ticket_card.dart';

class BusTicketsPage extends StatefulWidget {
  final int userId;
  final BusRoute busRoute;
  final Function(BusTicket, {bool isDuplicate}) printTickets;
  
  const BusTicketsPage({super.key, required this.userId, required this.busRoute, required this.printTickets});

  @override
  State<BusTicketsPage> createState() => _BusTicketsPageState();
}

class _BusTicketsPageState extends State<BusTicketsPage> with WidgetsBindingObserver {
  late final StorageService _storageService;
  List<BusTicket> ticketsList = [];
  List<BusTicket> bookedTicketsList = [];
  List<BusTicket> cancelledTicketsList = [];
  bool _isAppActive = true;
  bool _isReloading = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _loadCachedTickets(); // Load stored tickets first
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
    fetchTickets(); // Then fetch new data
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
    String? cachedData = prefs.getString('cached_bus_tickets_${widget.busRoute.id}');

    if (cachedData != null) {
      try {
        List<dynamic> dataList = jsonDecode(cachedData);
        setState(() {
          ticketsList = dataList.map((json) => BusTicket.fromJson(json)).toList();
          _filterTicketsByStatus(ticketsList);
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('Error loading cached tickets: $e');
      }
    }
  }

  /// Filter tickets based on status
  void _filterTicketsByStatus(List<BusTicket> tickets) {    
    bookedTicketsList = tickets.where((ticket) {
      return ticket.status == 'booked' || ticket.status == 'paid' || ticket.status == 'confirmed';
    }).toList();
    
    cancelledTicketsList = tickets.where((ticket) {
      return ticket.status == 'cancelled' || ticket.status == 'refunded';
    }).toList();    
  }

  /// Fetch tickets from backend based on bus route ID and cache them
  Future<void> fetchTickets({bool useDNS = true}) async {
    if (!_isAppActive) return; // Prevent fetching when app is inactive

    setState(() {
      _isLoading = true;
    });

    final Uri uri = useDNS 
        ? Uri.parse('${backend_url}api/bus_route_tickets/${widget.userId}/${widget.busRoute.id}') 
        : Uri.parse('${backend_url_with_fallback_ip}bus_route_tickets/${widget.userId}/${widget.busRoute.id}');

    try {

      debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Fetching Tickets at body: ${uri}");

      final response = await http.get(uri);

      debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Response status: ${response.statusCode}");
      debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Response body: ${response.body}");

      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body);
        debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> dataList length: ${dataList.length}");
        
        List<BusTicket> tickets = dataList.map((json) => BusTicket.fromJson(json)).toList();
        debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> tickets count: ${tickets.length}");

        setState(() {
          ticketsList = tickets;
          _filterTicketsByStatus(tickets);
          _isLoading = false;
          _isReloading = false;
        });

        // Cache the data locally
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_bus_tickets_${widget.busRoute.id}', jsonEncode(dataList));
        
        // Show success message if tickets found
        if (tickets.isEmpty) {
          _showSnackBar('No tickets found for this route');
        } else {
          _showSnackBar('Loaded ${tickets.length} tickets');
        }
      } else if (response.statusCode == 302) {
        if (_isReloading) {
          _handleHTTPRedirect();
        }
      } else {
        throw Exception('Failed to load bus tickets: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: $useDNS');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await fetchTickets(useDNS: false); // Recursive retry
          return;
        }
      }

      _handleSocketException(e);

      setState(() {
        _isReloading = false;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('An error occurred: $e');
      _showSnackBar('An error occurred: $e');
      setState(() {
        _isLoading = false;
        _isReloading = false;
      });
    }
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_bus_outlined,
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
            textAlign: TextAlign.center,
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

  Widget _buildTicketList(List<BusTicket> tickets, {bool isCancelled = false}) {
    if (tickets.isEmpty) {
      return _buildEmptyState(
        isCancelled ? 'No cancelled bus tickets found for this route' 
        : 'No booked bus tickets found for this route'
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
            return BusTicketCard(
              ticket: tickets[index],
              busRoute: widget.busRoute,
              printTickets: widget.printTickets,
              isCancelled: isCancelled,
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
            child: BusTicketCard(
              ticket: tickets[index],
              busRoute: widget.busRoute,
              printTickets: widget.printTickets,
              isCancelled: isCancelled,
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bus Tickets'),
              if (widget.busRoute.from.isNotEmpty && widget.busRoute.to.isNotEmpty)
                Text(
                  '${widget.busRoute.from} → ${widget.busRoute.to}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Booked'),
              Tab(text: 'Cancelled'),
            ],
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : ticketsList.isEmpty
            ? _buildEmptyState('No bus tickets found for this route')
            : TabBarView(
                children: [
                  // Booked Tickets (booked, paid, confirmed)
                  _buildTicketList(bookedTicketsList),
                  
                  // Cancelled Tickets (cancelled, refunded)
                  _buildTicketList(cancelledTicketsList, isCancelled: true),
                ],
              ),
      ),
    );
  }
}