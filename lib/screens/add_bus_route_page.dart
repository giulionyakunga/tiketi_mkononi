import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/bus.dart';
import 'package:tiketi_mkononi/models/bus_route.dart';
import 'package:tiketi_mkononi/screens/add_office_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:tiketi_mkononi/utils/extensions/list_extensions.dart';

class AddBusRoutePage extends StatefulWidget {
   final int userId;
  final int companyId;
  final String companyName;
  final String userName;
  final String userPhoneNumber;
  final bool isReplacableScreen;
  final Function refreshMethod;

  const AddBusRoutePage({super.key, required this.userId, required this.companyId, required this.companyName, required this.userName, required this.userPhoneNumber, required this.isReplacableScreen, required this.refreshMethod});

  @override
  State<AddBusRoutePage> createState() => _AddBusRoutePageState();
}

class _AddBusRoutePageState extends State<AddBusRoutePage> {
  int userId = 0;
  String role = "";
  final _formKey = GlobalKey<FormState>();
  int routeId = 0;
  final _routeNameController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _ticketPriceController = TextEditingController();
  final _startingPointController = TextEditingController();
  final _finalPointController = TextEditingController();

  int busId = 0;
  final _busNameController = TextEditingController();
  final _busRegistrationNumberController = TextEditingController();
  final _numberOfSeatRowsController = TextEditingController();
  final _seatsPerRowController = TextEditingController();
  final _toiletAtRowNumberController = TextEditingController();
  bool isHavingToilet = true;
  bool isToiletAtLeftSide = true;
  int numberOfRowsThatToiletSpans = 2;

  List<String> regions = [];
  List<String> offices = [];
  
  DateTime? _selectedDepartureDate;
  TimeOfDay? _selectedDepartureTime;

  DateTime? _selectedArrivalDate;
  TimeOfDay? _selectedArrivalTime;
  bool _isDateError = false;
  bool _isDateError2 = false;
  bool _isTimeError = false;
  bool _isTimeError2 = false;

  bool _isLoading = false;

  late final StorageService _storageService;

  List<Bus> buses = [];
  List<BusRoute> busRoutes = [];

