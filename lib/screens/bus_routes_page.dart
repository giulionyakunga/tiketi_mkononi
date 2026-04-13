import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/bus_route.dart';
import 'package:tiketi_mkononi/screens/add_bus_route_page.dart';
import 'package:tiketi_mkononi/screens/bus_tickets_checkout_page.dart';

class BusRoutesPage extends StatefulWidget {
  final int userId;
  final int officeId;
  final String officeName;
  final String companyName;
  final String userName;
  final String userPhoneNumber;
  final int companyId;
  final String role;

  const BusRoutesPage({super.key, required this.userId, required this.officeId, required this.officeName, required this.companyId, required this.companyName, required this.userName, required this.userPhoneNumber, required this.role});

  @override
  State<BusRoutesPage> createState() => _BusRoutesPageState();
}

class _BusRoutesPageState extends State<BusRoutesPage> {
  bool _isLoading = true;
  String _error = '';
  List<BusRoute> _busRoutes = [];
  BusRoute? _selectedBusRoute;
  int numberOfRoutes = 0;
  DateTime _selectedDate = DateTime.now();
  BluetoothInfo? selectedPrinter;
  Printer? selectedCablePrinter;
  String _typeFilter = 'all';
  
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchBarVisible = false;


  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  final _priceController = TextEditingController();
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();

    // Add 1 day to current date, then format and parse
    DateTime tomorrow = DateTime.now().add(Duration(days: 1));
    String dateStr = DateFormat('d-M-yyyy').format(tomorrow);
    _selectedDate = DateFormat('d-M-yyyy').parse(dateStr);

