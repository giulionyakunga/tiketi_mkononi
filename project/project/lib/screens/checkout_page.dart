import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/services/storage_service.dart';

class CheckoutPage extends StatefulWidget {
  final Event event;
  final Function refreshMethod;

  const CheckoutPage({super.key, required this.event, required this.refreshMethod});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> with WidgetsBindingObserver {
  int userId = 0;
  int trials = 30;
  late final StorageService _storageService;
  int eventId = 0;
  int quantity = 1;
  double ticketPrice = 0.0;
  String ticketTypeName = "";
  int numberOfTickets = 0;
  int soldTickets = 0;
  double totalPrice = 0.0;
  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = [/*'M-PESA',*/ 'MIXX BY YAS', 'AIRTEL MONEY', 'HALOPESA'];
  final _phoneNumberController = TextEditingController();
  bool _isLoading = false;
  bool _payed = false;
  bool soldOut = false;
  bool __processing_payment = false;
  Timer? _timer;
  bool _isAppActive = true;
  final _formKey = GlobalKey<FormState>();


  @override
  void initState() {
    super.initState();
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


  Future<void> _handlePaying() async {
    if (_formKey.currentState!.validate() && checkTicketAvailability()){
      try {

        setState(() {
          _isLoading = true;
        });

        String url = '${backend_url}api/checkout';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: '{"user_id": "$userId", "event_id": "$eventId", "quantity": "$quantity", "ticket_price": $ticketPrice, "ticket_type": "$ticketTypeName", "selected_payment_method": "$selectedPaymentMethod", "phone_number": "${_phoneNumberController.text.trim()}"}',
        );

        if (response.statusCode == 200) {
          // _showSnackBar(response.body);
          if ((response.body == "Payment failed, Plz check your account!") || (response.body == "Processing payment failed!") || response.body.contains("We currently have only")) {
            _showSnackBar(response.body);
          }
          else if (response.body == "Invalid msisdn!") {
            _showSnackBar("Transaction denied: Namba uliyoweka sio sahihi");
          }
          else if (response.body == "Processing payment!") {
            setState(() {
              __processing_payment = true;
              _payed = false;
            });
          } else if (response.body == "Payed successfully!" || response.body == "You have already booked for this event!") {
            setState(() {
              _payed = true;
              __processing_payment = false;
            });
            widget.refreshMethod();

            fetchTickets();
          }

        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
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

  void _startFetchingEventPaymentStatus() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isAppActive) {
        fetchEventPaymentStatus();
      }
    });
  }

  /// Fetch events from backend and cache them
  Future<void> fetchEventPaymentStatus() async {

    if (!_isAppActive || !__processing_payment) return; // Prevent fetching when app is inactive

    setState(() {
      trials--;
    });

    if(trials <= 0){
      setState(() {
        trials = 30;
        __processing_payment = false;
      });
    }

    String url = '${backend_url}api/event/$eventId/$userId';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        debugPrint('response.body : ${response.body}');

        if (jsonDecode(response.body)['transaction_description'] == "SENDER_NOT_ENOUGH_FUND") {
          _showSnackBar("Transaction denied: Hauna salio la kutosha, Pia unawe kuweke namba yenye salio hapo juu");
          setState(() {
            trials = 30;
            __processing_payment = false;
          });

          return;
        }

        if (jsonDecode(response.body)['transaction_description'] == "Not routed") {
          _showSnackBar("Transaction denied: Mfumo hauruhusu malipo kwa M-Pesa");
          setState(() {
            trials = 30;
            __processing_payment = false;
          });

          return;
        }

        bool hasTicket = jsonDecode(response.body)['has_ticket'];

        if(hasTicket) {
          setState(() {
            _payed = true;
            __processing_payment = false;
          });
        }
      } else {
        throw Exception('Failed to load event');
      }
    } catch (e) {
      debugPrint('Error fetching event: $e');
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

        // Cache the data locally
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_tickets', jsonEncode(dataList));
        
        _showSnackBar("Tickets fetched and cached Locally");
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
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
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
              color: Colors.blue,
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _isAppActive = false;
    } else if (state == AppLifecycleState.resumed) {
      _isAppActive = true;
    }
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEventDetailsCard(),
            const SizedBox(height: 20),
            _buildTicketSelectionCard(),
            const SizedBox(height: 20),
            _buildQuantitySelector(),
            const SizedBox(height: 20),
            _buildPaymentMethodSelector(),
            const SizedBox(height: 20),
            _buildPhoneNumberInput(),
            const SizedBox(height: 20),
            _buildSummaryCard(),
            const SizedBox(height: 20),
            _buildCheckoutButton(),
            const SizedBox(height: 10),
            _buildPoweredByLabel(),
          ],
        ),
      ),
    );
  }

  Widget _buildEventDetailsCard() {
    return SizedBox(
      width: double.infinity, // Takes full width
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.event.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('📅 Date: ${widget.event.date}'),
              Text('⏰ Time: ${widget.event.time}'),
              Text('📍 Venue: ${widget.event.venue}'),
            ],
          ),
        ),
      )
    );
  }

  Widget _buildTicketSelectionCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: widget.event.ticketTypes.map((ticketType) {
          if (ticketType.soldTickets < ticketType.numberOfTickets) {
            return RadioListTile<double>(
              title: Text('${ticketType.name} - TSH ${ticketType.price.toInt()}', style: Theme.of(context).textTheme.bodyMedium),
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
        }).whereType<Widget>().toList(),
      ),

    );
  }

  Widget _buildQuantitySelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('🎟 Tickets'),
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
      color: Colors.blueAccent,
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
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
    );
  }

  Widget _buildPhoneNumberInput() {
    return 
    Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _phoneNumberController,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              labelStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              prefixIcon: Icon(
                Icons.person,
                color: Colors.grey[600],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: Colors.grey[400]!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(
                  color: Colors.grey[400]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: const BorderSide(
                  color: Colors.blue, // Highlight color when focused
                  width: 2.0,
                ),
              ),
              filled: true,
              fillColor: Colors.grey[200], // Light background color
              contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
            ),
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
            ),
            validator: (value) {
            if (value == null || value.isEmpty) {
              return null; // Return null if the input empty
            }else {
              if (value.length > 15) {
                return 'Invalid phone number';
              }

              // Regex to match: 1 to 3 digits (country code) followed by exactly 9 digits
              final regex = RegExp(r'^\d{1,3}\d{9}$'); 

              if (!regex.hasMatch(value.trim())) {
                return 'Invalid number, Number format: 255xxxxxxxxxx';
              }
            }

            return null; // Return null if the input is valid
          },
          )
        ]
      )
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        title: const Text('💰 Total'),
        trailing: Text('TSH ${totalPrice.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildCheckoutButton() {
    return SizedBox(
      width: double.infinity,
      child: (_payed || widget.event.has_ticket || soldOut) ?
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            disabledBackgroundColor: Colors.blue, // Set background color for disabled state
            disabledForegroundColor: Colors.white, // Set text/icon color when disabled
          ),
          child: _isLoading
          ? const CircularProgressIndicator()
          : Text(
            soldOut ? "Sold Out" : 'Booked',
            style: const TextStyle(
              fontSize: 16,
              // color: Colors.white, // Optional: Set the text color
            ),
          ),
        ),
      ) :
      __processing_payment ? 
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            disabledBackgroundColor: Colors.blue, // Set background color for disabled state
            disabledForegroundColor: Colors.white, // Set text/icon color when disabled
          ),
          child: _isLoading
          ? const CircularProgressIndicator()
          : Text(
            'Please wait...${trials}',
            style: const TextStyle(
              fontSize: 16,
              // color: Colors.white, // Optional: Set the text color
            ),
          ),
        ),
      ) :
      ElevatedButton(
        onPressed: _isLoading ? null : _handlePaying,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: _isLoading ? const CircularProgressIndicator() : const Text('Pay Now', style: TextStyle(fontSize: 16)),
      ),
    );
  }
}
