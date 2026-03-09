import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/consignments_page.dart';
import 'package:tiketi_mkononi/screens/platform_detector_stub.dart';
import 'package:tiketi_mkononi/screens/qr_scanner_cargo_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ConsignmentItem {
  String name;
  double value;
  int quantity;

  ConsignmentItem({
    required this.name,
    required this.value,
    required this.quantity,
  });
}

class AddConsignmentPage extends StatefulWidget {
  final int userId;
  final int companyId;
  final int officeId;
  final String companyName;
  final String userName;
  final String userPhoneNumber;

  const AddConsignmentPage({super.key, required this.userId, required this.companyId, required this.companyName, required this.officeId, required this.userName, required this.userPhoneNumber});

  @override
  State<AddConsignmentPage> createState() => _AddConsignmentPageState();
}

class _AddConsignmentPageState extends State<AddConsignmentPage> {
  int userId = 0;
  String role = "";
  List<String> officeNames = [];
  final _formKey = GlobalKey<FormState>();
  final _senderNameController = TextEditingController();
  final _senderPhoneNumberController = TextEditingController();
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneNumberController = TextEditingController();
  final _packageNameController = TextEditingController();
  final _packageValueController = TextEditingController();
  final _paidAmountController = TextEditingController();
  bool _isLoading = false;
  bool _isPaid = true;
  bool _isParcel = true;
  late final StorageService _storageService;

  List<ConsignmentItem> _consignmentItems = [];


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
      getCompanyOffices();
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

        String officeName2 = "";
        List<String> officeNames2 = [];

        // Loop through each office
        for (var office in responseData) {
          debugPrint("offices > ${responseData.length} id: ${widget.officeId}, ${office['id']}, ${office['name']}");

          // Add name to officeNames
          if (office['id'] != widget.officeId) {
            officeNames2.add(office['name']);
          }

          // If this office's id matches widget.officeId, set officeName
          if (office['id'] == widget.officeId) {
            officeName2 = office['name'];
          }
        }

