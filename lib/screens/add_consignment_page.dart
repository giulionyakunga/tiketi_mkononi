// in this file extract all the hardcoded strings and put the into a json file for localization for both app_en.arb and app_sw.arb

import 'dart:convert';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
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

  List<BluetoothInfo> devices = [];
  BluetoothInfo? selectedPrinter;

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
    if (Platform.isWindows) {
      _refreshCablePrinters();
      _loadSelectedPrinter();
    }
    _loadNumberOfReceipts();
    loadAndMatchPrinter();
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
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseAddAtLeastOneItem)),
      );
      return false;
    }

    int totalNumberOfConsignmentItems = 0;
    for (var i = 0; i < _consignmentItems.length; i++) {
      final consignmentItem = _consignmentItems[i];

      if (consignmentItem.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterItemName)), 
        );
        return false;
      }
      
      if (consignmentItem.value <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.itemPriceGreaterThanZero)),
        );
        return false;
      }

      if (consignmentItem.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.itemQuantityGreaterThanZero)),
        );
        return false;
      }

      totalNumberOfConsignmentItems = totalNumberOfConsignmentItems +  consignmentItem.quantity;

      if (consignmentItem.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.itemNamesCannotBeEmpty)),
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

          _printBluetoothReceipt(requestBody);
          
          if(_selectedNumberofReceiptsToPrint == 2) {
            _printBluetoothReceipt2(requestBody);

            if (Platform.isWindows) {
              _printCableReceipt(requestBody);
            }
          } else {
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
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.success),
          ],
        ),
        content: Text(AppLocalizations.of(context)!.packageAddedSuccessfully),
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
      decoration: _buildInputDecoration(AppLocalizations.of(context)!.itemName),
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
      decoration: _buildInputDecoration(AppLocalizations.of(context)!.price, prefixText: 'TSH '),
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
      decoration: _buildInputDecoration(AppLocalizations.of(context)!.quantity),
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
        Text(
          AppLocalizations.of(context)!.paymentStatus,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Text(
              _isPaid ?  AppLocalizations.of(context)!.paid :  AppLocalizations.of(context)!.notPaid,
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
        Text(
          AppLocalizations.of(context)!.packageType,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Row(
          children: [
            Text(
              _isParcel ? AppLocalizations.of(context)!.parcel : AppLocalizations.of(context)!.consignment,
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
          _isParcel ? AppLocalizations.of(context)!.addParcel : AppLocalizations.of(context)!.addConsignment,
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
                _printBluetoothTestReceipt();
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
                text: AppLocalizations.of(context)!.reprintReceipt,
                value: 'reprint_receipt',
              ),
              _buildMenuItem(
                icon: Icons.print,
                text: AppLocalizations.of(context)!.myReceipt,
                value: 'my_receipt',
              ),
              _buildMenuItem(
                icon: Icons.refresh,
                text: AppLocalizations.of(context)!.refreshPrinters,
                value: 'refresh_printers',
              ),
              _buildMenuItem(
                icon: Icons.numbers,
                text: AppLocalizations.of(context)!.printReceipts(_selectedNumberofReceiptsToPrint.toString()),
                value: 'number_of_receipts_to_print',
              ),
              _buildMenuItem(
                icon: Icons.account_balance_wallet,
                text: AppLocalizations.of(context)!.receiptsBalance(_selectedNumberofReceiptsToPrint.toString()),
                value: 'topup_receipt',
              ),
              _buildMenuItem(
                icon: Icons.add_card,
                text: AppLocalizations.of(context)!.topupReceipt,
                value: 'topup_receipt',
              ),
              const PopupMenuDivider(),
              _buildMenuItem(
                icon: Icons.exit_to_app,
                text: AppLocalizations.of(context)!.exit,
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
                        Text(
                          AppLocalizations.of(context)!.addNewConsignment,
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
                          if (value == null || value.isEmpty) return  AppLocalizations.of(context)!.pleaseEnterPackageName;
                          if (value.length > 100) return  AppLocalizations.of(context)!.packageName;
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _senderNameController,
                        maxLength: 100,
                        decoration: _buildInputDecoration( AppLocalizations.of(context)!.senderName, prefixIcon: Icons.person),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.isEmpty) return  AppLocalizations.of(context)!.pleaseEnterSenderName;
                          if (value.length > 100) return 'Sender name must be 100 characters or less';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _senderPhoneNumberController,
                        maxLength: 15,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration( AppLocalizations.of(context)!.senderPhoneNumber, prefixIcon: Icons.phone),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.isEmpty) return  AppLocalizations.of(context)!.pleaseEnterSenderPhone;
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
                        decoration: _buildInputDecoration(AppLocalizations.of(context)!.from, prefixIcon: Icons.business),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.isEmpty) return  AppLocalizations.of(context)!.pleaseEnterOrigin;
                          if (value.length > 100) return AppLocalizations.of(context)!.originMaxLength;
                          return null;
                        },
                      ) :
                      DropdownButtonFormField<String>(
                        value: _fromController.text.isNotEmpty ? _fromController.text : null, // preselect if any
                        decoration: _buildInputDecoration(AppLocalizations.of(context)!.from, prefixIcon: Icons.business),
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
                        decoration: _buildInputDecoration(AppLocalizations.of(context)!.to, prefixIcon: Icons.business),
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
                          if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterDestination;
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
                          if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterReceiverName;
                          if (value.length > 100) return AppLocalizations.of(context)!.receiverNameMaxLength;
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _receiverPhoneNumberController,
                        maxLength: 15,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration(AppLocalizations.of(context)!.receiverPhoneNumber, prefixIcon: Icons.phone),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterReceiverPhone;
                          if (value.length > 15) return AppLocalizations.of(context)!.receiverPhoneMaxLength;
                          return null;
                        },
                      ),
      
                      if (!_isParcel) ...[
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.consignmentItems,
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
                            label: Text(AppLocalizations.of(context)!.addItems),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _packageValueController,
                        maxLength: 8,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration(AppLocalizations.of(context)!.packageValue, prefixText: 'TSH '),
                        style: const TextStyle(fontSize: 16),
                        validator: _isParcel ? (value) {
                          if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterPackageValue;
                          if (value.length > 8) return AppLocalizations.of(context)!.packageValueMaxLength;
                          return null;
                        } : (value) {
                          if (value == null || value.isEmpty) {
                            _packageValueController.text = '0';
                            return null;
                          };
                          if (value.length > 8) return AppLocalizations.of(context)!.packageValueMaxLength;
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _paidAmountController,
                        maxLength: 8,
                        enabled: _isParcel,
                        decoration: _buildInputDecoration(AppLocalizations.of(context)!.paidAmount, prefixText: 'TSH '),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 16),
                        validator: _isParcel ? (value) {
                          if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterPaidAmount;
                          if (value.length > 8) return AppLocalizations.of(context)!.paidAmountMaxLength;
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
                                  _isParcel ? AppLocalizations.of(context)!.addParcel : AppLocalizations.of(context)!.addConsignment,
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
                    Text(
                      AppLocalizations.of(context)!.addNewConsignment,
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
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.packageName, prefixIcon: Icons.person),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterPackageName;
                      if (value.length > 100) return AppLocalizations.of(context)!.packageNameMaxLength;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senderNameController,
                    maxLength: 100,
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.senderName, prefixIcon: Icons.person),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterSenderName;
                      if (value.length > 100) return AppLocalizations.of(context)!.senderNameMaxLength;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _senderPhoneNumberController,
                    maxLength: 15,
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.senderPhoneNumber, prefixIcon: Icons.phone),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterSenderPhone;
                      if (value.length > 15) return AppLocalizations.of(context)!.senderPhoneMaxLength;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  (widget.officeId > 0) ?
                  TextFormField(
                    controller: _fromController,
                    maxLength: 100,
                    enabled: false,
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.from, prefixIcon: Icons.business),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterOrigin;
                      if (value.length > 100) return AppLocalizations.of(context)!.originMaxLength;
                      return null;
                    },
                  ) :
                  DropdownButtonFormField<String>(
                    value: _fromController.text.isNotEmpty ? _fromController.text : null, // preselect if any
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.from, prefixIcon: Icons.business),
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
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseSelectOrigin;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
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
                      controller.text = _toController.text;

                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: _buildInputDecoration(
                          AppLocalizations.of(context)!.to,
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
                  TextFormField(
                    controller: _receiverNameController,
                    maxLength: 100,
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.receiverName, prefixIcon: Icons.person),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterReceiverName;
                      if (value.length > 100) return AppLocalizations.of(context)!.receiverNameMaxLength;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _receiverPhoneNumberController,
                    maxLength: 15,
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.receiverPhoneNumber, prefixIcon: Icons.phone),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterReceiverPhone;
                      if (value.length > 15) return AppLocalizations.of(context)!.receiverPhoneMaxLength;
                      return null;
                    },
                  ),
  
                  if (!_isParcel) ...[
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.consignmentItems,
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
                        label: Text(AppLocalizations.of(context)!.addItems),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _packageValueController,
                    maxLength: 8,
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.packageValue, prefixText: 'TSH '),
                    style: const TextStyle(fontSize: 16),
                    validator: _isParcel ? (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterPackageValue;
                      if (value.length > 8) return AppLocalizations.of(context)!.packageValueMaxLength;
                      return null;
                    } : (value) {
                      if (value == null || value.isEmpty) {
                        _packageValueController.text = '0';
                        return null;
                      };
                      if (value.length > 8) return AppLocalizations.of(context)!.packageValueMaxLength;
                      return null;
                    },
                  ),
                   const SizedBox(height: 16),
                  TextFormField(
                    controller: _paidAmountController,
                    maxLength: 8,
                    enabled: _isParcel,
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.paidAmount, prefixText: 'TSH '),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16),
                    validator: _isParcel ? (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterPaidAmount;
                      if (value.length > 8) return AppLocalizations.of(context)!.paidAmountMaxLength;
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
                              _isParcel ? AppLocalizations.of(context)!.addParcel : AppLocalizations.of(context)!.addConsignment,
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
    debugPrint("Refreshing printers...");
    devices = await PrintBluetoothThermal.pairedBluetooths;

    debugPrint("Refreshing printers...");

    if (devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noPairedPrinterFound)),  
      );
      return;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text( AppLocalizations.of(context)!.foundPairedPrinters(devices.length.toString()))),
      );
    }

    await _selectPrinterDialog();
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
        SnackBar(content: Text(AppLocalizations.of(context)!.printerNotConnected)),
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
        SnackBar(content: Text(AppLocalizations.of(context)!.printerNotConnected)),
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
      "Package No: $packageId",
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
      "cid": packageId,
      "oid": consignment['office_id'],
    }));

    bytes += generator.qrcode(
      data,
      size: QRSize.size5,
    );

    bytes += generator.text(
      receiptFooter,
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
    bytes += generator.text(
      'Phone: +255 651 138 380',
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
        SnackBar(content: Text(AppLocalizations.of(context)!.printerNotConnected)),
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
      "PKG No: $packageId",
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
      "cid": packageId,
      "oid": consignment['office_id'],
    }));

    bytes += generator.qrcode(
      data,
      size: QRSize.size7,
    );

    bytes += generator.text(
      receiptFooter,
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
    bytes += generator.text(
      'Phone: +255 651 138 380',
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
                    "Phone: +255 651 138 380",
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

  Future<void> loadAndMatchPrinter() async {
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
        SnackBar(content: Text(AppLocalizations.of(context)!.noPrintersFound)),
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
}