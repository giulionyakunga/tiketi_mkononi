import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/models/transaction_data.dart';
import 'package:tiketi_mkononi/screens/tickets_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  final Event event;
  final Function refreshMethod;

  const CheckoutPage({
    super.key, 
    required this.event, 
    required this.refreshMethod
  });

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> with WidgetsBindingObserver {
  int userId = 0;
  late final StorageService _storageService;
  int eventId = 0; 
  int quantity = 1;
  double ticketPrice = 0.0;
  String ticketTypeName = "";
  int numberOfTickets = 0;
  int soldTickets = 0;
  double totalPrice = 0.0;
  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = ['MIXX BY YAS', 'M-PESA', 'AIRTEL MONEY', 'HALOPESA', 'AZAMPESA'];
  final _phoneNumberController = TextEditingController();
  bool _isLoading = false;
  bool _payed = false;
  bool _sold = false;
  bool soldOut = false;
  bool __processing_payment = false;
  bool _processing_selling = false;
  Timer? _timer;
  bool _isAppActive = true;
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  DateTime _selectedDate2 = DateTime.now();
  int eventTicketsCount = 0;
  Map<String, dynamic> ticketTypesTicketsCount = {};
  late final profile;
  late final WebSocketService _webSocketService;

  @override
  void initState() {
    super.initState();
    getTicketsCount();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
    _loadUserProfile();
  }

  void _loadUserProfile() {
    profile = _storageService.getUserProfile();
    if (profile != null) {

      setState(() {
        userId = profile.id;
        _phoneNumberController.text = profile.phoneNumber;
      });
    }
  }
  
  Future<void> getTicketsCount({bool useDNS = true}) async {

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/event_tickets_count/${widget.event.id}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}event_tickets_count/${widget.event.id}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if((responseData['tickets_count']) != null){
          setState(() {
            eventTicketsCount = responseData['tickets_count'];
            ticketTypesTicketsCount = responseData['ticket_types'];
          });
        }
        
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
          await getTicketsCount(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching check tickets scan status: $e');
    }
  }
  
  Future<void> getTicketsCountByDate({bool useDNS = true}) async {

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/event_tickets_count_by_date/${widget.event.id}/${DateFormat('d-M-yyyy').format(_selectedDate2)}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}event_tickets_count_by_date/${widget.event.id}/${DateFormat('d-M-yyyy').format(_selectedDate2)}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if((responseData['tickets_count']) != null){
          setState(() {
            eventTicketsCount = responseData['tickets_count'];
            ticketTypesTicketsCount = responseData['ticket_types'];
          });
        }
        
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
          await getTicketsCountByDate(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching check tickets scan status: $e');
    }
  }

  int getTicketTypesTicketsCount (Map<String, dynamic> ticketTypesTicketsCount, String name) {

    if (ticketTypesTicketsCount.isNotEmpty) {
      return ticketTypesTicketsCount[name];
    }
    return 0;
  }


  bool checkTicketAvailability() {
    for (var ticketType in widget.event.ticketTypes) {
      if(ticketType.name == ticketTypeName){
        if( ( getTicketTypesTicketsCount(ticketTypesTicketsCount, ticketType.name) + quantity) > ticketType.numberOfTickets ){
          int remainingTickets = ticketType.numberOfTickets - getTicketTypesTicketsCount(ticketTypesTicketsCount, ticketType.name);
          
          if(widget.event.daily_event == 'yes') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Only $remainingTickets $ticketTypeName tickets remain for ${DateFormat('EEE, MMM d, yyyy').format(_selectedDate2)}')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Only $remainingTickets $ticketTypeName tickets available')),
            );
          }
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _handlePaying({bool useDNS = true}) async {
    debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>> _handlePaying");
    if (_formKey.currentState!.validate() && checkTicketAvailability()){
      if(widget.event.daily_event == 'yes') {
        if (_selectedDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select event date')),
          );
          return;
        }
      }

    debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>> _handlePaying... 1");


      String selectedPaymentMethod2 = '';
      if(selectedPaymentMethod == 'M-PESA') {
        selectedPaymentMethod2 = 'Mpesa';
      }else if(selectedPaymentMethod == 'MIXX BY YAS') {
        selectedPaymentMethod2 = 'Tigo';
      }else if(selectedPaymentMethod == 'AIRTEL MONEY') {
        selectedPaymentMethod2 = 'Airtel';
      }else if(selectedPaymentMethod == 'HALOPESA') {
        selectedPaymentMethod2 = 'Halopesa';
      }else if(selectedPaymentMethod == 'AZAMPESA') {
        selectedPaymentMethod2 = 'Azampesa';
      }

      final Map<String, dynamic> requestBody = {
        'user_id': userId,
        'event_id': eventId,
        'quantity': quantity,
        'ticket_price': ticketPrice,
        'ticket_type': ticketTypeName,
        'date': (widget.event.daily_event == 'yes') ? _selectedDate?.toIso8601String()  : null ,
        'selected_payment_method': selectedPaymentMethod2,
        'phone_number': formatPhoneNumber(_phoneNumberController.text),
      };


    debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>> _handlePaying... 2");

      if (widget.event.category.toUpperCase() == "SPORTS") {
        await _storageService.saveUserProfile(profile);
      }

      try {
        setState(() => _isLoading = true);

        final Uri uri = useDNS ? Uri.parse('${backend_url}api/checkout') // Original URL 
        : Uri.parse('${backend_url_with_fallback_ip}checkout'); // Use IP

        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(requestBody),
        );

    debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>> _handlePaying... 3");


        if (response.statusCode == 200) {
    debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>> _handlePaying... 4");
    debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>> response.body : ${response.body}");

          if ((response.body == "Payment failed, Plz check your account!") || 
              (response.body == "Payment Unsuccessful") ||
              response.body.contains("We currently have only")) {
            _showSnackBar(response.body);
          }else if (response.body == "Not routed") {
            _showSnackBar("Malipo hayawezi kukamilika kwa M-Pesa. Tafadhali tumia namba ya mtandao tofauti ili kuendelea na malipo yako");
          }
          else if (response.body == "Invalid msisdn!") {
            _showSnackBar("Muamala Haujakamilika: Namba uliyoweka sio sahihi");
          }
          else if (response.body == "Processing payment!") {
            _webSocketService = ref.read(websocketServiceProvider);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _webSocketService.connect(
                userId,
                eventId,
              );
            });

            setState(() {
              __processing_payment = true;
              _payed = false;
            });
          } else if (response.body == "Payed successfully!" || 
                     response.body == "You have already booked for this event!") {
            setState(() {
              _payed = true;
              __processing_payment = false;
            });
            widget.refreshMethod();
            fetchTickets();
          }
        } else if (response.statusCode == 302) {
          _handleHTTPRedirect();
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
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
            await _handlePaying(useDNS: false); // Recursive retry

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('use_dns', false);
            return;
          }
        }
      } catch (e) {
        _showSnackBar('An error occurred: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSelling({bool useDNS = true}) async {
    if (checkTicketAvailability()){
        try {
          setState(() => _isLoading = true);

          final Uri uri = useDNS ? Uri.parse('${backend_url}api/confirm') // Original URL 
          : Uri.parse('${backend_url_with_fallback_ip}confirm'); // Use IP
        
          final response = await http.post(
            uri,
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
                _sold = true;
                _processing_selling = false;
              });
              widget.refreshMethod();
              fetchTickets();
            }
          }  else if (response.statusCode == 302) {
            _handleHTTPRedirect();
          } else {
            _showSnackBar('Request failed: ${response.statusCode}');
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
              await _handleSelling(useDNS: false); // Recursive retry

              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('use_dns', false);
              return;
            }
          }
        } catch (e) {
          _showSnackBar('An error occurred: $e');
        } finally {
          setState(() => _isLoading = false);
        }
    }
  }


  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> fetchTickets({bool useDNS = true}) async {
    if (!_isAppActive) return;

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/tickets/$userId') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}tickets/$userId'); // Use IP

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_tickets', jsonEncode(dataList));
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

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
    }
  }

  String formatPhoneNumber(String rawNumber) {
    rawNumber = rawNumber.trim();
    if (rawNumber.startsWith('0')) {
      return '255${rawNumber.substring(1)}';
    }
    return rawNumber; 
  }

  String _formatDate(String date) {
    try {
      final DateFormat inputFormat = DateFormat('dd-MM-yyyy');
      final DateTime dateTime = inputFormat.parse(date);
      final DateFormat outputFormat = DateFormat('EEEE, MMMM d, yyyy');
      return outputFormat.format(dateTime);
    } catch (e) {
      return date;
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
            // 'FastHub Solutions',
            'AzamPay',
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
    _webSocketService.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void disconnectWebSocketService() {
    _webSocketService.disconnect();
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

    if (ticketPrice == 0.0) {
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
        soldOut = true;
      }
    }

    totalPrice = ticketPrice * quantity;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          if(_payed || (widget.event.tickets.length > 1))
          ElevatedButton.icon(
            icon: Icon(
              Icons.logout,
              size: 16,
            ),
            label: Text(
              'Tickets(${quantity + widget.event.tickets.length})',
              style: TextStyle(
                fontSize: 12,
              )
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange[800],
              padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => TicketsPage(eventId: widget.event.id),
                ),
              );
            },
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
                if(widget.event.daily_event == 'yes')
                _buildDateSelector(),
                if(widget.event.daily_event == 'yes')
                const SizedBox(height: 20),
                _buildPaymentMethodSelector(isLargeScreen),
                const SizedBox(height: 20),
                _buildPhoneNumberInput(),
                const SizedBox(height: 20),
                if (widget.event.category.toUpperCase() == "SPORTS")
                const SizedBox(height: 20),
                _buildSummaryCard(isVeryLargeScreen),
                const SizedBox(height: 20),
                _buildConnectionStatusSection(),
                const SizedBox(height: 20),
                (widget.event.userId == userId) ?
                _buildSellButton() : _buildCheckoutButton(),
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
            (widget.event.daily_event == 'yes') ? 
            _buildDetailRow('📅', '', 'Everyday') :
            _buildDetailRow('📅', 'Date:', widget.event.date),
            
            (widget.event.time.contains(":")) ?
            _buildDetailRow('⏰', 'Time:', widget.event.time) :
            _buildDetailRow('⏰', '', 'Everytime'),

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
                  return RadioListTile<double>(
                    title: Text(
                      '${ticketType.name} - TSH${NumberFormat('#,##0').format(ticketType.price.toInt())}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    value: ticketType.price,
                    groupValue: ticketPrice,
                    onChanged: (value) {
                      setState(() {
                        ticketPrice = value!;
                        ticketTypeName = ticketType.name;
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

  Widget _buildDateSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('📅 Date', style: TextStyle(fontSize: 16)),
            Row(
              children: [
                _buildDatePicker()
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      if((picked != _selectedDate)) {
        setState(() {
          _selectedDate = picked;
          _selectedDate2 = picked;
        });
        getTicketsCountByDate();
        fetchTickets();
      }
    }
  }

  Widget _buildDatePicker() {
    return TextButton.icon(
      onPressed: () => _selectDate(context),
      icon: Icon(Icons.calendar_today, size: 18, color: Colors.orange[800]), // Optional: Adjust icon size
      label: Text(
        _selectedDate == null
            ? 'Select Date'
            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
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
        side: BorderSide(
          color: _selectedDate == null ? Colors.grey[400]! : Colors.orange[800]!,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector(bool isLargeScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 16, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Payment Method",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const Divider(),
          if (isLargeScreen)
            Row(
              children: paymentMethods.map((method) {
                return Expanded(
                  child: RadioListTile(
                    title: Text(method),
                    value: method,
                    groupValue: selectedPaymentMethod,
                    onChanged: (value) {
                      setState(() => selectedPaymentMethod = value.toString());
                    },
                  ),
                );
              }).toList(),
            )
          else
            Column(
              children: paymentMethods.map((method) {
                return RadioListTile(
                  title: Text(method),
                  value: method,
                  groupValue: selectedPaymentMethod,
                  onChanged: (value) {
                    setState(() => selectedPaymentMethod = value.toString());
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneNumberInput() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Phone Number',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          TextFormField(
            controller: _phoneNumberController,
            decoration: InputDecoration(
              hintText: '255xxxxxxxxx',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange[800]!, width: 2.0),
              ),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            style: const TextStyle(fontSize: 16),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return null;
              } else {
                if (value.length > 15) {
                  return 'Invalid phone number';
                }
                final regex = RegExp(r'^\d{1,3}\d{9}$'); 
                if (!regex.hasMatch(value.trim())) {
                  return 'Invalid number, Number format: 255xxxxxxxxxx';
                }
              }
              return null;
            },
          )
        ]
      )
    );
  }



  Widget _buildConnectionStatusSection() {
    if (!__processing_payment) {
      return Center(
        child: !_payed ? 
        Text(
          "Waiting for payment",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ) :
        ElevatedButton.icon(
          icon: Icon(
            Icons.logout,
            size: 16,
          ),
          label: Text(
            quantity > 1 ? 'View Tickets($quantity)' : 'View Ticket($quantity)',
            style: TextStyle(
              fontSize: 12,
            )
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.orange[800],
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 2,
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TicketsPage(eventId: widget.event.id),
              ),
            );
          },
        )
      );
    }

    return Column(
      children: [
        const SizedBox(height: 8),
        StreamBuilder<bool>(
          stream: _webSocketService.connectionStatusStream,
          builder: (context, snapshot) {
            bool isConnected = snapshot.data ?? false;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isConnected 
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isConnected 
                            ? Colors.green.withOpacity(0.3)
                            : Colors.red.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pulsing dot
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isConnected ? Colors.green : Colors.red,
                          ),
                        ),
                        // Status text
                        Text(
                          isConnected ? '✓ Connected' : '✗ Disconnected',
                          style: TextStyle(
                            color: isConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        StreamBuilder<TransactionData>(
          stream: _webSocketService.transactionDataStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Text(
                  'Waiting for payment confirmation...',
                  style: TextStyle(fontSize: 14),
                ),
              );
            }

            final transactionData = snapshot.data!;
            if (transactionData.id > 0 && transactionData.eventId == widget.event.id) {
              // Use a post-frame callback to update state after build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (transactionData.hasTicket) {
                  setState(() {
                    _payed = true;
                    __processing_payment = false;
                  });
                  disconnectWebSocketService();
                }
              });
            }
            return const Text(
              'Waiting for payment confirmation...',
              style: TextStyle(fontSize: 16),
            );
          },
        ),
      ],
    );
  }





  Widget _buildSummaryCard(final isLargeScreen) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'SUMMARY',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Event: ',
                    style: const TextStyle(
                      fontSize: 18, 
                      color: Colors.grey
                    ),
                  ),
                  TextSpan(
                    text: '${widget.event.name}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              )
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Ticket Type: ',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey
                    ),
                  ),
                  TextSpan(
                    text: '$ticketTypeName',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              )
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Number of Tickets: ',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.grey
                    ),
                  ),
                  TextSpan(
                    text: '$quantity',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              )
            ),
            const SizedBox(height: 12), // Add some spacing
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Date: ',
                    style: const TextStyle(
                      fontSize: 18, 
                      color: Colors.grey
                    ),
                  ),
                  TextSpan(
                    text: ((widget.event.daily_event == 'yes') && (_selectedDate != null)) ? '${_formatDate('${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}')}' : '${_formatDate(widget.event.date)}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              )
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Time: ',
                    style: const TextStyle(
                      fontSize: 18, 
                      color: Colors.grey
                    ),
                  ),
                  TextSpan(
                    text: '${widget.event.time}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              )
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Payment Method: ',
                    style: const TextStyle(
                      fontSize: 18, 
                      color: Colors.grey
                    ),
                  ),
                  TextSpan(
                    text: '$selectedPaymentMethod',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              )
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'Phone Number: ',
                    style: const TextStyle(
                      fontSize: 18, 
                      color: Colors.grey
                    ),
                  ),
                  TextSpan(
                    text: '${_phoneNumberController.text}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              )
            ),
            const SizedBox(height: 12),
            // Total price row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '💰 Total',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(              
                  'TSH${NumberFormat('#,##0').format(totalPrice.toInt())}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: (_payed || soldOut) ?
      ElevatedButton(
        onPressed: _isLoading ? null : _handlePaying,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          soldOut ? "Sold Out" : 'Booked',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ) :
      __processing_payment ? 
      ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Please wait...',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ) :
      ElevatedButton(
        onPressed: _isLoading ? null : _handlePaying,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              'Pay Now', 
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
      ),
    );
  }

  Widget _buildSellButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: (_sold || soldOut) ?
      ElevatedButton(
        onPressed: (soldOut) ? null : _handleSelling,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[800],
          disabledBackgroundColor: Colors.orange[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          soldOut ? "Sold Out" : 'Sold',
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ) :
      _processing_selling ? 
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
        onPressed: _isLoading ? null : _handleSelling,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange[800],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          :  Text(
              'Sell',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
      ),
    );
  }
}




