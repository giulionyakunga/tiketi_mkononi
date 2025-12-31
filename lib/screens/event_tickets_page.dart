import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:tiketi_mkononi/screens/edit_ticket_page.dart';
import 'package:tiketi_mkononi/screens/ticket_qr_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:excel/excel.dart' hide Border;  // Hide Excel's Border
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class EventTicketsPage extends StatefulWidget {
  final Event event;
  const EventTicketsPage({super.key, required this.event});

  @override
  State<EventTicketsPage> createState() => _EventTicketsPageState();
}

class _EventTicketsPageState extends State<EventTicketsPage> with WidgetsBindingObserver {
  int userId = 0;
  late final StorageService _storageService;
  List<Ticket> ticketsList = [];
  List<Ticket> ticketsList2 = [];
  List<TicketType> ticketTypesList = [];
  Timer? _timer;
  bool _isAppActive = true;
  DateTime _selectedDate = DateTime.now();
  bool _isSearchBarVisible = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    if(widget.event.daily_event == 'no') {
      String dateStr = widget.event.date; // Format: d-M-yyyy
      _selectedDate = DateFormat('d-M-yyyy').parse(dateStr);
    }

    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _startFetchingTickets();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    ticketsList = _filterTickets(ticketsList2);
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
      fetchTickets();
    }
  }

  void _startFetchingTickets() {
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isAppActive) {
        fetchTickets();
      }
    });
  }

  Future<void> exportTicketsToExcel(List<Ticket> ticketsList, {bool share = false}) async {
    if(ticketsList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No tickets found')),
      );
      return;
    }

    // Create a new Excel document
    final excel = Excel.createExcel();
    final Sheet sheet = excel.sheets['Sheet1']!;

    // Add headers
    sheet.appendRow([
      'Name',
      'Email',
      'Phone Number',
      'Event Name',
      'Date',
      'Time',
      'Ticket Type',
      'Price (TSH)',
      'Attendance'
    ]);

    // Add ticket data
    for (final ticket in ticketsList) {
      sheet.appendRow([
        ticket.userName,
        ticket.userEmail,
        ticket.userPhoneNumber,
        ticket.eventName,
        ticket.date,
        ticket.time,
        ticket.ticketType,
        ticket.price,
        (ticket.scanStatus == 1) ? "Attended": "Missed",
      ]);
    }

    // Calculate summary values
    final numberOfTickets = ticketsList.length;
    final totalAmount = ticketsList.fold<double>(0.0, (sum, ticket) => sum + ticket.price);
    final scannedTicketsCount = ticketsList.where((ticket) => ticket.scanStatus == 1).length;
    final missedTicketsCount = numberOfTickets - scannedTicketsCount;

    // Add an empty row to visually separate data and summary
    sheet.appendRow([' ']);

    // Add summary row
    sheet.appendRow(['Number of Tickets', numberOfTickets.toString()]);
    sheet.appendRow(['Attended', scannedTicketsCount.toString()]);
    sheet.appendRow(['Missed', missedTicketsCount.toString()]);
    sheet.appendRow(['Total Collection ', 'TSH${totalAmount.toStringAsFixed(2)}']);

    // Save the file
    try {
      if(kIsWeb) {
        // Trigger download in browser
        excel.save(fileName: 'Tickets_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx');
      } else {
        if(share) {
            // 2. Save to a temporary file (mobile only)
            final dir = await getTemporaryDirectory();
            final file = File('${dir.path}/Tickets_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx');
            await file.writeAsBytes(excel.encode()!);

            // 3. Share the file
            await Share.shareXFiles(
              [XFile(file.path)],  // Wrap in XFile
              text: 'Check out this tickets data! 📊',  // Optional text
            );
        }else {
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/Tickets_Export_${DateTime.now().millisecondsSinceEpoch}.xlsx';
          final file = File(filePath);
          await file.writeAsBytes(excel.encode()!);

          // Open the file
          await OpenFile.open(filePath);
        }
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      // Handle error (show a snackbar or dialog)
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _searchController.dispose();
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

  
  List<Ticket> _filterTickets(List<Ticket> tickets) {
    List<Ticket> filtered = tickets;
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((ticket) => 
          ticket.userName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    return filtered;
  }

  Future<void> fetchTickets({bool useDNS = true}) async {
    if (!_isAppActive) return;

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/event_tickets/${widget.event.id}/${DateFormat('d-M-yyyy').format(_selectedDate)}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/event_tickets/${widget.event.id}/${DateFormat('d-M-yyyy').format(_selectedDate)}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body)['tickets'];
        List<Ticket> tickets = dataList.map((json) => Ticket.fromJson(json)).toList();

        List<dynamic> dataList2 = jsonDecode(response.body)['ticket_types'];
        List<TicketType> ticketTypes = dataList2.map((json) => TicketType.fromJson(json)).toList();

        setState(() {
          ticketsList = _filterTickets(tickets);
          ticketsList2 = tickets;
          ticketTypesList = ticketTypes;
        });
      } else {
        throw Exception('Failed to load tickets');
      }
    }on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await fetchTickets(useDNS: false); // Recursive retry
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
    }
  }

  Future<void> _updateTicketConfirmStatus(int ticketId, int eventId, int confirmStatus, {bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/update_ticket_confirm_status/${eventId}/${DateFormat('d-M-yyyy').format(_selectedDate)}/$ticketId/${confirmStatus}')
    : Uri.parse('${backend_url_with_fallback_ip}api/update_ticket_confirm_status/${eventId}/${DateFormat('d-M-yyyy').format(_selectedDate)}/$ticketId/${confirmStatus}');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body)['tickets'];
        List<Ticket> tickets = dataList.map((json) => Ticket.fromJson(json)).toList();

        List<dynamic> dataList2 = jsonDecode(response.body)['ticket_types'];
        List<TicketType> ticketTypes = dataList2.map((json) => TicketType.fromJson(json)).toList();

        setState(() {
          ticketsList = _filterTickets(tickets);
          ticketsList2 = tickets;
          ticketTypesList = ticketTypes;
        });
      } else {
        throw Exception('Failed to load tickets');
      }
    }on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await fetchTickets(useDNS: false); // Recursive retry
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
    }
  }

  double getTotalCollection() {
    return ticketsList.fold(0, (sum, ticket) => sum + ticket.price);
  }

  int countConfirmedTickets() {
    return ticketsList.where((ticket) => ticket.confirmStatus == 1).length;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),    // Allow dates as early as year 2000
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      if((picked != _selectedDate)) {
        setState(() {
          _selectedDate = picked;
        });
        fetchTickets();
      }
    }
  }

  Widget _buildSearchBar(bool isDarkMode, bool isLargeScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: 8,
        horizontal: isLargeScreen ? 200 : 0,
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
            hintText: 'Search tickets...',
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

  Widget _buildDatePicker() {
    return TextButton.icon(
      onPressed: () => _selectDate(context),
      icon: const Icon(Icons.calendar_today, size: 18), // Optional: Adjust icon size
      label: Text(
        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w500,
          fontSize: 14, // Smaller font size for compactness
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0), // Near-zero vertical padding
        minimumSize: const Size(0, 30), // Set a small fixed height (e.g., 30 logical pixels)
        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Reduces touch target to content size
        visualDensity: VisualDensity.compact, // Squeezes elements closer
        backgroundColor: Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Colors.black, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDarkMode, bool isLargeScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: // Search Bar
          _isSearchBarVisible ? _buildSearchBar(isDarkMode, isLargeScreen) 
          : const Text('Tickets'),
          backgroundColor: const Color.fromARGB(255, 240, 244, 247),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 📅 Date Picker
                  if (!_isSearchBarVisible)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _buildDatePicker(),
                  ),
                  if (!_isSearchBarVisible)
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    tooltip: 'More Options',
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.orange[800],
                    ),
                    onSelected: (value) {
                      if (value == 'download') {
                        exportTicketsToExcel(ticketsList);
                      } else if (value == 'share') {
                        exportTicketsToExcel(ticketsList, share: true);
                      } else if (value == 'search') {
                        setState(() {
                          _isSearchBarVisible = !_isSearchBarVisible;
                          _searchController.clear();
                          _onSearchChanged();
                        });
                      }
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem(
                        value: 'download',
                        child: Text('Download Excel'),
                      ),
                      if(!kIsWeb)
                      PopupMenuItem(
                        value: 'share',
                        child: Text('Share Excel'),
                      ),
                      PopupMenuItem(
                        value: 'search',
                        child: Text('Search Ticket'),
                      ),
                    ],
                  ),
                  if (_isSearchBarVisible)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                    icon: Icon(
                      Icons.close,
                      color: Colors.orange[800],
                    ),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged();
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _isSearchBarVisible = !_isSearchBarVisible;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],

          bottom: TabBar(
            tabs: [
              Tab(text: 'Tickets'),
              Tab(text: (widget.event.type == 'paid') ? 'Collection' : 'Confirmations'),
            ],
          ),
        ),
        body: ticketsList.isEmpty
            ? Center(
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
                    'No tickets found',
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
                          ticketsList = ticketsList2;
                          _searchController.clear();
                        });
                      },
                      child: const Text('Clear filters'),
                    ),
                ],
              ),
            )
            : TabBarView(
                children: [
                  // Tickets List
                  ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: ticketsList.length,
                    itemBuilder: (context, index) {
                      return TicketCard(
                        ticket: ticketsList[index],
                        event: widget.event,
                        isMobile: true, 
                        userId: userId, 
                        refreshMethod: _updateTicketConfirmStatus, 
                        onTicketUpdated: fetchTickets,
                      );
                    },
                  ),
                  
                  // Collection Tab
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildCollectionSummaryCard(context),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: ticketsList.length,
                            itemBuilder: (context, index) {
                              final ticket = ticketsList[index];
                              return ListTile(
                                title: Text(ticket.userName),
                                subtitle: Text(ticket.ticketType),
                                trailing: (widget.event.type == 'paid') ? Text(
                                  'TSH${NumberFormat('#,##0').format(ticket.price.toInt())}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ) : Text(""),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDesktopLayout(bool isDarkMode, bool isLargeScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: _isSearchBarVisible ? _buildSearchBar(isDarkMode, isLargeScreen) : const Text('Tickets'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
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
          IconButton(
            icon: Icon(
              Icons.download,
              color: Colors.orange[800],
            ),
            onPressed: () {
              setState(() {
                exportTicketsToExcel(ticketsList);
              });
            },
          ),
          _buildDatePicker(),
          const SizedBox(width: 10)
        ],
      ),
      body: ticketsList.isEmpty
          ? Center(
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
                    'No tickets found',
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
                          ticketsList = ticketsList2;
                          _searchController.clear();
                        });
                      },
                      child: const Text('Clear filters'),
                    ),
                ],
              )
            )
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tickets List
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                         Text(
                          'Ticket Sales for ${widget.event.name}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: ticketsList.length,
                            itemBuilder: (context, index) {
                              return TicketCard(
                                ticket: ticketsList[index],
                                event: widget.event,
                                isMobile: false, 
                                userId: userId,
                                refreshMethod: _updateTicketConfirmStatus,
                                onTicketUpdated: fetchTickets,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 24),
                  
                  // Collection Summary
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _buildCollectionSummaryCard(context),
                        const SizedBox(height: 16),
                        const Text(
                          'Recent Sales',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: ticketsList.length,
                            itemBuilder: (context, index) {
                              final ticket = ticketsList[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(ticket.userName),
                                  subtitle: Text(ticket.ticketType),
                                  trailing: (widget.event.type == 'paid') ? Text(
                                    'TSH${NumberFormat('#,##0').format(ticket.price.toInt())}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ) : Text("Free"),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCollectionSummaryCard(BuildContext context) {
    final bool isPaidEvent = widget.event.type == 'paid';
    final bool isWedding = widget.event.category.toUpperCase() == "WEDDING";
    final totalCollection = getTotalCollection().toInt();
    final totalTickets = ticketsList.length;
    final confirmedTickets = countConfirmedTickets();

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      shadowColor: Colors.black.withOpacity(0.1),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey[50]!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPaidEvent ? Icons.attach_money : Icons.people_alt,
                      size: 24,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isPaidEvent ? 'Total Collection' : 'Total Confirmations',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Main Amount/Count
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      isPaidEvent 
                          ? 'TSH ${NumberFormat('#,##0').format(totalCollection)}'
                          : NumberFormat('#,##0').format(totalTickets),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                        fontSize: 28,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPaidEvent ? 'Total Revenue' : 'Total Attendees',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Stats Row
              Row(
                children: [
                  // Tickets Sold
                  Expanded(
                    child: _buildStatItem(
                      context,
                      icon: Icons.confirmation_number,
                      value: NumberFormat('#,##0').format(totalTickets),
                      label: 'Tickets ${isPaidEvent ? 'Sold' : 'Confirmed'}',
                      color: Colors.blue,
                    ),
                  ),
                  
                  // Wedding Confirmed (if applicable)
                  if (isWedding) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatItem(
                        context,
                        icon: Icons.verified_user,
                        value: NumberFormat('#,##0').format(confirmedTickets),
                        label: 'Confirmed',
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // Available Ticket Types
              if (ticketTypesList.any((type) => type.soldTickets < type.numberOfTickets)) ...[
                const Divider(
                  height: 24,
                  thickness: 1,
                  color: Colors.grey,
                ),
                
                Text(
                  'Available Ticket Types',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                ...ticketTypesList.map((ticketType) {
                  if (ticketType.soldTickets < ticketType.numberOfTickets) {
                    final availableTickets = ticketType.numberOfTickets - ticketType.soldTickets;
                    final percentage = (ticketType.soldTickets / ticketType.numberOfTickets) * 100;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ticketType.name,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$availableTickets available',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getProgressColor(percentage),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${ticketType.soldTickets}/${ticketType.numberOfTickets}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget for stat items
  Widget _buildStatItem(BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method for progress colors
  Color _getProgressColor(double percentage) {
    if (percentage < 50) return Colors.green;
    if (percentage < 80) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return isDesktop ? _buildDesktopLayout(isDarkMode, isLargeScreen) : _buildMobileLayout(isDarkMode, isLargeScreen);
  }
}

class TicketCard extends StatelessWidget {
  final Ticket ticket;
  final Event event;
  final bool isMobile;
  final int userId;
  final Function refreshMethod;
  final Function onTicketUpdated;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.event,
    required this.userId,
    required this.isMobile,
    required this.refreshMethod,
    required this.onTicketUpdated,
  });

  Future<void> _launchPhoneCall(BuildContext context, String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  Future<void> _launchEmailApp(BuildContext context,
      {required String recipient, String? subject, String? body}) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: recipient,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );

    try {
      await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch email: $e')),
      );
    }
  }

  // Helper method to get card styling based on confirmStatus
  _CardStyle _getCardStyle(int confirmStatus) {
    switch (confirmStatus) {
      case 1: // Confirmed
        return _CardStyle(
          backgroundColor: Colors.green[50]!,
          borderColor: Colors.green,
          accentColor: Colors.green,
          statusText: 'Confirmed',
          statusIcon: Icons.verified,
        );
      case 0: // Not confirmed
        return _CardStyle(
          backgroundColor: Colors.orange[50]!,
          borderColor: Colors.orange,
          accentColor: Colors.orange,
          statusText: 'Pending',
          statusIcon: Icons.pending,
        );
      default: // Other statuses
        return _CardStyle(
          backgroundColor: Colors.grey[50]!,
          borderColor: Colors.grey,
          accentColor: Colors.grey,
          statusText: 'Unknown',
          statusIcon: Icons.help_outline,
        );
    }
  }

  Widget _buildStatusTicks() {
    if (ticket.smsSent == true && ticket.whatsappSent == true) {
      // Two blue ticks
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 16, color: Colors.blue),
        ],
      );
    } else if (ticket.smsSent == true) {
      // Two grey ticks (SMS sent but WhatsApp not sent)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all, size: 16, color: Colors.grey),
        ],
      );
    } else {
      // One grey tick (nothing sent)
      return Icon(Icons.done, size: 16, color: Colors.grey);
    }
  }

  // Method to navigate to edit ticket page
  void _navigateToEditTicket(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditTicketPage(
          userId: userId,
          ticket: ticket,
          event: event,
          refreshMethod: () => onTicketUpdated(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardStyle = _getCardStyle(ticket.confirmStatus);

    if (isMobile) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: cardStyle.borderColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardStyle.backgroundColor,
                cardStyle.backgroundColor.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row with status badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            ticket.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cardStyle.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardStyle.accentColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cardStyle.statusIcon,
                                size: 14,
                                color: cardStyle.accentColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                cardStyle.statusText,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: cardStyle.accentColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Price row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ticket Price',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                        Text(
                          (ticket.price > 0.0)
                              ? 'TSH${NumberFormat('#,##0').format(ticket.price.toInt())}'
                              : "Free",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Ticket type
                    _InfoRow(
                      icon: Icons.confirmation_number,
                      iconColor: cardStyle.accentColor,
                      label: 'Type:',
                      value: ticket.ticketType,
                    ),
                    const SizedBox(height: 8),
                    // Contact information
                    _ContactButton(
                      icon: Icons.phone,
                      label: 'Phone:',
                      value: ticket.userPhoneNumber,
                      onPressed: () => _launchPhoneCall(context, ticket.userPhoneNumber),
                      color: cardStyle.accentColor,
                    ),
                    const SizedBox(height: 8),
                    _ContactButton(
                      icon: Icons.email,
                      label: 'Email:',
                      value: ticket.userEmail,
                      onPressed: () => _launchEmailApp(
                        context,
                        recipient: ticket.userEmail,
                        subject: 'Tiketi_Mkononi',
                        body: '',
                      ),
                      color: cardStyle.accentColor,
                    ),
                    const SizedBox(height: 8),
                    _ContactButton(
                      icon: ticket.confirmStatus == 0 ? Icons.check_box_outline_blank : Icons.check_box_rounded,
                      label: ticket.confirmStatus == 0 ? 'Confirm' : 'Unconfirm',
                      value: '',
                      onPressed: () => refreshMethod(ticket.id, ticket.eventId, ticket.confirmStatus == 0 ? 1 : 0),
                      color: cardStyle.accentColor,
                    ),
                    if (userId == ticket.userId) const SizedBox(height: 12),
                    if (userId == ticket.userId)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TicketQRPage(ticket: ticket, event: event),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code, size: 20),
                          label: const Text('Show Ticket QR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cardStyle.accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    
                    // Add extra space at the bottom for the icons
                    SizedBox(height: 24),
                  ],
                ),
              ),

              // Bottom left: Edit icon (only for ticket owner or admin)
              if (userId == ticket.userId) // Add your admin check logic here
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(Icons.edit, size: 18, color: Colors.blue),
                      onPressed: () => _navigateToEditTicket(context),
                      padding: EdgeInsets.all(6),
                      constraints: BoxConstraints(),
                    ),
                  ),
                ),

              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildStatusTicks(),
                      if (ticket.smsSent == true && ticket.whatsappSent == true) SizedBox(width: 4),
                      if (ticket.smsSent == true && ticket.whatsappSent == true)
                      Text(
                        'Sent',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Desktop version
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: cardStyle.borderColor.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        margin: const EdgeInsets.only(bottom: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardStyle.backgroundColor,
                cardStyle.backgroundColor.withOpacity(0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            ticket.userName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cardStyle.accentColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: cardStyle.accentColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                cardStyle.statusIcon,
                                size: 16,
                                color: cardStyle.accentColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                cardStyle.statusText,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cardStyle.accentColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _InfoRow(
                          icon: Icons.confirmation_number,
                          iconColor: cardStyle.accentColor,
                          label: 'Ticket Type:',
                          value: ticket.ticketType,
                          isDesktop: true,
                        ),
                        _InfoRow(
                          icon: Icons.attach_money,
                          iconColor: cardStyle.accentColor,
                          label: 'Price:',
                          value: (ticket.price > 0.0)
                              ? 'TSH${NumberFormat('#,##0').format(ticket.price.toInt())}'
                              : "Free",
                          valueStyle: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                          isDesktop: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.calendar_today,
                      iconColor: cardStyle.accentColor,
                      label: 'Created:',
                      value: "${ticket.createdAt}",
                      isDesktop: true,
                    ),
                    
                    // Add extra space at the bottom for the icons
                    SizedBox(height: 24),
                  ],
                ),
              ),

              // Bottom left: Edit icon (desktop)
              if (userId == ticket.userId)
              Positioned(
                bottom: 12,
                left: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit, size: 20, color: Colors.blue),
                    onPressed: () => _navigateToEditTicket(context),
                    padding: EdgeInsets.all(8),
                    constraints: BoxConstraints(),
                  ),
                ),
              ),

              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _buildStatusTicks(),
                      SizedBox(width: 6),
                      Text(
                        'Notification Status',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }
}

// Helper class for card styling
class _CardStyle {
  final Color backgroundColor;
  final Color borderColor;
  final Color accentColor;
  final String statusText;
  final IconData statusIcon;

  _CardStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.accentColor,
    required this.statusText,
    required this.statusIcon,
  });
}

// Reusable info row widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final TextStyle? valueStyle;
  final bool isDesktop;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueStyle,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: isDesktop ? 18 : 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: valueStyle ??
              Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
        ),
      ],
    );
  }
}

// Reusable contact button widget
class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onPressed;
  final Color color;

  const _ContactButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.normal,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}