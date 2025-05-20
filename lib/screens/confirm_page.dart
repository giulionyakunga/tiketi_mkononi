import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/services/storage_service.dart';

class ConfirmPage extends StatefulWidget {
  final Event event;
  final Function refreshMethod;

  const ConfirmPage({
    super.key, 
    required this.event, 
    required this.refreshMethod
  });

  @override
  State<ConfirmPage> createState() => _ConfirmPageState();
}

class _ConfirmPageState extends State<ConfirmPage> with WidgetsBindingObserver {
  int userId = 0;
  late final StorageService _storageService;
  int eventId = 0;
  int quantity = 1;
  double ticketPrice = 0.0;
  String ticketTypeName = "";
  int numberOfTickets = 0;
  int soldTickets = 0;
  double totalPrice = 0.0;
  final _phoneNumberController = TextEditingController();
  bool _isLoading = false;
  bool _confirmed = false;
  bool full = false;
  bool _processing_confirmation = false;
  bool _isAppActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
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
        _phoneNumberController.text = profile.phoneNumber;
      });
    }
  }

  bool checkTicketAvailability() {
    for (var ticketType in widget.event.ticketTypes) {
      if(ticketType.name == ticketTypeName){
        if( (ticketType.soldTickets + quantity) > ticketType.numberOfTickets ){
          int remainingTickets = ticketType.numberOfTickets - ticketType.soldTickets;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('We currently have only $remainingTickets $ticketTypeName ticket(s) remaining')),
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _handleConfirming() async {
    if (checkTicketAvailability()){
      try {
        setState(() => _isLoading = true);

        String url = '${backend_url}api/confirm';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: '{"user_id": "$userId", "event_id": "$eventId", "quantity": "$quantity", "ticket_price": $ticketPrice, "ticket_type": "$ticketTypeName"}',
        );

        if (response.statusCode == 200) {
          if ((response.body == "Confirmation failed, Plz check your account!") || 
              response.body.contains("We currently have only")) {
            _showSnackBar(response.body);
          } else if (response.body == "Confirmed!" || 
                     response.body == "You have already confirmed for this event!") {
            _showSnackBar(response.body);
            setState(() {
              _confirmed = true;
              _processing_confirmation = false;
            });
            widget.refreshMethod();
            fetchTickets();
          }
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
        }
      } on SocketException catch (e) {
        if (e.osError?.errorCode == 7 || e.osError?.errorCode == 111) {
          showDialog(
            context: context,
            builder: (context) => const AlertDialog(
              title: Text('Connection Error'),
              content: Text('Could not connect to the server. Please check your internet connection.'),
            ),
          );
        } else {
          _showSnackBar('Connection Error occurred: ${e.message}');
        }
      } catch (e) {
        _showSnackBar('An error occurred: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      if(!checkTicketAvailability()){
        _showSnackBar("Not enough tickets available");
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> fetchTickets() async {
    if (!_isAppActive) return;

    String url = '${backend_url}api/tickets/$userId';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_tickets', jsonEncode(dataList));
      } else {
        throw Exception('Failed to load tickets');
      }
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
    }
  }

  Widget _buildPoweredByLabel() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Powered by ',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
          Text(
            'FastHub Solutions',
            style: TextStyle(
              color: Colors.orange[800],
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    final isVeryLargeScreen = screenWidth > 1200;

    eventId = widget.event.id;

    if (ticketTypeName == "") {
      var availableTickets = widget.event.ticketTypes.where((ticket) => ticket.soldTickets < ticket.numberOfTickets).toList();
      if (availableTickets.isNotEmpty) {
        var cheapestTicket = availableTickets.reduce(
          (a, b) => a.price < b.price ? a : b,
        );

        ticketPrice = cheapestTicket.price;
        ticketTypeName = cheapestTicket.name;
        numberOfTickets = cheapestTicket.numberOfTickets;
        soldTickets = cheapestTicket.soldTickets;
      }
      else {
        full = true;
      }
    }

    totalPrice = ticketPrice * quantity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          TextButton(
            child: _confirmed ? Text(
              "Tickets($quantity)",
              style: TextStyle(fontSize: 14, color: Colors.green),
            ) : Text(""),
            onPressed: _confirmed ? () {
              Navigator.pushReplacementNamed(context, '/tickets');
            } : null,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isVeryLargeScreen ? 800 : (isLargeScreen ? 600 : double.infinity),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 24 : 16,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEventDetailsCard(isLargeScreen),
                const SizedBox(height: 20),
                _buildTicketSelectionCard(),
                const SizedBox(height: 20),
                _buildQuantitySelector(),
                const SizedBox(height: 20),
                _buildSummaryCard(),
                const SizedBox(height: 20),
                _buildCheckoutButton(),
                const SizedBox(height: 10),
                _buildPoweredByLabel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventDetailsCard(bool isLargeScreen) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.event.name, 
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: isLargeScreen ? 22 : 18,
              )
            ),
            const SizedBox(height: 12),
            _buildDetailRow('📅', 'Date:', widget.event.date),
            _buildDetailRow('⏰', 'Time:', widget.event.time),
            _buildDetailRow('📍', 'Venue:', widget.event.venue),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Ticket Type",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            Column(
              children: widget.event.ticketTypes.map((ticketType) {
                if (ticketType.soldTickets < ticketType.numberOfTickets) {
                  return RadioListTile<String>(
                    title: Text(
                      '${ticketType.name} - Free', 
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    value: ticketType.name,
                    groupValue: ticketTypeName,
                    onChanged: (value) {
                      setState(() {
                        ticketTypeName = ticketType.name;
                        ticketPrice = ticketType.price;
                        numberOfTickets = ticketType.numberOfTickets;
                        soldTickets = ticketType.soldTickets;
                      });
                    },
                  );
                }
                return const SizedBox.shrink();
              }).toList(),
            )
          ]
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('🎟 Tickets', style: TextStyle(fontSize: 16)),
            Row(
              children: [
                _buildQuantityButton(Icons.remove, () => setState(() => quantity = (quantity > 1) ? quantity - 1 : 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(quantity.toString(), style: const TextStyle(fontSize: 18)),
                ),
                _buildQuantityButton(Icons.add, () => setState(() => quantity++)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon),
      color: Colors.orange[800],
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '💰 Total',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'TSH ${totalPrice.toInt()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: (_confirmed || widget.event.hasTicket || full) ?
      ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[800],
          disabledBackgroundColor: Colors.orange[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          full ? "Full" : 'Confirmed',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ) :
      _processing_confirmation ? 
      ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Please wait...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ) :
      ElevatedButton(
        onPressed: _isLoading ? null : _handleConfirming,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              'Confirm', 
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
      ),
    );
  }
}