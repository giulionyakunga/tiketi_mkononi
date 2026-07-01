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
import 'package:permission_handler/permission_handler.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/Order.dart';
import 'package:tiketi_mkononi/models/product.dart';
import 'package:tiketi_mkononi/models/shop.dart';
import 'package:tiketi_mkononi/screens/orders_page.dart';
import 'package:tiketi_mkononi/screens/platform_detector_stub.dart';
import 'package:tiketi_mkononi/screens/qr_scanner_cargo_page.dart';
import 'package:tiketi_mkononi/services/SimpleCodec.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class AddOrderPage extends StatefulWidget {
  final int userId;
  final int shopId;
  final String shopName;
  final String userName;
  final String userPhoneNumber;
  final bool isReplacableScreen;

  const AddOrderPage({super.key, required this.userId, required this.shopId, required this.shopName, required this.userName, required this.userPhoneNumber, required this.isReplacableScreen});

  @override
  State<AddOrderPage> createState() => _AddOrderPageState();
}

class _AddOrderPageState extends State<AddOrderPage> {
  int userId = 0;
  String role = "";
  String officeName = '';
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneNumberController = TextEditingController();
  final _productNameController = TextEditingController();
  bool _isLoading = false;
  bool _isPaid = true;
  late final StorageService _storageService;
  Shop? shop;

  List<BluetoothInfo> devices = [];
  BluetoothInfo? selectedPrinter;

  Printer? selectedCablePrinter;
  int _selectedNumberofReceiptsToPrint = 1;

  String receiptFooter = "Karibu Sana";

  List<OrderItem> _orderItems = [];
  late Order _addedOrder;
  List<Product> productsList = [];
  int totalQuantity = 0;
  double totalPrice = 0;
  
  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = ['MIXX BY YAS', 'M-PESA', 'AIRTEL MONEY', 'HALOPESA', 'AZAMPESA'];

  int receiptsBalance = 0;
  List<dynamic> receiptPackages = [];

  int _orderItemsVersion = 0;
  List<TextEditingController> _priceControllers = [];

