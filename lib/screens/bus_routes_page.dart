import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/bus_route.dart';
import 'package:tiketi_mkononi/screens/add_bus_route_page.dart';
import 'package:tiketi_mkononi/screens/bus_tickets_checkout_page.dart';
import 'package:url_launcher/url_launcher.dart';  // Hide Excel's Border

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
  String? _error;
  List<BusRoute> _busRoutes = [];
  BusRoute? _selectedBusRoute;
  bool _showDetails = false;
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
  bool _isEditing = false;
  BusRoute? _editingRoute;

  @override
  void initState() {
    super.initState();
    String dateStr = DateFormat('d-M-yyyy').format(DateTime.now());
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
        _error = null;
        _showDetails = false;
        _selectedBusRoute = null;
      });

      final uri = useDNS ? Uri.parse('$backend_url/api/bus_routes/${widget.companyId}/${DateFormat('d-M-yyyy').format(_selectedDate)}')
      : Uri.parse('${backend_url_with_fallback_ip}bus_routes/${widget.companyId}/${DateFormat('d-M-yyyy').format(_selectedDate)}');

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

  IconData _getPackageTypeIcon(bool? type) {
    if (type!)
      return Icons.inventory_2;   // package/box icon
    else
      return Icons.local_shipping; // shipment icon
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
        title: Text(
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

      body: Stack(
        children: [

          RefreshIndicator(
            onRefresh: _fetchBusRoutes,
            color: Colors.teal,
            child: _buildBody(),
          ),

          if (_showDetails && _selectedBusRoute != null) ...[
            
            /// This disables background clicks
            ModalBarrier(
              dismissible: true,
              onDismiss: () {
                setState(() {
                  _showDetails = false;
                  _selectedBusRoute = null;
                });
              },
              color: Colors.black.withOpacity(0.2),
            ),

            /// Details panel
            Align(
              alignment: Alignment.bottomCenter,
              child: _buildDetailsPanel(),
            ),
          ],
        ],
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
      onPressed: () {
        Navigator.pushReplacement(
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

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType:
            isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final isLargeScreen = _isLargeScreen(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 60,
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchBusRoutes,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_busRoutes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox,
                size: 80,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Bus Routes Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bus routes you create will appear here',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    var filteredBusRoutes = _busRoutes.where((r) {
      if (_typeFilter == 'all') return true;
      return _typeFilter == 'scheduled'
          ? r.status == 'scheduled'
          : r.status == 'rescheduled';
    }).toList();

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredBusRoutes = filteredBusRoutes.where(
        (route) => (route.to.toLowerCase().contains(_searchQuery.toLowerCase()) || route.from.toLowerCase().contains(_searchQuery.toLowerCase()))
      ).toList();
    }

    setState(() {
      numberOfRoutes = filteredBusRoutes.length;
    });

    return Column(
      children: [
        // Search Bar
        if (_isSearchBarVisible) _buildSearchBar(isDarkMode, isLargeScreen),

        // FILTER BUTTONS
        _buildTypeFilter(),

        // Main Amount/Count
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.teal.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$numberOfRoutes',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                (numberOfRoutes > 1) ? 'Routes' : 'Route',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.teal[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 26,
                ),
              ),
            ],
          ),
        ),

        isLargeScreen ? Expanded(
          child: Row(
            children: [
              /// LEFT PANEL — Bus Routes LIST
              Container(
                width: 420,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: ListView.builder(
                  itemCount: filteredBusRoutes.length,
                  itemBuilder: (context, index) {
                    final route = filteredBusRoutes[index];
                    final isSelected = _selectedBusRoute == route;

                    return Card(
                      elevation: isSelected ? 6 : 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: isSelected
                            ? BorderSide(color: Colors.teal.shade400, width: 2)
                            : BorderSide.none,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          debugPrint('Selected route: ${route.from} → ${route.to}');
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BusTicketsCheckoutPage(userId: widget.userId, companyId: widget.companyId, busRoute: route, refreshMethod: _fetchBusRoutes),
                            )
                          );
                          
                          _fetchBusRoutes();
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [

                              /// PACKAGE ICON
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getPackageTypeIcon(route.status == 'scheduled'),
                                  color: Colors.teal,
                                ),
                              ),

                              const SizedBox(width: 12),

                              /// PACKAGE INFO
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start, 
                                  children: [
                                    Text(
                                      '${route.from} - ${route.to}' ?? 'Unnamed Route',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${route.from} → ${route.to}",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade400,
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              /// RIGHT PANEL — DETAILS
              Expanded(
                child: _selectedBusRoute == null
                    ? Center(
                        child: Text(
                          "Select a route to view details",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildRouteDetails(_selectedBusRoute!),
                      ),
              ),
            ],
          ),
        ) :
        Expanded(
          child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredBusRoutes.length,
              itemBuilder: (context, index) {
                final route = filteredBusRoutes[index];
                final isSelected = _selectedBusRoute == route;

                return Card(
                  elevation: isSelected ? 8 : 2,
                  margin: const EdgeInsets.only(bottom: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: isSelected
                        ? BorderSide(color: Colors.teal.shade300, width: 2)
                        : BorderSide.none,
                  ),

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Material(
                      color: Colors.white,
                      child: InkWell(
                        onTap: () async {
                          debugPrint('Selected route: ${route.from} → ${route.to}');
                          // sell ticket for this route
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BusTicketsCheckoutPage(userId: widget.userId, companyId: widget.companyId, busRoute: route, refreshMethod: _fetchBusRoutes),
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
                              /// ================= HEADER =================
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          "${route.from}",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1A1A1A),
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Icon(
                                            Icons.arrow_forward,
                                            size: 16,
                                            color: Colors.teal.shade300,
                                          ),
                                        ),
                                        Text(
                                          "${route.to}",
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF1A1A1A),
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              /// TIME INFORMATION
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.schedule, size: 18, color: Colors.grey.shade600),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Departure: ${route.departureTime} • Arrival: ${route.arrivalTime}",
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              /// PRICE
                              Container(
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
                                    Text(
                                      "TZS ${NumberFormat('#,##0').format(route.ticketPrice)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: Colors.teal.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              /// ================= EXPANDABLE EDIT FORM =================
                              if (_isEditing && _editingRoute?.id == route.id) ...[
                                const SizedBox(height: 24),
                                Divider(height: 1, color: Colors.grey.shade200),
                                const SizedBox(height: 20),

                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        _buildTextField("Origin", _originController),
                                        const SizedBox(height: 12),
                                        _buildTextField("Destination", _destinationController),
                                        const SizedBox(height: 12),
                                        _buildTextField("Departure Time", _departureController),
                                        const SizedBox(height: 12),
                                        _buildTextField("Arrival Time", _arrivalController),
                                        const SizedBox(height: 12),
                                        _buildTextField("Ticket Price", _priceController, isNumber: true),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            /// SAVE BUTTON
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    route.from = _originController.text;
                                                    route.to = _destinationController.text;
                                                    route.departureTime = _departureController.text;
                                                    route.arrivalTime = _arrivalController.text;
                                                    route.ticketPrice =
                                                        double.tryParse(_priceController.text) ?? 0;

                                                    _isEditing = false;
                                                    _editingRoute = null;
                                                  });

                                                  // 👉 call your update API here
                                                  print("Updated route ${route.id}");
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.teal.shade600,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  elevation: 0,
                                                ),
                                                child: const Text("Save Changes"),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            /// CANCEL BUTTON
                                            Expanded(
                                              child: OutlinedButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _isEditing = false;
                                                    _editingRoute = null;
                                                  });
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.grey.shade700,
                                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  side: BorderSide(color: Colors.grey.shade300),
                                                ),
                                                child: const Text("Cancel"),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 6),

                              Row(
                                children: [
                                  /// EDIT BUTTON
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.edit_outlined, 
                                        color: Colors.teal.shade700, 
                                        size: 14,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isEditing = true;
                                          _editingRoute = route;

                                          _originController.text = route.from;
                                          _destinationController.text = route.to;
                                          _departureController.text = route.departureTime;
                                          _arrivalController.text = route.arrivalTime;
                                          _priceController.text = route.ticketPrice.toString();
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  /// DELETE BUTTON
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.delete_outline, 
                                        color: Colors.red.shade600, 
                                        size: 14,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text("Delete Route"),
                                            content: const Text(
                                                "Are you sure you want to delete this route?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text("Cancel"),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => Navigator.pop(context, true),
                                                child: const Text("Delete"),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          // 👉 call your delete API/function here
                                          print("Deleted route ${route.id}");
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 18),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.info_outline, 
                                        color: Colors.teal.shade700,
                                        size: 14,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _selectedBusRoute = route;
                                          _showDetails = true;
                                        });
                                      },
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
          )
        )
      ]
    );
  }

  List<BluetoothInfo> devices = [];

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