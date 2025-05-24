import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

class EventTicketsPage extends StatefulWidget {
  final Event event;
  const EventTicketsPage({super.key, required this.event});

  @override
  State<EventTicketsPage> createState() => _EventTicketsPageState();
}

class _EventTicketsPageState extends State<EventTicketsPage>
    with WidgetsBindingObserver {
  int userId = 0;
  late final StorageService _storageService;
  List<Ticket> ticketsList = [];
  List<TicketType> ticketTypesList = [];
  Timer? _timer;
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
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

  Future<void> fetchTickets() async {
    if (!_isAppActive) return;

    String url = '${backend_url}api/event_tickets/${widget.event.id}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body)['tickets'];
        debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> dataList : $dataList");
        List<Ticket> tickets = dataList.map((json) => Ticket.fromJson(json)).toList();

        debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> tickets : $tickets");

        List<dynamic> dataList2 = jsonDecode(response.body)['ticket_types'];
        List<TicketType> ticketTypes = 
            dataList2.map((json) => TicketType.fromJson(json)).toList();

        setState(() {
          ticketsList = tickets;
          ticketTypesList = ticketTypes;
        });
      } else {
        throw Exception('Failed to load tickets');
      }
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
    }
  }

  double getTotalCollection() {
    return ticketsList.fold(0, (sum, ticket) => sum + ticket.price);
  }

  Widget _buildMobileLayout() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tickets'),
          backgroundColor: const Color.fromARGB(255, 240, 244, 247),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tickets'),
              Tab(text: 'Collection'),
            ],
          ),
        ),
        body: ticketsList.isEmpty
            ? const Center(child: Text('No tickets found'))
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

  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickets'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: ticketsList.isEmpty
          ? const Center(child: Text('No tickets found'))
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
              'Total Collection',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'TSH ${getTotalCollection().toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${ticketsList.length} tickets sold',
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
                        Text("${ticketType.soldTickets} sold"),
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
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
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