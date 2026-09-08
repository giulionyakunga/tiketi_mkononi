import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
// import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/order.dart';
import 'package:tiketi_mkononi/models/shop.dart';
import 'package:tiketi_mkononi/screens/add_order_page.dart';
import 'package:tiketi_mkononi/services/SimpleCodec.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:url_launcher/url_launcher.dart';  // Hide Excel's Border


class OrdersPage extends StatefulWidget {
  final int userId;
  final int shopId;
  final String shopName;
  final String shopLocation;
  final String userName;
  final String userPhoneNumber;
  final String role;
  final Shop shop;

  const OrdersPage({super.key, required this.userId, required this.shopId, required this.shopName, required this.shopLocation, required this.userName, required this.userPhoneNumber, required this.role, required this.shop});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _isLoading = false;
  String? _error;
  List<Order> _orders = [];
  double totalSales = 0;
  Order? _selectedOrder;
  bool _showDetails = false;
  DateTime _selectedDate = DateTime.now();
  BluetoothInfo? selectedPrinter;
  Printer? selectedCablePrinter;
  String _paymentFilter = 'all';

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchBarVisible = false;
  String receiptFooter = "Karibu Sana";

  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = ['MIXX BY YAS', 'M-PESA', 'AIRTEL MONEY', 'HALOPESA', 'AZAMPESA'];

  int receiptsBalance = 0;
  List<dynamic> receiptPackages = [];

