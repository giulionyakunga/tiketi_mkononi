import 'dart:convert';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/consignments_page.dart';
import 'package:tiketi_mkononi/screens/platform_detector_stub.dart';
import 'package:tiketi_mkononi/screens/qr_scanner_cargo_page.dart';
import 'package:tiketi_mkononi/services/SimpleCodec.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

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
  final bool isReplacableScreen;

  const AddConsignmentPage({super.key, required this.userId, required this.companyId, required this.companyName, required this.officeId, required this.userName, required this.userPhoneNumber, required this.isReplacableScreen});

  @override
  State<AddConsignmentPage> createState() => _AddConsignmentPageState();
}

class _AddConsignmentPageState extends State<AddConsignmentPage> {
  int userId = 0;
  String role = "";
  String officeName = '';
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

  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  BluetoothDevice? selectedDevice;
  BluetoothDevice? selectedPrinter;
  Printer? selectedCablePrinter;
  int _selectedNumberofReceiptsToPrint = 1;

  String receiptFooter = "Karibu Sana";

  List<ConsignmentItem> _consignmentItems = [];
  Map<String, dynamic>? _addedConsignment;
  
  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = ['MIXX BY YAS', 'M-PESA', 'AIRTEL MONEY', 'HALOPESA', 'AZAMPESA'];

  int receiptsBalance = 0;
  int packageId = 0;
  List<dynamic> receiptPackages = [];

  int _consignmentItemsVersion = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _addConsignmentItem();
    _refreshBluetoothPrinters();
    if (Platform.isWindows) {
      _refreshCablePrinters();
      _loadSelectedPrinter();
    }
    _loadNumberOfReceipts();
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

        List<String> officeNames2 = [];

        // Loop through each office
        for (var office in responseData) {
          // Add name to officeNames
          if (office['id'] != widget.officeId) {
            officeNames2.add(office['name']);
          }

          // If this office's id matches widget.officeId, set officeName
          if (office['id'] == widget.officeId) {
            setState(() {
              officeName = office['name'];
              _fromController.text = office['name'];
            });
          }
        }

