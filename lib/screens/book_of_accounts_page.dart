// book_of_accounts_page.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/account_record.dart';
import 'package:tiketi_mkononi/screens/record_details_page.dart';

// Import your AccountRecord model and AddNewRecordPage
// import 'account_record.dart';
// import 'add_new_record_page.dart';

class BookOfAccountsPage extends StatefulWidget {
  final int userId;

  const BookOfAccountsPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<BookOfAccountsPage> createState() => _BookOfAccountsPageState();
}

class _BookOfAccountsPageState extends State<BookOfAccountsPage> {
  List<AccountRecord> _records = [];
  bool _isLoading = true;
  String? _errorMessage;
  List<AccountRecord> _filteredRecords = [];
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'All';
  DateTime _selectedDate = DateTime.now();


  @override
  void initState() {
    super.initState();
    _fetchRecords();
    _searchController.addListener(_filterRecords);
    
    String dateStr = DateFormat('d-M-yyyy').format(DateTime.now());
    _selectedDate = DateFormat('d-M-yyyy').parse(dateStr);

  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecords({int days=0}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final Uri uri = Uri.parse('${backend_url}api/account_records/${widget.userId}/${DateFormat('d-M-yyyy').format(_selectedDate)}/$days');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          _records = data.map((json) => AccountRecord.fromJson(json)).toList();
          _filteredRecords = _records;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load records. Status code: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: Please check your internet connection';
        _isLoading = false;
      });
    }
  }

  void _filterRecords() {
    String searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredRecords = _records.where((record) {
        bool matchesSearch = record.itemName.toLowerCase().contains(searchTerm) ||
            record.date.contains(searchTerm);
        
        if (_selectedFilter == 'All') return matchesSearch;
        
        // Add more filter options based on date ranges
        DateTime recordDate = DateTime.parse(record.date);
        DateTime now = DateTime.now();
        
        switch (_selectedFilter) {
          case 'Today':
            return matchesSearch && 
                recordDate.year == now.year && 
                recordDate.month == now.month && 
                recordDate.day == now.day;
          case 'This Week':
            DateTime weekAgo = now.subtract(Duration(days: 7));
            return matchesSearch && recordDate.isAfter(weekAgo);
          case 'This Month':
            return matchesSearch && 
                recordDate.year == now.year && 
                recordDate.month == now.month;
          default:
            return matchesSearch;
        }
      }).toList();
    });
  }

  Future<void> _refreshRecords() async {
    await _fetchRecords();
  }

  void _navigateToAddRecord() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddNewRecordPage(
          userId: widget.userId,
          backendUrl: backend_url,
        ),
      ),
    );

    if (result == true) {
      _fetchRecords();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Record added successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
          side: const BorderSide(color: Colors.black, width: 1.5),
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
        _fetchRecords();
      }
    }
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text(
          'Book of Accounts',
          style: TextStyle( 
            fontWeight: FontWeight.w600,
            fontSize: 19,
          ),
        ),
        titleSpacing: 0,
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _buildDatePicker(),
          ),
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
            onSelected: (value) {
              if (value == 'refresh') {
                _refreshRecords();
              } else if (value == 'filter') {
                _showFilterDialog();
              } else if (value == 'exit') {
                Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
              _buildMenuItem(
                icon: Icons.refresh,
                text: 'Refresh',
                value: 'refresh',
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                icon: Icons.filter_list,
                text: 'Filter',
                value: 'filter',
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                icon: Icons.exit_to_app,
                text: 'Exit',
                value: 'exit',
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            // padding: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by item name or date...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 60,
                        color: Colors.red[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _refreshRecords,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : _filteredRecords.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No records found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'Try adjusting your search'
                                : 'Add your first record to get started',
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth > 600) {
                          return _buildTabletLayout();
                        } else {
                          return _buildMobileLayout();
                        }
                      },
                    ),
      floatingActionButton: FloatingActionButton( 
        onPressed: _navigateToAddRecord,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        child: Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return RefreshIndicator(
      onRefresh: _refreshRecords,
      color: Colors.blue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredRecords.length,
        itemBuilder: (context, index) {
          final record = _filteredRecords[index];
          return _buildRecordCard(record);
        },
      ),
    );
  }

  Widget _buildTabletLayout() {
    return RefreshIndicator(
      onRefresh: _refreshRecords,
      color: Colors.blue,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredRecords.length,
        itemBuilder: (context, index) {
          final record = _filteredRecords[index];
          return _buildRecordCard(record);
        },
      ),
    );
  }

  // Widget _buildRecordCard(AccountRecord record) {
  //   final dateFormat = DateFormat('MMM dd, yyyy');
  //   final timeFormat = DateFormat('hh:mm a');
    
  //   return Card(
  //     elevation: 2,
  //     shape: RoundedRectangleBorder(
  //       borderRadius: BorderRadius.circular(12),
  //     ),
  //     child: InkWell(
  //       onTap: () {
  //         // Navigate to record details if needed
  //       },
  //       borderRadius: BorderRadius.circular(12),
  //       child: Container(
  //         padding: const EdgeInsets.all(16),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             // Header with date and time
  //             Row(
  //               children: [
  //                 Container(
  //                   padding: const EdgeInsets.symmetric(
  //                     horizontal: 8,
  //                     vertical: 4,
  //                   ),
  //                   decoration: BoxDecoration(
  //                     color: Colors.blue[50],
  //                     borderRadius: BorderRadius.circular(6),
  //                   ),
  //                   child: Text(
  //                     record.date,
  //                     style: TextStyle(
  //                       fontSize: 12,
  //                       fontWeight: FontWeight.w500,
  //                       color: Colors.blue[700],
  //                     ),
  //                   ),
  //                 ),
  //                 const SizedBox(width: 8),
  //                 Text(
  //                   record.time,
  //                   style: TextStyle(
  //                     fontSize: 12,
  //                     color: Colors.grey[600],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 12),
  //             // Item name
  //             Text(
  //               record.itemName,
  //               style: const TextStyle(
  //                 fontSize: 18,
  //                 fontWeight: FontWeight.bold,
  //               ),
  //               maxLines: 1,
  //               overflow: TextOverflow.ellipsis,
  //             ),
  //             const SizedBox(height: 12),
  //             // Quantity and price row
  //             Row(
  //               children: [
  //                 Expanded(
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         'Quantity',
  //                         style: TextStyle(
  //                           fontSize: 12,
  //                           color: Colors.grey[600],
  //                         ),
  //                       ),
  //                       const SizedBox(height: 4),
  //                       Text(
  //                         record.quantity.toString(),
  //                         style: const TextStyle(
  //                           fontSize: 16,
  //                           fontWeight: FontWeight.w600,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //                 Expanded(
  //                   child: Column(
  //                     crossAxisAlignment: CrossAxisAlignment.start,
  //                     children: [
  //                       Text(
  //                         'Unit Price',
  //                         style: TextStyle(
  //                           fontSize: 12,
  //                           color: Colors.grey[600],
  //                         ),
  //                       ),
  //                       const SizedBox(height: 4),
  //                       Text(
  //                         'TSH${record.unitPrice.toStringAsFixed(2)}',
  //                         style: const TextStyle(
  //                           fontSize: 16,
  //                           fontWeight: FontWeight.w600,
  //                         ),
  //                       ),
  //                     ],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 12),
  //             // Total price
  //             Container(
  //               padding: const EdgeInsets.all(8),
  //               decoration: BoxDecoration(
  //                 color: Colors.green[50],
  //                 borderRadius: BorderRadius.circular(6),
  //               ),
  //               child: Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   Text(
  //                     'Total',
  //                     style: TextStyle(
  //                       fontWeight: FontWeight.w500,
  //                       color: Colors.green[800],
  //                     ),
  //                   ),
  //                   Text(
  //                     'TSH${record.totalPrice.toStringAsFixed(2)}',
  //                     style: TextStyle(
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.bold,
  //                       color: Colors.green[800],
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ),
  //   );
  // }


  Widget _buildRecordCard(AccountRecord record) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecordDetailsPage(record: record),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date & Time + Payment Method
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${record.date} ${record.time}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      record.paymentMethod,
                      style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Item name
              Text(
                record.itemName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),

              // Quantity & Unit Price
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Qty: ${record.quantity}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Unit: TSH${record.unitPrice.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Total Price
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    'Total: TSH${record.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter by Date', 
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              // _buildFilterOption('All',),
              _buildFilterOption('Today', 1),
              _buildFilterOption('This Week', 7),
              _buildFilterOption('This Month', 30),
              _buildFilterOption('This Year', 365),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterOption(String option, int days) {
    return ListTile(
      title: Text(option),
      leading: Radio<String>(
        value: option,
        groupValue: _selectedFilter,
        onChanged: (value) {
          setState(() {
            _selectedFilter = value!;
            // _filterRecords();
            _fetchRecords(days: days);
          });
          Navigator.pop(context);
        },
        activeColor: Colors.blue,
      ),
    );
  }
}