  @override
  void initState() {
    super.initState();

    String dateStr = DateFormat('d-M-yyyy').format(DateTime.now());
    _selectedDate = DateFormat('d-M-yyyy').parse(dateStr);

    _fetchOrders();

    if (Platform.isWindows) {
      _loadSelectedPrinter();
    }
  
    _loadNumberOfReceipts();
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
            hintText: 'Search order or customer name',
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

  Future<void> _fetchOrders({bool useDNS = true}) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
        _showDetails = false;
        _selectedOrder = null;
      });

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/orders/${widget.userId}/${widget.shop.id}/${widget.role}/${DateFormat('d-M-yyyy').format(_selectedDate)}')
      : Uri.parse('${backend_url_with_fallback_ip}orders/${widget.userId}/${widget.shop.id}/${widget.role}/${DateFormat('d-M-yyyy').format(_selectedDate)}');

      debugPrint('Fetching orders from: $uri');

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        debugPrint('Fetched orders: ${response.body}');

        final dynamic responseData = jsonDecode(response.body);
        final numberOfOrders = responseData['number_of_orders'];
        final filteredOrders = responseData['filtered_orders'];
        
        // Handle different response structures
        List<Order> ordersList = []; 
        if (filteredOrders is List) {
          ordersList = filteredOrders.map((e) => Order.fromJson(e)).toList();
        } else if (filteredOrders is Map && filteredOrders.containsKey('data')) {
          ordersList = (filteredOrders['data'] as List).map((e) => Order.fromJson(e)).toList();
        }

        double totalPrice = 0;

        for (var order in ordersList) {
          totalPrice += (order.totalPrice).toDouble();
        }

        setState(() {
          totalSales = totalPrice;
          _orders = ordersList;
        });
        
        debugPrint('Loaded ${ordersList.length} orders');

        debugPrint('numberOfOrders: ${numberOfOrders}');
        debugPrint('number of filteredOrders: ${filteredOrders.length}');

        if(numberOfOrders != filteredOrders.length) {
          _showOrderPaymentDialog();
        }
      } else {
        _error = 'Failed to load orders (${response.statusCode})';
        debugPrint(_error);
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchOrders(useDNS: false);
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
        _fetchOrders();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.myOrders,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${widget.shopName} - ${widget.shopLocation}',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _buildDatePicker(),
          ),
          if (_selectedOrder != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _showDetails = false;
                  _selectedOrder = null;
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
            onRefresh: _fetchOrders,
            color: Colors.teal,
            child: _buildBody(),
          ),

          if (_showDetails && _selectedOrder != null) ...[
            
            /// This disables background clicks
            ModalBarrier(
              dismissible: true,
              onDismiss: () {
                setState(() {
                  _showDetails = false;
                  _selectedOrder = null;
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
      tooltip: "Add Order",
      onPressed: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AddOrderPage(
              userId: widget.userId,
              shopName: widget.shopName,
              shopLocation: widget.shopLocation,
              userName: widget.userName,
              userPhoneNumber: widget.userPhoneNumber,
              isReplacableScreen: true,
              shopId: widget.shopId, 
              orderCount: _orders.length,
            ),
          ),
        );
        _fetchOrders();
      },
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        AppLocalizations.of(context)!.add2,
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
    final bool isActive = _paymentFilter == value;

    return GestureDetector(
      onTap: () {
        if (value == 'all') {
          setState(() {
            _paymentFilter = 'all';
          });
        } else if (value == 'paid') {
          setState(() {
            _paymentFilter = value;
          });
        } else if (value == 'unpaid') {
          setState(() {
            _paymentFilter = value;
          });
        } else if (value == 'export_unpaid') {
          exportOrders(_orders, type: 0);
        } else if (value == 'export_paid') {
          exportOrders(_orders, type: 1);
        } else if (value == 'export_all') {
          exportOrders(_orders);
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
  
  Future<void> exportOrders(List<Order> orders, {int type = 2}) async {
    if(orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No orders found')),
      );
      return;
    }

    String fileName = 'All_Orders.xlsx';
    
    if(type == 0) {
      fileName = 'Paid_Orders.xlsx';
      orders = orders.where((c) {
        return (c.paymentStatus == false);
      }).toList();
    } else if(type == 1) {
      fileName = 'UnPaid_Orders.xlsx';
      orders = orders.where((c) {
        return (c.paymentStatus == true);
      }).toList();
  } else {
    orders = orders.where((c) {
      return (c.paymentStatus == true); 
    }).toList();
  }

    // Create a new Excel document
    final excel = Excel.createExcel();
    final Sheet sheet = excel.sheets['Sheet1']!;

    // Add header row
    sheet.appendRow([
      'Order ID',
      'Customer Name',
      'Customer Phone',
      'Total Price',
      'Payment Status',
      'Items',
      'Issued By',
      'Issuer Phone'
    ]);

    // Add order data
    for (final order in orders) {
      // Convert orders items to a readable string
      final items = (order.orderItems as List)
          .map((item) =>
              "${item.name} (x${item.quantity}) - TZS${NumberFormat('#,##0.00').format(item.price)}") 
          .join(", ");

      sheet.appendRow([
        order.orderId,
        order.customerName,
        order.customerPhoneNumber,
        order.totalPrice,
        order.paymentStatus ? 'Paid' : 'Unpaid',
        items,
        order.issuedBy,
        order.issuerPhoneNumber,
      ]);
    }


    // Save the file
    try {
      if(kIsWeb) { 
        // Trigger download in browser
        excel.save(fileName: fileName);
      } else {
          final directory = await getTemporaryDirectory();
          final filePath = '${directory.path}/${fileName}';
          final file = File(filePath);
          await file.writeAsBytes(excel.encode()!);

          // Open the file
          await OpenFile.open(filePath);
        
      }
    } catch (e) {
      print('Error exporting to Excel: $e');
      // Handle error (show a snackbar or dialog)
    }
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  /// Helper methods for status handling
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_actions;
      case 'processing':
        return Icons.refresh;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'delivered':
        return Icons.delivery_dining;
      case 'received':
        return Icons.shopping_bag;
      case 'sent':
        return Icons.pending_actions;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.shopping_bag;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'processing':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'delivered':
        return Colors.purple;
      case 'received':
        return Colors.teal;
      case 'sent':
        return Colors.red;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.teal;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Issued By';
      case 'processing':
        return 'Held By';
      case 'completed':
        return 'Completed By';
      case 'cancelled':
        return 'Cancelled By';
      case 'delivered':
        return 'Delivered By';
      case 'received':
        return 'Received By';
      case 'sent':
        return 'Issued By';
      case 'rejected':
        return 'Rejected By';
      default:
        return '';
    }
  }

  Widget _buildBody() {
    final isLargeScreen = _isLargeScreen(context);
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    if (_isLoading && _orders.isEmpty) {
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
                onPressed: _fetchOrders,
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

    if (_orders.isEmpty) {
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
            Text(
              AppLocalizations.of(context)!.noOrdersYet,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.yourOrdersWillAppearHere,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    var filteredOrders = _orders.where((c) {
      if (_paymentFilter == 'all') return true;
      return _paymentFilter == 'unpaid' ? c.paymentStatus == false : c.paymentStatus == true;
    }).toList();


    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredOrders = filteredOrders.where(
        (order) => (order.orderId.toLowerCase().contains(_searchQuery.toLowerCase()) || order.customerName.toLowerCase().contains(_searchQuery.toLowerCase()))
      ).toList();
    }

    double totalPaidAmount = 0;

    for (var order in filteredOrders) {
      totalPaidAmount += (order.totalPrice).toDouble();
    }

    setState(() {
      totalSales = totalPaidAmount;
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
                'TSH ${NumberFormat('#,##0').format(totalSales)}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[700],
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.totalSales,
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
              /// LEFT PANEL — ORDER LIST
              Container(
                width: 420,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: ListView.builder(
                  itemCount: filteredOrders.length,
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final isSelected = _selectedOrder == order;

                    return 
                    Card(
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
                            _selectedOrder = order;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              /// ORDER ICON
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(order.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _getStatusIcon(order.status),
                                  color: _getStatusColor(order.status),
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              /// ORDER INFO
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    /// Order ID and Status
                                    Row(
                                      children: [
                                        Text(
                                          'Order #${order.orderId}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(order.status).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            order.status.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: _getStatusColor(order.status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 4),
                                    
                                    /// Customer Name
                                    Text(
                                      order.customerName,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 4),
                                    
                                    /// Order Items Summary
                                    Row(
                                      children: [
                                        Text(
                                          '${order.orderItems.length} item${order.orderItems.length > 0 ? 's' : ''}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 4,
                                          height: 4,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade400,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'TZS${NumberFormat('#,##0.00').format(order.totalPrice)}',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(height: 4),
                                    
                                    /// Payment Status
                                    Row(
                                      children: [
                                        Icon(
                                          order.paymentStatus 
                                              ? Icons.check_circle_outline 
                                              : Icons.pending_outlined,
                                          size: 14,
                                          color: order.paymentStatus 
                                              ? Colors.green 
                                              : Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          order.paymentStatus ? 'Paid' : 'Pending Payment',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: order.paymentStatus 
                                                ? Colors.green 
                                                : Colors.orange,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              /// Date and Chevron
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    order.date,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
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
                child: _selectedOrder == null
                    ? Center(
                        child: Text(
                          "Select an order to view details",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildOrderDetails(_selectedOrder!),
                      ),
              ),
            ],
          ),
        ) :
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredOrders.length,
            itemBuilder: (context, index) {
              final order = filteredOrders[index];
              final isSelected = _selectedOrder == order;
          
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
                      if (_selectedOrder == order) {
                        _showDetails = !_showDetails;
                      } else {
                        _selectedOrder = order;
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
                        // Header Row - Order ID and Total
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
                                Icons.shopping_bag,
                                color: Colors.teal,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order #${order.orderId}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    order.customerName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Total Price at top right
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
                                    "TZS${NumberFormat('#,##0.00').format(order.totalPrice)}",
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
                        
                        const SizedBox(height: 8),
                        // Status and Payment Info Row
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(order.status).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStatusIcon(order.status),
                                    size: 14,
                                    color: _getStatusColor(order.status),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    order.status.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: _getStatusColor(order.status),
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
                                color: _getPaymentStatusColor(order.paymentStatus).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    order.paymentStatus
                                        ? Icons.check_circle
                                        : Icons.pending,
                                    size: 14,
                                    color: _getPaymentStatusColor(order.paymentStatus),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getPaymentStatusText(order.paymentStatus),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: _getPaymentStatusColor(order.paymentStatus),
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
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.shopping_cart_outlined,
                                    size: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${order.orderItems.length} items',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Order Date and Shop Info
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                order.date,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(Icons.store,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                'Shop #${order.shopId}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const Divider(),
                        
                        // Customer & Issuer Info
                        Row(
                          children: [
                            Expanded(
                              child: _buildPersonInfo(
                                icon: Icons.person_outline,
                                label: 'Customer',
                                name: order.customerName,
                                phone: order.customerPhoneNumber,
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.grey.shade300,
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                            ),
                            if (order.issuedBy != "")
                            Expanded(
                              child: _buildPersonInfo(
                                icon: Icons.assignment_ind,
                                label: (!order.isRemote) ? 'Issued By' : _getStatusText(order.status),
                                name: order.issuedBy,
                                phone: order.issuerPhoneNumber,
                              ),
                            ),
                          ],
                        ),
                        
                        const Divider(),
                        
                        // Order Items Preview
                        if (order.orderItems.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Items',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...order.orderItems.take(3).map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Colors.teal.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${item.quantity}x',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.teal.shade700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    'TZS${NumberFormat('#,##0').format(item.price * item.quantity)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            if (order.orderItems.length > 3)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '+${order.orderItems.length - 3} more items',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontStyle: FontStyle.italic,
                                  ),
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

    bytes += generator.text(widget.shopName,
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

  Future<void> _printBluetoothReceipt(Order order) async {
    debugPrint("Printing via Bluetooth...");

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

    final items = order.orderItems;

    DateTime now = DateTime.now();
    String duplicateDateTime = DateFormat('d/M/y H:m').format(now);

    DateTime orderDate = order.createdAt;
    String formattedDateTime = DateFormat('d/M/y H:m').format(orderDate);

    List<int> bytes = [];

    bytes += generator.text("********************************",
      styles: const PosStyles(
        align: PosAlign.center,
      )
    );

    bytes += generator.text("KOPI YA PILI ${duplicateDateTime}",
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
      "  ",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(widget.shopName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      )
    );

    bytes += generator.text(
      "Phone: ${order.issuerPhoneNumber}",
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );

    bytes += generator.text(
      "Location: ${widget.shopLocation}",
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );

    bytes += generator.text(
      "ORDER RECEIPT",
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.text(
      "Order No: ${order.orderId}",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      "  ",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.row([ 
      PosColumn(text: "Customer Name", width: 6),
      PosColumn(
        text: order.customerName, 
        width: 6,
        styles: const PosStyles(bold: true),
      ),
    ]);
    
    double totalPrice = double.tryParse(
      order.totalPrice.toString()
    ) ?? 0;

    bytes += generator.row([
      PosColumn(text: "Total Price", width: 6),
      PosColumn(
        text: 'TZS${NumberFormat('#,##0').format(totalPrice)}', 
        width: 6,
        styles: const PosStyles(bold: true),
      ),
    ]);

    bytes += generator.row([
      PosColumn(text: "Payment Status", width: 6),
      PosColumn(
        text: order.paymentStatus ? "PAID" : "NOT PAID",
        width: 6,
        styles: const PosStyles(bold: true),
      ),
    ]);

    bytes += generator.text(
      "  ",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      "Customer Details",
      styles: const PosStyles(bold: true),
    );
    bytes += generator.row([
      PosColumn(text: "Name", width: 6),
      PosColumn(text: order.customerName, width: 6),
    ]);
    bytes += generator.row([
      PosColumn(text: "Phone number", width: 6),
      PosColumn(text: order.customerPhoneNumber, width: 6),
    ]);

    bytes += generator.text(
      "  ",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      "Order Items",
      styles: const PosStyles(bold: true),
    );

    bytes += generator.row([
      PosColumn(
        text: 'Product',
        width: 6,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(bold: true, align: PosAlign.center),
      ),
      PosColumn(
        text: "Price",
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right),
      ),
    ]);

    int totalAmount = 0;
    // Items
    if(items.length > 0) { 
      for (var item in items) {
        totalAmount += (item.price as num).toInt() * (item.quantity as num).toInt();

        bytes += generator.row([ 
          PosColumn(
            text: item.name,
            width: 6,
          ),
          PosColumn(
            text: item.quantity.toString(),
            width: 2,
            styles: const PosStyles(bold: true, align: PosAlign.center),
          ),
          PosColumn(
            text: "TZS${NumberFormat('#,##0').format(item.price)}",
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.text("--------------------------------",
        styles: const PosStyles(
          align: PosAlign.center,
        )
      );

      bytes += generator.row([
        PosColumn(
          text: "Total Amount", 
          width: 6,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(text: "TZS${NumberFormat('#,##0').format(totalAmount)}", width: 6, styles: const PosStyles(bold: true, align: PosAlign.right)),
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
      PosColumn(text: order.issuedBy, width: 6),
    ]);
    bytes += generator.row([
      PosColumn(text: "Phone number", width: 6),
      PosColumn(text: order.issuerPhoneNumber, width: 6),
    ]);
    bytes += generator.row([
      PosColumn(text: "Date", width: 6),
      PosColumn(text: formattedDateTime, width: 6),
    ]);

    bytes += generator.text(
      "  ",
      styles: const PosStyles(align: PosAlign.center),
    );

    // QR
    String data = SimpleCodec.encode(jsonEncode({
      "oid": order.id,
      "sid": order.shopId,
    }));

    bytes += generator.qrcode(
      data,
      size: QRSize.size5,
    );

    bytes += generator.text(
      "  ",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      receiptFooter,
      styles: const PosStyles(align: PosAlign.center)
    );

    bytes += generator.text(
      "  ",
      styles: const PosStyles(align: PosAlign.center),
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

  Future<void> _printCableReceipt(Order order) async {
    debugPrint("Printing via cable...");

    final pdf = pw.Document();

    // final logoData = await rootBundle.load('assets/telabs_logo.png');
    // final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    final fontData = await rootBundle.load('assets/fonts/inter/Inter_24pt-Regular.ttf');
    final customFont = pw.Font.ttf(fontData);

    const pageWidth = 226.0;

    final items = order.orderItems;

    int totalAmount = 0;
    // Items
    if(items.length > 0) { 
      for (var item in items) {
        totalAmount += (item.price as num).toInt() * (item.quantity as num).toInt();
      }
    }

    DateTime now = DateTime.now();
    String formattedDateTime = DateFormat('d/M/y H:m').format(now);

    String data = SimpleCodec.encode(jsonEncode({
      "oid": order.id,
      "sid": order.shopId,
    }));

    pdf.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(pageWidth, double.infinity),
        build: (context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [

                /// LOGO
                // pw.Center(
                //   child: pw.Image(logoImage, width: 70),
                // ),

                pw.SizedBox(height: 6),

                /// COMPANY NAME
                pw.Center(
                  child: pw.Text(
                    widget.shopName.toUpperCase(),
                    style: pw.TextStyle(
                      font: customFont,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.Text(
                  "Location: ${widget.shopLocation}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),

                pw.Text(
                  "Phone No: ${order.issuerPhoneNumber}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),

                pw.Center(
                  child: pw.Text(
                    "ORDER RECEIPT",
                    style: pw.TextStyle(
                      font: customFont,
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.SizedBox(height: 6),

                /// ORDERS INFO
                pw.Center(
                  child: pw.Text(
                  "Order No: ${order.orderId}",
                    style: pw.TextStyle(
                      font: customFont,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.SizedBox(height: 6),

                pw.Text(
                  "Name: ${order.customerName}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),

                pw.Text(
                  "Total Price: ${order.totalPrice}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),

                pw.Text(
                  "Payment Status: ${order.paymentStatus ? "Paid" : "Not Paid"}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),

                pw.SizedBox(height: 6),

                /// CUSTOMER
                pw.Text(
                  "Customer Details",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.Text(
                  "Name: ${order.customerName}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),

                pw.Text(
                  "Phone number: ${order.customerPhoneNumber}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),

                pw.SizedBox(height: 6),

                /// ITEMS
                if (items.length > 0) ...[
                  pw.Text(
                    "Items",
                    style: pw.TextStyle(
                      font: customFont,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 2),

                  for (int i = 0; i < items.length; i++)
                    pw.Text(
                      "${i + 1}. ${items[i].name} (x${items[i].quantity})  "
                      "TZS${NumberFormat('#,##0').format(((items[i].price) * items[i].quantity).toInt())}",
                      style: pw.TextStyle(
                        font: customFont,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.normal,
                      ),
                    ),
                ],

                pw.Text(
                  "--------------------------------",
                  style: pw.TextStyle(
                    font: customFont,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),

                pw.Text(
                  "Total Amount: ${totalAmount}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.Text(
                  "--------------------------------",
                  style: pw.TextStyle(font: customFont),
                ),

                /// ISSUED BY
                pw.Text(
                  "Issued By",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.Text(
                  "Name: ${order.issuedBy}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),

                pw.Text(
                  "Phone: ${order.issuerPhoneNumber}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
                ),

                pw.Text(
                  "Date: ${formattedDateTime}",
                  style: pw.TextStyle(
                    font: customFont,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.normal,
                  ),
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
                    receiptFooter,
                    style: pw.TextStyle(
                      font: customFont,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.normal,
                    ),
                  ),
                ),

                pw.SizedBox(height: 10),

                pw.Center(
                  child: pw.Text(
                    "Powered by Tiketi Mkononi",
                    style: pw.TextStyle(
                      font: customFont,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.Center(
                  child: pw.Text(
                    "Email:tiketimkononi@telabs.co.tz",
                    style: pw.TextStyle(
                      font: customFont,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
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

  Future<void> _saveReceiptsBalance(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('paid_sms_balance', value);
  }

  Future<void> _loadNumberOfReceipts() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      receiptsBalance = prefs.getInt('paid_sms_balance') ?? 0;
    });
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

  Future<void> _shareOrder(Order order) async {
    final pdf = pw.Document();
    final items = order.orderItems;

    String formattedDateTime = DateFormat('d/M/y H:m').format(order.createdAt);

    String data = SimpleCodec.encode(jsonEncode({
      "oid": order.id,
      "sid": order.shopId,
    }));

    // Calculate totals
    double totalItemsValue = items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 8),

              // Shop Name
              pw.Center(
                child: pw.Text(
                  widget.shopName,
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 8),

              // Receipt Title
              pw.Center(
                child: pw.Text(
                  'ORDER RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 5),

              // Order ID
              pw.Center(
                child: pw.Text(
                  "Order No: ${order.orderId}",
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 3),

              // Customer Info
              pw.Text('Customer', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              _pdfRow('Name', order.customerName),
              _pdfRow('Phone', order.customerPhoneNumber),

              pw.Divider(),

              // Order Summary
              pw.Text('Order Summary', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              _pdfRow('Order Date', _formatDate(order.updatedAt)),
              _pdfRow('Total Items', items.length.toString()),
              _pdfRow('Total Amount', 'TZS${NumberFormat('#,##0.00').format(order.totalPrice)}'),
              _pdfRow('Payment Status', order.paymentStatus ? 'Paid' : 'Pending'),

              pw.Divider(),

              // Order Items
              if (items.isNotEmpty) ...[
                pw.Text('Order Items', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                
                ...items.map<pw.Widget>((item) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '${item.name}',
                        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      ),
                      _pdfRow('  Qty', '${item.quantity}'),
                      _pdfRow('  Price', 'TZS${NumberFormat('#,##0.00').format(item.price)}'),
                      _pdfRow('  Subtotal', 'TZS${NumberFormat('#,##0.00').format(item.price * item.quantity)}'),
                      pw.SizedBox(height: 4),
                    ],
                  );
                }).toList(),
                
                // Total line for items
                pw.Divider(thickness: 0.5),
                _pdfRow('Total', 'TZS${NumberFormat('#,##0.00').format(totalItemsValue)}'),
              ],

              pw.Divider(),

              // Issued By
              pw.Text('Issued By', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              _pdfRow('Name', order.issuedBy),
              _pdfRow('Phone', order.issuerPhoneNumber),

              pw.Text(
                "Date: ${formattedDateTime}",
                style: pw.TextStyle(fontSize: 8),
              ),

              pw.SizedBox(height: 6),

              // QR Code
              pw.Center(
                child: pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: data,
                  width: 60,
                  height: 60,
                ),
              ),

              pw.SizedBox(height: 8),

              // Thank You
              pw.Center(
                child: pw.Text(
                  'Thank you',
                  style: pw.TextStyle(fontSize: 10),
                ),
              ),

              pw.SizedBox(height: 10),

              // Footer
              pw.Center(
                child: pw.Text(
                  'Powered by Tiketi Mkononi',
                  style: pw.TextStyle(fontSize: 8),
                ),
              ),
                              
              pw.SizedBox(height: 2),

              pw.Center(
                child: pw.Text(
                  "Email: tiketimkononi@telabs.co.tz",
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
      '${dir.path}/order_receipt.pdf',
    );

    await file.writeAsBytes(await pdf.save());

    // Share PDF
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Order Receipt #${order.orderId}',
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
  final order = _selectedOrder;
  if (order == null) return const SizedBox();

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
        // Drag handle
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header with actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: Colors.teal.shade700,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Order Details2',
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
                  onPressed: () => _shareOrder(order),
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
                    _printBluetoothReceipt(order);
                    if (Platform.isWindows) {
                      _printCableReceipt(order);
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        const Divider(),

        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order ID and Status
                _buildOrderHeader(order),

                const SizedBox(height: 16),

                // Customer Information
                _buildDetailSection(
                  title: 'Customer Information',
                  icon: Icons.person_outline,
                  children: [
                    _buildDetailRow('Name', order.customerName),
                    _buildDetailRow(
                      'Phone',
                      order.customerPhoneNumber,
                      clickable: true,
                      onTap: () {
                        _launchPhoneCall(order.customerPhoneNumber);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Order Summary
                _buildDetailSection(
                  title: 'Order Summary',
                  icon: Icons.receipt_long,
                  children: [
                    _buildDetailRow(
                      'Total Items',
                      order.orderItems.length.toString(),
                    ),
                    _buildDetailRow(
                      'Total Price',
                      'TZS${NumberFormat('#,##0.00').format(order.totalPrice)}',
                    ),
                    _buildDetailRow(
                      'Payment Status',
                      order.paymentStatus ? '✅ Paid' : '⏳ Pending',
                    ),
                    _buildDetailRow('Order Date', _formatDate(order.updatedAt)),
                  ],
                ),

                const SizedBox(height: 16),

                // Order Items
                if (order.orderItems.isNotEmpty)
                  _buildOrderItemsSection(order.orderItems),

                const SizedBox(height: 16),

                // Issued By
                _buildDetailSection(
                  title: (!order.isRemote) ? 'Issued By' : _getStatusText(order.status),
                  icon: Icons.assignment_ind,
                  children: [
                    _buildDetailRow('Name', order.issuedBy),
                    _buildDetailRow(
                      'Phone',
                      order.issuerPhoneNumber,
                      clickable: true,
                      onTap: () {
                        _launchPhoneCall(order.issuerPhoneNumber);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Additional Information
                _buildDetailSection(
                  title: 'Additional Information',
                  icon: Icons.info_outline,
                  children: [
                    _buildDetailRow('Order ID', order.orderId),
                    _buildDetailRow('Order Status', order.status),
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

/// Helper widget for order header
Widget _buildOrderHeader(Order order) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.teal.shade50,
          Colors.teal.shade100.withOpacity(0.3),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.teal.shade200),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Order #${order.orderId}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                order.customerName,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: (order.status.toUpperCase() == 'SENT') ? () => _showOrderConfirmationDialog(order) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(order.status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

void _showOrderConfirmationDialog(Order order) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.local_shipping,
              color: Colors.blue,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text('Confirm Order'),
            ),
          ],
        ),
        content: const Text(
          'Do you accept and confirm that you have received this order?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showRejectReasonDialog(order);
            },
            child: const Text(
              'Reject',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _updateOrderStatus(
                order,
                status: 'received',
              );
            },
            child: const Text('Accept / Receive'),
          ),
        ],
      
      );
    },
  );
}

void _showRejectReasonDialog(Order order) {
  final TextEditingController reasonController =
      TextEditingController();

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.cancel,
              color: Colors.red,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text('Reject Order'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejecting this order:',
            ),

            const SizedBox(height: 12),

            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final reason = reasonController.text.trim();

              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Please enter a reason for rejecting the order.',
                    ),
                  ),
                );
                return;
              }

              Navigator.pop(dialogContext);

              _updateOrderStatus(
                order,
                status: 'rejected',
                rejectionReason: reason,
              );
            },
            child: const Text('Reject Order'),
          ),
        ],
      );
    },
  );
}

Future<void> _updateOrderStatus(
  Order order, {
  required String status,
  String? rejectionReason,
  bool useDNS = true,
}) async {
  try {
    final Uri uri = useDNS 
        ? Uri.parse(
            '${backend_url}api/update_order/${widget.userId}/${order.orderId}',
          )
        : Uri.parse(
            '${backend_url_with_fallback_ip}update_order/${widget.userId}/${order.orderId}',
          );

    final Map<String, dynamic> body = {
      'status': status,
      'user_name': widget.userName,
      'user_phone_number': widget.userPhoneNumber,
      'shop_name': widget.shopName,
    };

    if (rejectionReason != null && rejectionReason.isNotEmpty) {
      body['rejection_reason'] = rejectionReason;
    }

    debugPrint('Updating order: ${order.orderId}');
    debugPrint('URL: $uri');
    debugPrint('Body: ${jsonEncode(body)}');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    debugPrint('Response status: ${response.statusCode}');
    debugPrint('Response body: ${response.body}');

    final responseData = jsonDecode(response.body);
    String message = responseData['message'];

    if (response.statusCode >= 200 && response.statusCode < 300) {
      _fetchOrders();

      _saveReceiptsBalance(responseData['number_of_sms']);

      // Update the local order object
      setState(() {
        order.status = status;
        receiptsBalance = responseData['number_of_sms'];

        if (status == 'rejected') {
          order.rejectionReason = rejectionReason!;
        }
      });

      if (status == 'received') { 
        _showSuccessDialog();
      } else {
        _showRejectedSuccessDialog();
      }
    } else if (response.statusCode == 404) {
      _fetchOrders();

      _saveReceiptsBalance(responseData['number_of_sms']);

      if (message.trim() == "Kifurushi chako kimeisha!") {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.trim())),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to update order. '
            'Server returned ${response.statusCode}, ${response.body}',
          ),
        ),
      );
    }
  } catch (e) {
    debugPrint('Error updating order: $e');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Failed to update order: $e',
        ),
      ),
    );
  }
}
 

  Future<void> getReceiptPackages({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/receipt_packages_new/${widget.role}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}receipt_packages_new/${widget.role}'); // Use 

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

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting offices: $e');
    } finally {
      debugPrint('Process finished');
    }
  }

  Future<void> _payDialog() async {
    int? selectedReceiptPackages = receiptPackages.isNotEmpty ? receiptPackages[0]["number_of_receipts"] as int : null;
    int? selectedAmount = receiptPackages.isNotEmpty ? receiptPackages[0]["price"] as int : null;

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
                          "Receipts ${pkg["number_of_receipts"]} - TSH ${NumberFormat('#,##0').format(pkg["price"])}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: pkg["number_of_receipts"],
                        groupValue: selectedReceiptPackages,
                        onChanged: (value) {
                          setState(() {
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
                            debugPrint('Selected payment method: $value');
                            debugPrint('Selected payment method: $selectedPaymentMethod');
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
                        onPressed: _isLoading ? null : () async {
                          if(selectedReceiptPackages != null && selectedReceiptPackages! > 0) {
                            setState(() => _isLoading = true);

                            await _sendPaymentRequest(
                              phoneController.text.trim(),
                              selectedReceiptPackages,
                              selectedAmount,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Tafadhali chagua kifurushi")),
                            );
                          }
                        },
                        child: _isLoading ? const CircularProgressIndicator() : const Text("Lipa"),
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

      debugPrint('Selected payment method: $selectedPaymentMethod');

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
      setState(() => _isLoading = true);

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

      _handleSocketException(e);
    } catch (e) {
      print("Payment error: $e");
    } finally {
      setState(() => _isLoading = false);
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

  void _showRejectedSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            SizedBox(width: 8),
            Text('Order Rejected'),
          ],
        ),
        content: const Text(
          'The order has been rejected successfully.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.success),
          ],
        ),
        content: Text(AppLocalizations.of(context)!.orderReceivedSuccessfully),
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

  void _showOrderPaymentDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.red),
            SizedBox(width: 4),
            Text(AppLocalizations.of(context)!.paymentRequired),
          ],
        ),
        content: Text(AppLocalizations.of(context)!.youHaveOrdersPleasePayToView),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.red,
              ),
            ),
          ),

          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await getReceiptPackages();
              _payDialog();
            },
            child: const Text('Pay Now'),
          ),

        ],
      ),
    );
  }

/// Helper widget for order items section
Widget _buildOrderItemsSection(List<OrderItem> items) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            Text(
              'Order Items (${items.length})',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((item) => _buildOrderItemTile(item)).toList(),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
                            'TZS${items.fold(0.0, (sum, item) => sum + (item.price * item.quantity)).toStringAsFixed(2)}',

              // 'TZS${NumberFormat('#,##0.00').format(items.fold(0.0, (sum, item) => sum + (item.price * item.quantity)).toStringAsFixed(2))}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.teal,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Helper widget for individual order item tile
Widget _buildOrderItemTile(OrderItem item) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${item.quantity}x',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              Text(
                'TZS${NumberFormat('#,##0.00').format(item.price)} × ${item.quantity}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'TZS${NumberFormat('#,##0.00').format(item.price * item.quantity)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  /// Helper method to format date
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildOrderDetails(Order order) {
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
            /// HEADER WITH ACTIONS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.teal.shade700,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Order Details',
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
                      onPressed: () => _shareOrder(order),
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
                        if (Platform.isWindows) {
                          debugPrint("Printing via cable...");
                          _printCableReceipt(order);
                        } else {
                          debugPrint("Printing via Bluetooth...");
                          _printBluetoothReceipt(order);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
              
                    /// ORDER ID AND STATUS
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order #${order.orderId}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(order.status).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            order.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getStatusColor(order.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    /// CUSTOMER INFO
                    Row(
                      children: [
                        Icon(Icons.person_outline, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            order.customerName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Icon(Icons.phone_outlined, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          order.customerPhoneNumber,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
              
                    /// ORDER SUMMARY
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '${order.orderItems.length} item${order.orderItems.length > 0 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.attach_money, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'TZS${order.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    /// PAYMENT STATUS
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: order.paymentStatus 
                            ? Colors.green.withOpacity(0.1) 
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            order.paymentStatus 
                                ? Icons.check_circle_outline 
                                : Icons.pending_outlined,
                            size: 18,
                            color: order.paymentStatus ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            order.paymentStatus ? 'Payment Completed' : 'Payment Pending',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: order.paymentStatus ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const Divider(height: 32),
              
                    /// ORDER ITEMS SECTION
                    if (order.orderItems.isNotEmpty)
                      _buildOrderItemsSection(order.orderItems),
                    
                    const SizedBox(height: 16),
                    
                    /// ISSUED BY SECTION
                    _buildDetailSection(
                      title: (!order.isRemote) ? 'Issued By' : _getStatusText(order.status),
                      icon: Icons.assignment_ind,
                      children: [
                        _buildDetailRow('Name', order.issuedBy),
                        _buildDetailRow('Phone', order.issuerPhoneNumber),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    /// ADDITIONAL INFO
                    _buildDetailSection(
                      title: 'Additional Information',
                      icon: Icons.info_outline,
                      children: [
                        _buildDetailRow('Order Date', _formatDate(order.updatedAt)),
                        _buildDetailRow('Shop ID', order.shopId.toString()),
                        _buildDetailRow('User ID', order.userId.toString()),
                        _buildDetailRow('Status', order.status),
                      ],
                    ),
                  
                  ]
                )
              )
            )
          ],
        ),
      ),
    );
  }

  /// Helper widget for detail section
  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...children,
      ],
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
}