// final websocketServiceProvider = Provider<WebSocketService>((ref) {

final websocketServiceProvider = Provider.autoDispose<WebSocketService>((ref) {
  return WebSocketService();
});

class WebSocketService {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  Timer? _timeoutTimer;

  bool _isDisposed = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  DateTime? _lastReceivedTime;

  final int maxReconnectAttempts = 1000;
  final Duration reconnectInterval = const Duration(seconds: 2);
  final Duration heartbeatInterval = const Duration(seconds: 15);
  final Duration connectionTimeout = const Duration(seconds: 10);
  final Duration pingTimeout = const Duration(seconds: 30);

  int? _userId;
  int? _eventId;
  bool _useDNS = true;

  late final StreamSubscription _connectivitySubscription;

  final _connectionStatusController = StreamController<bool>.broadcast(sync: true);
  final _transactionDataController = StreamController<TransactionData>.broadcast(sync: true);

  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;
  Stream<TransactionData> get transactionDataStream => _transactionDataController.stream;

  WebSocketService() {
    _listenToConnectivity();
  }

  /// 🔌 Listen to network changes
  void _listenToConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
      if (_isDisposed) return;

      final hasInternet = result != ConnectivityResult.none;
      debugPrint('🌐 Connectivity changed: $result (hasInternet: $hasInternet, _isDisposed: $_isDisposed, _isConnected: $_isConnected, _isConnecting: $_isConnecting)');
      