// AddNewRecordPage (simplified version)
class AddNewRecordPage extends StatefulWidget {
  final int userId;
  final String backendUrl;

  const AddNewRecordPage({
    Key? key,
    required this.userId,
    required this.backendUrl,
  }) : super(key: key);

  @override
  State<AddNewRecordPage> createState() => _AddNewRecordPageState();
}

class _AddNewRecordPageState extends State<AddNewRecordPage> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSubmitting = false;
  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = ['CASH', 'MIXX BY YAS', 'M-PESA', 'AIRTEL MONEY', 'HALOPESA', 'AZAMPESA'];
  bool _isLoading = false;

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

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Record'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isSubmitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Item Name Field
                    TextFormField(
                      controller: _itemNameController,
                      decoration: InputDecoration(
                        labelText: 'Item Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.shopping_bag),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter item name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Quantity Field
                    TextFormField(
                      controller: _quantityController,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter quantity';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Price Field
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: 'Unit Price',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: const Icon(Icons.money),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter price';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildPaymentMethodSelector(isLargeScreen),
                    const SizedBox(height: 16),


                    // Date Picker
                    ListTile(
                      title: const Text('Date'),
                      subtitle: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                      ),
                      leading: const Icon(Icons.calendar_today),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      onTap: _selectDate,
                    ),
                    const SizedBox(height: 16),

                    // Time Picker
                    ListTile(
                      title: const Text('Time'),
                      subtitle: Text(
                        _selectedTime.format(context),
                      ),
                      leading: const Icon(Icons.access_time),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      onTap: _selectTime,
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Add Record',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      try {
        final Uri uri = Uri.parse('${widget.backendUrl}api/add_new_record');
        
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': widget.userId,
            'item_name': _itemNameController.text,
            'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
            'time': _selectedTime.format(context),
            'quantity': int.parse(_quantityController.text),
            'unit_price': double.parse(_priceController.text),
            'payment_method': selectedPaymentMethod,
          }),
        );

        if (response.statusCode == 201 || response.statusCode == 200) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add record: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Network error: Please check your internet connection'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }
}