  @override
  void initState() {
    super.initState();
    _seatsPerRowController.text = '4';
    _toiletAtRowNumberController.text = '7';
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
        role = profile.role;
      });

      if(profile.role == "user") {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sorry! You can't add a route")),
        );
      }

      getUserRole();
      getCompanyOffices();
      getBuses();
      getBusRoutes();
    }
  }

  Future<void> getCompanyOffices({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/company_offices/${widget.companyId}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}company_offices/${widget.companyId}'); // Use IP
        
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        debugPrint("response.body : ${response.body}");

        final responseData = jsonDecode(response.body); // This is a List<dynamic>
        

        List<String> regionsList = [];
        List<String> officesList = [];

        // Loop through each office
        for (var office in responseData) {
          // Add name to regionsList
          regionsList.add(office['name']);

          // If this office's id matches widget.officeId, set from
          if (office['company_id'] == widget.companyId) {
            officesList.add(office['name']);
          }
        }

        if(regionsList.isNotEmpty) {
          setState(() {
            regions = regionsList;
          });
        }

        if(officesList.length > 1) {
          setState(() {
            offices = officesList;
          });
        } else {
          _showRequiredOfficeDialog();
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
          await getCompanyOffices(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting offices: $e');
    } finally {
      debugPrint('Process finished');
    }
  }

  void _showRequiredOfficeDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Offices Required',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: const Text(
        'You must have at least two offices to continue. Please add an office now.',
        style: TextStyle(fontSize: 14),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddOfficePage(userId: widget.userId, companyId: widget.companyId,)),
            );
            getCompanyOffices();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('ADD OFFICE'),
        ),
      ],
    ),
  );
}

  Future<void> getUserRole({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/get_user_role/$userId') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}get_user_role/$useDNS'); // Use IP
        
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);   
        if((role != responseData['role'])) {
          setState(() {
            role = responseData['role'];
          });
          var profile = _storageService.getUserProfile();
          profile!.role =  responseData['role'];
          await _storageService.saveUserProfile(profile);

          if(responseData['role'] == "user") {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Sorry, You can't add a route")),
            );
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
          await getUserRole(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting server metrics: $e');
    } finally {
      debugPrint('Process finished');
    }
  }


  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDepartureDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDepartureTime = picked;
      });
    }
  }

  Future<void> _selectDate2(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedArrivalDate = picked;
      });
    }
  }

  Future<void> _selectTime2(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedArrivalTime = picked;
      });
    }
  }

  void _scrollToFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }
  
  Future<void> _addBusRoute({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    if (_fromController.text.trim().toLowerCase() == _toController.text.trim().toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Origin and destination cannot be the same location.')),
      );
      return;
    }

    if (_startingPointController.text.trim().toLowerCase() == _finalPointController.text.trim().toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting and final point cannot be the same location.')),
      );
      return;
    }

    if (_selectedDepartureDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Departure date is required'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isDateError = true;
      });
      return;
    } else {
      setState(() {
        _isDateError = false;
      });
    }

    if (_selectedDepartureTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Departure time is required'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isTimeError = true;
      });
      return;
    } else {
      setState(() {
        _isTimeError = false;
      });

    }

    if (_selectedArrivalDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arrival date is required'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isDateError2 = true;
      });
      return;
    } else {
      setState(() {
        _isDateError2 = false;
      });
    }

    if (_selectedArrivalTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arrival time is required'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isTimeError2 = true;
      });
      return;
    } else {
      setState(() {
        _isTimeError2 = false;
      });
    }

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'company_id': widget.companyId,
      'from': _fromController.text.trim().toUpperCase(),
      'to': _toController.text.trim().toUpperCase(),
      'starting_point': _startingPointController.text.trim().toUpperCase(),
      'final_point': _finalPointController.text.trim().toUpperCase(),
      'ticket_price': _ticketPriceController.text.trim(),
      'bus_name': _busNameController.text.trim().toUpperCase(),
      'bus_registration_number': _busRegistrationNumberController.text.trim().toUpperCase(),
      'number_of_seat_rows': int.tryParse(_numberOfSeatRowsController.text.trim()) ?? 0,
      'seats_per_row': int.tryParse(_seatsPerRowController.text.trim()) ?? 0,
      'is_having_toilet': isHavingToilet,
      'is_toilet_at_left_side': isToiletAtLeftSide,
      'toilet_at_row_number': int.tryParse(_toiletAtRowNumberController.text.trim()) ?? 0,
      'number_of_rows_that_toilet_spans': numberOfRowsThatToiletSpans,
      'departure_date': _selectedDepartureDate?.toIso8601String(),
      'departure_time': '${_selectedDepartureTime!.hour}:${_selectedDepartureTime!.minute}',
      'arrival_date': _selectedArrivalDate ?.toIso8601String(),
      'arrival_time': '${_selectedArrivalTime!.hour}:${_selectedArrivalTime!.minute}',
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/add_bus_route') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}add_bus_route'); // Use IP

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Bus route added successfully!") {
          widget.refreshMethod();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        if ((response.statusCode == 400) || (response.statusCode == 500)) {
          _showSnackBar('Request failed: ${response.body}');
          return;
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
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
          await _addBusRoute(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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

  
  Future<void> getBuses({bool useDNS = true}) async {
    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/buses/${widget.companyId}') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}buses/${widget.companyId}'); // Use IP

      debugPrint('Fetching buses from: ${uri.toString()}');

      final response = await http.get(uri);
    
      if (response.statusCode == 200) {
        debugPrint("Loaded buses: ${response.body}");
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Bus.fromJson(json)).toList();

        setState(() {
          buses = newItems;
        });

        debugPrint("Loaded ${newItems.length} buses");
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
          await getBuses(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting notification preferences: $e');
    }
  }

  Future<void> getBusRoutes({bool useDNS = true}) async {
    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/company_bus_routes/${widget.companyId}') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}company_bus_routes/${widget.companyId}'); // Use IP

        debugPrint('Fetching bus routes from: ${uri.toString()}');

      final response = await http.get(uri);
    
      if (response.statusCode == 200) {
          debugPrint("Loaded bus routes: ${response.body}");

        debugPrint("Loaded bus routes: ${response.body}");

        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => BusRoute.fromJson(json)).toList();

        setState(() {
          busRoutes = newItems;
        });

        debugPrint("Loaded ${newItems.length} routes");

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
          await getBusRoutes(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting notification preferences: $e');
    }
  }

  @override
  void dispose() {
    _routeNameController.dispose();
    _toController.dispose();
    _fromController.dispose();
    _startingPointController.dispose();
    _finalPointController.dispose();
    _ticketPriceController.dispose();
    _busNameController.dispose();
    _busRegistrationNumberController.dispose();
    _numberOfSeatRowsController.dispose();
    _seatsPerRowController.dispose();
    _toiletAtRowNumberController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration(String label, {String? prefixText, String? hintText, IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      hintText: hintText,
      prefixIcon: (prefixIcon != null) ? Icon(
        prefixIcon,
        color: Colors.grey[600],
      ) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.teal[800]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    );
  }

  Widget _buildDateTimePickers(bool isLargeScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Departure Time',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildDatePicker()),
            const SizedBox(width: 16),
            Expanded(child: _buildTimePicker()),
          ],
        ),
        if (_isDateError)
        const Padding(
          padding: EdgeInsets.only(left: 12, top: 4),
          child: Text(
            'Please select departure date',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
        if (_isTimeError)
        const Padding(
          padding: EdgeInsets.only(left: 12, top: 4),
          child: Text(
            'Please select departure time',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimePickers2(bool isLargeScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Arrival Time',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildDatePicker2()),
            const SizedBox(width: 16),
            Expanded(child: _buildTimePicker2()),
          ],
        ),
        if (_isDateError2)
        const Padding(
          padding: EdgeInsets.only(left: 12, top: 4),
          child: Text(
            'Please select arrival date',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
        if (_isTimeError2)
        const Padding(
          padding: EdgeInsets.only(left: 12, top: 4),
          child: Text(
            'Please select arrival time',
            style: TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return TextButton.icon(
      onPressed: () => _selectDate(context),
      icon: Icon(Icons.calendar_today, color: Colors.teal[800]),
      label: Text(
        _selectedDepartureDate == null
            ? 'Select Date'
            : '${_selectedDepartureDate!.day}/${_selectedDepartureDate!.month}/${_selectedDepartureDate!.year}',
        style: TextStyle(
          color: _isDateError ? Colors.red : (_selectedDepartureDate == null ? Colors.grey[600] : Colors.black),
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(
          color: _isDateError ? Colors.red : (_selectedDepartureDate == null ? Colors.grey[400]! : Colors.teal[800]!),
          width: 1.5,
        ),
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildTimePicker() {
    return TextButton.icon(
      onPressed: () => _selectTime(context),
      icon: Icon(Icons.access_time, color: Colors.teal[800]),
      label: Text(
        _selectedDepartureTime == null
            ? 'Select Time'
            : _selectedDepartureTime!.format(context),
        style: TextStyle(
          color: _selectedDepartureTime == null ? Colors.grey[600] : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(
          color: _selectedDepartureTime == null ? Colors.grey[400]! : Colors.teal[800]!,
          width: 1.5,
        ),
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildDatePicker2() {
    return TextButton.icon(
      onPressed: () => _selectDate2(context),
      icon: Icon(Icons.calendar_today, color: Colors.teal[800]),
      label: Text(
        _selectedArrivalDate == null
            ? 'Select Date'
            : '${_selectedArrivalDate!.day}/${_selectedArrivalDate!.month}/${_selectedArrivalDate!.year}',
        style: TextStyle(
          color: _isDateError2 ? Colors.red : (_selectedArrivalDate == null ? Colors.grey[600] : Colors.black),
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(
          color: _isDateError2 ? Colors.red : (_selectedArrivalDate == null ? Colors.grey[400]! : Colors.teal[800]!),
          width: 1.5,
        ),
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildTimePicker2() {
    return TextButton.icon(
      onPressed: () => _selectTime2(context),
      icon: Icon(Icons.access_time, color: Colors.teal[800]),
      label: Text(
        _selectedArrivalTime == null
            ? 'Select Time'
            : _selectedArrivalTime!.format(context),
        style: TextStyle(
          color: _selectedArrivalTime == null ? Colors.grey[600] : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(
          color: _selectedArrivalTime == null ? Colors.grey[400]! : Colors.teal[800]!,
          width: 1.5,
        ),
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildRowsAndSeatsField() {
   
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bus Seat Layout Configuration',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildRowsField(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSeatsField(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Example: 16 rows × 6 seats = 64 total seats',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600], 
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 16),
        _buildBusConfigurationCard()
      ],
    );
  }

  Widget _buildRowsField() {
    return TextFormField(
      controller: _numberOfSeatRowsController,
      enabled: busId == 0, // Disable if a bus is selected
      decoration: _buildInputDecoration('No of Seat Rows', prefixIcon: Icons.chair),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildSeatsField() {
    return TextFormField(
      controller: _seatsPerRowController,
      enabled: busId == 0, // Disable if a bus is selected
      decoration: _buildInputDecoration('Seats per Row', prefixIcon: Icons.chair),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 14),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter seats per row';
        }
        if (value.trim() != '4') {
          return 'Only 4 seats per row allowed';
        }
        return null;
      },
    );
  }

  // Safe way to convert string to int
  int getNumberOfSeatRows(String intString) {
    int? rows = int.tryParse(intString);
    return rows ?? 10; // Return parsed value or default
  }

  // Add this method to your _BusTicketsCheckoutPageState class
  Widget _buildBusConfigurationCard() {  
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          // Header with gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.teal[700]!,
                  Colors.teal[900]!,
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bus Configuration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Customize bus amenities and layout',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Configuration options
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Toilet availability section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    children: [
                      // Toilet availability switch
                      SwitchListTile(
                        value: isHavingToilet,
                        onChanged: (busId == 0) ? (bool value) {
                          setState(() {
                            isHavingToilet = value;
                            // If toilet is disabled, also disable side selection
                            if (!value) {
                              isToiletAtLeftSide = true;
                            }
                          });
                        } : null,
                        title: Row(
                          children: [
                            Icon(
                              Icons.wc,
                              color: isHavingToilet ? Colors.blue[700] : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Toilet Available',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          isHavingToilet 
                              ? 'Toilet facility is available on this bus'
                              : 'No toilet facility on this bus',
                          style: TextStyle(
                            fontSize: 12,
                            color: isHavingToilet ? Colors.green[700] : Colors.grey,
                          ),
                        ),
                        activeColor: Colors.teal[700],
                        secondary: isHavingToilet
                            ? Icon(Icons.check_circle, color: Colors.green[400], size: 20)
                            : Icon(Icons.block, color: Colors.red[400], size: 20),
                      ),
                      
                      // Toilet side selection (only shown if toilet is available)
                      if (isHavingToilet)  
                        Column(
                          children: [
                            const Divider(height: 1, thickness: 1),
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Toilet Position',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildToiletSideOption(
                                          isLeft: true,
                                          isSelected: isToiletAtLeftSide,
                                          onTap: (busId == 0) ? () {
                                            setState(() {
                                              isToiletAtLeftSide = true;
                                            });
                                          } : () {},
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildToiletSideOption(
                                          isLeft: false,
                                          isSelected: !isToiletAtLeftSide,
                                          onTap: (busId == 0) ? () {
                                            setState(() {
                                              isToiletAtLeftSide = false;
                                            });
                                          } : () {},
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Toilet Row Number Input
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[300]!),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.format_line_spacing,
                                                size: 18,
                                                color: Colors.teal[700],
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Toilet Location',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange[100],
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'At which row?',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.orange[800],
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                flex: 2,
                                                child: TextFormField(
                                                  controller: _toiletAtRowNumberController,
                                                  keyboardType: TextInputType.number,
                                                  enabled: busId == 0, // Disable if a bus is selected
                                                  decoration: InputDecoration(
                                                    hintText: 'Row number',
                                                    prefixIcon: Icon(Icons.numbers, size: 16, color: Colors.teal[400]),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: const BorderSide(color: Colors.teal),
                                                    ),
                                                    filled: true,
                                                    fillColor: Colors.grey[50],
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                  ),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      // Update the toilet row number
                                                    });
                                                  },
                                                  validator: (value) {
                                                    if (value == null || value.isEmpty) {
                                                      return 'Please enter row number';
                                                    }
                                                    int? rowNum = int.tryParse(value);
                                                    int totalRows = getNumberOfSeatRows(_numberOfSeatRowsController.text);
                                                    if (rowNum == null || rowNum < 1 || rowNum > totalRows - 1) {
                                                      return 'Row must be between 1 and ${totalRows - 1}';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                flex: 2,
                                                child: DropdownButtonFormField<int>(
                                                  value: numberOfRowsThatToiletSpans,
                                                  decoration: InputDecoration( 
                                                    hintText: 'Select number of rows',
                                                    prefixIcon: Icon(Icons.table_rows, size: 16, color: Colors.teal[400]),
                                                    border: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                                    ),
                                                    enabledBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                                    ),
                                                    focusedBorder: OutlineInputBorder(
                                                      borderRadius: BorderRadius.circular(10),
                                                      borderSide: const BorderSide(color: Colors.teal),
                                                    ),
                                                    filled: true,
                                                    fillColor: Colors.grey[50],
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                                  ),
                                                  items: (busId == 0) ? const [
                                                    DropdownMenuItem<int>(
                                                      value: 2,
                                                      child: Text('2 rows'),
                                                    ),
                                                    DropdownMenuItem<int>(
                                                      value: 3,
                                                      child: Text('3 rows'),
                                                    ),
                                                  ] : [
                                                    DropdownMenuItem<int>(
                                                      value: numberOfRowsThatToiletSpans,
                                                      child: Text('$numberOfRowsThatToiletSpans row'),
                                                    ),
                                                  ],
                                                  onChanged: (busId == 0) ? (int? newValue) {
                                                    setState(() {
                                                      numberOfRowsThatToiletSpans = newValue!;
                                                    });
                                                  } : null, // Disable if a bus is selected
                                                  validator: (value) {
                                                    if (value == null) {
                                                      return 'Please select number of rows the toilet spans';
                                                    }
                                                    return null;
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          // Row slider for quick selection
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Quick Select:',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              SizedBox(
                                                height: 30,
                                                child: ListView.builder(
                                                  scrollDirection: Axis.horizontal,
                                                  itemCount: ((getNumberOfSeatRows(_numberOfSeatRowsController.text)/2).toInt()),
                                                  itemBuilder: (context, index) {
                                                    int rowNumber = index + (getNumberOfSeatRows(_numberOfSeatRowsController.text)/2).toInt();
                                                    bool isSelected = _toiletAtRowNumberController.text == rowNumber.toString();
                                                    return GestureDetector(
                                                      onTap: () {
                                                        setState(() {
                                                          _toiletAtRowNumberController.text = rowNumber.toString();
                                                        });
                                                      },
                                                      child: Container(
                                                        margin: const EdgeInsets.only(right: 8),
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: isSelected ? Colors.teal[700] : Colors.white,
                                                          borderRadius: BorderRadius.circular(15),
                                                          border: Border.all(
                                                            color: isSelected ? Colors.teal[700]! : Colors.grey[300]!,
                                                          ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            'Row $rowNumber',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: isSelected ? Colors.white : Colors.grey[700],
                                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.amber[50],
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.amber[200]!),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.info_outline, size: 14, color: Colors.amber[700]),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Toilet will be placed after the specified row, spanning across 2 rows',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.amber[800],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),



                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Visual bus layout preview
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.visibility, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            'Preview Layout',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Simple bus layout preview
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Left side preview
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isHavingToilet && isToiletAtLeftSide
                                      ? Colors.teal[100]
                                      : Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: isHavingToilet && isToiletAtLeftSide
                                      ? Icon(Icons.wc, size: 20, color: Colors.blue[700])
                                      : Icon(Icons.event_seat, size: 20, color: Colors.green[700]),
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Aisle
                              Container(
                                width: 20,
                                height: 40,
                                color: Colors.grey[200],
                                child: const Center(
                                  child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 20),
                              // Right side preview
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isHavingToilet && !isToiletAtLeftSide
                                      ? Colors.teal[100]
                                      : Colors.green[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Center(
                                  child: isHavingToilet && !isToiletAtLeftSide
                                      ? Icon(Icons.wc, size: 20, color: Colors.blue[700])
                                      : Icon(Icons.event_seat, size: 20, color: Colors.green[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green[400],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('Seat', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 12),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.teal[400],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('Toilet', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                ),                
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for toilet side selection option
  Widget _buildToiletSideOption({
    required bool isLeft,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.teal[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.teal[400]! : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              isLeft ? Icons.format_align_left : Icons.format_align_right,
              color: isSelected ? Colors.teal[700] : Colors.grey[600],
              size: 24,
            ),
            const SizedBox(height: 8),
            Text(
              isLeft ? 'Left Side' : 'Right Side',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.teal[700] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isLeft ? 'Toilet on left' : 'Toilet on right',
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.teal[500] : Colors.grey[500],
              ),
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.teal[700],
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
    

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = _isLargeScreen(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Route'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 1000 : double.infinity,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 32 : 16,
              vertical: 16,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLargeScreen) ...[
                    const Text(
                      'Add Route',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'Route Information',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),

                  const SizedBox(height: 6),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _routeNameController.text),

                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return busRoutes.map((BusRoute) => '${BusRoute.from.toUpperCase()}-${BusRoute.to.toUpperCase()}' );
                      }
                      return busRoutes.map((busRoute) => busRoute.from.toUpperCase().contains(textEditingValue.text.toUpperCase()) ? '${busRoute.from.toUpperCase()}-${busRoute.to.toUpperCase()}' : null).whereType<String>(); 
                    },

                    onSelected: (String selection) {
                      _routeNameController.text = selection;
                      BusRoute? selectedBusRoute = busRoutes.firstWhereOrNull((r) => ('${r.from.toUpperCase()}-${r.to.toUpperCase()}') == selection);
                      debugPrint("Selected route name: $selection");
                      debugPrint("Selected route: ${selectedBusRoute?.from} - ${selectedBusRoute?.to}");

                      if (selectedBusRoute != null) {
                        debugPrint("Selected route ID: ${selectedBusRoute.id}");
                        setState(() {
                          routeId = selectedBusRoute.id;
                        });

                        _fromController.text = selectedBusRoute.from;
                        _toController.text = selectedBusRoute.to;
                        if(_startingPointController.text.isEmpty) {
                          _startingPointController.text = selectedBusRoute.from;
                        }
                        if(_finalPointController.text.isEmpty) {
                          _finalPointController.text = selectedBusRoute.to;
                        }
                        _ticketPriceController.text = selectedBusRoute.ticketPrice.toString();
                      }
                    },

                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      controller.text = _routeNameController.text;

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _buildInputDecoration(
                          'Route Name',
                          hintText: 'Dar - Dom',
                          prefixIcon: Icons.directions_bus,
                        ),
                        onChanged: (value) {
                          _routeNameController.text = value;

                          BusRoute? selectedBusRoute = busRoutes.firstWhereOrNull((r) => ('${r.from.toUpperCase()}-${r.to.toUpperCase()}') == value);

                          if (selectedBusRoute != null) {
                            setState(() {
                              routeId = selectedBusRoute.id;
                            });

                            _fromController.text = selectedBusRoute.from;
                            _toController.text = selectedBusRoute.to;
                            if(_startingPointController.text.isEmpty) {
                              _startingPointController.text = selectedBusRoute.from;
                            }
                            if(_finalPointController.text.isEmpty) {
                              _finalPointController.text = selectedBusRoute.to;
                            }
                            _ticketPriceController.text = selectedBusRoute.ticketPrice.toString();
                          } else {
                            setState(() {
                              routeId = 0;
                            });

                            _fromController.text = '';
                            _toController.text = '';
                            
                            _ticketPriceController.text = '';
                          }
                        },
                        maxLength: 100,
                        validator: (value) {
                          return null;
                        },
                      );
                    },

                    // 👇 THIS CONTROLS HEIGHT
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: SizedBox(
                            height: 300, // 👈 🔥 increase this (e.g. 400, 500)
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);

                                return ListTile(
                                  dense: true, // 👈 reduces item height
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _fromController.text),

                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return regions;
                      }
                      return regions.where((office) =>
                          office.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },

                    onSelected: (String selection) {
                      _fromController.text = selection;
                    },

                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      controller.text = _fromController.text;

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _buildInputDecoration(
                          AppLocalizations.of(context)!.from,
                          prefixIcon: Icons.business,
                        ),
                        onChanged: (value) {
                          _fromController.text = value;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!.pleaseEnterOrigin;
                          }
                          return null;
                        },
                      );
                    },

                    // 👇 THIS CONTROLS HEIGHT
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: SizedBox(
                            height: 300, // 👈 🔥 increase this (e.g. 400, 500)
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);

                                return ListTile(
                                  dense: true, // 👈 reduces item height
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _toController.text),

                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return regions;
                      }
                      return regions.where((office) =>
                          office.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },

                    onSelected: (String selection) {
                      _toController.text = selection;
                    },

                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      controller.text = _toController.text;

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _buildInputDecoration(
                          AppLocalizations.of(context)!.to2,
                          prefixIcon: Icons.business,
                        ),
                        onChanged: (value) {
                          _toController.text = value;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!.pleaseEnterDestination;
                          }
                          return null;
                        },
                      );
                    },

                    // 👇 THIS CONTROLS HEIGHT
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: SizedBox(
                            height: 300, // 👈 🔥 increase this (e.g. 400, 500)
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);

                                return ListTile(
                                  dense: true, // 👈 reduces item height
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _startingPointController.text),

                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return offices;
                      }
                      return offices.where((office) =>
                          office.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },

                    onSelected: (String selection) {
                      _startingPointController.text = selection;
                    },

                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      controller.text = _startingPointController.text;

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _buildInputDecoration(
                          AppLocalizations.of(context)!.startingPoint,
                          prefixIcon: Icons.location_on_outlined,
                        ),
                        onChanged: (value) {
                          _startingPointController.text = value;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!.pleaseEnterOrigin;
                          }
                          return null;
                        },
                      );
                    },

                    // 👇 THIS CONTROLS HEIGHT
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: SizedBox(
                            height: 300, // 👈 🔥 increase this (e.g. 400, 500)
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);

                                return ListTile(
                                  dense: true, // 👈 reduces item height
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _finalPointController.text),

                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return offices;
                      }
                      return offices.where((office) =>
                          office.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },

                    onSelected: (String selection) {
                      _finalPointController.text = selection;
                    },

                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      controller.text = _finalPointController.text;

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _buildInputDecoration(
                          AppLocalizations.of(context)!.finalPoint,
                          prefixIcon: Icons.location_on_outlined,
                        ),
                        onChanged: (value) {
                          _finalPointController.text = value;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!.pleaseEnterDestination;
                          }
                          return null;
                        },
                      );
                    },

                    // 👇 THIS CONTROLS HEIGHT
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: SizedBox(
                            height: 300, // 👈 🔥 increase this (e.g. 400, 500)
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);

                                return ListTile(
                                  dense: true, // 👈 reduces item height
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ticketPriceController,
                    maxLength: 100,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: _buildInputDecoration('Ticket Price', prefixIcon: Icons.monetization_on, hintText: 'Ticket Price'),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter ticket price';
                      if (value.length > 100) return 'Ticket price must be 100 characters or less';
                      return null;
                    },
                  ),
                
                  const SizedBox(height: 24),

                  _buildDateTimePickers(isLargeScreen),
                  const SizedBox(height: 16),
                  _buildDateTimePickers2(isLargeScreen),

                  const SizedBox(height: 16),

                  const Text(
                    'Bus Information',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _busRegistrationNumberController.text),

                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return buses.map((bus) => bus.registrationNumber.toUpperCase());
                      }
                      
                      return buses.map((bus) => bus.registrationNumber.toUpperCase().contains(textEditingValue.text.toUpperCase()) ? bus.registrationNumber.toUpperCase() : null).whereType<String>();
                    },

                    onSelected: (String selection) {
                      _busRegistrationNumberController.text = selection;
                      Bus? selectedBus = buses.firstWhereOrNull((r) => r.registrationNumber == selection);

                      debugPrint("Bus registration number: $selection");
                      debugPrint("Selected route: ${selectedBus?.registrationNumber} - ${selectedBus?.name}");

                      if (selectedBus != null) {
                        debugPrint("Selected bus ID: ${selectedBus.id}");
                        setState(() {
                          busId = selectedBus.id;
                          isHavingToilet = selectedBus.isHavingToilet;
                          isToiletAtLeftSide = selectedBus.isToiletAtLeftSide;
                          numberOfRowsThatToiletSpans = selectedBus.numberOfRowsThatToiletSpans;
                        });
                        _busNameController.text = selectedBus.name.toString();
                        _numberOfSeatRowsController.text = selectedBus.numberOfSeatRows.toString();
                        _seatsPerRowController.text = selectedBus.seatsPerRow.toString();
                        _toiletAtRowNumberController.text = selectedBus.toiletAtRowNumber.toString();
                      }
                    },

                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      controller.text = _busRegistrationNumberController.text;

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _buildInputDecoration(
                          'Bus Registration Number',
                          prefixIcon: Icons.confirmation_number,
                          hintText: 'T 123 ABC',
                        ),
                        onChanged: (value) {
                          _busRegistrationNumberController.text = value;
                          Bus? selectedBus = buses.firstWhereOrNull((r) => r.registrationNumber == value);

                          if (selectedBus != null) {
                            setState(() {
                              busId = selectedBus.id;
                              isHavingToilet = selectedBus.isHavingToilet;
                              isToiletAtLeftSide = selectedBus.isToiletAtLeftSide;
                              numberOfRowsThatToiletSpans = selectedBus.numberOfRowsThatToiletSpans;
                            });

                            _busNameController.text = selectedBus.name.toString();
                            _numberOfSeatRowsController.text = selectedBus.numberOfSeatRows.toString();
                            _seatsPerRowController.text = selectedBus.seatsPerRow.toString();
                            _toiletAtRowNumberController.text = selectedBus.toiletAtRowNumber.toString();
                          } else {
                            setState(() {
                              busId = 0;
                              isHavingToilet = true;
                              isToiletAtLeftSide = true;
                              numberOfRowsThatToiletSpans = 2;
                            });
                            _busNameController.text = '';
                            _numberOfSeatRowsController.text = '';
                            _seatsPerRowController.text = '';
                            _toiletAtRowNumberController.text = '';
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!.pleaseEnterBusRegistrationNumber;
                          }
                          return null;
                        },
                      );
                    },

                    // 👇 THIS CONTROLS HEIGHT
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          child: SizedBox(
                            height: 300, // 👈 🔥 increase this (e.g. 400, 500)
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);

                                return ListTile(
                                  dense: true, // 👈 reduces item height
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _busNameController,
                    maxLength: 100,
                    decoration: _buildInputDecoration('Bus Name', prefixIcon: Icons.directions_bus),
                    style: const TextStyle(fontSize: 16),
                    enabled: busId == 0, // Disable if a bus is selected
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterBusName;
                      if (value.length > 100) return 'Bus name must be 100 characters or less';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  _buildRowsAndSeatsField(),
                  
                  const SizedBox(height: 16),
                  SizedBox(
                    width: isLargeScreen ? 400 : double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _addBusRoute,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.teal[800],
                      ),
                      child: _isLoading 
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Add Route',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}