  @override
  void initState() {
    super.initState();
    getShopProducts();
    _fetchShop();
    _initializeServices();
    _addOrderItem();
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
          SnackBar(content: Text("Sorry! You can't add an order")),
        );
      }

      getUserRole();
    }
  }
  
  Future<void> getShopProducts({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/shop_products/${widget.shopId}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}shop_products/${widget.shopId}'); // Use IP

      debugPrint('Fetching shop products from: ${uri.toString()}');
        
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        debugPrint("response.body : ${response.body}");

        final List<dynamic> jsonList = jsonDecode(response.body);
        final newItems = jsonList.map((json) => Product.fromJson(json)).toList();

        if(newItems.length > 0) {
          setState(() {
            productsList = newItems;
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
          await getShopProducts(useDNS: false); // Recursive retry

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

  Future<void> _fetchShop({bool useDNS = true}) async {
    try {

      final uri = useDNS ? Uri.parse('${backend_url}api/shop/${widget.shopId}')
      : Uri.parse('${backend_url_with_fallback_ip}shop/${widget.shopId}');

      final response = await http.get(uri);
      debugPrint("response.body : ${response.body}");

      if (response.statusCode == 200) {

        final dynamic responseData = jsonDecode(response.body);


        if (responseData is List && responseData.isNotEmpty) {
          // The first item in the list is the shop data
          setState(() {
            shop = Shop.fromJson(responseData[0] as Map<String, dynamic>);
          });
        } else {
          // Handle error
          throw Exception('Invalid response format');
        }
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchShop(useDNS: false);
        return;
      } 
    } catch (e) {
      debugPrint('An error occurred: ${e.toString()}');
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
              SnackBar(content: Text("Sorry, You can't add an order")),
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


  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  void _addOrderItem() {
    setState(() {
      _orderItems.add(OrderItem(
        id: 0,
        name: '',
        price: 0,
        quantity: 1, 
        createdAt: DateTime.now(), 
        updatedAt: DateTime.now(),
      ));

      _orderItemsVersion++; // Increment version
      _priceControllers.add(TextEditingController(text: '0'));

      totalQuantity = _orderItems.fold(
        0,
        (sum, item) => sum + item.quantity,
      );

      totalPrice = _orderItems.fold(
        0,
        (sum, item) => sum + (item.price * item.quantity),
      );
    });
  }

  void _removeOrderItem(int index) {
    setState(() {
      _orderItems.removeAt(index);
      _priceControllers.removeAt(index);
      _orderItemsVersion++; // Increment version
    });
  }

  bool _validateOrderItems() {
    if (_orderItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.pleaseAddAtLeastOneItem)),
      );
      return false;
    }

    int totalNumberOfOrderItems = 0;
    for (var i = 0; i < _orderItems.length; i++) {
      final orderItem = _orderItems[i];

      if (orderItem.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseEnterItemName)), 
        );
        return false;
      }
      
      if (orderItem.price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.itemPriceGreaterThanZero)),
        );
        return false;
      }

      if (orderItem.quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.itemQuantityGreaterThanZero)),
        );
        return false;
      }

      totalNumberOfOrderItems = totalNumberOfOrderItems +  orderItem.quantity;

      if (orderItem.name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.itemNamesCannotBeEmpty)),
        );
        return false;
      }

      if (orderItem.name.length > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item names must be 100 characters or less')),
        );
        return false;
      }

      for (var j = i + 1; j < _orderItems.length; j++) {
        if (orderItem.name.trim() == _orderItems[j].name.trim()) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.itemNamesShouldBeDifferent)),
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
  
  Future<void> _placeOrder({bool useDNS = true}) async {
    _printCableFile();
    
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    if (!_validateOrderItems()) {
      return;
    }

    double totalPrice = 0.0;
    for (var item in _orderItems) {
      totalPrice += (item.price * item.quantity);
    }

    String dateStr = DateFormat('d-M-yyyy').format(DateTime.now());
    DateTime _orderDate = DateFormat('d-M-yyyy').parse(dateStr);

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'shop_id': widget.shopId,
      'customer_name': _customerNameController.text.trim(),
      'customer_phone_number': _customerPhoneNumberController.text.trim(),
      'date': DateFormat('d-M-yyyy').format(_orderDate),
      'payment_status': _isPaid ? true : false,
      'order_items': _orderItems.map((order_item) => {
        'name': order_item.name.trim(),
        'price': order_item.price,
        'quantity': order_item.quantity,
      }).toList(),
      'total_price': totalPrice,
      'issued_by': widget.userName,
      'issuer_phone_number': widget.userPhoneNumber,
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/place_order') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}place_order'); // Use IP

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String message = responseData['message'];
        
        if (message.trim() == "Order added successfully!")  {
          receiptsBalance = responseData['number_of_sms'];
          _saveReceiptsBalance(responseData['number_of_sms']);

          debugPrint('message : $message');

          debugPrint('responseData : $responseData');
          debugPrint('responseData2 : $responseData');

          _customerNameController.clear();
          _customerPhoneNumberController.clear();
          _productNameController.clear();
          _orderItems.clear();
          _addOrderItem();

          dynamic jsonData = jsonDecode(response.body);
          final newOrder = Order.fromJson(jsonData);

          setState(() {
            _addedOrder = newOrder;
            receiptFooter = responseData['receipt_footer'];
          });

          if (Platform.isWindows) {
            _printCableReceipt(_addedOrder);
          } else {
            _printBluetoothReceipt(_addedOrder);
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
          await _placeOrder(useDNS: false); // Recursive retry

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
                        onPressed: () async {
                          if(selectedReceiptPackages != null && selectedReceiptPackages! > 0) {
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

      debugPrint('Selected payment method 2: $selectedPaymentMethod2');

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
    _customerNameController.dispose();
    _customerPhoneNumberController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  Widget _buildOrderItemField(int index, bool isLargeScreen) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            isLargeScreen 
                ? _buildDesktopOrderItemFields(index)
                : _buildMobileOrderItemFields(index),
            const SizedBox(height: 8),
            _buildOrderItemActions(index),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopOrderItemFields(int index) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildOrderItemNameInputField(index),
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

  Widget _buildMobileOrderItemFields(int index) {
    return Column(
      children: [
        _buildOrderItemNameInputField(index),
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

  Widget _buildOrderItemNameInputField(int index) {
    return Autocomplete<Product>(
      displayStringForOption: (Product option) => '${option.brand} ${option.name}',

      initialValue: TextEditingValue(
        text: _orderItems[index].name,
      ),

      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return productsList;
        }
        
        return productsList.where((product) =>
            (product.brand+ ' ' + product.name).toLowerCase().contains(textEditingValue.text.toLowerCase()));

      },

      onSelected: (Product selection) {
        debugPrint('Selected product name: ${selection.name}, price: ${selection.price}');
        setState(() {
          _orderItems[index].name = selection.name;
          _orderItems[index].price = selection.price;
          _priceControllers[index].text = selection.price.toStringAsFixed(0);

          totalPrice = _orderItems.fold(
            0,
            (sum, item) => sum + (item.price * item.quantity),
          );
        });
      },

      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: _buildInputDecoration(
            AppLocalizations.of(context)!.productName,
            prefixIcon: Icons.inventory,
          ),
          onChanged: (value) {
            debugPrint('Edited product name: $value');
            final product = productsList.firstWhere(
              (p) => p.name.toLowerCase() == value.toLowerCase(),
              orElse: () => Product(
                id: 0,
                shopId: 0,
                name: value.toUpperCase(),
                brand: '',
                unit: '', 
                price: _orderItems[index].price,
                quantity: _orderItems[index].quantity,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );

            setState(() {
              _orderItems[index].name = product.name;
              _orderItems[index].price = product.price;
              _orderItems[index].quantity = product.quantity;

              totalPrice = _orderItems.fold(
                0,
                (sum, item) => sum + (item.price * item.quantity),
              );
            });
          },
          
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.pleaseEnterProductName;
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
              height: 300,
              width: MediaQuery.of(context).size.width * 0.9,
              child: ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);

                  return ListTile(
                    dense: true,
                    title: Text('${option.brand} ${option.name} ${option.unit} - TSH ${NumberFormat('#,##0').format(option.price)}'),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  double getTotalValue() {
    double totalValue = 0;

    for (int index = 0; index < _orderItems.length; index++) {
      totalValue += _orderItems[index].price * _orderItems[index].quantity;
    }

    return totalValue;
  }

  Widget _buildPriceField(int index) {
    return TextFormField(
      key: ValueKey('price_${_orderItemsVersion}_$index'), // Unique key
      controller: _priceControllers[index],
      decoration: _buildInputDecoration(
        AppLocalizations.of(context)!.price,
        prefixText: 'TSH ',
      ),
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14),
      onChanged: (value) {
        _orderItems[index].price = double.tryParse(value) ?? 0;
      },
    );
  }

  Widget _buildQuantityField(int index) {
    final item = _orderItems[index];
    
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).primaryColor,
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minus button with Material ripple
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
            child: InkWell(
              onTap: () {
                if (item.quantity > 1) {
                  setState(() {
                    item.quantity--;

                    totalQuantity = _orderItems.fold(
                      0,
                      (sum, item) => sum + item.quantity,
                    );

                    totalPrice = _orderItems.fold(
                      0,
                      (sum, item) => sum + (item.price * item.quantity),
                    );
                  });
                }
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Icon(
                  Icons.remove,
                  size: 20,
                  color: item.quantity > 1 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey,
                ),
              ),
            ),
          ),
          
          // Quantity display
          Container(
            width: 40,
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              ),
            ),
            child: Text(
              item.quantity.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          // Plus button with Material ripple
          Material(
            color: Colors.transparent,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            child: InkWell(
              onTap: () {
                setState(() {
                  item.quantity++;

                  totalQuantity = _orderItems.fold(
                    0,
                    (sum, item) => sum + item.quantity,
                  );

                  totalPrice = _orderItems.fold(
                    0,
                    (sum, item) => sum + (item.price * item.quantity),
                  );
                });
              },
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Icon(
                  Icons.add,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemActions(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_orderItems.length > 1)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeOrderItem(index),
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
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.placeOrder,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              shop != null ? '${widget.shopName} - ${shop!.location}' : widget.shopName,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),

        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              if(widget.isReplacableScreen) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrdersPage(userId: userId, shopId: widget.shopId, shopName: widget.shopName, userName: widget.userName, userPhoneNumber: widget.userPhoneNumber, role: role),
                  ),
                ); 
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrdersPage(userId: userId, shopId: widget.shopId, shopName: widget.shopName, userName: widget.userName, userPhoneNumber: widget.userPhoneNumber, role: role),
                  ),
                );
              }
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart),

                if (_orderItems.isNotEmpty) 
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      '$totalQuantity',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // IconButton(
          //   icon: const Icon(Icons.qr_code_scanner),
          //   onPressed: () {
          //     // (kIsWeb) ? 
          //     //   _handleQRCodeScannerUnavailablility()
          //     // :
          //     // Navigator.push(
          //     //   context,
          //     //   MaterialPageRoute(
          //     //     builder: (context) => QRScannerCargoPage(userId: widget.userId, companyId: widget.companyId, shopName: widget.shopName, officeId: widget.officeId, userName: widget.userName, userPhoneNumber: widget.userPhoneNumber),
          //     //   ),
          //     // );
          //   },
          // ),
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
                if (_addedOrder != null) {
                  _printBluetoothReceipt(_addedOrder);
                }
              } else if (value == 'refresh_printers') {
                if (Platform.isWindows) {
                  _refreshCablePrinters();
                } else {
                  _printBluetoothTestReceipt();
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
                text: widget.shopName,
                value: '--',
              ),
              _buildMenuItem(
                icon: Icons.print,
                text: AppLocalizations.of(context)!.reprintReceipt,
                value: 'reprint_receipt',
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
                text: AppLocalizations.of(context)!.receiptsBalance(receiptsBalance.toString()),
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
                          AppLocalizations.of(context)!.placeOrder,
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
                        controller: _customerNameController,
                        maxLength: 100,
                        decoration: _buildInputDecoration( AppLocalizations.of(context)!.customerName, prefixIcon: Icons.person),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.isEmpty) return  AppLocalizations.of(context)!.pleaseEnterCustomerName;
                          if (value.length > 100) return 'Sender name must be 100 characters or less';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customerPhoneNumberController,
                        maxLength: 15,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration( AppLocalizations.of(context)!.customerPhoneNumber, prefixIcon: Icons.phone),
                        style: const TextStyle(fontSize: 16),
                        validator: (value) {
                          if (value == null || value.isEmpty) return  AppLocalizations.of(context)!.pleaseEnterCustomerPhone;
                          if (value.length > 15) return 'Sender phone number must be 15 characters or less';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                          Text(
                              AppLocalizations.of(context)!.orderItems,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                      "TZS${NumberFormat('#,##0.00').format(totalPrice)}",
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
                      ..._orderItems.asMap().entries.map((entry) {
                        return _buildOrderItemField(entry.key, isLargeScreen);
                      }),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton.icon(
                          onPressed: _addOrderItem,
                          icon: const Icon(Icons.add),
                          label: Text(AppLocalizations.of(context)!.addItems),
                        ),
                      ),
                      const SizedBox(height: 24),


                      SizedBox(
                        width: isLargeScreen ? 400 : double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _placeOrder,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.teal[800],
                          ),
                          child: _isLoading 
                              ? const CircularProgressIndicator()
                              : 
                              Text(
                                AppLocalizations.of(context)!.placeOrder,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),

                              // Column(
                              //   children: [
                              //     Text(
                              //       AppLocalizations.of(context)!.placeOrder,
                              //       style: TextStyle(
                              //         fontSize: 16,
                              //         color: Colors.white,
                              //       ),
                              //     ),

                              //     Text(
                              //       "TZS${NumberFormat('#,##0.00').format(totalPrice)}",
                              //       style: TextStyle(
                              //           fontSize: 9,
                              //           fontWeight: FontWeight.w500,
                              //           color: Colors.teal.shade800,
                              //       ),
                              //     ),
                              //   ]
                              // )
                              
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
                  _buildPaymentStatusToggle(),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _customerNameController,
                    maxLength: 100,
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.customerName, prefixIcon: Icons.person),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterCustomerName;
                      if (value.length > 100) return AppLocalizations.of(context)!.customerNameMaxLength;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _customerPhoneNumberController,
                    maxLength: 15,
                    keyboardType: TextInputType.number,
                    decoration: _buildInputDecoration(AppLocalizations.of(context)!.customerPhoneNumber, prefixIcon: Icons.phone),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return AppLocalizations.of(context)!.pleaseEnterCustomerPhone;
                      if (value.length > 15) return AppLocalizations.of(context)!.senderPhoneMaxLength;
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                      Text(
                          AppLocalizations.of(context)!.orderItems,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                                  "TZS${NumberFormat('#,##0.00').format(totalPrice)}",
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
                  ..._orderItems.asMap().entries.map((entry) {
                    return _buildOrderItemField(entry.key, isLargeScreen);
                  }),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: _addOrderItem,
                      icon: const Icon(Icons.add),
                      label: Text(AppLocalizations.of(context)!.addItems),
                    ),
                  ),                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: isLargeScreen ? 400 : double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _placeOrder,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.teal[800],
                      ),
                      child: _isLoading ? const CircularProgressIndicator()
                      : 
                      Text(
                        AppLocalizations.of(context)!.placeOrder,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),

                        // Column(
                        //   children: [
                        //     Text(
                        //       AppLocalizations.of(context)!.placeOrder,
                        //       style: TextStyle(
                        //         fontSize: 16,
                        //         color: Colors.white,
                        //       ),
                        //     ),

                        //     Text(
                        //       "TZS${NumberFormat('#,##0.00').format(totalPrice)}",
                        //       style: TextStyle(
                        //           fontSize: 9,
                        //           fontWeight: FontWeight.w500,
                        //           color: Colors.teal.shade800,
                        //       ),
                        //     ),
                        //   ]
                        // ),
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
    debugPrint("Printing via Bluetooth...");

    selectedPrinter = null;
    await clearSelectedPrinter();

    await _refreshBluetoothPrinters();
    if (selectedPrinter == null) return;

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

    DateTime orderDate = order.createdAt;
    String formattedDateTime = DateFormat('d/M/H H:m').format(orderDate);

    List<int> bytes = [];

    bytes += generator.text(widget.shopName.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size1,
      )
    );

    bytes += generator.text(
      "ORDER RECEIPT",
      styles: const PosStyles(align: PosAlign.center),
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
      PosColumn(text: order.customerName, width: 6),
    ]);
    
    double totalPrice = double.tryParse(
      order.totalPrice.toString()
    ) ?? 0;

    bytes += generator.row([
      PosColumn(text: "Total Price", width: 6),
      PosColumn(text: 'TZS ${NumberFormat('#,##0').format(totalPrice)}', width: 6),
    ]);

    bytes += generator.row([
      PosColumn(text: "Payment Status", width: 6),
      PosColumn(text: order.paymentStatus ? "Paid" : "Not Paid", width: 6),
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

    int totalAmount = 0;
    // Items
    if(items.length > 0) {
      for (var item in items) {
        totalAmount += (item.price as num).toInt() * (item.quantity as num).toInt();
        bytes += generator.row([
          PosColumn(
              text: "${item.name} x${item.quantity}", width: 8),
          PosColumn(
              text: "TZS ${NumberFormat('#,##0').format(((item.price)))}", width: 4, styles: const PosStyles(align: PosAlign.right)),
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

    final fontData = await rootBundle.load('assets/fonts/poppins/Poppins-Regular.ttf');
    final customFont = pw.Font.ttf(fontData);

    const pageWidth = 226.0;

    final items = order.orderItems;

    DateTime orderDate = order.createdAt;
    String formattedDateTime = DateFormat('d/M/H H:m').format(orderDate);

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
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.Center(
                  child: pw.Text(
                    "ORDER RECEIPT",
                    style: pw.TextStyle(
                      font: customFont,
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                pw.SizedBox(height: 6),

                /// PACKAGE INFO
                pw.Text(
                  "Order No: ${order.id}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Total Price: ${order.totalPrice}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Payment Status: ${order.paymentStatus ? "Paid" : "Not Paid"}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.SizedBox(height: 6),

                pw.Text(
                  "--------------------------------",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.SizedBox(height: 6),

                /// SENDER
                pw.Text(
                  "Customer Details",
                  style: pw.TextStyle(
                    font: customFont,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),

                pw.Text(
                  "Name: ${order.customerName}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Phone: ${order.customerPhoneNumber}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.SizedBox(height: 6),

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
                      "${i + 1}. ${items[i].name} (x${items[i].quantity})  "
                      "TZS ${NumberFormat('#,##0').format(((items[i].price) * items[i].quantity).toInt())}",
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
                  "Name: ${order.issuedBy}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Phone: ${order.issuerPhoneNumber}",
                  style: pw.TextStyle(font: customFont),
                ),

                pw.Text(
                  "Date: ${formattedDateTime}",
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

  Future<void> _printCableFile() async {
    debugPrint("Printing PDF file via cable...");

    try {
      // Load PDF file from assets
      final pdfData = await rootBundle.load(
        'assets/sample_doc.pdf',
      );

      final bytes = pdfData.buffer.asUint8List();

      if (selectedCablePrinter != null) {
        try {
          await Printing.directPrintPdf(
            printer: selectedCablePrinter!,
            onLayout: (PdfPageFormat format) async => bytes,
          );

          debugPrint("Print success");
        } catch (e, s) {
          debugPrint("PRINT ERROR: $e");
          debugPrint("$s");
        }

      } else {
        await _selectCablePrinterDialog();
      }
    } catch (e) {
      debugPrint("Print error: $e");
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

  Future<void> clearSelectedPrinter() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('printer_name');
    await prefs.remove('printer_mac');
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