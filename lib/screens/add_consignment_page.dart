import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/services/storage_service.dart';

class ConsignmentItem {
  String name;
  double price;
  int quantity;
  String consignmentItemInformation;

  ConsignmentItem({
    required this.name,
    required this.price,
    required this.quantity,
    required this.consignmentItemInformation,
  });
}

class AddConsignmentPage extends StatefulWidget {
  final Function refreshMethod;

  const AddConsignmentPage({super.key, required this.refreshMethod});

  @override
  State<AddConsignmentPage> createState() => _AddConsignmentPageState();
}

class _AddConsignmentPageState extends State<AddConsignmentPage> {
  int userId = 0;
  String role = "";
  final _formKey = GlobalKey<FormState>();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _senderNameController = TextEditingController();
  final _senderPhoneNumberController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneNumberController = TextEditingController();
  final _packageSizeController = TextEditingController();
  final _packageTypeController = TextEditingController();
  final _paidAmountController = TextEditingController();
  bool _isLoading = false;
  bool _isPaid = true;
  late final StorageService _storageService;

  final List<ConsignmentItem> _consignmentItems = [];


  @override
  void initState() {
    super.initState();
    _initializeServices();
    _addConsignmentItem();
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
        // Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sorry! You can't add a consignment")),
        );
      }

      getUserRole();
    }
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
            // Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Sorry, You can't add a consignment")),
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

  void _addConsignmentItem() {
    setState(() {
      _consignmentItems.add(ConsignmentItem(
        name: 'Regular', 
        price: 0, 
        quantity: 0,
        consignmentItemInformation: "",
      ));
    });
  }

  void _removeConsignmentItem(int index) {
    setState(() {
      _consignmentItems.removeAt(index);
    });
  }

  bool _validateConsignmentItems() {
    if (_consignmentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return false;
    }

    int totalNumberOfConsignmentItems = 0;
    for (var i = 0; i < _consignmentItems.length; i++) {
      final consignmentItem = _consignmentItems[i];
      
      if (consignmentItem.price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item prices must be greater than 0')),
        );
        return false;
      }

      if (consignmentItem.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Number of items must be greater than 0')),
        );
        return false;
      }

      totalNumberOfConsignmentItems = totalNumberOfConsignmentItems +  consignmentItem.quantity;

      if (consignmentItem.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item names cannot be empty')),
        );
        return false;
      }

      if (consignmentItem.name.length > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item names must be 100 characters or less')),
        );
        return false;
      }

      for (var j = i + 1; j < _consignmentItems.length; j++) {
        if (consignmentItem.name.trim() == _consignmentItems[j].name.trim()) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Item names should be different')),
          );
          return false;
        }
      }
    }

    return true;
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
  
  Future<void> _submitConsignment({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    if (!_validateConsignmentItems()) {
      return;
    }

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'name': _senderNameController.text.trim(),
      'payment_status': _isPaid ? "paid" : "not paid",
      'consignment_items': _consignmentItems.map((consignment_item) => {
        'name': consignment_item.name.trim(),
        'price': consignment_item.price,
        'quantity': consignment_item.quantity,
        'consignment_item_information': consignment_item.consignmentItemInformation.trim(),
      }).toList(),
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/add_consignment') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}add_consignment'); // Use IP

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Consignment added successfully!") {
          widget.refreshMethod();
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        if(response.statusCode == 413){
          _showSnackBar('Request failed: Image is Too Large');
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
          await _submitConsignment(useDNS: false); // Recursive retry

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


  @override
  void dispose() {
    _senderNameController.dispose();
    super.dispose();
  }

  Widget _buildConsignmentItemField(int index, bool isLargeScreen) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            isLargeScreen 
                ? _buildDesktopConsignmentItemFields(index)
                : _buildMobileConsignmentItemFields(index),
            const SizedBox(height: 8),
            _buildConsignmentItemActions(index),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopConsignmentItemFields(int index) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildConsignmentItemDropdown(index),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPriceField(index),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuantityField(index),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          maxLength: 250, // Added max length limit
          decoration: InputDecoration(
            labelText: 'Item Information',
            labelStyle: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            hintText: 'Enter item information...', // Optional hint text
            hintStyle: TextStyle(
              color: Colors.grey[500], // Lighter color for hint text
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), // Rounded corners
              borderSide: BorderSide(
                color: Colors.grey[400]!, // Light border color
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.orange[800]!, // Border color on focus
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey[400]!, // Default border color
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.grey[200], // Light background color
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Padding for the content
          ),
          onChanged: (value) {
            setState(() {
              _consignmentItems[index].consignmentItemInformation = value.trim();
            });
          },
          maxLines: 3,
          style: const TextStyle(
            fontSize: 16, // Input text font size
            color: Colors.black, // Input text color
          ),
          validator: (value) {
            if (value!.length > 250) {
              return 'Item information must be 250 characters or less';
            }
            return null;
          },
        ),
      ]
    );
  }

  Widget _buildMobileConsignmentItemFields(int index) {
    return Column(
      children: [
        _buildConsignmentItemDropdown(index),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildPriceField(index),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuantityField(index),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          maxLength: 250, // Added max length limit
          decoration: InputDecoration(
            labelText: 'Item Information',
            labelStyle: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            hintText: 'Enter icket information...', // Optional hint text
            hintStyle: TextStyle(
              color: Colors.grey[500], // Lighter color for hint text
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), // Rounded corners
              borderSide: BorderSide(
                color: Colors.grey[400]!, // Light border color
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.orange[800]!, // Border color on focus
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Colors.grey[400]!, // Default border color
                width: 1.5,
              ),
            ),
            filled: true,
            fillColor: Colors.grey[200], // Light background color
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12), // Padding for the content
          ),
          onChanged: (value) {
            setState(() {
              _consignmentItems[index].consignmentItemInformation = value.trim();
            });
          },
          maxLines: 3,
          style: const TextStyle(
            fontSize: 16, // Input text font size
            color: Colors.black, // Input text color
          ),
          validator: (value) {
            if (value!.length > 250) {
              return 'Item information must be 250 characters or less';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildConsignmentItemDropdown(int index) {
    return TextFormField(
      initialValue: _consignmentItems[index].name,
      decoration: _buildInputDecoration('Item Name'),
      style: const TextStyle(fontSize: 14),
      onChanged: (value) => setState(() => _consignmentItems[index].name = value),
    );
  }

  Widget _buildPriceField(int index) {
    return TextFormField(
      initialValue: _consignmentItems[index].price.toString(),
      decoration: _buildInputDecoration('Price', prefixText: 'TSH '),
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14),
      enabled: true,
      onChanged: (value) => setState(() {
        _consignmentItems[index].price = double.tryParse(value) ?? 0;
      }),
    );
  }

  Widget _buildQuantityField(int index) {
    return TextFormField(
      initialValue: _consignmentItems[index].quantity.toString(),
      decoration: _buildInputDecoration('Quantity'),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 14),
      onChanged: (value) => setState(() {
        _consignmentItems[index].quantity = int.tryParse(value) ?? 0;
      }),
    );
  }

  Widget _buildConsignmentItemActions(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_consignmentItems.length > 1)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeConsignmentItem(index),
          ),
      ],
    );
  }

  InputDecoration _buildInputDecoration(String label, {String? prefixText, IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
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
        borderSide: BorderSide(color: Colors.orange[800]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
  }

  Widget _buildPaymentStatusToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Payment Status',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Text(
              _isPaid ? 'Paid' : 'Not Paid',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _isPaid,
              onChanged: (value) => setState(() {
                _isPaid = value;
              }),
              activeColor: Colors.orange[800],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = _isLargeScreen(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Consignment'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
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
                      'Add New Consignment',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildPaymentStatusToggle(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senderNameController,
                    maxLength: 100,
                    decoration: _buildInputDecoration('Sender Name', prefixIcon: Icons.person),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter sender name';
                      if (value.length > 100) return 'Sender name must be 100 characters or less';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Consignment Items',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._consignmentItems.asMap().entries.map((entry) {
                    return _buildConsignmentItemField(entry.key, isLargeScreen);
                  }),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _addConsignmentItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Items'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: isLargeScreen ? 400 : double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitConsignment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange[800],
                      ),
                      child: _isLoading 
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Add Consignment',
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