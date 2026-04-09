import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/bus_route.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/bus_tickets_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';

class BusTicketsCheckoutPage extends StatefulWidget {
  final int userId;
  final int companyId;
  final BusRoute busRoute;
  final VoidCallback refreshMethod;

  const BusTicketsCheckoutPage({
    super.key,
    required this.userId,
    required this.companyId,
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
  String selectedPaymentMethod = 'CASH';
  final List<String> paymentMethods = ['CASH','MIXX BY YAS', 'M-PESA', 'AIRTEL MONEY', 'HALOPESA', 'AZAMPESA'];
  final _phoneNumberController = TextEditingController();
  bool _isLoading = false;
  bool _payed = false;
  bool _processingPayment = false;
  Timer? _timer;
  bool _isAppActive = true;
  final _formKey = GlobalKey<FormState>();

  String pickupLocation = '';
  String dropoffLocation = '';

  // Seat selection variables
  List<String> _selectedSeats = [];
  List<String> _bookedSeats = [];
  List<String> _allSeats = [];
  int _maxSelectableSeats = 1;

  @override
  void initState() {
    super.initState();
    pickupLocation = widget.busRoute.from;
    dropoffLocation = widget.busRoute.to;
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _initializeSeats();
    _getBookedSeats();
    _startFetchingBookedSeats();
    _setTicketPrice();
  }

  void _setTicketPrice() {
    setState(() {
      ticketPrice = widget.busRoute.ticketPrice;
      _maxSelectableSeats = 4;
    });
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
        _phoneNumberController.text = profile.phoneNumber;
      });
    }
  }

  void _initializeSeats() {
    List<String> letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'];
    _allSeats = [];
    
    int rows = widget.busRoute.bus?.numberOfSeatRows ?? 10;
    int seatsPerRow = widget.busRoute.bus?.seatsPerRow ?? 4;
    
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < seatsPerRow; col++) {
        _allSeats.add('${letters[row]}${col + 1}');
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

  Future<void> _handlePayment({bool useDNS = true}) async {
    if (_isLoading) return;

    if (_formKey.currentState!.validate() && checkNumberTickets()) {
      String selectedPaymentMethod2 = '';
      switch (selectedPaymentMethod) {
        case 'M-PESA':
          selectedPaymentMethod2 = 'Mpesa';
          break;
        case 'MIXX BY YAS':
          selectedPaymentMethod2 = 'Tigo';
          break;
        case 'AIRTEL MONEY':
          selectedPaymentMethod2 = 'Airtel';
          break;
        case 'HALOPESA':
          selectedPaymentMethod2 = 'Halopesa';
          break;
        case 'AZAMPESA':
          selectedPaymentMethod2 = 'Azampesa';
          break;
      }

      final Map<String, dynamic> requestBody = {
        'user_id': widget.userId,
        'bus_route_id': widget.busRoute.id,
        'company_id': widget.companyId,
        'quantity': _selectedSeats.length,
        'ticket_price': ticketPrice,
        'selected_seats': _selectedSeats,
        'selected_payment_method': selectedPaymentMethod2,
        'phone_number': formatPhoneNumber(_phoneNumberController.text),
      };

      try {
        setState(() => _isLoading = true);

        final Uri uri = useDNS 
            ? Uri.parse('${backend_url}api/bus_checkout')
            : Uri.parse('${backend_url_with_fallback_ip}bus_checkout');

        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(requestBody),
        );

        if (response.statusCode == 200) {
          if (response.body.contains("Payment failed") || 
              response.body.contains("Someone is already booking seat")) {
            _selectedSeats.clear();
            _showSnackBar(response.body);
          } else if (response.body == "Not routed") {
            _showSnackBar("Malipo hayawezi kukamilika. Tafadhali tumia namba ya mtandao tofauti");
          } else if (response.body == "Invalid msisdn!") {
            _showSnackBar("Namba uliyoweka sio sahihi");
          } else if (response.body == "Processing payment!") {
            setState(() {
              _processingPayment = true;
              _payed = false;
            });
            _startFetchingPaymentStatus();
          } else if (response.body == "Payed successfully!") {
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
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
        }
      } on SocketException catch (e) {
        _handleSocketException(e, useDNS, (retryUseDNS) => _handlePayment(useDNS: retryUseDNS));
      } catch (e) {
        _showSnackBar('An error occurred: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
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

      _fetchPaymentStatus();
    });
  }

  Future<void> _fetchPaymentStatus({bool useDNS = true}) async {
    final Uri uri = useDNS
        ? Uri.parse('${backend_url}api/bus_payment_status/${widget.userId}')
        : Uri.parse('${backend_url_with_fallback_ip}bus_payment_status/${widget.userId}');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final transactionDesc = responseData['transaction_description'];

        if (transactionDesc == "SENDER_NOT_ENOUGH_FUND") {
          if (_processingPayment) {
            _showSnackBar("Hauna salio la kutosha");
            setState(() {
              _processingPayment = false;
            });
          }
          return;
        }

        bool hasTicket = responseData['has_ticket'];

        if (hasTicket && transactionDesc == "Success") {
          setState(() {
            _payed = true;
            _processingPayment = false;
          });
          widget.refreshMethod();
          _selectedSeats.clear();
          _getBookedSeats();
          _fetchTickets();
          _showSnackBar("Payment successful! Your tickets have been booked.");
        }
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 11001 || e.osError?.errorCode == 7) && useDNS) {
        await _fetchPaymentStatus(useDNS: false);
      }
    } catch (e) {
      debugPrint('Error fetching payment status: $e');
    }
  }

  Future<void> _getBookedSeats({bool useDNS = true}) async {
    try {
      final Uri uri = useDNS
          ? Uri.parse('${backend_url}api/bus_booked_seats/${widget.busRoute.id}')
          : Uri.parse('${backend_url_with_fallback_ip}bus_booked_seats/${widget.busRoute.id}');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
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
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
  }

  @override
  Widget build(BuildContext context) {
    totalPrice = ticketPrice * _selectedSeats.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Ticket Checkout'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          if (_payed)
            ElevatedButton.icon(
              icon: const Icon(Icons.confirmation_number),
              label: const Text('My Tickets'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.orange[800],
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusTicketsPage(busRoute: widget.busRoute),
                  ),
                );
              },
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
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('🚌', 'Bus:', widget.busRoute.bus?.name ?? 'Standard Bus'),
            _buildDetailRow('🏢', 'Company:', 'Bus Company Name'),
            _buildDetailRow('⏰', 'Departure:', widget.busRoute.departureTime),
            _buildDetailRow('📅', 'Date:', widget.busRoute.departureDate),
            _buildDetailRow('💺', 'Available Seats:', '${_allSeats.length - _bookedSeats.length}'),
            _buildDetailRow('💰', 'Price:', 'TSh ${NumberFormat('#,##0').format(ticketPrice.toInt())}'),
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
    // Sample locations - replace with your actual data
    final List<Map<String, String>> popularLocations = [
      {'name': 'Current Location', 'icon': '📍'},
      {'name': 'Dar es Salaam Bus Terminal', 'icon': '🚌'},
      {'name': 'Ubungo Bus Terminal', 'icon': '🏢'},
      {'name': 'Mwenge Bus Stop', 'icon': '🚏'},
      {'name': 'Kariakoo Market', 'icon': '🏪'},
      {'name': 'Posta Bus Stop', 'icon': '📮'},
    ];
    
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
            
            const SizedBox(height: 12),
            
            // Recent/Suggested locations
            const Text(
              'Suggested Locations',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: popularLocations.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final location = popularLocations[index];
                  return ActionChip(
                    label: Text(
                      location['name']!,
                      style: const TextStyle(fontSize: 13),
                    ),
                    avatar: Text(location['icon']!),
                    onPressed: () {
                      setState(() {
                        // Update pickup or dropoff based on context
                        // This is a simplified example
                      });
                    },
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                },
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
      {'name': 'Dar es Salaam Bus Terminal', 'address': 'Dar es Salaam', 'type': 'terminal'},
      {'name': 'Ubungo Bus Terminal', 'address': 'Ubungo, Dar es Salaam', 'type': 'terminal'},
      {'name': 'Mwenge Bus Stop', 'address': 'Mwenge, Dar es Salaam', 'type': 'stop'},
      {'name': 'Kariakoo Market', 'address': 'Kariakoo, Dar es Salaam', 'type': 'market'},
      {'name': 'Posta Bus Stop', 'address': 'Posta, Dar es Salaam', 'type': 'stop'},
      {'name': 'Temeke Bus Stop', 'address': 'Temeke, Dar es Salaam', 'type': 'stop'},
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
          builder: (context, setState) {
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
                          setState(() {
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
                      setState(() {
                        if (value.isEmpty) {
                          searchResults = [];
                        } else {
                          searchResults = allLocations
                              .where((loc) => loc['name']!
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
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
                                'Recent Locations',
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
                                        // Update the location
                                        setState(() {
                                          if (isPickup) {
                                            // Update pickup location logic here
                                          } else {
                                            // Update dropoff location logic here
                                          }
                                        });
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
                                  // Update the location
                                  setState(() {
                                    if (isPickup) {
                                      // Update pickup location logic here
                                      pickupLocation = location['name']!;
                                    } else {
                                      // Update dropoff location logic here
                                      dropoffLocation = location['name']!;
                                    }
                                  });
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
    final TextEditingController _manualPriceController = TextEditingController();
    bool isCustomRoute = false;
    double customTicketPrice = ticketPrice;
    
    // Check if locations are different from original route
    bool isPickupDifferent = pickupLocation != widget.busRoute.from;
    bool isDropoffDifferent = dropoffLocation != widget.busRoute.to;
    
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
                          child: TextFormField(
                            controller: _manualPriceController,
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
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Suggested price options
                    const Text(
                      'Suggested Prices:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPriceChip(widget.busRoute.ticketPrice * 0.8, '20% Off'),
                        _buildPriceChip(widget.busRoute.ticketPrice, 'Standard'),
                        _buildPriceChip(widget.busRoute.ticketPrice * 1.2, '20% Extra'),
                        _buildPriceChip(widget.busRoute.ticketPrice * 1.5, 'Premium'),
                      ],
                    ),
                    
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
    final bool isToiletOnLeft = widget.busRoute.bus?.isToiletAtLeftSide ?? true;
    
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

  // Reorder seats from [1,2,3,4] to [1,2,4,3]
  List<String> _reorderSeats(List<String> seats) {
    if (seats.length != 4) return seats; // Only reorder for 4-seat rows
    
    // Extract seat numbers
    final List<String> reordered = List.from(seats);
    if (reordered.length >= 4) {
      // Swap positions 2 and 3 (0-indexed: swap index 2 and 3)
      final temp = reordered[2];
      reordered[2] = reordered[3];
      reordered[3] = temp;
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
                        final bool isLastRow = rowNumber == totalRows;
                        final bool isToiletRow = widget.busRoute.bus?.isHavingToilet == true && (rowNumber == widget.busRoute.bus?.toiletAtRowNumber); // Toilet spans 2 rows
                        final bool isToiletNextRow = widget.busRoute.bus?.isHavingToilet == true && (rowNumber == (widget.busRoute.bus?.toiletAtRowNumber ?? 0) + 1); // Toilet spans 2 rows
                        
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
                                children: List.generate( (!isToiletRow && !isToiletNextRow) ?leftSeats.length : 1, (index) {
                                  final seat = leftSeats[index];
                                  final isBooked = _bookedSeats.contains(seat);
                                  final isSelected = _selectedSeats.contains(seat);
                                  
                                  // Check if this seat should be a toilet (only on toilet side)
                                  final bool isToiletSeat = isToiletRow && isToiletOnLeft && _isToiletPositionOnSide(index, leftSeats.length, true);
                                  final bool isToiletNextSeat = isToiletNextRow && isToiletOnLeft && _isToiletPositionOnSide(index, leftSeats.length, true);
                                  
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
                                  
                                  return _buildSeatWidget(seat, isBooked, isSelected);
                                }),
                              ),
                              
                              // Conditional rendering: Corridor for non-last rows
                              (!isLastRow) ?
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
                                      Icons.arrow_forward,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ) :
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  child: Row(
                                    children: List.generate(1, (index) {
                                      final seat = '5';
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
                                                seat,
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
                                children: List.generate(rightSeats.length, (index) {
                                  final seat = rightSeats[index];
                                  final isBooked = _bookedSeats.contains(seat);
                                  final isSelected = _selectedSeats.contains(seat);
                                  
                                  // Check if this seat should be a toilet (only on toilet side)
                                  final bool isToiletSeat = isToiletRow && !isToiletOnLeft && 
                                      _isToiletPositionOnSide(index, rightSeats.length, false);
                                  
                                  if (isToiletSeat) {
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Container(
                                        width: 36,
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
              if (value != null && value.isNotEmpty) {
                if (value.length > 15) return 'Invalid phone number';
                final regex = RegExp(r'^\d{1,3}\d{9}$');
                if (!regex.hasMatch(value.trim())) return 'Format: 255xxxxxxxxxx';
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
                          : const Text('Pay Now', style: TextStyle(fontSize: 16, color: Colors.white)),
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
}