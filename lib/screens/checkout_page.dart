import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/tickets_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';

class CheckoutPage extends StatefulWidget {
  final Event event;
  final Function refreshMethod;

  const CheckoutPage({
    super.key, 
    required this.event, 
    required this.refreshMethod
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> with WidgetsBindingObserver {
  int userId = 0;
  int trials = 10;
  late final StorageService _storageService;
  int eventId = 0; 
  int quantity = 1;
  double ticketPrice = 0.0;
  String ticketTypeName = "";
  int numberOfTickets = 0;
  int soldTickets = 0;
  double totalPrice = 0.0;
  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = ['MIXX BY YAS', 'AIRTEL MONEY', 'HALOPESA'];
  final _phoneNumberController = TextEditingController();
  bool _isLoading = false;
  bool _payed = false;
  bool soldOut = false;
  bool __processing_payment = false;
  Timer? _timer;
  bool _isAppActive = true;
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  DateTime _selectedDate2 = DateTime.now();
  int eventTicketsCount = 0;
  Map<String, dynamic> ticketTypesTicketsCount = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _startFetchingEventPaymentStatus();
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

  
  Future<void> getTicketsCountByDate({bool useDNS = true}) async {

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/event_tickets_count_by_date/${widget.event.id}/${DateFormat('d-M-yyyy').format(_selectedDate2)}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/event_tickets_count_by_date/${widget.event.id}/${DateFormat('d-M-yyyy').format(_selectedDate2)}'); // Use IP

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
          await getTicketsCountByDate(useDNS: false); // Recursive retry
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
    if (_formKey.currentState!.validate() && checkTicketAvailability()){
      if(widget.event.daily_event == 'yes') {
        if (_selectedDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select event date')),
          );
          return;
        }
      }

      final Map<String, dynamic> requestBody = {
        'user_id': userId,
        'event_id': eventId,
        'quantity': quantity,
        'ticket_price': ticketPrice,
        'ticket_type': ticketTypeName,
        'date': (widget.event.daily_event == 'yes') ? _selectedDate?.toIso8601String()  : null ,
        'selected_payment_method': selectedPaymentMethod,
        'phone_number': formatPhoneNumber(_phoneNumberController.text),
      };

      try {
        setState(() => _isLoading = true);

        final Uri uri = useDNS ? Uri.parse('${backend_url}api/checkout') // Original URL 
        : Uri.parse('${backend_url_with_fallback_ip}api/checkout'); // Use IP

        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          if ((response.body == "Payment failed, Plz check your account!") || 
              (response.body == "Processing payment failed!") || 
              response.body.contains("We currently have only")) {
            _showSnackBar(response.body);
          }
          else if (response.body == "Invalid msisdn!") {
            _showSnackBar("Muamala Haujakamilika: Namba uliyoweka sio sahihi");
          }
          else if (response.body == "Processing payment!") {
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

          // Retry with IP if DNS fails (errno = 7) and not already retrying
          if (e.osError!.errorCode == 7 && useDNS) {
            debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
            await _handlePaying(useDNS: false); // Recursive retry
            return;
          }
        }

        _handleSocketException(e);
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

  void _startFetchingEventPaymentStatus() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_isAppActive) {
        fetchEventPaymentStatus();
      }
    });
  }

  Future<void> fetchEventPaymentStatus({bool useDNS = true}) async {
    if (!_isAppActive || !__processing_payment) return;

    setState(() => trials--);

    if(trials <= 0){
      setState(() {
        trials = 10;
        __processing_payment = false;
      });
    }

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/event/$eventId/$userId') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/event/$eventId/$userId'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        debugPrint('response.body : ${response.body}');
        final responseData = jsonDecode(response.body);
        final transactionDesc = responseData['transaction_description'];

        if (transactionDesc == "SENDER_NOT_ENOUGH_FUND" || transactionDesc == "Please Confirm to submit the loan request") {
          if(__processing_payment) {
            _showSnackBar("Muamala Haujakamilika: Hauna salio la kutosha, Unaweza kuweka namba yenye salio hapo juu");
            setState(() {
              trials = 10;
              __processing_payment = false;
            });
          }
          return;
        } else if (transactionDesc == "Not routed") {
          if(__processing_payment) {
            _showSnackBar("Muamala Haujakamilika: Mfumo hauruhusu malipo kwa M-Pesa, Weka namba ya mtandao mwingine yenye salio hapo juu");
            setState(() {
              trials = 10;
              __processing_payment = false;
            });
          }
          return;
        } else if ((transactionDesc == "Invalid PIN.") || transactionDesc.contains("wrong PIN") ) {
          if(__processing_payment) {
            _showSnackBar("Muamala Haujakamilika: PIN uliyoingiza sio sahihi");
            setState(() {
              trials = 10;
              __processing_payment = false;
            });
          }
          return;
        } else if (transactionDesc == "User is Barred.") {
          if(__processing_payment) {
            _showSnackBar("Muamala Haujakamilika: Akaunti yako imezuiliwa");
            setState(() {
              trials = 10;
              __processing_payment = false;
            });
          }
          return;
        }  else if (transactionDesc == "Failed in Min and Max Amount") {
          if(__processing_payment) {
            _showSnackBar("Muamala Haujakamilika: Failed in Min and Max Amount");
            setState(() {
              trials = 10;
              __processing_payment = false;
            });
          }
          return;
        }

        bool hasTicket = responseData['has_ticket'];

        if(hasTicket && (transactionDesc == "Success")) {
          setState(() {
            _payed = true;
            __processing_payment = false;
          });
        }
      } else {
        throw Exception('Failed to load event');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await fetchEventPaymentStatus(useDNS: false); // Recursive retry
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching event: $e');
    }
  }

  Future<void> fetchTickets({bool useDNS = true}) async {
    if (!_isAppActive) return;

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/tickets/$userId') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/tickets/$userId'); // Use IP

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

  String formatPhoneNumber(String rawNumber) {
    rawNumber = rawNumber.trim();
    if (rawNumber.startsWith('0')) {
      return '255${rawNumber.substring(1)}';
    }
    return rawNumber; 
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
    _timer?.cancel();
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
          TextButton(
            child: _payed ? Text(
              "Tickets($quantity)",
              style: TextStyle(fontSize: 14, color: Colors.green),
            ) : Text(""),
            onPressed: _payed ? () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => TicketsPage(eventId: widget.event.id),
                ),
              );
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
                if(widget.event.daily_event == 'yes')
                _buildDateSelector(),
                if(widget.event.daily_event == 'yes')
                const SizedBox(height: 20),
                _buildPaymentMethodSelector(isLargeScreen),
                const SizedBox(height: 20),
                _buildPhoneNumberInput(),
                const SizedBox(height: 20),
                _buildSummaryCard(isVeryLargeScreen),
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

  Widget _buildSummaryCard(final isLargeScreen) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    text: '$ticketTypeName (x$quantity)',
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
          'Please wait...$trials',
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
}