        if(responseData.length > 0) {
          setState(() {
            officeNames = officeNames2;
            _fromController.text = officeName2;
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
        name: '',
        value: 0,
        quantity: 0,
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
      
      if (consignmentItem.value <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item value must be greater than 0')),
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

    ConsignmentItem consignmentItem;
    if(_isParcel) {
      consignmentItem = ConsignmentItem(
        name: _packageNameController.text.trim(), 
        value: double.tryParse(_packageValueController.text.trim()) ?? 0.0,
        quantity: 1,
      );
      _consignmentItems = [consignmentItem];
    }

    if (!_validateConsignmentItems()) {
      return;
    }

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'company_id': widget.companyId,
      'office_id': widget.officeId,
      'package_name': _packageNameController.text.trim(),
      'sender_name': _senderNameController.text.trim(),
      'sender_phone_number': _senderPhoneNumberController.text.trim(),
      'from': _fromController.text.trim(),
      'to': _toController.text.trim(),
      'receiver_name': _receiverNameController.text.trim(),
      'receiver_phone_number': _receiverPhoneNumberController.text.trim(),
      'package_value': _packageValueController.text.trim(),
      'paid_amount': _paidAmountController.text.trim(),
      'payment_status': _isPaid ? true : false,
      'is_parcel': _isParcel ? true : false,
      'consignment_items': _consignmentItems.map((consignment_item) => {
        'name': consignment_item.name.trim(),
        'value': consignment_item.value,
        'quantity': consignment_item.quantity,
      }).toList(),
      'issued_by': widget.userName,
      'issuer_phone_number': widget.userPhoneNumber,
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
          _packageNameController.clear();
          _senderNameController.clear();
          _senderPhoneNumberController.clear();
          _fromController.clear();
          _toController.clear();
          _receiverNameController.clear();
          _receiverPhoneNumberController.clear();
          _packageValueController.clear();
          _paidAmountController.clear();
          _consignmentItems.clear();
          if(!_isParcel) {
            _addConsignmentItem();
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ConsignmentsPage(userId: userId, officeId: 0, officeName: '', companyId: 0, role: role, companyName: widget.companyName,),
            ),
          );
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
    _packageNameController.dispose();
    _senderNameController.dispose();
    _senderPhoneNumberController.dispose();
    _fromController.dispose();
    _toController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneNumberController.dispose();
    _packageValueController.dispose();
    _paidAmountController.dispose();
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

  double getTotalValue() {
    double totalValue = 0;

    for (int index = 0; index < _consignmentItems.length; index++) {
      totalValue += _consignmentItems[index].value * _consignmentItems[index].quantity;
    }

    return totalValue;
  }

  Widget _buildPriceField(int index) {
    return TextFormField(
      // initialValue: _consignmentItems[index].value.toString(),
      decoration: _buildInputDecoration('Price', prefixText: 'TSH '),
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14),
      enabled: true,
      onChanged: (value) => setState(() {
        _consignmentItems[index].value = double.tryParse(value) ?? 0;
        _paidAmountController.text = '${getTotalValue()}';
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
        _paidAmountController.text = '${getTotalValue()}';
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
        borderSide: BorderSide(color: Colors.teal[800]!, width: 2),
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
              activeColor: Colors.teal[800],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPackageTypeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Package Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Text(
              _isParcel ? 'Parcel' : 'Consignment',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 8),
            Switch(
              value: _isParcel,
              onChanged: (value) => setState(() {
                _isParcel = value;
              }),
              activeColor: Colors.teal[800],
            ),
          ],
        ),
      ],
    );
  }

  void _handleQRCodeScannerUnavailablility () {
     showDialog(
      context: context,
      builder: (context) => AlertDialog( 
        title: const Text('QR Code Scanning Unavailable'),
        content: const Text('This feature is only supported in the Tiketi Mkononi mobile app. Please download and open the application on your smartphone to scan QR codes'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _launchStore();
            },
            child: const Text('Install App', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  
  Future<void> _launchStore() async {  
    const appStoreUrl = "https://apps.apple.com/app/id6746575990"; // iOS
    const playStoreUrl = "https://play.google.com/store/apps/details?id=com.telabs.tiketi_mkononi"; // Android

    Uri storeUrl;
    if(kIsWeb) {
      storeUrl = Uri.parse(
        isAndroidWeb() ? playStoreUrl : appStoreUrl,
      );
    }else {
      storeUrl = Uri.parse(
        Platform.isAndroid ? playStoreUrl : appStoreUrl,
      );
    }

    if (!await launchUrl(storeUrl, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $storeUrl");
    }
  }


  @override
  Widget build(BuildContext context) {
    final isLargeScreen = _isLargeScreen(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isParcel ? 'Add Parcel' : 'Add Consignment'),       
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConsignmentsPage(userId: userId, officeId: 0, officeName: '', companyId: 0, role: role, companyName: widget.companyName,),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {
              (kIsWeb) ? 
                _handleQRCodeScannerUnavailablility()
              :
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => QRScannerCargoPage(userId: widget.userId, companyId: widget.companyId, companyName: widget.companyName, officeId: widget.officeId, userName: widget.userName, userPhoneNumber: widget.userPhoneNumber),
                ),
              );
            },
          ),
        ],
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
                  _buildPackageTypeToggle(),
                  _buildPaymentStatusToggle(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _packageNameController,
                    maxLength: 100,
                    decoration: _buildInputDecoration('Package Name', prefixIcon: Icons.person),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter package name';
                      if (value.length > 100) return 'Package name must be 100 characters or less';
                      return null;
                    },
                  ),
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
                  TextFormField(
                    controller: _senderPhoneNumberController,
                    maxLength: 15,
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration('Sender Phone Number', prefixIcon: Icons.phone),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter sender phone number';
                      if (value.length > 15) return 'Sender phone number must be 15 characters or less';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _fromController,
                    maxLength: 100,
                    enabled: false,
                    decoration: _buildInputDecoration('From', prefixIcon: Icons.business),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter origin';
                      if (value.length > 100) return 'Origin name must be 100 characters or less';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _toController.text.isNotEmpty ? _toController.text : null, // preselect if any
                    decoration: _buildInputDecoration('Destination', prefixIcon: Icons.business),
                    style: const TextStyle(fontSize: 16),
                    items: officeNames.map((office) {
                      return DropdownMenuItem<String>(
                        value: office,
                        child: Text(
                          office,
                          style: TextStyle(color: Colors.black),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _toController.text = value; // update controller so form works
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please select a destination';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _receiverNameController,
                    maxLength: 100,
                    decoration: _buildInputDecoration('Receiver Name', prefixIcon: Icons.person),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter receiver name';
                      if (value.length > 100) return 'Receiver name must be 100 characters or less';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _receiverPhoneNumberController,
                    maxLength: 15,
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration('Receiver Phone Number', prefixIcon: Icons.phone),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter receiver phone number';
                      if (value.length > 15) return 'Receiver phone number must be 15 characters or less';
                      return null;
                    },
                  ),
  
                  if (!_isParcel) ...[
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
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _packageValueController,
                    maxLength: 8,
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration('Package Value', prefixText: 'TSH '),
                    style: const TextStyle(fontSize: 16),
                    validator: _isParcel ? (value) {
                      if (value == null || value.isEmpty) return 'Please enter package value';
                      if (value.length > 8) return 'Package value must be 8 characters or less';
                      return null;
                    } : (value) {
                      if (value == null || value.isEmpty) {
                        _packageValueController.text = '0';
                        return null;
                      };
                      if (value.length > 8) return 'Package value must be 8 characters or less';
                      return null;
                    },
                  ),
                   const SizedBox(height: 16),
                  TextFormField(
                    controller: _paidAmountController,
                    maxLength: 8,
                    enabled: _isParcel,
                    decoration: _buildInputDecoration('Paid Amount', prefixText: 'TSH '),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16),
                    validator: _isParcel ? (value) {
                      if (value == null || value.isEmpty) return 'Please enter Paid Amount';
                      if (value.length > 8) return 'Paid amount must be 8 characters or less';
                      return null;
                    } : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: isLargeScreen ? 400 : double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitConsignment,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.teal[800],
                      ),
                      child: _isLoading 
                          ? const CircularProgressIndicator()
                          : Text(
                              _isParcel ? 'Add Parcel' : 'Add Consignment',
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