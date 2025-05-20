import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:http/http.dart' as http;
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
  final List<String> paymentMethods = ['MIXX BY YAS', 'AIRTEL MONEY', 'HALOPESA'];
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
        setState(() => _isLoading = true);

        String url = '${backend_url}api/checkout';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: '{"user_id": "$userId", "event_id": "$eventId", "quantity": "$quantity", "ticket_price": $ticketPrice, "ticket_type": "$ticketTypeName", "selected_payment_method": "$selectedPaymentMethod", "phone_number": "${formatPhoneNumber(_phoneNumberController.text)}"}',
        );

        if (response.statusCode == 200) {
          if ((response.body == "Payment failed, Plz check your account!") || 
              (response.body == "Processing payment failed!") || 
              response.body.contains("We currently have only")) {
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
          } else if (response.body == "Payed successfully!" || 
                     response.body == "You have already booked for this event!") {
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

  Future<void> fetchEventPaymentStatus() async {
    if (!_isAppActive || !__processing_payment) return;

    setState(() => trials--);

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
        final responseData = jsonDecode(response.body);
        final transactionDesc = responseData['transaction_description'];

        if (transactionDesc == "SENDER_NOT_ENOUGH_FUND" || 
            transactionDesc == "Please Confirm to submit the loan request") {
          if(__processing_payment) {
            _showSnackBar("Transaction denied: Hauna salio la kutosha, Pia unaweza kuweka namba yenye salio hapo juu");
            setState(() {
              trials = 30;
              __processing_payment = false;
            });
          }
          return;
        } else if (transactionDesc == "Not routed") {
          if(__processing_payment) {
            _showSnackBar("Transaction denied: Mfumo hauruhusu malipo kwa M-Pesa");
            setState(() {
              trials = 30;
              __processing_payment = false;
            });
          }
          return;
        } else if (transactionDesc == "Invalid PIN.") {
          if(__processing_payment) {
            _showSnackBar("Transaction denied: PIN uliyoingiza sio sahihi");
            setState(() {
              trials = 30;
              __processing_payment = false;
            });
          }
          return;
        }

        bool hasTicket = responseData['has_ticket'];
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
                _buildPaymentMethodSelector(isLargeScreen),
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
                      '${ticketType.name} - TSH ${ticketType.price.toInt()}',
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
      child: (_payed || widget.event.hasTicket || soldOut) ?
      ElevatedButton(
        onPressed: null,
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