        if(officeNames2.length > 0) {
          setState(() {
            officeNames = officeNames2;
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

  Future<void> getReceiptPackages({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/receipt_packages') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}receipt_packages'); // Use IP
        
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


  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  void _addConsignmentItem() {
    setState(() {
      _consignmentItems.add(ConsignmentItem(
        name: '',
        value: 0,
        quantity: 1,
      ));
      _consignmentItemsVersion++; // Increment version
    });
  }

  void _removeConsignmentItem(int index) {
    setState(() {
      _consignmentItems.removeAt(index);
      _consignmentItemsVersion++; // Increment version
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

      if (consignmentItem.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter item name')), 
        );
        return false;
      }
      
      if (consignmentItem.value <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item price must be greater than 0')),
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

    if (_fromController.text.trim().toLowerCase() == _toController.text.trim().toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Origin and destination cannot be the same location.')),
      );
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
        final responseData = jsonDecode(response.body);
        String message = responseData['message'];
        
        if ((message.trim() == "Consignment added successfully!") || (message.trim() == "Parcel added successfully!"))  {
          receiptsBalance = responseData['number_of_sms'];
          _saveReceiptsBalance(responseData['number_of_sms']);

          debugPrint('message : $message');

          debugPrint('responseData : $responseData');
          packageId = responseData['id'];
          debugPrint('responseData2 : $responseData');
          setState(() {
            packageId = responseData['id'];
            receiptFooter = responseData['receipt_footer'];
          });

          _packageNameController.clear();
          _senderNameController.clear();
          _senderPhoneNumberController.clear();
          _toController.clear();
          _receiverNameController.clear();
          _receiverPhoneNumberController.clear();
          _packageValueController.clear();
          _paidAmountController.clear();
          _consignmentItems.clear();
          _addConsignmentItem();

          setState(() {
            _addedConsignment = requestBody;
          });

          if(_selectedNumberofReceiptsToPrint == 2) {
            _printBluetoothReceipt(requestBody);
            _printBluetoothReceipt2(requestBody);

            if (Platform.isWindows) {
              _printCableReceipt(requestBody);
            }
          } else {
            _printBluetoothReceipt(requestBody);
            if (Platform.isWindows) {
              _printCableReceipt(requestBody);
            }
          }

          _showSuccessDialog();
        }

        if (message.trim() == "Kifurushi chako kimeisha!") {
          await getReceiptPackages();
          _payDialog();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.trim())),
          );
        }
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

  Future<void> _payDialog() async {
    int? selectedPackage;
    int? selectedReceiptPackages;
    int? selectedAmount;
    String? selectedPaymentMethod;

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
                          "Receipts ${pkg["number_of_receipts"]} - TSH ${pkg["price"]}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: pkg["number_of_receipts"],
                        groupValue: selectedPackage,
                        onChanged: (value) {
                          setState(() {
                            selectedPackage = value;
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
                        onPressed: () async {
                          await _sendPaymentRequest(
                            phoneController.text.trim(),
                            selectedReceiptPackages,
                            selectedAmount,
                          );
                        },
                        child: const Text("Lipa"),
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Success'),
          ],
        ),
        content: const Text('Package added successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true);
            },
            child: const Text('OK'),
          )
        ],
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
              child: _buildConsignmentItemNameInputField(index),
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
        _buildConsignmentItemNameInputField(index),
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

  Widget _buildConsignmentItemNameInputField(int index) {
    return TextFormField(
      key: ValueKey('name_${_consignmentItemsVersion}_$index'), // Unique key that changes when list is cleared
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
      key: ValueKey('price_${_consignmentItemsVersion}_$index'), // Unique key
      initialValue: _consignmentItems[index].value.toString(),
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
      key: ValueKey('quantity_${_consignmentItemsVersion}_$index'), // Unique key
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
                receiptFooter = value ? "Karibu Sana" : "Thank You";
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
    final isLargeScreen = _isLargeScreen(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isParcel ? 'Add Parcel' : 'Add Consignment',
          style: TextStyle(
            fontSize: 15,
          ),
        ),       
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping),
            onPressed: () {
              
              if(widget.isReplacableScreen) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConsignmentsPage(userId: userId, officeId: widget.officeId, officeName: officeName, companyId: widget.companyId, role: role, companyName: widget.companyName, userName: widget.userName, userPhoneNumber: widget.userPhoneNumber,),
                  ),
                ); 
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConsignmentsPage(userId: userId, officeId: widget.officeId, officeName: officeName, companyId: widget.companyId, role: role, companyName: widget.companyName, userName: widget.userName, userPhoneNumber: widget.userPhoneNumber,),
                  ),
                );
              }
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
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            tooltip: 'More Options',
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            icon: Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 22,
            ),
            onSelected: (value) async {
              if (value == 'reprint_receipt') {
                if (_addedConsignment != null) {
                  _printBluetoothReceipt(_addedConsignment);
                }
              } else if (value == 'my_receipt') {
                if (_addedConsignment != null) {
                  _printBluetoothReceipt2(_addedConsignment);
                }
              } else if (value == 'refresh_printers') {
                _hardRefreshBluetoothPrinters();
                if (Platform.isWindows) {
                  _refreshCablePrinters();
                }
              } else if (value == 'number_of_receipts_to_print') {
                await _selectNumberofReceiptsToPrintDialog();
              } else if (value == 'topup_receipt') {
                await getReceiptPackages();
                _payDialog();
              } else if (value == 'exit') {
                Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [              
              _buildMenuItem(
                icon: Icons.business_sharp,
                text: widget.companyName,
                value: '--',
              ),
              _buildMenuItem(
                icon: Icons.print,
                text: 'My Receipt',
                value: 'my_receipt',
              ),
              _buildMenuItem(
                icon: Icons.refresh,
                text: 'Refresh Printers',
                value: 'refresh_printers',
              ),
              _buildMenuItem(
                icon: Icons.numbers,
                text: 'Print ${_selectedNumberofReceiptsToPrint} Receipts',
                value: 'number_of_receipts_to_print',
              ),
              _buildMenuItem(
                icon: Icons.account_balance_wallet,
                text: 'Receipts Balance: ${receiptsBalance}',
                value: 'topup_receipt',
              ),
              _buildMenuItem(
                icon: Icons.add_card,
                text: 'Topup Receipt',
                value: 'topup_receipt',
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
            child: isLargeScreen ? Center(
              child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 500, // limit width
              ),
              child:
                Form(
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
                      (widget.officeId > 0) ?
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
                      ) :
                      DropdownButtonFormField<String>(
                        value: _fromController.text.isNotEmpty ? _fromController.text : null, // preselect if any
                        decoration: _buildInputDecoration('From', prefixIcon: Icons.business),
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
                            _fromController.text = value; // update controller so form works
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please select a origin';
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
            ) :
            Form(
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
                  (widget.officeId > 0) ?
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
                  ) :
                  DropdownButtonFormField<String>(
                    value: _fromController.text.isNotEmpty ? _fromController.text : null, // preselect if any
                    decoration: _buildInputDecoration('From', prefixIcon: Icons.business),
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
                        _fromController.text = value; // update controller so form works
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please select a origin';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // DropdownButtonFormField<String>(
                  //   value: _toController.text.isNotEmpty ? _toController.text : null, // preselect if any
                  //   decoration: _buildInputDecoration('Destination', prefixIcon: Icons.business),
                  //   style: const TextStyle(fontSize: 16),
                  //   items: officeNames.map((office) {
                  //     return DropdownMenuItem<String>(
                  //       value: office,
                  //       child: Text(
                  //         office,
                  //         style: TextStyle(color: Colors.black),
                  //       ),
                  //     );
                  //   }).toList(),
                  //   onChanged: (value) {
                  //     if (value != null) {
                  //       _toController.text = value; // update controller so form works
                  //     }
                  //   },
                  //   validator: (value) {
                  //     if (value == null || value.isEmpty) return 'Please select a destination';
                  //     return null;
                  //   },
                  // ),
                  Autocomplete<String>(
                    initialValue: TextEditingValue(text: _toController.text),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return officeNames;
                      }
                      return officeNames.where((office) =>
                          office.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                    },
                    onSelected: (String selection) {
                      _toController.text = selection;
                    },
                    fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                      // sync controller
                      controller.text = _toController.text;

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _buildInputDecoration(
                          'Destination',
                          prefixIcon: Icons.business,
                        ),
                        onChanged: (value) {
                          _toController.text = value; // allows custom input
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter or select a destination';
                          }
                          return null;
                        },
                      );
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
  
  Future<void> _refreshBluetoothPrinters() async {

    bool? isConnected = await bluetooth.isConnected;

    if (!(isConnected ?? false)) {
      debugPrint(' Not Connected to bluetooth device, connecting...');
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();

      if (devices.isNotEmpty) {
        await _selectPrinterDialog(devices);

        if (selectedPrinter == null) {
          print("No printer found");
          return;
        }

        try {
          await bluetooth.connect(selectedPrinter!);
          isConnected = true;
        } catch (e) {
          isConnected = false;
          debugPrint('Failed to connect to printer: $e');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to connect to printer'),
              backgroundColor: Colors.red,
            ),
          );
          return; // stop printing
        }
      } else {
        // No paired printer found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No paired Bluetooth printer found.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // stop printing
      }
    }

    if (!(isConnected ?? false)) {
      // Printer still not connected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer is not connected.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bluetooth.printNewLine();
    bluetooth.printCustom(" ", 2, 1);
    bluetooth.printNewLine();
    bluetooth.paperCut();
   
  }

  Future<void> _hardRefreshBluetoothPrinters() async {

    bool? isConnected = await bluetooth.isConnected;

    if (isConnected == true) {
      await bluetooth.disconnect();
      isConnected = false;
    }

    bluetooth = BlueThermalPrinter.instance;
    selectedDevice = null;
    selectedPrinter = null;
    selectedCablePrinter = null;


    if (!(isConnected ?? false)) {
      debugPrint(' Not Connected to bluetooth device, connecting...');
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();

      if (devices.isNotEmpty) {
        await _selectPrinterDialog(devices);

        if (selectedPrinter == null) {
          print("No printer found");
          return;
        }

        try {
          await bluetooth.connect(selectedPrinter!);
          isConnected = true;
        } catch (e) {
          isConnected = false;
          debugPrint('Failed to connect to printer: $e');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to connect to printer'),
              backgroundColor: Colors.red,
            ),
          );
          return; // stop printing
        }
      } else {
        // No paired printer found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No paired Bluetooth printer found.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // stop printing
      }
    }

    if (!(isConnected ?? false)) {
      // Printer still not connected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer is not connected.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bluetooth.printNewLine();
    bluetooth.printCustom("********************************", 1, 1);
    bluetooth.printCustom("*${widget.companyName}*", 2, 1);
    bluetooth.printCustom("********************************", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
   
  }

  Future<void> _printBluetoothReceipt(dynamic consignment) async {

    bool? isConnected = await bluetooth.isConnected;

    if (!(isConnected ?? false)) {
      debugPrint(' Not Connected to bluetooth device, connecting...');
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();

      if (devices.isNotEmpty) {
        await _selectPrinterDialog(devices);

        if (selectedPrinter == null) {
          print("No printer found");
          return;
        }

        try {
          await bluetooth.connect(selectedPrinter!);
          isConnected = true;
        } catch (e) {
          isConnected = false;
          debugPrint('Failed to connect to printer: $e');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to connect to printer'),
              backgroundColor: Colors.red,
            ),
          );
          return; // stop printing
        }
      } else {
        // No paired printer found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No paired Bluetooth printer found.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // stop printing
      }
    }

    if (!(isConnected ?? false)) {
      // Printer still not connected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer is not connected.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final items = consignment['consignment_items'] ?? [];

    bluetooth.printNewLine();
    bluetooth.printCustom("********************************", 1, 1);
    bluetooth.printCustom(widget.companyName, 1, 1);
    bluetooth.printCustom("********************************", 1, 1);
    bluetooth.printCustom(consignment['is_parcel'] ? "PARCEL RECEIPT" : "CONSIGNMENT RECEIPT", 1, 1);
    bluetooth.printCustom("Package No: ${packageId}", 1, 1);
    bluetooth.printLeftRight("Package Name", consignment['package_name'] ?? '', 1);

    // final packageValue = (consignment['package_value'] ?? 0).toInt();
    // bluetooth.printLeftRight(
    //   "Package Value",
    //   packageValue == 0
    //       ? "N/A"
    //       : "TZS ${NumberFormat('#,##0').format((consignment['package_value'] ?? 0).toInt())}",
    //   1,
    // );
    bluetooth.printLeftRight(
      "Package Value",
      "TZS ${consignment['package_value']}",
      1,
    );

    bluetooth.printLeftRight("Payment Status", consignment['payment_status'] ? 'Paid' : 'Not Paid', 1);

    if(consignment['payment_status']) {
      bluetooth.printLeftRight(
        "Paid Amount",
        "TZS ${consignment['paid_amount']}",
        // "TZS ${NumberFormat('#,##0').format((consignment['paid_amount'] ?? 0).toInt())}",
        1,
      );
    }

    bluetooth.printCustom("Route", 1, 0);
    bluetooth.printLeftRight("From", consignment['from'] ?? '', 1);
    bluetooth.printLeftRight("To", consignment['to'] ?? '', 1);

    bluetooth.printCustom("Sender", 1, 0);
    bluetooth.printLeftRight("Name", consignment['sender_name'] ?? '', 1);
    bluetooth.printLeftRight("Phone", consignment['sender_phone_number'] ?? '', 1);

    bluetooth.printCustom("Receiver", 1, 0); 
    bluetooth.printLeftRight("Name", consignment['receiver_name'] ?? '', 1);
    bluetooth.printLeftRight("Phone", consignment['receiver_phone_number'] ?? '', 1);

    if ((items.length > 1) && (items.length <= 10)) {
      bluetooth.printCustom("Items", 1, 0);

      int index = 1;
      for (var item in items) {
        bluetooth.printLeftRight(
          "$index. ${item['name']} (x${item['quantity']})",
          "TZS ${NumberFormat('#,##0').format((((item['value'] ?? 0).toInt()) * item['quantity']).toInt())}",
          1,
        );

        index++;
      }
    }

    bluetooth.printNewLine();
    bluetooth.printCustom("Issued By", 1, 0);
    bluetooth.printLeftRight("Name", consignment['issued_by'] ?? '', 1);
    bluetooth.printLeftRight("Phone", consignment['issuer_phone_number'] ?? '', 1);

    String data = SimpleCodec.encode(jsonEncode({
      "cid": packageId,
      "oid": consignment['office_id'],
    }));

    // QR CODE
    bluetooth.printQRcode(
      data,
      200,
      200,
      1,
    );

    bluetooth.printCustom(receiptFooter, 1, 1);
    bluetooth.printNewLine();
    bluetooth.printCustom("Powered by Tiketi Mkononi", 1, 1);
    bluetooth.printCustom("Email:tiketimkononi@telabs.co.tz", 1, 1);
    bluetooth.printCustom("Phone: +255 672 120 941", 1, 1);
    bluetooth.printCustom("********************************", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  Future<void> _printBluetoothReceipt2(dynamic consignment) async {

    bool? isConnected = await bluetooth.isConnected;

    if (!(isConnected ?? false)) {
      debugPrint(' Not Connected to bluetooth device, connecting...');
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();

      if (devices.isNotEmpty) {
        await _selectPrinterDialog(devices);

        if (selectedPrinter == null) {
          print("No printer found");
          return;
        }

        try {
          await bluetooth.connect(selectedPrinter!);
          isConnected = true;
        } catch (e) {
          isConnected = false;
          debugPrint('Failed to connect to printer: $e');

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to connect to printer'),
              backgroundColor: Colors.red,
            ),
          );
          return; // stop printing
        }
      } else {
        // No paired printer found
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No paired Bluetooth printer found.'),
            backgroundColor: Colors.red,
          ),
        );
        return; // stop printing
      }
    }

