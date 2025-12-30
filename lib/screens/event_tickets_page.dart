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

  double getTotalCollection() {
    return ticketsList.fold(0, (sum, ticket) => sum + ticket.price);
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
                        isMobile: true,
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
                                isMobile: false,
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
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              (widget.event.type == 'paid') ? 'Total Collection' : 'Total Confirmations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            (widget.event.type == 'paid') ?
            Text(
              'TSH ${NumberFormat('#,##0').format(getTotalCollection().toInt())}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ) : Text(
              '${NumberFormat('#,##0').format(ticketsList.length)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            if(widget.event.type == 'paid')
            Text(
              '${NumberFormat('#,##0').format(ticketsList.length)} tickets sold',
              style: Theme.of(context).textTheme.bodyLarge, 
            ),
            const Divider(),
            Column(
              children: ticketTypesList.map((ticketType) {
                if (ticketType.soldTickets < ticketType.numberOfTickets) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ticketType.name),
                        Text("${ticketType.soldTickets}"),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              }).toList(),
            )
          ],
        ),
      ),
    );
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
  final bool isMobile;

  const TicketCard({
    super.key,
    required this.ticket,
    required this.isMobile,
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

  Future<void> _launchEmailApp(BuildContext context, { required String recipient, String? subject, String? body}) async {
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

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return 
      Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ticket.userName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    (ticket.price > 0.0) 
                        ? 'TSH${NumberFormat('#,##0').format(ticket.price.toInt())}' 
                        : "Free",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4), // Reduced from 8 to 4
              Text(
                'Type: ${ticket.ticketType}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4), // Uniform spacing
              TextButton(
                onPressed: () => _launchPhoneCall(context, ticket.userPhoneNumber),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Phone number: ',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: ticket.userPhoneNumber,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.blue,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4), // Uniform spacing
              TextButton(
                onPressed: () => _launchEmailApp(
                  context,
                  recipient: ticket.userEmail,
                  subject: 'Tiketi_Mkononi',
                  body: '',
                ),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Email: ',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: ticket.userEmail,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.blue,
                          fontWeight: FontWeight.normal,
                          decoration: TextDecoration.underline,
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
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
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
                      ),
                    ),
                  ),
                  Text(
                    (ticket.price > 0.0) ? 'TSH${NumberFormat('#,##0').format(ticket.price.toInt())}' : "Free",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.confirmation_number, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    ticket.ticketType,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    "${ticket.createdAt}",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
  }
}