      debugPrint('🌐 Internet restored → attempting reconnection');
      _handleConnectionLost('Connectivity lost');
    });
  }

  /// 🔗 Connect with timeout
  Future<void> connect(
    int userId,
    int eventId,
    { bool useDNS = true }
  ) async {
    debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> _isDisposed : $_isDisposed');

    if (_isDisposed) return;

    debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 22 _isDisposed : $_isDisposed');
    
    _userId = userId;
    _eventId = eventId;
    _useDNS = useDNS;
    _isConnecting = true;

    // Cancel any pending reconnection
    _cancelReconnection();

    try {
      final uri = Uri.parse(
        useDNS ? backend_ws_url : backend_ws_url_with_fallback_ip,
      );

      debugPrint('🔗 Connecting to: $uri');

      // Set connection timeout
      _timeoutTimer?.cancel();
      _timeoutTimer = Timer(connectionTimeout, () {
        if (_isConnecting) {
          debugPrint('⏰ Connection timeout');
          _handleConnectionLost('Connection timeout');
        }
      });

      // Close existing socket if any
      if(_isConnected){
        await _closeSocket();
      }

      // Create new connection
      _channel = WebSocketChannel.connect(uri);
      
      // Wait for connection with timeout
      await _channel!.ready.timeout(connectionTimeout);
      
      _timeoutTimer?.cancel();
      _isConnecting = false;
      
      _isConnected = true;
      _reconnectAttempts = 0;
      _lastReceivedTime = DateTime.now();
      
      debugPrint('✅ WebSocket connected successfully');
      _connectionStatusController.add(true);
      _cancelReconnection();

      _startHeartbeat();

      // Send subscription message
      _channel!.sink.add(jsonEncode({
        "user_id": userId,
        "event_id": eventId,
        "type": "subscribe",
        "data": "transaction",
      }));

      // Listen for messages
      _channel!.stream.listen(
        (message) => _handleIncomingMessage(message),
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          _handleConnectionLost('WebSocket error: $error');
        },
        onDone: () {
          debugPrint('🔌 WebSocket connection closed');
          _handleConnectionLost('Connection closed by server');
        },
        cancelOnError: true,
      );

    }  on WebSocketChannelException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');

      final inner = e.inner;

      if (inner is SocketException) {
        final osError = inner.osError;

        if (osError != null) {
          debugPrint('  - Error number (errno): ${osError.errorCode}');
          debugPrint('  - OS message: ${osError.message}');
          debugPrint('  - errorCode: ${osError.errorCode}');
          debugPrint('  - useDNS: $useDNS');

          // DNS failure (Windows: 11001, Linux/macOS: 7)
          if ((osError.errorCode == 11001 || osError.errorCode == 7) && useDNS) {
            debugPrint('DNS failed! Retrying with IP: $backend_url_with_fallback_ip...');
            await connect(userId, eventId, useDNS: false); // Recursive retry

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('use_dns', false);
            return;
          }
        }
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
          await connect( userId, eventId, useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
    } catch (e) {
      _timeoutTimer?.cancel();
      _isConnecting = false;
      debugPrint('❌ Connect error: $e');
      _handleConnectionLost('Connect error: $e');
    }
  }

  /// ❤️ Heartbeat with timeout detection
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (!_isConnected) return;

      // Check if we haven't received anything in too long
      if (_lastReceivedTime != null && 
        DateTime.now().difference(_lastReceivedTime!) > pingTimeout) {
        debugPrint('⏰ No response for ${pingTimeout.inSeconds}s, assuming dead connection');
        return;
      }

      try {
        debugPrint('❤️ Sending ping');
        _channel?.sink.add(jsonEncode({"type": "ping"}));
      } catch (_) {
        _handleConnectionLost('Heartbeat failed');
      }
    });
  }

  /// 📩 Incoming messages
  void _handleIncomingMessage(dynamic message) {
    _lastReceivedTime = DateTime.now();
    
    try {
      final data = jsonDecode(message);
      debugPrint('📥 Received: ${data['type']}');
      
      if (data['type'] == 'pong') {
        debugPrint('❤️ Received pong');
        return;
      }
      
      if (data['type'] == 'transaction') {
        _transactionDataController.add(TransactionData.fromJson(data['transaction']));
      }
    } catch (e) {
      debugPrint('⚠️ Parse error: $e');
    }
  }

  /// ❌ Connection lost handler
  void _handleConnectionLost(String reason) {
    if (_isDisposed) return;
    
    debugPrint('❌ WebSocket disconnected: $reason');
    
    // Don't spam the controller
    if (_isConnected) {
      _isConnected = false;
      _connectionStatusController.add(false);
    }
    
    _isConnecting = false;
    _closeSocket();

    debugPrint(' Date : _userId : $_userId, _eventId: $_eventId');
    
    _scheduleReconnection(_userId!, _eventId!);
    debugPrint('Here hcl3');
  
  }



