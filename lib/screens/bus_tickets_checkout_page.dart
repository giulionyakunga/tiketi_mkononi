
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/bus_route.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/models/bus_ticket.dart';
import 'package:tiketi_mkononi/screens/bus_tickets_page.dart';
import 'package:tiketi_mkononi/services/SimpleCodec.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';


class BusTicketsCheckoutPage extends StatefulWidget {
  final int userId;
  final String role;
  final int companyId;
  final String companyName;
  final BusRoute busRoute;
  final VoidCallback refreshMethod;

  const BusTicketsCheckoutPage({
    super.key,
    required this.userId,
    required this.role,
    required this.companyId,
    required this.companyName,
    required this.busRoute,
    required this.refreshMethod,
  });

  @override
  State<BusTicketsCheckoutPage> createState() => _BusTicketsCheckoutPageState();
}

class _BusTicketsCheckoutPageState extends State<BusTicketsCheckoutPage> with WidgetsBindingObserver {
  late final StorageService _storageService;
  int quantity = 1;
  double ticketPrice = 0.0;
  double totalPrice = 0.0;
  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = ['MIXX BY YAS', 'M-PESA', 'AIRTEL MONEY', 'HALOPESA', 'AZAMPESA'];
  String selectedTicketPaymentMethod = 'CASH';
  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _manualPriceController = TextEditingController();
  final FocusNode _priceFocusNode = FocusNode();
  final TextEditingController _passengerNameController = TextEditingController();
  String issuedBy = '';
  bool _isLoading = false;
  bool _payed = false;
  bool _processingPayment = false;
  Timer? _timer;
  bool _isAppActive = true;
  final _formKey = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  String pickupLocation = '';
  String dropoffLocation = '';

  // Seat selection variables
  List<String> _selectedSeats = [];
  List<String> _bookedSeats = [];
  List<String> _allSeats = [];
  List<BusTicket> busTickets = [];
  int _maxSelectableSeats = 2;

  List<dynamic> receiptPackages = [];
  int receiptsBalance = 0;

  List<BluetoothInfo> devices = [];
  BluetoothInfo? selectedPrinter;

  String receiptFooter = "Karibu Sana";

  @override
  void initState() {
    super.initState();
    pickupLocation = widget.busRoute.startingPoint;
    dropoffLocation = widget.busRoute.finalPoint;
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _initializeSeats();
    _getBookedSeats();
    _startFetchingBookedSeats();
    _setTicketPrice();

    loadAndMatchPrinter();
  }

  void _setTicketPrice() {
    setState(() {
      ticketPrice = widget.busRoute.ticketPrice;
      _manualPriceController.text = '${widget.busRoute.ticketPrice}';
    });
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    receiptsBalance = prefs.getInt('receipts_balance') ?? 0;
    _storageService = StorageService(prefs);
    _loadUserProfile();
  }

  Future<void> _saveReceiptsBalance(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('receipts_balance', value);
  }



  void _loadUserProfile() {
    final profile = _storageService.getUserProfile();
    if (profile != null) {
      setState(() {
        if (widget.companyId == 0) {
          _phoneNumberController.text = profile.phoneNumber;
          _passengerNameController.text = '${profile.firstName} ${profile.lastName}';
        } else {
          issuedBy = profile.firstName;
        }
      });
    }
  }

