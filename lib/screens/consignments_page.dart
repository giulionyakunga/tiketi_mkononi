import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tiketi_mkononi/screens/add_consignment_page.dart';
import 'package:tiketi_mkononi/services/SimpleCodec.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:url_launcher/url_launcher.dart';  // Hide Excel's Border


class ConsignmentsPage extends StatefulWidget {
  final int userId;
  final int officeId;
  final String officeName;
  final String companyName;
  final String userName;
  final String userPhoneNumber;
  final int companyId;
  final String role;

  const ConsignmentsPage({super.key, required this.userId, required this.officeId, required this.officeName, required this.companyId, required this.companyName, required this.userName, required this.userPhoneNumber, required this.role});

  @override
  State<ConsignmentsPage> createState() => _ConsignmentsPageState();
}

class _ConsignmentsPageState extends State<ConsignmentsPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _consignments = [];
  double totalCollection = 0;
  dynamic _selectedConsignment;
  bool _showDetails = false;
  DateTime _selectedDate = DateTime.now();
  BluetoothInfo? selectedPrinter;
  Printer? selectedCablePrinter;
  String _appbarLabel = 'Consignments';
  String _typeFilter = 'all'; // all | parcel | consignment
  String _paymentFilter = 'all'; // all | parcel | consignment
  

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchBarVisible = false;

  @override
  void initState() {
    super.initState();
    String dateStr = DateFormat('d-M-yyyy').format(DateTime.now());
    _selectedDate = DateFormat('d-M-yyyy').parse(dateStr);

    _fetchConsignments();

    if (Platform.isWindows) {
      _loadSelectedPrinter();
    }
  
    loadAndMatchPrinter();

  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _fetchConsignments({bool useDNS = true}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _showDetails = false;
        _selectedConsignment = null;
      });

      final uri = useDNS ? Uri.parse('$backend_url/api/consignments/${widget.userId}/${widget.role}/${widget.officeId}/${widget.companyId}/${DateFormat('d-M-yyyy').format(_selectedDate)}')
      : Uri.parse('${backend_url_with_fallback_ip}consignments/${widget.userId}/${widget.role}/${widget.officeId}/${widget.companyId}/${DateFormat('d-M-yyyy').format(_selectedDate)}');

      final response = await http.get(uri);

      debugPrint('Fetching consignments from: $uri');

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);
        
        // Handle different response structures
        List<dynamic> consignmentsList = [];
        if (responseData is List) {
          consignmentsList = responseData;
        } else if (responseData is Map && responseData.containsKey('data')) {
          consignmentsList = responseData['data'] as List;
        }

        double totalPaidAmount = 0;

        for (var consignment in consignmentsList) {
          totalPaidAmount += (consignment['paid_amount'] ?? 0).toDouble();
        }

        setState(() {
          totalCollection = totalPaidAmount;
          _consignments = consignmentsList;
        });
        
        debugPrint('Loaded ${consignmentsList.length} consignments');
      } else {
        _error = 'Failed to load consignments (${response.statusCode})';
        debugPrint(_error);
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchConsignments(useDNS: false);
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

  String _getPaymentStatusText(bool? status) {
    if (status == null) return 'Unknown';
    return status ? 'Paid' : 'Not Paid';
  }

  Color _getPaymentStatusColor(bool? status) {
    if (status == null) return Colors.grey;
    return status ? Colors.green : Colors.teal;
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
        _fetchConsignments();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (widget.officeId > 0) ? '${widget.officeName} $_appbarLabel' : '$_appbarLabel',
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
          if (_selectedConsignment != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _showDetails = false;
                  _selectedConsignment = null;
                  _printBluetoothTestReceipt();
                  if (Platform.isWindows) {
                    _refreshCablePrinters();
                  }
                });
              },
            ),
        ],
      ),

      body: Stack(
        children: [

          RefreshIndicator(
            onRefresh: _fetchConsignments,
            color: Colors.teal,
            child: _buildBody(),
          ),

          if (_showDetails && _selectedConsignment != null) ...[
            
            /// This disables background clicks
            ModalBarrier(
              dismissible: true,
              onDismiss: () {
                setState(() {
                  _showDetails = false;
                  _selectedConsignment = null;
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
      tooltip: "Add Consignment",
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => AddConsignmentPage(
              userId: widget.userId,
              companyId: widget.companyId,
              companyName: widget.companyName,
              officeId: widget.officeId,
              userName: widget.userName,
              userPhoneNumber: widget.userPhoneNumber,
              isReplacableScreen: true,
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
              label: "Parcels",
              icon: Icons.inventory_2,
              value: "parcels",
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: "Consignments",
              icon: Icons.local_shipping,
              value: "consignments",
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: "Paid",
              icon: Icons.check_circle,
              value: "paid",
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: "Unpaid",
              icon: Icons.money_off,
              value: "unpaid",
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: "Export Unpaid",
              icon: Icons.download,
              value: "export_unpaid",
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: "Export Paid",
              icon: Icons.download,
              value: "export_paid",
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              label: "Export All",
              icon: Icons.download,
              value: "export_all",
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
        if (value == 'all') {
          setState(() {
            _paymentFilter = 'all';
            _typeFilter = value;
            _appbarLabel = '${value[0].toUpperCase() + value.substring(1)}';
          });
        }
        if((value == 'parcels') || (value == 'consignments')) {
          setState(() {
            _paymentFilter = 'all';
            _typeFilter = value;
            _appbarLabel = '${value[0].toUpperCase() + value.substring(1)}';
          });
        } else if (value == 'unpaid') {
          setState(() {
            _typeFilter = 'all';
            _paymentFilter = value;
          });
        } else if (value == 'export_unpaid') {
          exportUnpaidPackages(_consignments);
        } else if (value == 'export_paid') {
          exportPaidPackages(_consignments);
        } else if (value == 'export_all') {
          exportAllPackages(_consignments);
        } else if (value == 'paid') {
          setState(() {
            _typeFilter = 'all';
            _paymentFilter = value;
          });
        }
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
  
  Future<void> exportUnpaidPackages(List<dynamic> consignments) async {
    if(consignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No packages found')),
      );
      return;
    }
    
    consignments = consignments.where((c) {
      return (c['payment_status'] == false);
    }).toList();

    // Create a new Excel document
    final excel = Excel.createExcel();
    final Sheet sheet = excel.sheets['Sheet1']!;

    // Add header row
    sheet.appendRow([
      'Package Name',
      'Package Number',
      'Sender Name',
      'Sender Phone',
      'From',
      'To',
      'Receiver Name',
      'Receiver Phone',
      'Package Value',
      'Amount to be Paid',
      'Payment Status',
      'Is Parcel',
      'Items',
      'Issued By',
      'Issuer Phone'
    ]);

    // Add consignment data
    for (final consignment in consignments) {

      // Convert consignment items to a readable string
      final items = (consignment['consignment_items'] as List)
          .map((item) =>
              "${item['name']} (x${item['quantity']}) - ${item['value']}")
          .join(", ");

      sheet.appendRow([
        consignment['package_name'],
        consignment['id'],
        consignment['sender_name'],
        consignment['sender_phone_number'],
        consignment['from'],
        consignment['to'],
        consignment['receiver_name'],
        consignment['receiver_phone_number'],
        consignment['package_value'],
        consignment['paid_amount'],
        consignment['payment_status'] ? 'Paid' : 'Unpaid',
        consignment['is_parcel'] ? 'Yes' : 'No',
        items,
        consignment['issued_by'],
        consignment['issuer_phone_number'],
      ]);
    }


    // Save the file
    try {
      if(kIsWeb) { 
        // Trigger download in browser
        excel.save(fileName: 'Unpaid_Packages.xlsx');
      } else {
        // if(share) {
        //     // 2. Save to a temporary file (mobile only)
        //     final dir = await getTemporaryDirectory();
        //     final file = File('${dir.path}/Unpaid_Packages.xlsx');
        //     await file.writeAsBytes(excel.encode()!);

        //     // 3. Share the file
        //     await Share.shareXFiles(
        //       [XFile(file.path)],  // Wrap in XFile
        //       text: 'Check out this tickets data! 📊',  // Optional text
        //     );
        // }else {

          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/Unpaid_Packages.xlsx';
          final file = File(filePath);
          await file.writeAsBytes(excel.encode()!);

          // Open the file
          await OpenFilex.open(filePath);
        
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      // Handle error (show a snackbar or dialog)
    }
  }

  Future<void> exportPaidPackages(List<dynamic> consignments) async {
    if(consignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No packages found')),
      );
      return;
    }

    consignments = consignments.where((c) {
      return c['payment_status'] == true;
    }).toList();

    // Create a new Excel document
    final excel = Excel.createExcel();
    final Sheet sheet = excel.sheets['Sheet1']!;

    // Add header row
    sheet.appendRow([
      'Package Name',
      'Package Number',
      'Sender Name',
      'Sender Phone',
      'From',
      'To',
      'Receiver Name',
      'Receiver Phone',
      'Package Value',
      'Paid Amount',
      'Payment Status',
      'Is Parcel',
      'Items',
      'Issued By',
      'Issuer Phone'
    ]);

    // Add consignment data
    for (final consignment in consignments) {

      // Convert consignment items to a readable string
      final items = (consignment['consignment_items'] as List)
          .map((item) =>
              "${item['name']} (x${item['quantity']}) - ${item['value']}")
          .join(", ");

      sheet.appendRow([
        consignment['package_name'],
        consignment['id'],
        consignment['sender_name'],
        consignment['sender_phone_number'],
        consignment['from'],
        consignment['to'],
        consignment['receiver_name'],
        consignment['receiver_phone_number'],
        consignment['package_value'],
        consignment['paid_amount'],
        consignment['payment_status'] ? 'Paid' : 'Unpaid',
        consignment['is_parcel'] ? 'Yes' : 'No',
        items,
        consignment['issued_by'],
        consignment['issuer_phone_number'],
      ]);
    }


    // Save the file
    try {
      if(kIsWeb) { 
        // Trigger download in browser
        excel.save(fileName: 'Paid_Packages.xlsx');
      } else {
        // if(share) {
        //     // 2. Save to a temporary file (mobile only)
        //     final dir = await getTemporaryDirectory();
        //     final file = File('${dir.path}/Paid_Packages.xlsx');
        //     await file.writeAsBytes(excel.encode()!);

        //     // 3. Share the file
        //     await Share.shareXFiles(
        //       [XFile(file.path)],  // Wrap in XFile
        //       text: 'Check out this tickets data! 📊',  // Optional text
        //     );
        // }else {

          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/Paid_Packages.xlsx';
          final file = File(filePath);
          await file.writeAsBytes(excel.encode()!);

          // Open the file
          await OpenFilex.open(filePath);
        
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      // Handle error (show a snackbar or dialog)
    }
  }


  Future<void> exportAllPackages(List<dynamic> consignments) async {
    if(consignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No packages found')),
      );
      return;
    }

    // Create a new Excel document
    final excel = Excel.createExcel();
    final Sheet sheet = excel.sheets['Sheet1']!;

    // Add header row
    sheet.appendRow([
      'Package Name',
      'Package Number',
      'Sender Name',
      'Sender Phone',
      'From',
      'To',
      'Receiver Name',
      'Receiver Phone',
      'Package Value',
      'Paid Amount',
      'Payment Status',
      'Is Parcel',
      'Items',
      'Issued By',
      'Issuer Phone'
    ]);

    // Add consignment data
    for (final consignment in consignments) {

      // Convert consignment items to a readable string
      final items = (consignment['consignment_items'] as List)
          .map((item) =>
              "${item['name']} (x${item['quantity']}) - ${item['value']}")
          .join(", ");

      sheet.appendRow([
        consignment['package_name'],
        consignment['id'],
        consignment['sender_name'],
        consignment['sender_phone_number'],
        consignment['from'],
        consignment['to'],
        consignment['receiver_name'],
        consignment['receiver_phone_number'],
        consignment['package_value'],
        consignment['paid_amount'],
        consignment['payment_status'] ? 'Paid' : 'Unpaid',
        consignment['is_parcel'] ? 'Yes' : 'No',
        items,
        consignment['issued_by'],
        consignment['issuer_phone_number'],
      ]);
    }


    // Save the file
    try {
      if(kIsWeb) { 
        // Trigger download in browser
        excel.save(fileName: 'All_Packages.xlsx');
      } else {
        // if(share) {
        //     // 2. Save to a temporary file (mobile only)
        //     final dir = await getTemporaryDirectory();
        //     final file = File('${dir.path}/All_Packages.xlsx');
        //     await file.writeAsBytes(excel.encode()!);

        //     // 3. Share the file
        //     await Share.shareXFiles(
        //       [XFile(file.path)],  // Wrap in XFile
        //       text: 'Check out this tickets data! 📊',  // Optional text
        //     );
        // }else {

          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/All_Packages.xlsx';
          final file = File(filePath);
          await file.writeAsBytes(excel.encode()!);

          // Open the file
          await OpenFilex.open(filePath);
        
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      // Handle error (show a snackbar or dialog)
    }
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
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
                onPressed: _fetchConsignments,
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

    if (_consignments.isEmpty) {
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
              'No Consignments Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Consignments you create will appear here',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    var filteredConsignments = _consignments.where((c) {
      if (_typeFilter == 'all') return true;
      return _typeFilter == 'parcels'
          ? c['is_parcel'] == true
          : c['is_parcel'] == false;
    }).toList();

    filteredConsignments = filteredConsignments.where((c) {
      if (_paymentFilter == 'all') return true;
      return _paymentFilter == 'unpaid' ? c['payment_status'] == false : c['payment_status'] == true;
    }).toList();


    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredConsignments = filteredConsignments.where(
        (consignment) => (consignment['package_name'].toLowerCase().contains(_searchQuery.toLowerCase()) || consignment['sender_name'].toLowerCase().contains(_searchQuery.toLowerCase()))
      ).toList();
    }

    double totalPaidAmount = 0;

    for (var consignment in filteredConsignments) {
      totalPaidAmount += (consignment['paid_amount'] ?? 0).toDouble();
    }

    setState(() {
      totalCollection = totalPaidAmount;
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
                'TSH ${NumberFormat('#,##0').format(totalCollection)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Total Revenue',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.teal[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        isLargeScreen ? Expanded(
          child: Row(
            children: [
              /// LEFT PANEL — CONSIGNMENT LIST
              Container(
                width: 420,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: ListView.builder(
                  itemCount: filteredConsignments.length,
                  itemBuilder: (context, index) {
                    final consignment = filteredConsignments[index];
                    final isSelected = _selectedConsignment == consignment;

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
                        onTap: () {
                          setState(() {
                            _selectedConsignment = consignment;
                          });
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
                                  _getPackageTypeIcon(consignment['is_parcel']),
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
                                      consignment['package_name'] ??
                                          'Unnamed Package',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${consignment['from']} → ${consignment['to']}",
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
                child: _selectedConsignment == null
                    ? Center(
                        child: Text(
                          "Select a consignment to view details",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildConsignmentDetails(_selectedConsignment),
                      ),
              ),
            ],
          ),
        ) :
        Expanded(
          child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredConsignments.length,
              itemBuilder: (context, index) {
                final consignment = filteredConsignments[index];
                final isSelected = _selectedConsignment == consignment;
          

              final paidAmount = (consignment['paid_amount'] ?? 0).toInt();

              return Card(
                elevation: isSelected ? 8 : 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: isSelected
                      ? BorderSide(color: Colors.teal.shade300, width: 2)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (_selectedConsignment == consignment) {
                        _showDetails = !_showDetails;
                      } else {
                        _selectedConsignment = consignment;
                        _showDetails = true;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getPackageTypeIcon(consignment['is_parcel']),
                                color: Colors.teal,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: 
                                  Text(
                                    consignment['package_name'] ?? 'Unnamed Package',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              
                            ),
                            // Paid amount at top right
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "TZS ${NumberFormat('#,##0').format(paidAmount)}",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.teal.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              child: const SizedBox(width: 20),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getPaymentStatusColor(
                                        consignment['payment_status'])
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    consignment['payment_status'] == true
                                        ? Icons.check_circle
                                        : Icons.pending,
                                    size: 14,
                                    color: _getPaymentStatusColor(
                                        consignment['payment_status']),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getPaymentStatusText(
                                        consignment['payment_status']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: _getPaymentStatusColor(
                                          consignment['payment_status']),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getPaymentStatusColor(
                                        consignment['payment_status'])
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Package No: ${consignment['id']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: _getPaymentStatusColor(
                                          consignment['payment_status']),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Route information
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        consignment['from'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.arrow_forward,
                                    size: 16, color: Colors.grey.shade400),
                              ),
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 16, color: Colors.grey.shade600),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        consignment['to'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        // Sender & Receiver info
                        Row(
                          children: [
                            Expanded(
                              child: _buildPersonInfo(
                                icon: Icons.person_outline,
                                label: 'Sender',
                                name: consignment['sender_name'],
                                phone: consignment['sender_phone_number'],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.grey.shade300,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            Expanded(
                              child: _buildPersonInfo(
                                icon: Icons.person,
                                label: 'Receiver',
                                name: consignment['receiver_name'],
                                phone: consignment['receiver_phone_number'],
                              ),
                            ),
                          ],
                        ),
                      ],
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

  Widget _buildPersonInfo({
    required IconData icon,
    required String label,
    required String? name,
    required String? phone,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          name ?? 'N/A',
          style: const TextStyle(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          phone ?? 'N/A',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  List<BluetoothInfo> devices = [];

  
  Future<void> _refreshBluetoothPrinters() async {
    debugPrint("Refreshing printers...");
    devices = await PrintBluetoothThermal.pairedBluetooths;

    debugPrint("Refreshing printers...");

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No paired Bluetooth printer found')),
      );
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Found ${devices.length} paired Bluetooth printer')),
      );
    }

    await _selectPrinterDialog();
  }
  

  Future<void> _refreshCablePrinters() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("selected_printer_url");
    await prefs.remove("selected_printer_name");

    setState(() {
      selectedCablePrinter = null;
    });

    await _selectCablePrinterDialog(); // fallback
  }

  Future<void> _printBluetoothTestReceipt() async {
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
        const SnackBar(content: Text("Printer not connected")),
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

  Future<void> _printBluetoothReceipt(dynamic consignment) async {
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
        const SnackBar(content: Text("Printer not connected")),
      );
      selectedPrinter = null;
      await _refreshBluetoothPrinters();
      if (selectedPrinter == null) return;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);

    final items = consignment['consignment_items'] ?? [];

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
      consignment['is_parcel'] ? "PARCEL RECEIPT" : "CONSIGNMENT RECEIPT",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      "Package No: ${consignment['id']}",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.row([
      PosColumn(text: "Package Name", width: 6),
      PosColumn(text: consignment['package_name'] ?? '', width: 6),
    ]);
    
    double packageValue = double.tryParse(
      consignment['package_value']?.toString() ?? '0'
    ) ?? 0;

    bytes += generator.row([
      PosColumn(text: "Package Value", width: 6),
      PosColumn(text: 'TZS ${NumberFormat('#,##0').format(packageValue)}', width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Payment Status", width: 6),
      PosColumn(text: consignment['payment_status'] ? "Paid" : "Not Paid", width: 6),
    ]);

    double paidAmount = double.tryParse(
      consignment['paid_amount']?.toString() ?? '0'
    ) ?? 0;

    bytes += generator.row([
      PosColumn(text: "Paid Amount", width: 6),
      PosColumn(text: 'TZS ${NumberFormat('#,##0').format(paidAmount)}', width: 6),
    ]);

    bytes += generator.text(
      "Route:",
      styles: const PosStyles(bold: true),
    );

    bytes += generator.row([
      PosColumn(text: "From", width: 6),
      PosColumn(text: consignment['from'] ?? '', width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "To", width: 6),
      PosColumn(text: consignment['to'] ?? '', width: 6),
    ]);

    bytes += generator.text(
      "Sender:",
      styles: const PosStyles(bold: true),
    );
    bytes += generator.row([
      PosColumn(text: "Name", width: 6),
      PosColumn(text: consignment['sender_name'] ?? '', width: 6),
    ]);
    bytes += generator.row([
      PosColumn(text: "Phone number", width: 6),
      PosColumn(text: consignment['sender_phone_number'] ?? '', width: 6),
    ]);

    bytes += generator.text(
      "Receiver:",
      styles: const PosStyles(bold: true),
    );
    bytes += generator.row([
      PosColumn(text: "Name", width: 6),
      PosColumn(text: consignment['receiver_name'] ?? '', width: 6),
    ]);
    bytes += generator.row([
      PosColumn(text: "Phone number", width: 6),
      PosColumn(text: consignment['receiver_phone_number'] ?? '', width: 6),
    ]);

    int totalAmount = 0;
    // Items
    if(items.length > 1) {
      for (var item in items) {
        totalAmount += (item['value'] as num).toInt() * (item['quantity'] as num).toInt();
        bytes += generator.row([
          PosColumn(
              text: "${item['name']} x${item['quantity']}", width: 8),
          PosColumn(
              text: "TZS ${NumberFormat('#,##0').format(((item['value'] ?? 0)))}", width: 4, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      bytes += generator.text("--------------------------------",
        styles: const PosStyles(
          align: PosAlign.center,
        )
      );

      bytes += generator.row([
        PosColumn(text: "Total Amount", width: 6),
        PosColumn(text: "TZS ${NumberFormat('#,##0').format(totalAmount)}", width: 6, styles: const PosStyles(align: PosAlign.right)),
      ]);

      bytes += generator.text("--------------------------------",
        styles: const PosStyles(
          align: PosAlign.center,
        )
      );
    }


    bytes += generator.text(
      "Issued By:",
      styles: const PosStyles(bold: true),
    );
    bytes += generator.row([
      PosColumn(text: "Name", width: 6),
      PosColumn(text: consignment['issued_by'] ?? '', width: 6),
    ]);
    bytes += generator.row([
      PosColumn(text: "Phone number", width: 6),
      PosColumn(text: consignment['issuer_phone_number'] ?? '', width: 6),
    ]);

    // QR
    String data = SimpleCodec.encode(jsonEncode({
      "cid": consignment['id'],
      "oid": consignment['office_id'],
    }));

    bytes += generator.qrcode(
      data,
      size: QRSize.size5,
    );

    bytes += generator.text(
      'Karibu Sana',
      styles: const PosStyles(align: PosAlign.center)
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

  Future<void> _printBluetoothReceipt2(dynamic consignment) async {
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
        const SnackBar(content: Text("Printer not connected")),
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
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      )
    );

    bytes += generator.text("********************************",
      styles: const PosStyles(
        align: PosAlign.center,
      )
    );

    bytes += generator.text(
      consignment['is_parcel'] ? "PARCEL INFO" : "CONSIGNMENT INFO",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      "PKG No: ${consignment['id']}",
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.text(
      "PKG Name: ${consignment['package_name']}",
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.text(
      "${consignment['from']} to ${consignment['to']}",
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.text(
      "Name:${consignment['receiver_name']}",
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      "Phone:${consignment['receiver_phone_number']}",
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    // QR
    String data = SimpleCodec.encode(jsonEncode({
      "cid": consignment['id'],
      "oid": consignment['office_id'],
    }));

    bytes += generator.qrcode(
      data,
      size: QRSize.size7,
    );

    bytes += generator.text(
      'Karibu Sana',
      styles: const PosStyles(align: PosAlign.center)
    );

    bytes += generator.text(
      'Powered by Tiketi Mkononi',
      styles: const PosStyles(align: PosAlign.center)
    );
    bytes += generator.text(
      'Email:tiketimkononi@telabs.co.tz',
      styles: const PosStyles(align: PosAlign.center)
    );
  
    bytes += generator.feed(1);
    bytes += generator.cut();

    await PrintBluetoothThermal.writeBytes(bytes);
  }
  
  Future<void> _printCableReceipt(dynamic consignment) async {
    final pdf = pw.Document();

    // final logoData = await rootBundle.load('assets/telabs_logo.png');
    // final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    final fontData =
        await rootBundle.load('assets/fonts/poppins/Poppins-Regular.ttf');
    final customFont = pw.Font.ttf(fontData);

    const pageWidth = 226.0;

    final items = consignment['consignment_items'] ?? [];

    String data = SimpleCodec.encode(jsonEncode({
      "cid": consignment['id'],
      "oid": consignment['office_id'],
    }));

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(pageWidth, double.infinity),
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                /// LOGO
                // pw.Center(
                //   child: pw.Image(logoImage, width: 70),
                // ),

                pw.SizedBox(height: 6),

                /// COMPANY NAME
                // pw.Center(
                //   child: pw.Text(
                //     widget.companyName,
                //     style: pw.TextStyle(
                //       font: customFont,
                //       fontSize: 10,
                //       fontWeight: pw.FontWeight.bold,
                //     ),
                //   ),
                // ),

                pw.Text(
                  widget.companyName,
                  style: pw.TextStyle(font: customFont, fontSize: 10),
                ),

                // pw.Center(
                //   child: pw.Text(
                //     consignment['is_parcel']
                //         ? "PARCEL RECEIPT"
                //         : "CONSIGNMENT RECEIPT",
                //     style: pw.TextStyle(
                //       font: customFont,
                //       fontSize: 9,
                //       fontWeight: pw.FontWeight.bold,
                //     ),
                //   ),
                // ),

                pw.Text(
                  consignment['is_parcel']
                  ? "PARCEL RECEIPT"
                  : "CONSIGNMENT RECEIPT",
                  style: pw.TextStyle(font: customFont, fontSize: 10),
                ),

                pw.SizedBox(height: 6),

                pw.Text(
                  "********************************",
                  style: pw.TextStyle(font: customFont),
                ),

                /// PACKAGE INFO
                pw.Text(
                  "Package No: ${consignment['id']}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                pw.Text(
                  "Package Name: ${consignment['package_name'] ?? ''}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                pw.Text(
                  "Package Value: TZS ${consignment['package_value']}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                pw.Text(
                  "Payment Status: ${consignment['payment_status'] ? "Paid" : "Not Paid"}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                if (consignment['payment_status'])
                  pw.Text(
                    "Paid Amount: TZS ${consignment['paid_amount']}",
                    style: pw.TextStyle(font: customFont, fontSize: 9),
                  ),

                pw.SizedBox(height: 6),

                pw.Text(
                  "--------------------------------",
                  style: pw.TextStyle(font: customFont),
                ),

                /// ROUTE
                pw.Text(
                  "Route",
                  style: pw.TextStyle(
                    font: customFont,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9
                  ),
                ),

                pw.Text(
                  "From: ${consignment['from'] ?? ''}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                pw.Text(
                  "To: ${consignment['to'] ?? ''}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                pw.SizedBox(height: 6),

                /// SENDER
                pw.Text(
                  "Sender",
                  style: pw.TextStyle(
                    font: customFont,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9
                  ),
                ),

                pw.Text(
                  "Name: ${consignment['sender_name'] ?? ''}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                pw.Text(
                  "Phone: ${consignment['sender_phone_number'] ?? ''}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                pw.SizedBox(height: 6),

                /// RECEIVER
                pw.Text(
                  "Receiver",
                  style: pw.TextStyle(
                    font: customFont,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9
                  ),
                ),

                pw.Text(
                  "Name: ${consignment['receiver_name'] ?? ''}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                pw.Text(
                  "Phone: ${consignment['receiver_phone_number'] ?? ''}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                /// ITEMS
                if ((items.length > 1) && (items.length <= 10)) ...[
                  pw.SizedBox(height: 6),

                  pw.Text(
                    "Items",
                    style: pw.TextStyle(
                      font: customFont,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9
                    ),
                  ),

                  pw.SizedBox(height: 4),

                  for (int i = 0; i < items.length; i++)
                    pw.Text(
                      "${i + 1}. ${items[i]['name']} (x${items[i]['quantity']})  "
                      "TZS ${NumberFormat('#,##0').format(((items[i]['value'] ?? 0) * items[i]['quantity']).toInt())}",
                      style: pw.TextStyle(font: customFont, fontSize: 9),
                    ),
                ],

                pw.SizedBox(height: 6),

                pw.Text(
                  "--------------------------------",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                /// ISSUED BY
                pw.Text(
                  "Issued By",
                  style: pw.TextStyle(
                    font: customFont,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9
                  ),
                ),

                pw.Text(
                  "Name: ${consignment['issued_by'] ?? ''}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                pw.Text(
                  "Phone: ${consignment['issuer_phone_number'] ?? ''}",
                  style: pw.TextStyle(font: customFont, fontSize: 9),
                ),

                pw.SizedBox(height: 14),

                /// QR
                pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: data,
                    width: 110,
                    height: 110,
                  ),
                ),

                pw.SizedBox(height: 10),

                /// FOOTER
                pw.Center(
                  child: pw.Text(
                    "Thank you",
                    style: pw.TextStyle(font: customFont, fontSize: 9),
                  ),
                ),

                pw.SizedBox(height: 10),

                pw.Center(
                  child: pw.Text(
                    "Powered by Tiketi Mkononi",
                    style: pw.TextStyle(font: customFont, fontSize: 10),
                  ),
                ),

                pw.Center(
                  child: pw.Text(
                    "Email:tiketimkononi@telabs.co.tz",
                    style: pw.TextStyle(fontSize: 9),
                  ),
                ),

                pw.Text(
                  "********************************",
                  style: pw.TextStyle(font: customFont),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (selectedCablePrinter != null) {
      await Printing.directPrintPdf(
        printer: selectedCablePrinter!,
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } else {
      await _selectCablePrinterDialog();
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

  Future<void> saveSelectedPrinter(BluetoothInfo printer) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('printer_name', printer.name);
    await prefs.setString('printer_mac', printer.macAdress);
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




  Future<void> _selectCablePrinterDialog() async {
    final printers = await Printing.listPrinters();

    if (printers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No printers found.')),
      );
      return;
    }

    Printer? selected;

    await showDialog(
      context: context,
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;
            final dialogWidth = isSmallScreen ? constraints.maxWidth * 0.9 : 400.0;

            return AlertDialog(
              contentPadding: EdgeInsets.all(20),
              title: Text("Select a printer"),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: dialogWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: printers
                        .map(
                          (printer) => ListTile(
                            title: Text(printer.name),
                            subtitle: Text(printer.url),
                            onTap: () {
                              selected = printer;
                              Navigator.of(context).pop();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      // Save selected printer
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedPrinterUrl', selected!.url);
      _saveSelectedCablePrinter(selected!);
      selectedCablePrinter = selected;
    }
  }

  Future<void> _loadSelectedPrinter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('selected_printer_url');
    String? name = prefs.getString('selected_printer_name');

    if (url != null && name != null) {
      setState(() {
        selectedCablePrinter = Printer(url: url, name: name);
      });
    }
  }

  Future<void> _saveSelectedCablePrinter(Printer printer) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_url', printer.url);
    await prefs.setString('selected_printer_name', printer.name);
    setState(() {
      selectedCablePrinter = printer;
    });
  }

  Future<void> _shareConsignment(dynamic consignment) async {
    final pdf = pw.Document();
    final items = consignment['consignment_items'] ?? [];

    String data = SimpleCodec.encode(jsonEncode({
      "cid": consignment['id'],
      "oid": consignment['office_id'],
    }));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              pw.SizedBox(height: 8),

              pw.Center(
                child: pw.Text(
                  widget.companyName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Center(
                child: pw.Text(
                  consignment['is_parcel'] ? 'PARCEL RECEIPT' : 'CONSIGNMENT RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 5),

              pw.Center(
                child: pw.Text(
                  "  Package No: ${consignment['id']}",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 3),

              _pdfRow('  Package Name', consignment['package_name']),

              _pdfRow(
                '  Package Value',
                'TZS ${NumberFormat('#,##0').format((consignment['package_value'] ?? 0).toInt())}',
              ),

              _pdfRow(
                '  Paid Amount',
                'TZS ${NumberFormat('#,##0').format((consignment['paid_amount'] ?? 0).toInt())}',
              ),

              pw.Divider(),

              pw.Text('  Route', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),

              _pdfRow('  From', consignment['from']),
              _pdfRow('  To', consignment['to']),

              pw.Divider(),

              pw.Text('  Sender', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),

              _pdfRow('  Name', consignment['sender_name']),
              _pdfRow('  Phone', consignment['sender_phone_number']),

              pw.Divider(),

              pw.Text('  Receiver', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),

              _pdfRow('  Name', consignment['receiver_name']),
              _pdfRow('  Phone', consignment['receiver_phone_number']),

              if (items.length > 1) ...[
                pw.Divider(),
                pw.Text('  Items', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),


                ...items.asMap().entries.map<pw.Widget>((entry) {
                  int index = entry.key;
                  var item = entry.value;

                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '  ${index + 1}. ${item['name']}',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      ),
                      _pdfRow('    Quantity', '${item['quantity'] ?? 1}'),
                      _pdfRow(
                        '    Total Value',
                        'TZS ${NumberFormat('#,##0').format(((item['value'] ?? 0) * item['quantity']).toInt())}',
                      ),
                      pw.SizedBox(height: 4),
                    ],
                  );
                }).toList(),
              ],

              pw.Divider(),

              pw.Text('  Issued By', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),

              _pdfRow('  Name', consignment['issued_by']),
              _pdfRow('  Phone', consignment['issuer_phone_number']),

              pw.SizedBox(height: 6),

              pw.Center( child: pw.BarcodeWidget( barcode: pw.Barcode.qrCode(), data: data, width: 60, height: 60, ),),

              pw.SizedBox(height: 8),

              pw.Center(
                child: pw.Text(
                  'Thank you',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),

              pw.SizedBox(height: 10),

              pw.Center(
                child: pw.Text(
                  'Powered by Tiketi Mkononi',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ),
                            
              pw.SizedBox(height: 2),

              pw.Center(
                child: pw.Text(
                  "Email:tiketimkononi@telabs.co.tz",
                  style: pw.TextStyle(fontSize: 9),
                ),
              ),

              pw.SizedBox(height: 10),

            ],
          );
        },
      ),
    );

    // Save PDF
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/receipt.pdf',
    );

    await file.writeAsBytes(await pdf.save());

    // Share PDF
    await Share.shareXFiles(
      [XFile(file.path)],
      text: consignment['is_parcel'] ? 'Parcel Receipt' : 'Consignment Receipt',
    );
  }
  
  pw.Widget _pdfRow(String label, String? value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontSize: 7),
            ),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(
              value ?? '',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel() {
    final consignment = _selectedConsignment;
    if (consignment == null) return const SizedBox();

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
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline, 
                  color: Colors.teal.shade700
                ),

                const SizedBox(width: 4),

                Expanded(
                  child: Text(
                    consignment['is_parcel'] ? 'Parcel Details' : 'Consignment Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),

                SizedBox(
                  width: 32,
                  child: IconButton(
                    icon: const Icon(Icons.share),
                    color: Colors.blue,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _shareConsignment(consignment),
                  ),
                ),

                SizedBox(
                  width: 32,
                  child: IconButton(
                    icon: const Icon(Icons.print),
                    color: Colors.teal,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () { 
                      _printBluetoothReceipt(consignment);
                      if (Platform.isWindows) {
                        _printCableReceipt(consignment);
                      }
                    },
                  ),
                ),

                SizedBox(
                  width: 32,
                  child: IconButton(
                    icon: const Icon(Icons.print),
                    color: Colors.red,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _printBluetoothReceipt2(consignment),
                  ),
                ),
              ],
            )
          ),

          const Divider(),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection(
                    title: 'Package Information',
                    icon: Icons.inventory,
                    children: [
                      _buildDetailRow('Package No', '${consignment['id']}'),
                      _buildDetailRow('Package Name', consignment['package_name']),
                      _buildDetailRow('Package Value', 'TZS${NumberFormat('#,##0').format(  (consignment['package_value'] ?? 0).toInt())}'),
                      _buildDetailRow('Paid Amount', 'TZS${NumberFormat('#,##0').format(  (consignment['paid_amount'] ?? 0).toInt())}'),
                      
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildDetailSection(
                    title: 'Route Information',
                    icon: Icons.route,
                    children: [
                      _buildDetailRow('From', consignment['from']),
                      _buildDetailRow('To', consignment['to']),
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildDetailSection(
                    title: 'Sender Details',
                    icon: Icons.person_outline,
                    children: [
                      _buildDetailRow('Name', consignment['sender_name']),
                      _buildDetailRow(
                        'Phone', 
                        consignment['sender_phone_number'], 
                        clickable: true,
                        onTap: () {
                          _launchPhoneCall(consignment['sender_phone_number']);
                        }
                      ),
                      
                    ],
                  ),

                  const SizedBox(height: 16),

                  _buildDetailSection(
                    title: 'Receiver Details',
                    icon: Icons.person,
                    children: [
                      _buildDetailRow('Name', consignment['receiver_name']),
                      _buildDetailRow(
                        'Phone', 
                        consignment['receiver_phone_number'],
                        clickable: true,
                        onTap: () {
                          _launchPhoneCall(consignment['receiver_phone_number']);
                        }
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  if (consignment['consignment_items'] != null && (consignment['consignment_items'] as List).length > 1)
                  _buildItemsSection(consignment['consignment_items']),

                  const SizedBox(height: 16),

                  _buildDetailSection(
                    title: 'Issued By',
                    icon: Icons.assignment_ind,
                    children: [
                      _buildDetailRow('Name', consignment['issued_by']),
                      _buildDetailRow(
                        'Phone', 
                        consignment['issuer_phone_number'],
                        clickable: true,
                        onTap: () {
                          _launchPhoneCall(consignment['issuer_phone_number']);
                        }
                      ),
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

  Widget _buildConsignmentDetails(Map consignment) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline, 
                    color: Colors.teal.shade700
                  ),

                  const SizedBox(width: 4),

                  Expanded(
                    child: Text(
                      consignment['is_parcel'] ? 'Parcel Details' : 'Consignment Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ),

                  SizedBox(
                    width: 32,
                    child: IconButton(
                      icon: const Icon(Icons.share),
                      color: Colors.blue,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _shareConsignment(consignment),
                    ),
                  ),

                  SizedBox(
                    width: 32,
                    child: IconButton(
                      icon: const Icon(Icons.print),
                      color: Colors.teal,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () { 
                        _printBluetoothReceipt(consignment);
                        if (Platform.isWindows) {
                          _printCableReceipt(consignment);
                        }
                      },
                    ),
                  ),

                  SizedBox(
                    width: 32,
                    child: IconButton(
                      icon: const Icon(Icons.print),
                      color: Colors.red,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _printBluetoothReceipt2(consignment),
                    ),
                  ),
                ],
              )
            ),

            const Divider(),

            /// TITLE
            Text(
              consignment['package_name'] ?? "Package",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            /// ROUTE
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(child: Text(consignment['from'] ?? "")),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward),
                const SizedBox(width: 10),
                Icon(Icons.location_on, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(child: Text(consignment['to'] ?? "")),
              ],
            ),

            const Divider(height: 32),

            /// SENDER / RECEIVER
            Row(
              children: [
                Expanded(
                  child: _buildPersonInfo(
                    icon: Icons.person_outline,
                    label: "Sender",
                    name: consignment['sender_name'],
                    phone: consignment['sender_phone_number'],
                  ),
                ),
                Expanded(
                  child: _buildPersonInfo(
                    icon: Icons.person,
                    label: "Receiver",
                    name: consignment['receiver_name'],
                    phone: consignment['receiver_phone_number'],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// SCROLLABLE AREA
            Expanded(
              child: ListView(
                children: [

                  if (consignment['consignment_items'] != null &&
                      (consignment['consignment_items'] as List).isNotEmpty)
                    _buildItemsSection(consignment['consignment_items']),

                  const SizedBox(height: 16),

                  _buildDetailSection(
                    title: 'Issued By',
                    icon: Icons.assignment_ind,
                    children: [
                      _buildDetailRow('Name', consignment['issued_by']),
                      _buildDetailRow('Phone', consignment['issuer_phone_number']),
                    ],
                  ),
                ],
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

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
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

  Widget _buildItemsSection(List<dynamic> items) {
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
                Icon(Icons.shopping_bag, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  'Consignment Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} items',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.teal.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Unnamed Item',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildItemInfo(
                            label: 'Value',
                            value: 'TZS ${NumberFormat('#,##0').format((item['value'] ?? 0).toInt())}',
                          ),
                        ),
                        Expanded(
                          child: _buildItemInfo(
                            label: 'Quantity',
                            value: '${item['quantity'] ?? '1'}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemInfo({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

}