void _scheduleReconnection(
  int userId,
  int eventId,
  { bool immediate = false }
) {
  if (_isDisposed || 
      _reconnectAttempts >= maxReconnectAttempts ||
      _isConnecting ||
      _isConnected) {
    return;
  }

  _reconnectAttempts++;
  
  // Exponential backoff with jitter
  final baseDelay = immediate ? 1 : _reconnectAttempts * 2;
  final delay = Duration(seconds: baseDelay.clamp(1, 60));
  
  // Add some jitter to prevent thundering herd
  final jitter = Random().nextInt(2000) - 1000; // -1000 to +1000 ms
  final jitteredMilliseconds = delay.inMilliseconds + jitter;
  
  // Ensure minimum delay of 100ms
  final finalMilliseconds = jitteredMilliseconds.clamp(100, 60000);
  
  debugPrint('🔁 Reconnecting in ${finalMilliseconds ~/ 1000}s (attempt $_reconnectAttempts/$maxReconnectAttempts)');
  debugPrint('🔁 Reconnecting _isDisposed: ${_isDisposed}, _isConnected: ${_isConnected}, _isConnecting: ${_isConnecting}');

  _reconnectTimer?.cancel();
  _reconnectTimer = Timer(Duration(milliseconds: 1000), () {
    if (!_isDisposed && !_isConnected && !_isConnecting) {
      connect(userId, eventId, useDNS: _useDNS);
    }
  });
}

  /// ✋ Cancel pending reconnection
  void _cancelReconnection() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  /// 🔒 Close socket safely
  Future<void> _closeSocket() async {
    // debugPrint('Here c1');
    _heartbeatTimer?.cancel();
    // debugPrint('Here c2');
    _heartbeatTimer = null;
    // debugPrint('Here c3');
    
    _timeoutTimer?.cancel();
    // debugPrint('Here c4');
    _timeoutTimer = null;
    // debugPrint('Here c5');
    
    try {
      // debugPrint('Here c6');
      await _channel?.sink.close(1000);
      // debugPrint('Here c7');
    } catch (e) {
      // debugPrint('⚠️ Error closing socket: $e');
    } finally {
      _channel = null;
    }
  }

  /// 🔄 Manual reconnect
  Future<void> reconnect() async {
    // debugPrint('🔄 Manual reconnect requested');
    _cancelReconnection();
    _reconnectAttempts = 0;
    
    if (_userId != null && _eventId != null) {
      await connect(_userId!, _eventId!, useDNS: _useDNS);
    }
  }

  /// ⛔ Manual disconnect (temporary)
  void disconnect() {
    debugPrint('⛔ Manual disconnecting'); 
    _isConnected = false;
    _isConnecting = false;
    _cancelReconnection();
    _closeSocket();
    _connectionStatusController.add(false);
  }

  /// 📊 Get connection status
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  int get reconnectAttempts => _reconnectAttempts;

  /// 🧹 Final cleanup
  void dispose() {
    debugPrint('🧹 >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>  Disposing WebSocketService');
    _isDisposed = true;
    disconnect();
    _connectivitySubscription.cancel();
    _transactionDataController.close();
    _connectionStatusController.close();
  }
}