    if (!(isConnected ?? false)) {
      // Printer still not connected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer is not connected.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final items = consignment['consignment_items'] ?? [];

    bluetooth.printNewLine();
    bluetooth.printCustom("********************************", 1, 1);
    bluetooth.printCustom(widget.companyName, 2, 1);
    bluetooth.printCustom("********************************", 1, 1);
    bluetooth.printCustom(consignment['is_parcel'] ? "PARCEL CODE" : "CONSIGNMENT CODE", 2, 1);
    bluetooth.printCustom("Pkg No: ${packageId}", 2, 1);

    if(consignment['is_parcel']) {
      bluetooth.printCustom("${consignment['package_name']}", 2, 1);
    } else {
      if (items.length > 1) {
        bluetooth.printCustom("${consignment['package_name']}(${items.length})", 2, 1);
      } else {
        bluetooth.printCustom("${consignment['package_name']}", 2, 1);
      }
    }

    bluetooth.printCustom("${consignment['receiver_name']}", 2, 1);
    bluetooth.printCustom("${consignment['receiver_phone_number']}", 2, 1);

    String data = SimpleCodec.encode(jsonEncode({
      "cid": packageId,
      "oid": consignment['office_id'],
    }));

    // QR CODE
    bluetooth.printQRcode(
      data,
      250,
      250,
      1,
    );

    bluetooth.printCustom("Powered by Tiketi Mkononi", 1, 1);
    bluetooth.printCustom("Email:tiketimkononi@telabs.co.tz", 1, 1);
    bluetooth.printCustom("Phone: +255 672 120 941", 1, 1);
    bluetooth.printCustom("********************************", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut();
  }

  Future<void> _printCableReceipt(dynamic consignment) async {
    final pdf = pw.Document();

    final logoData = await rootBundle.load('assets/telabs_logo.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

    final fontData =
        await rootBundle.load('assets/fonts/poppins/Poppins-Regular.ttf');
    final customFont = pw.Font.ttf(fontData);

    const pageWidth = 226.0;

    final items = consignment['consignment_items'] ?? [];

    String data = SimpleCodec.encode(jsonEncode({
      "cid": packageId,
      "oid": consignment['office_id'],
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
                    widget.companyName,
                    style: pw.TextStyle(
                      font: customFont,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.Center(
                  child: pw.Text(
                    consignment['is_parcel']
                        ? "PARCEL RECEIPT"
                        : "CONSIGNMENT RECEIPT",
                    style: pw.TextStyle(
                      font: customFont,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.SizedBox(height: 6),

                pw.Text(
                  "********************************",
                  style: pw.TextStyle(font: customFont),
                ),

                /// PACKAGE INFO
                pw.Text(
                  "Package No: ${packageId}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Package Name: ${consignment['package_name'] ?? ''}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Package Value: TZS ${consignment['package_value']}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Payment Status: ${consignment['payment_status'] ? "Paid" : "Not Paid"}",
                  style: pw.TextStyle(font: customFont),
                ),

                if (consignment['payment_status'])
                  pw.Text(
                    "Paid Amount: TZS ${consignment['paid_amount']}",
                    style: pw.TextStyle(font: customFont),
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
                  ),
                ),

                pw.Text(
                  "From: ${consignment['from'] ?? ''}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "To: ${consignment['to'] ?? ''}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.SizedBox(height: 6),

                /// SENDER
                pw.Text(
                  "Sender",
                  style: pw.TextStyle(
                    font: customFont,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.Text(
                  "Name: ${consignment['sender_name'] ?? ''}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Phone: ${consignment['sender_phone_number'] ?? ''}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.SizedBox(height: 6),

                /// RECEIVER
                pw.Text(
                  "Receiver",
                  style: pw.TextStyle(
                    font: customFont,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.Text(
                  "Name: ${consignment['receiver_name'] ?? ''}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Phone: ${consignment['receiver_phone_number'] ?? ''}",
                  style: pw.TextStyle(font: customFont),
                ),

                /// ITEMS
                if ((items.length > 1) && (items.length <= 10)) ...[
                  pw.SizedBox(height: 6),

                  pw.Text(
                    "Items",
                    style: pw.TextStyle(
                      font: customFont,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),

                  pw.SizedBox(height: 4),

                  for (int i = 0; i < items.length; i++)
                    pw.Text(
                      "${i + 1}. ${items[i]['name']} (x${items[i]['quantity']})  "
                      "TZS ${NumberFormat('#,##0').format(((items[i]['value'] ?? 0) * items[i]['quantity']).toInt())}",
                      style: pw.TextStyle(font: customFont),
                    ),
                ],

                pw.SizedBox(height: 6),

                pw.Text(
                  "--------------------------------",
                  style: pw.TextStyle(font: customFont),
                ),

                /// ISSUED BY
                pw.Text(
                  "Issued By",
                  style: pw.TextStyle(
                    font: customFont,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.Text(
                  "Name: ${consignment['issued_by'] ?? ''}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Phone: ${consignment['issuer_phone_number'] ?? ''}",
                  style: pw.TextStyle(font: customFont),
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
                    style: pw.TextStyle(font: customFont),
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
                    style: pw.TextStyle(font: customFont, fontSize: 9),
                  ),
                ),

                pw.Center(
                  child: pw.Text(
                    "Phone: +255 672 120 941",
                    style: pw.TextStyle(font: customFont, fontSize: 9),
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

  Future<void> _refreshCablePrinters() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("selected_printer_url");
    await prefs.remove("selected_printer_name");

    setState(() {
      selectedCablePrinter = null;
    });

    await _selectCablePrinterDialog(); // fallback
  }

  Future<void> _saveNumberOfReceipts(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('number_of_receipts_to_print', value);
  }

  Future<void> _saveReceiptsBalance(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('receipts_balance', value);
  }

  Future<void> _loadNumberOfReceipts() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _selectedNumberofReceiptsToPrint = prefs.getInt('number_of_receipts_to_print') ?? 1;
      receiptsBalance = prefs.getInt('receipts_balance') ?? 0;
    });
  }

  Future<void> _selectNumberofReceiptsToPrintDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;
            final dialogWidth =
                isSmallScreen ? constraints.maxWidth * 0.9 : 400.0;

            return AlertDialog(
              contentPadding: const EdgeInsets.all(20),
              title: const Text("Select number of receipts"),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: dialogWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text("Print 1 receipt"),
                        selected: _selectedNumberofReceiptsToPrint == 1,
                        trailing: (_selectedNumberofReceiptsToPrint == 1) ? const Icon(Icons.check, color: Colors.green) : null,
                        onTap: () {
                          setState(() {
                            _selectedNumberofReceiptsToPrint = 1;
                          });
                          _saveNumberOfReceipts(1);
                          Navigator.of(context).pop();
                        },
                      ),
                      ListTile(
                        title: const Text("Print 2 receipts"),
                        selected: _selectedNumberofReceiptsToPrint == 2,
                        trailing: (_selectedNumberofReceiptsToPrint == 2) ? const Icon(Icons.check, color: Colors.green) : null,
                        onTap: () {
                          setState(() {
                            _selectedNumberofReceiptsToPrint = 2;
                          });
                          _saveNumberOfReceipts(2);
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectPrinterDialog(List<BluetoothDevice> devices) async {
    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No printers found.')),
      );
      return;
    }

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
                    children: devices
                        .map(
                          (device) => ListTile(
                            title: Text(device.name!),
                            subtitle: Text(device.address!),
                            onTap: () async {
                              _saveSelectedPrinter(device.name!);
                              selectedPrinter = device;
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

  Future<void> _saveSelectedPrinter(String printerName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_name', printerName);
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
}