  void _initializeSeats() {
    List<String> letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];
    List<int> numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26];
    _allSeats = [];
    
    int rows = widget.busRoute.bus?.numberOfSeatRows ?? 14;
    int seatsPerRow = widget.busRoute.bus?.seatsPerRow ?? 4;

    if(widget.busRoute.bus!.isLetteredSeats) {
      for (int row = 0; row < rows; row++) {
        for (int col = seatsPerRow - 1; col >= 0; col--) {
          _allSeats.add('${letters[row]}${col + 1}');
        }
      } 
    } else {
      for (int row = 0; row < rows; row++) {
        for (int col = seatsPerRow; col >= 1; col--) {
          _allSeats.add(
            ('${letters[row]}${((numbers[row] - 1) * 4) + col}')
          );
        }
      }
    }

  }

  void _startFetchingBookedSeats() {
    _timer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_isAppActive) {
        _getBookedSeats();
      }
    });
  }

  bool checkNumberTickets() {
    if (_selectedSeats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one seat')),
      );
      return false;
    }
    return true;
  }

  Future<void> getReceiptPackages({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/receipt_packages') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}receipt_packages'); // Use IP
        
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        debugPrint("response.body : ${response.body}");

        final responseData = jsonDecode(response.body); // This is a List<dynamic>

        if(responseData.length > 0) {
          setState(() {
            receiptPackages = responseData;
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
          await getReceiptPackages(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error getting offices: $e');
    } finally {
      debugPrint('Process finished');
    }
  }

  Future<void> _payDialog() async {
    int? selectedPackage;
    int? selectedReceiptPackages;
    int? selectedAmount;
    String? selectedPaymentMethod;

    final TextEditingController phoneController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              title: const Text(
                "Chagua kifurushi",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    const Divider(height: 4),
                    
                    /// Packages
                    ...receiptPackages
                    .map((pkg) {
                      return RadioListTile(
                        dense: true,  
                        visualDensity: const VisualDensity(vertical: -4),
                        title: Text(
                          "Receipts ${pkg["number_of_receipts"]} - TSH ${pkg["price"]}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: pkg["number_of_receipts"],
                        groupValue: selectedPackage,
                        onChanged: (value) {
                          setState(() {
                            selectedPackage = value;
                            selectedReceiptPackages = value;
                            selectedAmount = pkg["price"] as int;
                          });
                        },
                      );
                    }),

                    const SizedBox(height: 6),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Njia ya Malipo",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),

                    const Divider(height: 10),

                    /// Payment Methods
                    Column(
                      children: paymentMethods.map((method) {
                        return RadioListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -4),
                          title: Text(method, style: const TextStyle(fontSize: 12)),
                          value: method,
                          groupValue: selectedPaymentMethod,
                          onChanged: (value) {
                            setState(() {
                              selectedPaymentMethod = value.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 6),

                    /// Phone
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: "Namba ya simu ya malipo",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// Pay button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _sendPaymentRequest(
                            phoneController.text.trim(),
                            selectedReceiptPackages,
                            selectedAmount,
                          );
                        },
                        child: const Text("Lipa"),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


  Future<void> _sendPaymentRequest(
    String phone,
    int? receipts,
    int? amount,
    {bool useDNS = true}
  ) async {

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number cannot be empty')),
      );
      return;
    }

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/pay_daily_package/${widget.userId}')
    : Uri.parse('${backend_url_with_fallback_ip}pay_daily_package/${widget.userId}'); // Use IP

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

    try {
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "phone_number": phone,
          "receipts": receipts,
          "amount": amount,
          'selected_payment_method': selectedPaymentMethod2,
        }),
      );

      debugPrint('phone_number: $phone');
      debugPrint('receipts: $receipts');
      debugPrint('amount: $amount');

      if (response.statusCode == 200) {
        if (response.body == "Processing payment!") { 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ombi la malipo limetumwa")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
        }

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Malipo yameshindwa")),
        );
      }
    }  on SocketException catch (e) {
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
          await _sendPaymentRequest(phone, receipts, amount, useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }      
    } catch (e) {
      print("Payment error: $e");
    }
  }

  Future<void> _handlePayment({bool useDNS = true}) async {
    if (_isLoading) return;


    if (_formKey3.currentState != null) {
      if (!_formKey3.currentState!.validate()) {
        return;
      }
    }

    if (_formKey2.currentState!.validate() && _formKey.currentState!.validate() && checkNumberTickets()) {
      String selectedTicketPaymentMethod2 = selectedTicketPaymentMethod; 
      switch (selectedTicketPaymentMethod) {
        case 'M-PESA':
          selectedTicketPaymentMethod2 = 'Mpesa';
          break;
        case 'MIXX BY YAS':
          selectedTicketPaymentMethod2 = 'Tigo';
          break;
        case 'AIRTEL MONEY':
          selectedTicketPaymentMethod2 = 'Airtel';
          break;
        case 'HALOPESA':
          selectedTicketPaymentMethod2 = 'Halopesa';
          break;
        case 'AZAMPESA':
          selectedTicketPaymentMethod2 = 'Azampesa';
          break;
      }

      // Check if locations are different from original route
      bool isPickupDifferent = pickupLocation != widget.busRoute.startingPoint;
      bool isDropoffDifferent = dropoffLocation != widget.busRoute.finalPoint;
      
      if ((isPickupDifferent || isDropoffDifferent) && (ticketPrice == widget.busRoute.ticketPrice)  ) {
        bool isValidPrice = await _showCustomRouteDialog();
        if(isValidPrice) {
          return;
        }
      }

      final Map<String, dynamic> requestBody = {
        'user_id': widget.userId,
        'bus_route_id': widget.busRoute.id,
        'company_id': widget.companyId,
        'pickup_location': pickupLocation,
        'dropoff_location': dropoffLocation,
        'quantity': _selectedSeats.length,
        'ticket_price': ticketPrice,
        'passenger_name': (widget.companyId > 0) ? _passengerNameController.text.trim() : '',
        'phone_number': (widget.companyId > 0) ? formatPhoneNumber(_phoneNumberController.text) : '',
        'selected_seats': _selectedSeats,
        'selected_payment_method': selectedTicketPaymentMethod2, 
      };

      try {
        setState(() => _isLoading = true);

        final Uri uri = useDNS 
            ? Uri.parse('${backend_url}api/bus_ticket_checkout')
            : Uri.parse('${backend_url_with_fallback_ip}bus_ticket_checkout');

        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          String message = responseData['message'].trim();

          if (message.contains("Payment failed") || message.contains("Someone is already booking seat")) {
            _getBookedSeats();
            _selectedSeats.clear();
            _showSnackBar(response.body);
          } else if (message == "Not routed") {
            _showSnackBar("Malipo hayawezi kukamilika. Tafadhali tumia namba ya mtandao tofauti");
          } else if (message == "Invalid msisdn!") {
            _showSnackBar("Namba uliyoweka sio sahihi");
          } else if (message == "Processing payment!") {
            setState(() {
              _processingPayment = true;
              _payed = false;
            });
            _startFetchingPaymentStatus();
          } else if (message == "Bus tickets booked successfully!") {
            _selectedSeats.clear();
            receiptsBalance = responseData['number_of_sms'];
            _saveReceiptsBalance(responseData['number_of_sms']);
            receiptFooter = responseData['receipt_footer'];
            _getBookedSeats();

            pickupLocation = widget.busRoute.startingPoint;
            dropoffLocation = widget.busRoute.finalPoint;
            _setTicketPrice();
            _phoneNumberController.text = '';
            _manualPriceController.text = '';
            _passengerNameController.text = '';

            debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> responseData bus_tickets : ${responseData['bus_tickets']}');

            final List<dynamic> jsonList = responseData['bus_tickets']; // Remove jsonDecode
            busTickets = jsonList.map((json) => BusTicket.fromJson(json)).toList();

            if (busTickets.isNotEmpty) {
              for (var busTicket in busTickets) {
                await _printBluetoothReceipt(busTicket);
              }
            }

            _showSuccessDialog();
          } else if (message == "Payed successfully!") {
            setState(() {
              _payed = true;
              _processingPayment = false;
            });
            widget.refreshMethod();
            _selectedSeats.clear();
            _getBookedSeats();
            _fetchTickets();
            _showSnackBar("Payment successful! Your tickets have been booked.");
          } else {
            _showSnackBar(response.body);
          }
        } else if (response.statusCode == 302) {
          _handleHTTPRedirect();
        } else if (response.statusCode == 403) {
          final responseData = jsonDecode(response.body);
          String message = responseData['message'];

          if (message.trim() == "Kifurushi chako kimeisha!") {
            await getReceiptPackages();
            _payDialog();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message.trim())),
            );
          }
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
        }
      } on SocketException catch (e) {
        _handleSocketException(e, useDNS, (retryUseDNS) => _handlePayment(useDNS: retryUseDNS));
      } catch (e) {
        _showSnackBar('An error occurred: $e');
        debugPrint('An error occurred: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
    
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success!'),
          ],
        ),
        content: Text((quantity > 1)? 'Your tickets have been booked successfully.' : 'Your ticket has been booked successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  Future<bool> _showCustomRouteDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(  // Wrap Text with Expanded to prevent overflow
              child: Text(
                'Confirm Price',
                overflow: TextOverflow.visible,  // Allow text to wrap
                softWrap: true,  // Enable text wrapping
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We have detected that you are taking a custom route that differs from the standard route.',
              style: TextStyle(fontSize: 14),
              softWrap: true,  // Enable text wrapping
              overflow: TextOverflow.visible,  // Allow text to wrap
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(  // Use Flexible for long text
                    child: Text(
                      'Ticket Price:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(width: 4),  // Add spacing between text and price
                  Flexible(  // Make price flexible too
                    child: Text(
                      'TSh ${widget.busRoute.ticketPrice.toString()}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Would you like to adjust the ticket price for this custom route?',
              style: TextStyle(fontSize: 14),
              softWrap: true,  // Enable text wrapping
              overflow: TextOverflow.visible,  // Allow text to wrap
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text(
              'Proceed',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, true);
              FocusScope.of(context).requestFocus(_priceFocusNode);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Change Price'),
          ),
        ],
      ),
    ) ?? false;
  }
  
  void _startFetchingPaymentStatus() {
    int checksRemaining = 15;
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isAppActive || !_processingPayment) {
        timer.cancel();
        return;
      }

      checksRemaining--;
      if (checksRemaining <= 0) {
        timer.cancel();
        setState(() {
          _processingPayment = false;
        });
        return;
      }
    });
  }

  Future<void> _getBookedSeats({bool useDNS = true}) async {
    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/bus_booked_seats/${widget.busRoute.id}')
      : Uri.parse('${backend_url_with_fallback_ip}bus_booked_seats/${widget.busRoute.id}');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        debugPrint(' Booked seats : ${response.body}');
        
        final bookedSeats = jsonDecode(response.body);
        setState(() {
          _bookedSeats = List<String>.from(bookedSeats);
        });
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 11001 || e.osError?.errorCode == 7) && useDNS) {
        await _getBookedSeats(useDNS: false);
      }
    } catch (e) {
      debugPrint('Error getting booked seats: $e');
    }
  }

  Future<void> _fetchTickets({bool useDNS = true}) async {
    if (!_isAppActive) return;

    final Uri uri = useDNS
        ? Uri.parse('${backend_url}api/tickets/${widget.userId}')
        : Uri.parse('${backend_url_with_fallback_ip}tickets/${widget.userId}');

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_tickets', jsonEncode(dataList));
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 11001 || e.osError?.errorCode == 7) && useDNS) {
        await _fetchTickets(useDNS: false);
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3))
    );
  }

  void _handleSocketException(SocketException e, bool useDNS, Function(bool) retryFunction) {
    debugPrint('Network error: ${e.message}');
    
    if (e.osError != null && (e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
      debugPrint('DNS failed! Retrying with IP...');
      retryFunction(false);
      return;
    }
    
    _showSnackBar('Connection Error: Please check your internet connection');
  }

  void _handleHTTPRedirect() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Error'),
        content: const Text('Could not connect to the server. Please check your internet connection.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _phoneNumberController.dispose();
    _manualPriceController.dispose();
    _passengerNameController.dispose();
    _priceFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
  }

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String text,
    required String value,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade800,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    totalPrice = ticketPrice * _selectedSeats.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bus Ticket Checkout',
          style: TextStyle(
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            tooltip: 'More Options',
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            icon: Icon(
              Icons.more_vert,
              color: Colors.black,
              size: 22,
            ),
            onSelected: (value) async {
              if (value == 'my_tickets') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusTicketsPage(userId: widget.userId, busRoute: widget.busRoute, printTickets: _printBluetoothReceipt),
                  ),
                );
              } else if (value == 'reprint_receipt') {
                if (busTickets.isNotEmpty) {
                  for (var busTicket in busTickets) {
                    await _printBluetoothReceipt(busTicket);
                  }
                }
              } else if (value == 'refresh_printers') {
                _printBluetoothTestReceipt();
              } else if (value == 'topup_receipt') {
                await getReceiptPackages();
                _payDialog();
              } else if (value == 'exit') {
                Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [    
              _buildMenuItem(
                icon: Icons.confirmation_number,
                text: 'My Tickets',
                value: 'my_tickets',
              ),          
              _buildMenuItem(
                icon: Icons.print,
                text: AppLocalizations.of(context)!.reprintReceipt,
                value: 'reprint_receipt',
              ),
              _buildMenuItem(
                icon: Icons.refresh,
                text: AppLocalizations.of(context)!.refreshPrinters,
                value: 'refresh_printers',
              ),
              _buildMenuItem(
                icon: Icons.account_balance_wallet,
                text: AppLocalizations.of(context)!.receiptsBalance(receiptsBalance.toString()),
                value: 'topup_receipt',
              ),
              _buildMenuItem(
                icon: Icons.add_card,
                text: AppLocalizations.of(context)!.topupReceipt,
                value: 'topup_receipt',
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                icon: Icons.exit_to_app,
                text: AppLocalizations.of(context)!.exit,
                value: 'exit',
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRouteDetailsCard(),
            const SizedBox(height: 20),
            _buildLocationSelectionWidget(),
            const SizedBox(height: 20),
            _buildManualPriceCard(),
            const SizedBox(height: 20),
            _buildSeatSelection(),
            const SizedBox(height: 20),
            _buildPassengerNameInput(),
            if (widget.companyId == 0) ...[
              const SizedBox(height: 20),
              _buildPaymentMethodSelector(),
            ],
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

  String getAmPm(String time24) {
    // Parse "HH:mm"
    final parts = time24.split(':');
    if (parts.length != 2) return "Invalid time format";

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    // Validate
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return "Invalid time format";
    }

    // AM / PM logic
    if (hour < 12) {
      return "$time24 AM";
    } else {
      return "$time24 PM";
    }
  }

  Widget _buildRouteDetailsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.busRoute.from} → ${widget.busRoute.to}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('🚌', 'Bus:', widget.busRoute.bus!.name),
            _buildDetailRow('🏢', 'Company:', widget.busRoute.company!.name),
            _buildDetailRow('📅', 'Departure Date:', widget.busRoute.departureDate),
            _buildDetailRow('⏰', 'Departure Time:', getAmPm(widget.busRoute.departureTime)),
            _buildDetailRow('📅', 'Arrival Date:', widget.busRoute.arrivalDate),
            _buildDetailRow('⏰', 'Arrival Time:', getAmPm(widget.busRoute.arrivalTime)),
            _buildDetailRow('💺', 'Available Seats:', '${widget.busRoute.availableSeats}'),
            _buildDetailRow('💰', 'Price:', 'TSh ${NumberFormat('#,##0').format(ticketPrice.toInt())}'),
            if(widget.userId == widget.busRoute.userId)
            _buildDetailRow('🎟️', 'Total Collection:', 'TSh ${NumberFormat('#,##0').format(widget.busRoute.totalCollection.toInt())}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Add this method to your _BusTicketsCheckoutPageState class
  Widget _buildLocationSelectionWidget() {
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trip Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Pickup Location
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.circle, color: Colors.green, size: 16),
                    ),
                    title: const Text(
                      'Pickup Location',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      pickupLocation,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.swap_vert, color: Colors.grey),
                      onPressed: () {
                        // Swap pickup and dropoff
                        setState(() {
                          String tmpLocation = pickupLocation;
                          pickupLocation = dropoffLocation;
                          dropoffLocation = tmpLocation;
                        });
                      },
                    ),
                    onTap: () => _showLocationPicker(context, isPickup: true),
                  ),
                  
                  // Divider with swap icon
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, thickness: 1),
                  ),
                  
                  // Dropoff Location
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.red, size: 16),
                    ),
                    title: const Text(
                      'Dropoff Location',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      dropoffLocation,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: () => _showLocationPicker(context, isPickup: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to show location picker dialog
  Future<void> _showLocationPicker(BuildContext context, {required bool isPickup}) async {
    final TextEditingController searchController = TextEditingController();
    List<Map<String, String>> searchResults = [];
    
    // Sample locations - replace with your actual data source
    final List<Map<String, String>> allLocations = [
      {'name': 'Mbezi Bus Terminal', 'address': 'Dar es Salaam', 'type': 'terminal'},
      {'name': 'Ubungo Bus Terminal', 'address': 'Ubungo, Dar es Salaam', 'type': 'terminal'},
      {'name': 'Mwenge Bus Stop', 'address': 'Mwenge, Dar es Salaam', 'type': 'stop'},
      {'name': 'Kigamboni Bus Terminal', 'address': 'Kigamboni, Dar es Salaam', 'type': 'terminal'},
      {'name': 'Kimara Bus Stop', 'address': 'Kimara, Dar es Salaam', 'type': 'stop'},
      {'name': 'Mbagala Bus Terminal', 'address': 'Mbagala, Dar es Salaam', 'type': 'terminal'},
    ];
    
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {  // Renamed to avoid confusion
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Search bar
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search for a location...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          searchController.clear();
                          setModalState(() {
                            searchResults = [];
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        if (value.isEmpty) {
                          searchResults = [];
                        } else {
                          searchResults = allLocations
                              .where((loc) => loc['name']!
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                          if (searchResults.isEmpty) {
                            searchResults = [
                              {'name': value.toUpperCase(), 'address': value.toLowerCase(), 'type': 'stop'}
                            ];
                          }
                        }
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Results or recent locations
                  Expanded(
                    child: searchResults.isEmpty && searchController.text.isEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Popular Locations',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: allLocations.length,
                                  itemBuilder: (context, index) {
                                    final location = allLocations[index];
                                    return ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isPickup 
                                              ? Colors.green[50]
                                              : Colors.red[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isPickup 
                                              ? Icons.circle
                                              : Icons.location_on,
                                          color: isPickup 
                                              ? Colors.green
                                              : Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        location['name']!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        location['address']!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        // FIXED: Using parent widget's setState
                                        setState(() {
                                          if (isPickup) {
                                            pickupLocation = location['name']!;
                                          } else {
                                            dropoffLocation = location['name']!;
                                          }
                                        });
                                        debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>>>>> isPickup: $isPickup, location['name']: ${location['name']}");
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final location = searchResults[index];
                              return ListTile(
                                leading: const Icon(Icons.location_on, color: Colors.blue),
                                title: Text(location['name']!),
                                subtitle: Text(location['address']!),
                                onTap: () {
                                  Navigator.pop(context);
                                  // FIXED: Using parent widget's setState
                                  setState(() {
                                    if (isPickup) {
                                      pickupLocation = location['name']!;
                                    } else {
                                      dropoffLocation = location['name']!;
                                    }
                                  });
                                  debugPrint(" >>>>>>>>>>>>>>>>>>>>>>>>>>>>> isPickup: $isPickup, location['name']: ${location['name']}");
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Add this method to your _BusTicketsCheckoutPageState class
  Widget _buildManualPriceCard() {
    bool isCustomRoute = false;
    double customTicketPrice = ticketPrice;
    
    // Check if locations are different from original route
    bool isPickupDifferent = pickupLocation != widget.busRoute.startingPoint;
    bool isDropoffDifferent = dropoffLocation != widget.busRoute.finalPoint;
    
    if (isPickupDifferent || isDropoffDifferent) {
      isCustomRoute = true;
    }
    
    return isCustomRoute
        ? Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.only(bottom: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.orange[50]!,
                    Colors.orange[100]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning/Info header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange[200],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange[900],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Custom Route Detected',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'Pickup/Dropoff locations differ from standard route',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Original route info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          _buildRouteComparisonRow(
                            'Standard Route:',
                            '${widget.busRoute.from} → ${widget.busRoute.to}',
                            Icons.route,
                          ),
                          const SizedBox(height: 8),
                          _buildRouteComparisonRow(
                            'Standard Price:',
                            'TSh ${NumberFormat('#,##0').format(widget.busRoute.ticketPrice.toInt())}',
                            Icons.attach_money,
                          ),
                          if (isPickupDifferent)
                            const SizedBox(height: 8),
                          if (isPickupDifferent)
                            _buildRouteComparisonRow(
                              'Custom Pickup:',
                              pickupLocation,
                              Icons.circle,
                              iconColor: Colors.green,
                            ),
                          if (isDropoffDifferent)
                            const SizedBox(height: 8),
                          if (isDropoffDifferent)
                            _buildRouteComparisonRow(
                              'Custom Dropoff:',
                              dropoffLocation,
                              Icons.location_on,
                              iconColor: Colors.red,
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Manual price input
                    const Text(
                      'Enter Ticket Price',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: const Text(
                            'TSh',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Form(
                            key: _formKey3,
                            child: TextFormField(
                              controller: _manualPriceController,
                              focusNode: _priceFocusNode,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'Enter custom price',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Colors.orange),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                suffixText: 'TZS',
                                suffixStyle: const TextStyle(color: Colors.grey),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty) {
                                  double? price = double.tryParse(value);
                                  if (price != null && price > 0) {
                                    setState(() {
                                      customTicketPrice = price;
                                      ticketPrice = price;
                                      totalPrice = ticketPrice * _selectedSeats.length;
                                    });
                                  }
                                }
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter price';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // // Suggested price options
                    // const Text(
                    //   'Suggested Prices:',
                    //   style: TextStyle(
                    //     fontSize: 12,
                    //     fontWeight: FontWeight.w500,
                    //     color: Colors.grey,
                    //   ),
                    // ),
                    // const SizedBox(height: 8),
                    // Wrap(
                    //   spacing: 8,
                    //   runSpacing: 8,
                    //   children: [
                    //     _buildPriceChip(widget.busRoute.ticketPrice * 0.8, '20% Off'),
                    //     _buildPriceChip(widget.busRoute.ticketPrice, 'Standard'),
                    //     _buildPriceChip(widget.busRoute.ticketPrice * 1.2, '20% Extra'),
                    //     _buildPriceChip(widget.busRoute.ticketPrice * 1.5, 'Premium'),
                    //   ],
                    // ),
                    
                    const SizedBox(height: 12),
                    
                    // Current price display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Ticket Price:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'TSh ${NumberFormat('#,##0').format(customTicketPrice.toInt())}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    if (isPickupDifferent || isDropoffDifferent)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, size: 16, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Custom route prices may vary. Please confirm with bus company.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }

  // Helper method for route comparison rows
  Widget _buildRouteComparisonRow(String label, String value, IconData icon, {Color iconColor = Colors.grey}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Helper method for price chips
  Widget _buildPriceChip(double price, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TSh ${(price).toInt()}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '($label)',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to convert row letter to number (A=1, B=2, etc.)
  int _getRowNumber(String rowLetter) {
    return rowLetter.codeUnitAt(0) - 'A'.codeUnitAt(0) + 1;
  }

  // Helper method to determine if a seat position should be a toilet
  bool _isToiletPosition(int seatIndex, int totalSeatsPerRow) {
    final bus = widget.busRoute.bus;
    if (bus?.isHavingToilet != true) return false;
    
    final bool isToiletAtLeft = bus?.isToiletAtLeftSide ?? true;
    
    // Determine which seats to replace with toilet
    // For a bus with toilet, typically 2 seats are removed on one side
    if (isToiletAtLeft) {
      // Toilet on left side - first 2 seats are toilet
      return seatIndex < 2;
    } else {
      // Toilet on right side - last 2 seats are toilet
      return seatIndex >= totalSeatsPerRow - 2;
    }
  }

  // Build the front row with driver and staff area
  Widget _buildFrontRow() {    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          const SizedBox(width: 20), // Space for row letter (empty for front row)
          const SizedBox(width: 2),
          
          // Left side - Staff seat
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.green[100],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: const Center(
              child: Icon(Icons.assignment_ind, size: 20, color: Colors.green),
            ),
          ),
          
          // Staff label
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: const Text(
              'STAFF',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ),
          
          // Corridor space
          Container(
            width: 24,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: const SizedBox(width: 18),
            ),
          ),

          // Driver label
          const Text(
            'DRIVER',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
          ),

          const SizedBox(width: 2),
          
          // Right side - Driver seat with steering wheel
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.orange[100],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Center(
              child: Image.asset(
                'assets/stearing.png',
                width: 20,
                height: 20,
                color: Colors.orange, // Optional: tint the image
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reorder seats from [4,3,2,1] to [3,4,2,1]
  List<String> _reorderSeats(List<String> seats) {
    if (seats.length != 4) return seats; // Only reorder for 4-seat rows
    
    // Extract seat numbers
    final List<String> reordered = List.from(seats);
    if (reordered.length >= 4) {
      // Swap positions 0 and 1 (0-indexed: swap index 0 and 1)
      final temp = reordered[0];
      reordered[0] = reordered[1];
      reordered[1] = temp;
    }
    return reordered;
  }

  // Build individual seat widget
  Widget _buildSeatWidget(String seat, bool isBooked, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: isBooked ? null : () {
          setState(() {
            if (isSelected) {
              _selectedSeats.remove(seat);
            } else {
              if (_selectedSeats.length < _maxSelectableSeats) {
                _selectedSeats.add(seat);
                _getBookedSeats();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Maximum $_maxSelectableSeats seat${_maxSelectableSeats != 1 ? 's' : ''} can be selected')),
                );
              }
            }
          });
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isBooked ? Colors.black : (isSelected ? Colors.orange[800] : Colors.white),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isBooked ? Colors.grey : Colors.grey[400]!),
          ),
          child: Center(
            child: Text(
              seat.substring(1),
              style: TextStyle(
                color: isBooked || isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build individual seat widget
  Widget _buildEmptySeatWidget(String seat, bool isBooked, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: GestureDetector(
        onTap: isBooked ? null : () {},
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color:Colors.transparent,
          ),
        ),
      ),
    );
  }

  // Check toilet position on specific side
  bool _isToiletPositionOnSide(int seatIndex, int sideSeatCount, bool isLeftSide) {
    final bus = widget.busRoute.bus;
    if (bus?.isHavingToilet != true) return false;
    
    final bool isToiletAtLeft = bus?.isToiletAtLeftSide ?? true;
    
    // Only show toilet on the correct side
    if ((isLeftSide && !isToiletAtLeft) || (!isLeftSide && isToiletAtLeft)) {
      return false;
    }
    
    // Toilet takes 2 seats on the side
    const int toiletSeatCount = 2;
    
    if (isToiletAtLeft) {
      // Toilet on left side - remove last 2 seats of left section
      return seatIndex >= sideSeatCount - toiletSeatCount;
    } else {
      // Toilet on right side - remove first 2 seats of right section
      return seatIndex < toiletSeatCount;
    }
  }

  Widget _buildSeatSelection() {
    final seatsByRow = <String, List<String>>{};
    for (var seat in _allSeats) {
      final row = seat.substring(0, 1);
      seatsByRow.putIfAbsent(row, () => []).add(seat);
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Select Your Seats", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  '${_selectedSeats.length} seat${_selectedSeats.length != 1 ? 's' : ''} selected',
                  style: TextStyle(color: Colors.orange[800]),
                ),
              ],
            ),
            const Divider(),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Center(child: Text('FRONT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                height: (seatsByRow.length + 1) * 48.0, // +1 for front row
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // FRONT ROW (Driver & Staff row)
                      _buildFrontRow(),
                      
                      // Regular seats rows
                      ...seatsByRow.entries.map((entry) {
                        final rowLetter = entry.key;
                        final rowNumber = _getRowNumber(rowLetter);
                        final seats = _reorderSeats(entry.value); // Reorder seats to 1,2,4,3 pattern
                        final totalRows = widget.busRoute.bus?.numberOfSeatRows ?? 0;
                        
                        // Row checks
                        final bool isFirstRow = rowNumber == 1;
                        final bool isThreeSeatsAtFistRow = widget.busRoute.bus?.isThreeSeatsAtFistRow ?? true;
                        final bool isLastRow = rowNumber == totalRows;
                        final bool isToiletRow = widget.busRoute.bus?.isHavingToilet == true && (rowNumber == widget.busRoute.bus?.toiletAtRowNumber);
                        final bool isToiletNextRow = widget.busRoute.bus?.isHavingToilet == true && (rowNumber == (widget.busRoute.bus?.toiletAtRowNumber ?? 0) + 1); // Toilet spans 2 rows
                        final int numberOfRowsThatToiletSpans = widget.busRoute.bus!.numberOfRowsThatToiletSpans;
                        final bool isToiletNextNextRow = ((widget.busRoute.bus?.isHavingToilet == true) && ((rowNumber == (widget.busRoute.bus?.toiletAtRowNumber ?? 0) + 2)) && (numberOfRowsThatToiletSpans > 2)); // Toilet spans 3 rows

                        // Calculate the split point for left and right seats
                        final int leftSeatCount = seats.length ~/ 2;
                        final List<String> leftSeats = seats.take(leftSeatCount).toList();
                        final List<String> rightSeats = seats.skip(leftSeatCount).toList();
                        
                        final bool isToiletOnLeft = widget.busRoute.bus?.isToiletAtLeftSide ?? true;
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              SizedBox(width: 20, child: Text(rowLetter, style: const TextStyle(fontWeight: FontWeight.bold))),
                              const SizedBox(width: 2),
                              // Left side seats
                              Row(
                                children: List.generate( ((!isToiletRow && !isToiletNextRow && !isToiletNextNextRow) || !isToiletOnLeft) ? leftSeats.length : 1, (index) {
                                  final seat = leftSeats[index];
                                  final isBooked = _bookedSeats.contains(seat);
                                  final isSelected = _selectedSeats.contains(seat);
                                  
                                  // Check if this seat should be a toilet (only on toilet side)
                                  final bool isToiletSeat = isToiletRow && isToiletOnLeft && _isToiletPositionOnSide(index, leftSeats.length, true);
                                  final bool isToiletNextSeat = isToiletNextRow && isToiletOnLeft && _isToiletPositionOnSide(index, leftSeats.length, true);
                                  final bool isToiletNextNextSeat = isToiletNextNextRow && isToiletOnLeft && _isToiletPositionOnSide(index, rightSeats.length, true);

                                  if (isToiletSeat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Container(
                                        width: 80,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.blue[200]!),
                                        ),
                                        child: Icon(Icons.wc, size: 20, color: Colors.blue[700]),
                                      ),
                                    );
                                  }

                                  if (isToiletNextSeat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Container(
                                        width: 80,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'TOILET',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold, 
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        )
                                      ),
                                    );
                                  }

                                  if (isToiletNextNextSeat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Container(
                                        width: 80,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    );
                                  }

                                  if(isFirstRow && isThreeSeatsAtFistRow && index == 1) {
                                    return _buildEmptySeatWidget(seat, false, false); // Render empty space for missing seat
                                  } else {
                                    return _buildSeatWidget(seat, isBooked, isSelected);
                                  }
                                }),
                              ),
                              
                              // Conditional rendering: Corridor for non-last rows
                              (!isLastRow || (isLastRow && (isToiletRow || isToiletNextRow || isToiletNextNextRow))) ?
                                Container(
                                  width: 24,
                                  height: 36,
                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.arrow_back,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ) :
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    children: List.generate(1, (index) {
                                      final seat = '${leftSeats[index][0]}5';
                                      final isBooked = _bookedSeats.contains(seat);
                                      final isSelected = _selectedSeats.contains(seat);

                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8.0),
                                        child: GestureDetector(
                                          onTap: isBooked ? null : () {
                                            setState(() {
                                              if (isSelected) {
                                                _selectedSeats.remove(seat);
                                              } else {
                                                if (_selectedSeats.length < _maxSelectableSeats) {
                                                  _selectedSeats.add(seat);
                                                  _getBookedSeats();
                                                } else {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Maximum $_maxSelectableSeats seat${_maxSelectableSeats != 1 ? 's' : ''} can be selected')),
                                                  );
                                                }
                                              }
                                            });
                                          },
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: isBooked ? Colors.black : (isSelected ? Colors.orange[800] : Colors.white),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: isBooked ? Colors.grey : Colors.grey[400]!),
                                            ),
                                            child: Center(
                                              child: Text(
                                                seat.substring(1),
                                                style: TextStyle(
                                                  color: isBooked || isSelected ? Colors.white : Colors.black,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                                ) ,
                              
                              // Right side seats
                              Row(
                                children: List.generate( ((!isToiletRow && !isToiletNextRow && !isToiletNextNextRow) || isToiletOnLeft) ? rightSeats.length : 1, (index) {
                                  final seat = rightSeats[index];
                                  final isBooked = _bookedSeats.contains(seat);
                                  final isSelected = _selectedSeats.contains(seat);
                                  
                                  // Check if this seat should be a toilet (only on toilet side)
                                  final bool isToiletSeat = isToiletRow && !isToiletOnLeft && _isToiletPositionOnSide(index, rightSeats.length, false);
                                  final bool isToiletNextSeat = isToiletNextRow && !isToiletOnLeft && _isToiletPositionOnSide(index, rightSeats.length, false);
                                  final bool isToiletNextNextSeat = isToiletNextNextRow && !isToiletOnLeft && _isToiletPositionOnSide(index, rightSeats.length, false);

                                  if (isToiletSeat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Container(
                                        width: 80,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.blue[200]!),
                                        ),
                                        child: Icon(Icons.wc, size: 20, color: Colors.blue[700]),
                                      ),
                                    );
                                  }

                                  if (isToiletNextSeat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Container(
                                        width: 80,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Center(
                                          child: Text(
                                            'TOILET',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold, 
                                              color: Colors.blue[700],
                                            ),
                                          ),
                                        )
                                      ),
                                    );
                                  }

                                  if (isToiletNextNextSeat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Container(
                                        width: 80,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                        ),
                                      ),
                                    );
                                  }
                                  
                                  return _buildSeatWidget(seat, isBooked, isSelected);
                                }),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
            if (_selectedSeats.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selected Seats:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _selectedSeats.map((seat) => Chip(
                      label: Text(seat),
                      backgroundColor: Colors.orange[100],
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => setState(() => _selectedSeats.remove(seat)),
                    )).toList(),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 16, left: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Payment Method", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const Divider(),
          Column(
            children: paymentMethods.map((method) {
              return RadioListTile(
                title: Text(method),
                value: method,
                groupValue: selectedPaymentMethod,
                onChanged: (value) => setState(() => selectedPaymentMethod = value.toString()),
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
            child: Text('Phone Number', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          TextFormField(
            controller: _phoneNumberController,
            decoration: InputDecoration(
              hintText: '255xxxxxxxxx',
              prefixIcon: const Icon(Icons.phone),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[200],
            ),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Phone number is required';
              }
              
              final cleanedNumber = value.trim();
              
              // Check length (Tanzania numbers: 255 + 9 digits = 12 digits)
              if (cleanedNumber.length < 10 || cleanedNumber.length > 13) {
                return 'Phone number must be 10-13 digits';
              }
              
              // Check if it starts with 255 or 0
              if (!cleanedNumber.startsWith('255') && !cleanedNumber.startsWith('0')) {
                return 'Phone number must start with 255 or 0';
              }
              
              // Check if it contains only digits
              final phoneRegex = RegExp(r'^\d+$');
              if (!phoneRegex.hasMatch(cleanedNumber)) {
                return 'Phone number can only contain digits';
              }
              
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerNameInput() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Passenger Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          TextFormField(
            controller: _passengerNameController,
            decoration: InputDecoration(
              hintText: 'Passenger name',
              prefixIcon: const Icon(Icons.person),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[200],
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter passenger name';
              }
              if (value.trim().length < 3) {
                return 'Name must be at least 3 characters';
              }
              if (value.trim().length > 50) {
                return 'Name must be less than 50 characters';
              }
              // Optional: Check for valid name format (letters and spaces only)
              final nameRegex = RegExp(r'^[a-zA-Z\s\-\.]+$');
              if (!nameRegex.hasMatch(value.trim())) {
                return 'Name can only contain letters, spaces, dots, and hyphens';
              }
              return null;            
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SUMMARY', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(text: 'Route: ', style: TextStyle(color: Colors.grey)),
                  TextSpan(
                    text: '${widget.busRoute.from} → ${widget.busRoute.to}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(text: 'Via: ', style: TextStyle(color: Colors.grey)),
                  TextSpan(
                    text: widget.busRoute.via,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(text: 'Pickup: ', style: TextStyle(color: Colors.grey)),
                  TextSpan(
                    text: pickupLocation,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(text: 'Dropoff: ', style: TextStyle(color: Colors.grey)),
                  TextSpan(
                    text: dropoffLocation,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(text: 'Seats: ', style: TextStyle(color: Colors.grey)),
                  TextSpan(
                    text: _selectedSeats.isEmpty ? 'None selected' : _selectedSeats.join(', '),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(text: 'Date: ', style: TextStyle(color: Colors.grey)),
                  TextSpan(
                    text: widget.busRoute.departureDate,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                children: [
                  const TextSpan(text: 'Time: ', style: TextStyle(color: Colors.grey)),
                  TextSpan(
                    text: widget.busRoute.departureTime,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                ],
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('💰 Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(
                  'TSh ${NumberFormat('#,##0').format(totalPrice.toInt())}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutButton() {
    bool isSoldOut = _allSeats.length == _bookedSeats.length;
    
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: _payed
          ? ElevatedButton(
              onPressed: null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Booked!', style: TextStyle(fontSize: 16, color: Colors.white)),
            )
          : isSoldOut
              ? ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Sold Out', style: TextStyle(fontSize: 16, color: Colors.white)),
                )
              : _processingPayment
                  ? ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Processing...', style: TextStyle(fontSize: 16, color: Colors.white)),
                    )
                  : ElevatedButton(
                      onPressed: _isLoading ? null : _handlePayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[800],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text( (widget.companyId > 0) ? (quantity == 1) ? 'Book Ticket' : 'Book Tickets' : 'Pay Now', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
    );
  }

  Widget _buildPoweredByLabel() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Powered by ', style: TextStyle(color: Colors.grey, fontSize: 14, fontStyle: FontStyle.italic)),
          Text('AzamPay', style: TextStyle(color: Colors.orange[800], fontSize: 14, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Future<void> saveSelectedPrinter(BluetoothInfo printer) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('printer_name', printer.name);
    await prefs.setString('printer_mac', printer.macAdress);
  }

  Future<void> clearSelectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('printer_name');
    await prefs.remove('printer_mac');
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  Future<void> loadAndMatchPrinter() async {
    await requestPermissions();

    final prefs = await SharedPreferences.getInstance();

    print("******************************************************************************");
    final savedMac = prefs.getString('printer_mac');
    if (savedMac == null || savedMac.isEmpty) {
      debugPrint("No saved printer");
      await _refreshBluetoothPrinters();
      return;
    }

    debugPrint("Found saved printer");

    List<BluetoothInfo> devices = await PrintBluetoothThermal.pairedBluetooths;

    final matched = devices.where(
      (d) => d.macAdress == savedMac,
    ).toList();

    if (matched.isNotEmpty) {
      setState(() {
        selectedPrinter = matched.first;
      });

      debugPrint("Printer restored: ${matched.first.name}");
    } else {
      debugPrint("Saved printer not found");
      setState(() {
        selectedPrinter = null;
      });

      await _refreshBluetoothPrinters();
    }
  }

  Future<void> _selectPrinterDialog() async {
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Select Printer"),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5, // 50% of screen height
            ),
            child: SizedBox(
              width: double.maxFinite,
              child: ListView(
                children: devices.map((device) {
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(device.macAdress),
                    onTap: () {
                      selectedPrinter = device;
                      saveSelectedPrinter(device);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _refreshBluetoothPrinters() async {
    debugPrint("Refreshing printers...");
    devices = await PrintBluetoothThermal.pairedBluetooths;

    debugPrint("Refreshing printers...");

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noPairedPrinterFound)),  
      );
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text( AppLocalizations.of(context)!.foundPairedPrinters(devices.length.toString()))),
      );
    }

    await _selectPrinterDialog();
  }

  Future<void> _printBluetoothTestReceipt() async {
    selectedPrinter = null;
    await clearSelectedPrinter();

    await _refreshBluetoothPrinters();
    if (selectedPrinter == null) return;

    await PrintBluetoothThermal.disconnect; // ensure clean state

    bool connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: selectedPrinter!.macAdress,
    );

    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.printerNotConnected)),
      );
      selectedPrinter = null;
      await _refreshBluetoothPrinters();
      if (selectedPrinter == null) return;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    List<int> bytes = [];

    bytes += generator.text("********************************",
      styles: const PosStyles(
        align: PosAlign.center,
      )
    );

    bytes += generator.text(widget.companyName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
      )
    );

    bytes += generator.text("********************************",
      styles: const PosStyles(
        align: PosAlign.center,
      )
    );

    bytes += generator.feed(1);
    bytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  Future<void> _printBluetoothReceipt(BusTicket busTicket) async {
    if (selectedPrinter == null) {
      await _refreshBluetoothPrinters();
      if (selectedPrinter == null) return;
    }

    await PrintBluetoothThermal.disconnect; // ensure clean state

    bool connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: selectedPrinter!.macAdress,
    );

    if (!connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.printerNotConnected)),
      );
      selectedPrinter = null;
      await _refreshBluetoothPrinters();
      if (selectedPrinter == null) return;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    List<int> bytes = [];

    bytes += generator.text("********************************",
      styles: const PosStyles(
        align: PosAlign.center,
      )
    );

    bytes += generator.text(widget.companyName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
      )
    );

    bytes += generator.text("********************************",
      styles: const PosStyles(
        align: PosAlign.center,
      )
    );

    bytes += generator.text(
      "TICKET RECEIPT",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      "",
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text(
      "Route",
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text(
      "${widget.busRoute.from} - - - ${widget.busRoute.to}",
      styles: const PosStyles(bold: true),
    );

    bytes += generator.row([
      PosColumn(text: "Ticket No:", width: 6),
      PosColumn(text: busTicket.ticketCode, width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "From:", width: 6),
      PosColumn(text: busTicket.pickupLocation, width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "To:", width: 6),
      PosColumn(text: busTicket.dropoffLocation, width: 6),
    ]);

    bytes += generator.text(
      "",
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text(
      "BUS DETAILS",
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text(
      widget.busRoute.bus!.name,
      styles: const PosStyles(bold: false),
    );

    bytes += generator.row([
      PosColumn(text: "Plate No:", width: 6),
      PosColumn(text: widget.busRoute.bus!.registrationNumber, width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Travel Date:", width: 6),
      PosColumn(text: widget.busRoute.departureDate, width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Reporting Time:", width: 6),
      PosColumn(text: getAmPm(getTime30MinBefore(widget.busRoute.departureTime)), width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Departure Time:", width: 6),
      PosColumn(text: getAmPm(widget.busRoute.departureTime), width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Pickup point:", width: 6),
      PosColumn(text: busTicket.pickupLocation, width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Arrival Date:", width: 6),
      PosColumn(text: widget.busRoute.arrivalDate, width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Arrival Time:", width: 6),
      PosColumn(text: getAmPm(widget.busRoute.arrivalTime), width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Dropoff point:", width: 6),
      PosColumn(text: busTicket.dropoffLocation, width: 6),
    ]);

    bytes += generator.text(
      "",
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text(
      "PASSENGER DETAILS",
      styles: const PosStyles(bold: true),
    );

    bytes += generator.row([
      PosColumn(text: "Full Name:", width: 6),
      PosColumn(text: busTicket.passengerName, width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Phone:", width: 6),
      PosColumn(text: busTicket.phoneNumber, width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Seat Number:", width: 6),
      PosColumn(text: busTicket.seatNumber, width: 6),
    ]);

    bytes += generator.text("--------------------------------",
      styles: const PosStyles(
        align: PosAlign.center,
      )
    );

    bytes += generator.row([
      PosColumn(text: "Ticket Price:", width: 6),
      PosColumn(text: "TZS ${NumberFormat('#,##0').format(busTicket.ticketPrice)}", width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.text("--------------------------------",
      styles: const PosStyles(
        align: PosAlign.center,
      )
    );

    bytes += generator.text(
      "Issued By:",
      styles: const PosStyles(bold: true),
    );
    bytes += generator.row([
      PosColumn(text: "Name", width: 6),
      PosColumn(text: busTicket.issuedBy, width: 6),
    ]);
    bytes += generator.row([
      PosColumn(text: "Phone number", width: 6),
      PosColumn(text: busTicket.issuerPhoneNumber, width: 6),
    ]);

    String day = busTicket.createdAt.day.toString().padLeft(2, '0');
    String month = busTicket.createdAt.month.toString().padLeft(2, '0');
    String year = busTicket.createdAt.year.toString();
    String hour = busTicket.createdAt.hour.toString().padLeft(2, '0');
    String minute = busTicket.createdAt.minute.toString().padLeft(2, '0');
    String second = busTicket.createdAt.second.toString().padLeft(2, '0');

    bytes += generator.row([
      PosColumn(text: "Receipt Date", width: 6),
      PosColumn(text: '$day-$month-$year', width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Receipt Time", width: 6),
      PosColumn(text: '$hour:$minute:$second', width: 6),
    ]);

    // QR
    String data = SimpleCodec.encode(jsonEncode({
      "tid": busTicket.id,
      "cid": widget.companyId,
    }));

    bytes += generator.qrcode(
      data,
      size: QRSize.size5,
    );

    bytes += generator.text(
      receiptFooter,
      styles: const PosStyles(align: PosAlign.center)
    );

    bytes += generator.text(
      "",
      styles: const PosStyles(bold: true),
    );

    bytes += generator.text(
      'Powered by Tiketi Mkononi',
      styles: const PosStyles(align: PosAlign.center)
    );
    bytes += generator.text(
      'Email:tiketimkononi@telabs.co.tz',
      styles: const PosStyles(align: PosAlign.center)
    );
  
    bytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  String getTime30MinBefore(String departureTime) {
    // Split hour and minute
    final parts = departureTime.split(':');
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1]);

    // Create DateTime (use any date, only time matters)
    final now = DateTime.now();
    DateTime dateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Subtract 30 minutes
    final newTime = dateTime.subtract(const Duration(minutes: 30));

    // Format back to HH:mm
    String formattedHour = newTime.hour.toString().padLeft(2, '0');
    String formattedMinute = newTime.minute.toString().padLeft(2, '0');

    return "$formattedHour:$formattedMinute";
  }

}