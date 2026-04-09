import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/bus_route.dart';
import 'package:tiketi_mkononi/screens/bus_tickets_checkout_page.dart';

class FindBusRoutesPage extends StatefulWidget {
  final int userId;
  final int officeId;
  final String companyName;
  final String userName;
  final String userPhoneNumber;
  final int companyId;
  final String role;

  const FindBusRoutesPage({super.key, required this.userId, required this.officeId, required this.companyId, required this.companyName, required this.userName, required this.userPhoneNumber, required this.role});

  @override
  State<FindBusRoutesPage> createState() => _FindBusRoutesPageState();
}

class _FindBusRoutesPageState extends State<FindBusRoutesPage> {
  bool _isLoading = false;
  String? _error;
  List<BusRoute> _busRoutes = [];
  int numberOfRoutes = 0;
  DateTime _selectedDate = DateTime.now();
  String _typeFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String from = '';
  String to = '';
  List<String> regions = [];

  @override
  void initState() {
    super.initState();
    getRegions();
    String dateStr = DateFormat('d-M-yyyy').format(DateTime.now());
    _selectedDate = DateFormat('d-M-yyyy').parse(dateStr);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _findBusRoutes({bool useDNS = true}) async {
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both origin and destination locations')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final uri = useDNS 
        ? Uri.parse('${backend_url}api/find_bus_routes/${Uri.encodeComponent(from)}/${Uri.encodeComponent(to)}/${DateFormat('d-M-yyyy').format(_selectedDate)}')
        : Uri.parse('${backend_url_with_fallback_ip}find_bus_routes/${Uri.encodeComponent(from)}/${Uri.encodeComponent(to)}/${DateFormat('d-M-yyyy').format(_selectedDate)}');

      final response = await http.get(uri);

      debugPrint('Fetching bus routes from 2: $uri');

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => BusRoute.fromJson(json)).toList();
        
        setState(() {
          numberOfRoutes = newItems.length;
          _busRoutes = newItems;
        });
        
        debugPrint('Loaded ${newItems.length} bus routes');
      } else {
        _error = 'Failed to load bus routes (${response.statusCode})';
        debugPrint(_error);
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _findBusRoutes(useDNS: false);
        return;
      }
      _error = 'Network error. Please check your connection.';
    } catch (e) {
      _error = 'Unexpected error occurred: $e';
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCompanyBusRoutes({bool useDNS = true}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final uri = useDNS ? Uri.parse('${backend_url}api/bus_routes/${widget.companyId}/${DateFormat('d-M-yyyy').format(_selectedDate)}/${from}/${to}')
      : Uri.parse('${backend_url_with_fallback_ip}bus_routes/${widget.companyId}/${DateFormat('d-M-yyyy').format(_selectedDate)}/${from}/${to}');

      final response = await http.get(uri);

      debugPrint('Fetching bus routes from: $uri');

      if (response.statusCode == 200) {

        final List<dynamic> jsonList = jsonDecode(response.body);
        var newItems = jsonList.map((json) => BusRoute.fromJson(json)).toList();

        newItems = newItems.where((newItem) => (newItem.to.toLowerCase() != from.toLowerCase())).toList();

        setState(() {
          numberOfRoutes = newItems.length;
          _busRoutes = newItems;
        });
        
        debugPrint('Loaded ${newItems.length} bus routes');
      } else {
        _error = 'Failed to load bus routes (${response.statusCode})';
        debugPrint(_error);
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchCompanyBusRoutes(useDNS: false);
        return;
      }
      _error = 'Network error. Please check your connection.';
    } catch (e) {
      _error = 'Unexpected error occurred: $e';
      debugPrint('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> getRegions({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/get_regions/${widget.companyId}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}get_regions/${widget.companyId}'); // Use IP  

      debugPrint('Fetching company offices from: ${uri.toString()}');
        
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        debugPrint("response.body : ${response.body}");

        final responseData = jsonDecode(response.body); // This is a List<dynamic>

        List<String> regions2 = [];

        // Loop through each office
        for (var office in responseData) {
          // Add name to regions
          if (office['id'] != widget.officeId) {
            regions2.add(office['name']);
          }
          // If this office's id matches widget.officeId, set from
          if (office['id'] == widget.officeId) {
            setState(() {
              from = office['name'];
            });
          }
        }

        if(regions2.length > 0) {
          setState(() {
            regions = regions2;
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
          await getRegions(useDNS: false); // Recursive retry

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

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.calendar_today, color: Colors.teal[700], size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Travel Date',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      if (from.isNotEmpty && to.isNotEmpty) {
        if(widget.companyId > 0) {
          _fetchCompanyBusRoutes();
        } else {
          _findBusRoutes();
        }
      }
    }
  }

  Widget _buildLocationSelectionWidget() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Find Bus Routes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
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
                      'Origin Location',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      from.isEmpty ? 'Select origin location' : from,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: from.isEmpty ? Colors.grey : Colors.black87,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                    onTap: (widget.officeId == 0) ? () => _showLocationPicker(context, isOrigin: true) : () => {}, 
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1, thickness: 1),
                  ),
                  
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
                      'Destination Location',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    subtitle: Text(
                      to.isEmpty ? 'Select destination location' : to,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: to.isEmpty ? Colors.grey : Colors.black87,
                      ),
                    ),
                    trailing: (widget.officeId == 0) ? IconButton(
                      icon: const Icon(Icons.swap_vert, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          String temp = from;
                          from = to;
                          to = temp;
                        });
                      },
                    ) : null,
                    onTap: () => _showLocationPicker(context, isOrigin: false),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Date Picker - Place it HERE
            _buildDatePicker(),
            
            const SizedBox(height: 4),
            
            // Search button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if(widget.companyId > 0) {
                    _fetchCompanyBusRoutes();
                  } else {
                    _findBusRoutes();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Find Routes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationPicker(BuildContext context, {required bool isOrigin}) async {
    final TextEditingController searchController = TextEditingController();
    List<String> searchResults = [];
    
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
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
                          setStateSheet(() {
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
                      setStateSheet(() {
                        if (value.isEmpty) {
                          searchResults = [];
                        } else {
                          searchResults = regions
                              .where((region) => region
                                  .toLowerCase()
                                  .contains(value.toLowerCase()))
                              .toList();
                        }
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Expanded(
                    child: searchResults.isEmpty && searchController.text.isEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'All Locations',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: regions.length,
                                  itemBuilder: (context, index) {
                                    final location = regions[index];
                                    return ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isOrigin 
                                              ? Colors.green[50]
                                              : Colors.red[50],
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isOrigin 
                                              ? Icons.circle
                                              : Icons.location_on,
                                          color: isOrigin 
                                              ? Colors.green
                                              : Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        location,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      subtitle: Text(
                                        location,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        setState(() {
                                          if (isOrigin) {
                                            from = location;
                                          } else {
                                            to = location;
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
                                title: Text(location),
                                subtitle: Text(location),
                                onTap: () {
                                  Navigator.pop(context);
                                  setState(() {
                                    if (isOrigin) {
                                      from = location;
                                    } else {
                                      to = location;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bus Routes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildLocationSelectionWidget(),
            _isLoading ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                    const SizedBox(height: 16),
                    Text(_error!),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        if(widget.companyId > 0) {
                          _fetchCompanyBusRoutes();
                        } else {
                          _findBusRoutes();
                        }
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            : _buildRoutesList(),
          ],
        ),
      ),
    );
  }

  String calculateDuration({
    required String departureDate,
    required String departureTime,
    required String arrivalDate,
    required String arrivalTime,
  }) {
    try {
      // Parse dates and times
      List<String> depDateParts = departureDate.split('-');
      List<String> arrDateParts = arrivalDate.split('-');
      
      // Handle both 2-digit and 4-digit years
      int depYear = int.parse(depDateParts[2]);
      int arrYear = int.parse(arrDateParts[2]);
      
      // Convert 2-digit year to 4-digit if needed (assuming 2000s)
      if (depYear < 100) depYear += 2000;
      if (arrYear < 100) arrYear += 2000;
      
      // Parse departure time (assuming format like "21:00" or "04:55")
      List<String> depTimeParts = departureTime.split(':');
      List<String> arrTimeParts = arrivalTime.split(':');
      
      int depHour = int.parse(depTimeParts[0]);
      int depMinute = int.parse(depTimeParts[1]);
      int arrHour = int.parse(arrTimeParts[0]);
      int arrMinute = int.parse(arrTimeParts[1]);
      
      // Create DateTime objects
      DateTime depDateTime = DateTime(
        depYear,
        int.parse(depDateParts[1]), // month
        int.parse(depDateParts[0]), // day
        depHour,
        depMinute,
      );
      
      DateTime arrDateTime = DateTime(
        arrYear,
        int.parse(arrDateParts[1]), // month
        int.parse(arrDateParts[0]), // day
        arrHour,
        arrMinute,
      );
      
      // Calculate difference
      Duration difference = arrDateTime.difference(depDateTime);
      
      // Handle negative duration (if arrival is before departure, add 24 hours)
      if (difference.isNegative) {
        difference = difference + const Duration(days: 1);
      }
      
      // Format the duration
      int totalHours = difference.inHours;
      int minutes = difference.inMinutes.remainder(60);
      
      // Format as "Xh Ym" or "X hours Y minutes"
      if (totalHours > 0 && minutes > 0) {
        return "${totalHours}h ${minutes}m";
      } else if (totalHours > 0) {
        return "${totalHours}h";
      } else {
        return "${minutes}m";
      }
      
    } catch (e) {
      debugPrint("Error calculating duration: $e");
      return "Duration unknown";
    }
  }

  // Alternative version with more detailed formatting
  String calculateDurationDetailed({
    required String departureDate,
    required String departureTime,
    required String arrivalDate,
    required String arrivalTime,
  }) {
    try {
      // Parse dates
      List<String> depDateParts = departureDate.split('-');
      List<String> arrDateParts = arrivalDate.split('-');
      
      int depDay = int.parse(depDateParts[0]);
      int depMonth = int.parse(depDateParts[1]);
      int depYear = int.parse(depDateParts[2]);
      
      int arrDay = int.parse(arrDateParts[0]);
      int arrMonth = int.parse(arrDateParts[1]);
      int arrYear = int.parse(arrDateParts[2]);
      
      // Convert 2-digit years to 4-digit
      if (depYear < 100) depYear += 2000;
      if (arrYear < 100) arrYear += 2000;
      
      // Parse times
      List<String> depTimeParts = departureTime.split(':');
      List<String> arrTimeParts = arrivalTime.split(':');
      
      int depHour = int.parse(depTimeParts[0]);
      int depMinute = int.parse(depTimeParts[1]);
      int arrHour = int.parse(arrTimeParts[0]);
      int arrMinute = int.parse(arrTimeParts[1]);
      
      // Create DateTime objects
      DateTime departure = DateTime(depYear, depMonth, depDay, depHour, depMinute);
      DateTime arrival = DateTime(arrYear, arrMonth, arrDay, arrHour, arrMinute);
      
      // Calculate duration
      Duration duration = arrival.difference(departure);
      
      // Handle overnight trips
      if (duration.isNegative) {
        duration = Duration(
          hours: (24 - depHour) + arrHour,
          minutes: (60 - depMinute) + arrMinute,
        );
        // Adjust minutes if needed
        if (duration.inMinutes >= 60) {
          duration = Duration(minutes: duration.inMinutes);
        }
      }
      
      // Format output
      int days = duration.inDays;
      int hours = duration.inHours.remainder(24);
      int minutes = duration.inMinutes.remainder(60);
      
      List<String> parts = [];
      
      if (days > 0) {
        parts.add("$days day${days > 1 ? 's' : ''}");
      }
      if (hours > 0) {
        parts.add("$hours hour${hours > 1 ? 's' : ''}");
      }
      if (minutes > 0) {
        parts.add("$minutes minute${minutes > 1 ? 's' : ''}");
      }
      
      return parts.join(" ");
      
    } catch (e) {
      debugPrint("Error calculating duration: $e");
      return "0 hours";
    }
  }

  // Helper function to detect time period (NIGHT, EARLY MORNING, etc.)
  String getTimePeriod(String time) {
    try {
      List<String> timeParts = time.split(':');
      int hour = int.parse(timeParts[0]);
      
      if (hour >= 0 && hour < 4) {
        return "LATE NIGHT";
      } else if (hour >= 4 && hour < 6) {
        return "EARLY MORNING";
      } else if (hour >= 6 && hour < 12) {
        return "MORNING";
      } else if (hour >= 12 && hour < 17) {
        return "AFTERNOON";
      } else if (hour >= 17 && hour < 20) {
        return "EVENING";
      } else {
        return "NIGHT";
      }
    } catch (e) {
      return "";
    }
  }

  Widget _buildRoutesList() {
    var filteredBusRoutes = _busRoutes.where((r) {
      if (_typeFilter == 'all') return true;
      return _typeFilter == 'scheduled'
          ? r.status == 'scheduled'
          : r.status == 'rescheduled';
    }).toList();

    if (_searchQuery.isNotEmpty) {
      filteredBusRoutes = filteredBusRoutes.where(
        (route) => route.from.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                    route.to.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (filteredBusRoutes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No bus routes found for this route'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (widget.companyId > 0) {
          await _fetchCompanyBusRoutes();
        } else {
          await _findBusRoutes();
        }
      },
      color: Colors.teal,
      child: ListView.builder(
        shrinkWrap: true,  // Add this
        physics: const NeverScrollableScrollPhysics(),  // Add this to disable internal scrolling
        padding: const EdgeInsets.all(16),
        itemCount: filteredBusRoutes.length,
        itemBuilder: (context, index) {
          final route = filteredBusRoutes[index];


          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide.none,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                color: Colors.white,
                child: InkWell(
                  onTap: () {
                    debugPrint('Selected route: ${route.from} → ${route.to}');
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusTicketsCheckoutPage(
                          userId: widget.userId,
                          companyId: widget.companyId,
                          busRoute: route,
                          refreshMethod: () {},
                        ),
                      )
                    );
                  },
                  splashColor: Colors.teal.withOpacity(0.1),
                  highlightColor: Colors.teal.withOpacity(0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// COMPANY NAME & BUS TYPE
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Text(
                                route.company!.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.teal.shade800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                route.bus!.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        /// BUS MODEL & PLATE NUMBER
                        Row(
                          children: [
                            Icon(Icons.directions_bus, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              route.bus?.type ?? "bus type",
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.shade200),
                              ),
                              child: Text(
                                route.bus!.registrationNumber,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        /// TERMINAL INFORMATION
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.teal.shade600),
                            const SizedBox(width: 6),
                            Text(
                              route.from,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        /// ROUTE (FROM → TO)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    route.from,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                  Text(
                                    route.from,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(Icons.arrow_forward, size: 16, color: Colors.teal.shade700),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    route.to,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                  Text(
                                    route.to,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        /// TIME INFORMATION (DEPARTURE & ARRIVAL)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.departure_board, size: 16, color: Colors.teal.shade700),
                                        const SizedBox(width: 6),
                                        Text(
                                          "DEPARTURE",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade500,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      route.departureTime,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade800,
                                      ),
                                    ),
                                    Text(
                                      route.departureDate,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (route.departureTime.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          route.departureTime,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.indigo.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                child: Column(
                                  children: [
                                    Icon(Icons.arrow_forward, size: 20, color: Colors.grey.shade400),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${calculateDurationDetailed(departureDate: route.departureDate, departureTime: route.departureTime, arrivalDate: route.arrivalDate, arrivalTime: route.arrivalTime)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          "ARRIVAL",
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade500,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.flag, size: 16, color: Colors.teal.shade700),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      route.arrivalTime,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade800,
                                      ),
                                    ),
                                    Text(
                                      route.arrivalDate,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (route.arrivalTime.isNotEmpty)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          route.arrivalTime!,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),

                        /// AVAILABLE SEATS & PRICE
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: route.id == 0 ? Colors.red.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: route.id == 0 ? Colors.red.shade200 : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_seat,
                                      size: 18,
                                      color: route.id == 0 ? Colors.red.shade700 : Colors.teal.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Available Seats",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            route.id == 0 ? "SOLD OUT" : "${route.id} seats left",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: route.id == 0 ? Colors.red.shade700 : Colors.teal.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Colors.teal.shade50, Colors.teal.shade100],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.currency_franc, size: 18, color: Colors.teal.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Price per seat",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.teal.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            "TZS ${NumberFormat('#,##0').format(route.ticketPrice)}",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 14,
                                              color: Colors.teal.shade800,
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}