    _fetchBusRoutes();

  }

  @override
  void dispose() {
    _searchController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _departureController.dispose();
    _arrivalController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  
  Widget _buildSearchBar(bool isDarkMode, bool isLargeScreen) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.symmetric( 
        vertical: 8,
        horizontal: isLargeScreen ? 200 : 16,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDarkMode
              ? colorScheme.surfaceContainerHighest.withOpacity(0.8)
              : colorScheme.surface.withOpacity(0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.2 : 0.1),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDarkMode
                ? colorScheme.outline.withOpacity(0.3)
                : colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search package or sender name...',
            hintStyle: TextStyle(
              fontSize: isLargeScreen ? 16 : 14,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            border: InputBorder.none,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 6),
              child: Icon(
                Icons.search_rounded,
                size: isLargeScreen ? 24 : 20,
                color: isDarkMode ? Colors.white70 : Colors.teal[800]
              ),
            ),
            suffixIcon: _searchQuery.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: isLargeScreen ? 24 : 20,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged();
                        FocusScope.of(context).unfocus();
                      },
                    ),
                  )
                : null,
            contentPadding: EdgeInsets.symmetric(
              vertical: isLargeScreen ? 14 : 10,
              horizontal: 16,
            ),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: isLargeScreen ? 16 : 14,
            color: colorScheme.onSurface,
          ),
          cursorColor: colorScheme.primary,
          cursorWidth: 1.5,
          cursorHeight: isLargeScreen ? 20 : 18,
          onChanged: (value) => _onSearchChanged(),
        ),
      ),
    );
  }


  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  Future<void> _fetchBusRoutes({bool useDNS = true}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
        _showDetails = false;
        _selectedBusRoute = null;
      });

      final uri = useDNS ? Uri.parse('$backend_url/api/scheduled_bus_routes/${widget.companyId}/${DateFormat('d-M-yyyy').format(_selectedDate)}')
      : Uri.parse('${backend_url_with_fallback_ip}scheduled_bus_routes/${widget.companyId}/${DateFormat('d-M-yyyy').format(_selectedDate)}');

      final response = await http.get(uri);

      debugPrint('Fetching bus routes from: $uri');

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
        await _fetchBusRoutes(useDNS: false);
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

  Future<void> deleteRoute(int routeId, {bool useDNS = true}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
        _showDetails = false;
        _selectedBusRoute = null;
      });

      final uri = useDNS ? Uri.parse('$backend_url/api/delete_bus_route/${widget.userId}/$routeId')
      : Uri.parse('${backend_url_with_fallback_ip}scheduled_bus_routes/${widget.userId}/$routeId');

      debugPrint('Deleting bus routes from: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        if(response.body == 'Bus Route deleted successfully') {
          _fetchBusRoutes();

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.body),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.body),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else if (response.statusCode == 403) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.body),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        _error = 'Failed to delete bus routes (${response.statusCode})';
        debugPrint(_error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await deleteRoute(routeId, useDNS: false);
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

  Widget _buildDatePicker() {
    return TextButton.icon(
      onPressed: () => _selectDate(context),
      icon: const Icon(Icons.calendar_today, size: 18), // Optional: Adjust icon size
      label: Text(
        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
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
          side: BorderSide(color: Colors.teal[800]!, width: 1.5),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025),    // Allow dates as early as year 2000
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      if((picked != _selectedDate)) {
        setState(() {
          _selectedDate = picked;
        });
        _fetchBusRoutes();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bus Routes',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600
          ),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _buildDatePicker(),
          ),
          if (_selectedBusRoute != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _showDetails = false;
                  _selectedBusRoute = null;
                });
              },
            ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            (_isLoading && _busRoutes.isEmpty) ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text('Loading routes...'),
                ],
              ),
            )
            : _error != ''
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
                        _fetchBusRoutes();
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

      floatingActionButton: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [

    // ➕ Add Button (Primary)
    FloatingActionButton.extended(
      heroTag: "addBtn",
      backgroundColor: Colors.teal,
      tooltip: "Add Bus Route",
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddBusRoutePage(
              userId: widget.userId,
              companyId: widget.companyId,
              companyName: widget.companyName,
              userName: widget.userName,
              userPhoneNumber: widget.userPhoneNumber,
              isReplacableScreen: true, refreshMethod: _fetchBusRoutes,
            ),
          ),
        );
        _fetchBusRoutes();
      },
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        "Add",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    ),

    const SizedBox(height: 12),

    // 🔍 Search Button
    FloatingActionButton(
      heroTag: "searchBtn",
      backgroundColor: Colors.grey.shade800,
      mini: true,
      tooltip: "Search",
      onPressed: () {
        setState(() {
          _isSearchBarVisible = !_isSearchBarVisible;
          _searchController.clear();
          _onSearchChanged();
        });
      },
      child: const Icon(Icons.search, color: Colors.white),
    ),
    
  ],
),
      
    );
  }

  Widget _buildTypeFilter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(6, 12, 16, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: "All",
              icon: Icons.list,
              value: "all",
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: "Scheduled",
              icon: Icons.directions_bus,
              value: "scheduled",
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: "Rescheduled",
              icon: Icons.bus_alert,
              value: "rescheduled",
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: "Canceled",
              icon: Icons.bus_alert,
              value: "canceled",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final bool isActive = _typeFilter == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _typeFilter = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.teal : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.teal : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
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

  String getTimeOfDay(String time24) {
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

    // Determine time of day
    if (hour >= 5 && hour < 12) {
      return "Asubuhi"; // Morning
    } else if (hour >= 12 && hour < 17) {
      return "Mchana"; // Afternoon
    } else if (hour >= 17 && hour < 21) {
      return "Jioni"; // Evening
    } else {
      return "Usiku"; // Night (21:00–04:59)
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
      return 
       Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
                  const SizedBox(height: 16),
                  Text('No bus routes found for this date'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _fetchBusRoutes();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _fetchBusRoutes();
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
                  onTap: () async {
                    debugPrint('Selected route: ${route.from} → ${route.to}');
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BusTicketsCheckoutPage(
                          userId: widget.userId,
                          role: widget.role,
                          companyId: widget.companyId,
                          companyName: widget.companyName,
                          busRoute: route,
                          refreshMethod: () {},
                        ),
                      )
                    );
                    _fetchBusRoutes();
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
                                overflow: TextOverflow.ellipsis,
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
                                overflow: TextOverflow.ellipsis,
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
                              overflow: TextOverflow.ellipsis, 
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
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                  Text(
                                    route.startingPoint,
                                    overflow: TextOverflow.ellipsis,
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
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.teal.shade900,
                                    ),
                                  ),
                                  Text(
                                    route.finalPoint,
                                    overflow: TextOverflow.ellipsis,
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
                        const SizedBox(height: 6),

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
                                        const SizedBox(width: 4),
                                        Text(
                                          AppLocalizations.of(context)!.departure.toUpperCase(),
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
                                      '(${getTimeOfDay(route.departureTime)})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      route.departureDate,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                child: Column(
                                  children: [
                                    Text(
                                      'VIA ${route.via}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.green.shade600,
                                        fontWeight: FontWeight.w500
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${calculateDurationDetailed(departureDate: route.departureDate, departureTime: route.departureTime, arrivalDate: route.arrivalDate, arrivalTime: route.arrivalTime)}',
                                        overflow: TextOverflow.ellipsis,
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
                                          AppLocalizations.of(context)!.arrival.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade500,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
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
                                      '(${getTimeOfDay(route.arrivalTime)})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      route.arrivalDate,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey.shade600,
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
                                  color: route.availableSeats == 0 ? Colors.red.shade50 : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: route.availableSeats == 0 ? Colors.red.shade200 : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.event_seat,
                                      size: 18,
                                      color: route.availableSeats == 0 ? Colors.red.shade700 : Colors.teal.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            AppLocalizations.of(context)!.availableSeats,
                                            style: TextStyle( 
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            route.availableSeats == 0 ? "SOLD OUT" : "${route.availableSeats} seats left",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: route.availableSeats == 0 ? Colors.red.shade700 : Colors.teal.shade800,
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
                                            AppLocalizations.of(context)!.pricePerSeat,
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
                                              fontSize: 13,
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
                        const SizedBox(height: 6),

                        if(widget.userId == route.userId)
                        /// DELETE ICON - Bottom Right
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () {
                                // Check if booking has started
                                final int totalSeats = route.bus!.seatsPerRow * route.bus!.numberOfSeatRows;
                                final bool hasStartedBooking = route.availableSeats != totalSeats;
                                
                                if (hasStartedBooking) {
                                  // Show error dialog - booking already started
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Row(
                                        children: [
                                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 28),
                                          const SizedBox(width: 12),
                                          Expanded(  // ← This constrains the text
                                            child: Text(
                                              'Cannot Delete Route',
                                              style: TextStyle(fontWeight: FontWeight.bold),
                                              overflow: TextOverflow.ellipsis, // Optional: adds ... if still too long
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: const Text(
                                        'This route cannot be removed because passengers have already started booking seats.',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.teal.shade700,
                                          ),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  // Show confirmation dialog for deletion
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Row(
                                        children: [
                                          Icon(Icons.delete_outline, color: Colors.red.shade700, size: 28),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Delete Route',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Are you sure you want to delete this route?',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: Colors.grey.shade200),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${route.from} → ${route.to}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.teal.shade800,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Date: ${route.departureDate} at ${route.departureTime}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          const Text(
                                            'This action cannot be undone.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.grey.shade700,
                                          ),
                                          child: const Text('CANCEL'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            // Close dialog
                                            Navigator.pop(context);

                                            debugPrint('Delete route: ${route.id}');
                                            deleteRoute(route.id);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade700,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text('DELETE'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_outline, color: Colors.red.shade700, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppLocalizations.of(context)!.deleteRoute,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red.shade700,
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

  Widget _buildDetailsPanel() {
    final route = _selectedBusRoute;
    if (route == null) return const SizedBox();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        children: [

          /// DRAG HANDLE
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          /// HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.directions_bus, color: Colors.teal.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Route Details (${route.status.toUpperCase()})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          /// BODY
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// BUS INFO
                  _buildDetailSection(
                    title: 'Bus Information',
                    icon: Icons.directions_bus,
                    children: [
                      _buildDetailRow(
                          'Bus Number',
                          route.bus?.registrationNumber ?? 'N/A'),
                      _buildDetailRow(
                          'Name',
                          route.bus?.name ?? 'N/A'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// ROUTE
                  _buildDetailSection(
                    title: 'Route',
                    icon: Icons.route,
                    children: [
                      _buildDetailRow('From', route.from),
                      _buildDetailRow('To', route.to),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// SCHEDULE
                  _buildDetailSection(
                    title: 'Schedule',
                    icon: Icons.schedule,
                    children: [
                      _buildDetailRow('Departure Date', route.departureDate),
                      _buildDetailRow('Departure Time', route.departureTime),
                      _buildDetailRow('Arrival Date', route.arrivalDate),
                      _buildDetailRow('Arrival Time', route.arrivalTime),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// FINANCIALS
                  _buildDetailSection(
                    title: 'Pricing',
                    icon: Icons.attach_money,
                    children: [
                      _buildDetailRow(
                        'Ticket Price',
                        "TZS ${NumberFormat('#,##0').format(route.ticketPrice)}",
                      ),
                      _buildDetailRow(
                        'Total Collection',
                        "TZS ${NumberFormat('#,##0').format(route.totalCollection)}",
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// STATUS
                  _buildDetailSection(
                    title: 'Status',
                    icon: Icons.info,
                    children: [
                      _buildDetailRow('Current Status: ', route.status.toUpperCase()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.teal),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDetails(BusRoute route) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// HEADER
            Row(
              children: [
                Icon(Icons.directions_bus, color: Colors.teal.shade700),
                const SizedBox(width: 6),
                Text(
                  'Route Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            /// BUS INFO
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_bus, color: Colors.teal),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.bus?.registrationNumber ?? 'Unknown Bus',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        route.bus?.name ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// ROUTE (FROM → TO)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 18, color: Colors.green.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            route.from,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(Icons.arrow_forward, size: 18),

                  Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 18, color: Colors.red.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            route.to,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// DATE & TIME
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    icon: Icons.calendar_today,
                    label: "Departure Date",
                    value: route.departureDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoTile(
                    icon: Icons.access_time,
                    label: "Departure Time",
                    value: route.departureTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    icon: Icons.calendar_month,
                    label: "Arrival Date",
                    value: route.arrivalDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoTile(
                    icon: Icons.access_time_filled,
                    label: "Arrival Time",
                    value: route.arrivalTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            /// PRICE & COLLECTION
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    icon: Icons.attach_money,
                    label: "Ticket Price",
                    value:
                        "TZS ${NumberFormat('#,##0').format(route.ticketPrice)}",
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoTile(
                    icon: Icons.account_balance_wallet,
                    label: "Total Collection",
                    value:
                        "TZS ${NumberFormat('#,##0').format(route.totalCollection)}",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// STATUS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: route.status == 'scheduled'
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                route.status.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: route.status == 'scheduled'
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String? value, {
    bool clickable = false,
    VoidCallback? onTap,
  }) {
    final displayValue = value ?? 'N/A';

    Widget valueWidget = Text(
      displayValue,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: clickable ? Colors.blue : Colors.black,
        decoration:
            clickable ? TextDecoration.underline : TextDecoration.none,
      ),
    );

    if (clickable && onTap != null) {
      valueWidget = GestureDetector(
        onTap: onTap,
        child: valueWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(child: valueWidget),
        ],
      ),
    );
  }
}