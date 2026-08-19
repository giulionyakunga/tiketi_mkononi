import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tiketi_mkononi/models/shop.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';

class AddProductsPage extends StatefulWidget {
  final Shop shop;
  final int userId;

  const AddProductsPage({
    super.key,
    required this.shop,
    required this.userId,
  });

  @override
  State<AddProductsPage> createState() => _AddProductsPageState();
}

class _AddProductsPageState extends State<AddProductsPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _unitController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();

  bool _isLoading = false;
  bool useDNS = true;
  late TabController _tabController;

  // Excel file upload variables
  String? fileType;
  String? fileName;
  String base64File = "";

  // Single product variables
  String? _productName;
  String? _brand;
  String? _unit;
  double? _price;
  int? _quantity;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _brandController.dispose();
    _unitController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      useDNS = prefs.getBool('use_dns') ?? true;
    });
  }

  // Add multiple products via Excel
  Future<void> _uploadExcelProducts({bool useDNS = true}) async {
    if (base64File.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Excel file first')),
      );
      return;
    }

    final Map<String, dynamic> requestBody = {
      'shop_id': widget.shop.id,
      'user_id': widget.userId,
      'file_type': fileType,
      'file_name': fileName,
      'file_content': base64File,
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS
          ? Uri.parse('${backend_url}api/add_shop_products')
          : Uri.parse('${backend_url_with_fallback_ip}add_shop_products');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Shop products were added successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
          Navigator.pop(context);
        } else {
          try {
            final Uint8List bytes = response.bodyBytes;

            // Get temp directory
            final directory = await getTemporaryDirectory();

            final filePath =
                '${directory.path}/updated_file_${DateTime.now().millisecondsSinceEpoch}.xlsx';

            final file = File(filePath);

            await file.writeAsBytes(bytes, flush: true);

            // Open the Excel file
            final result = await OpenFile.open(filePath);

            debugPrint('Open result: ${result.message}');
          } catch (e) {
            debugPrint('Failed to open Excel file: $e');
          }
        }

        // Clear the file selection
        setState(() {
          base64File = "";
          fileName = null;
          fileType = null;
        });
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Failed to upload products: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred: ${e.message}');

      if (e.osError != null) {
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) &&
            useDNS) {
          debugPrint('DNS failed! Retrying with IP...');
          await _uploadExcelProducts(useDNS: false);
          return;
        }
      }
      _handleSocketException(e);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Add single product
  Future<void> _addSingleProduct({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    if (_productName == null || _productName!.isEmpty) {
      _showSnackBar('Please enter product name');
      return;
    }

    if (_price == null || _price! <= 0) {
      _showSnackBar('Please enter a valid price');
      return;
    }

    if (_quantity == null || _quantity! < 0) {
      _showSnackBar('Please enter a valid quantity');
      return;
    }

    final Map<String, dynamic> requestBody = {
      'shop_id': widget.shop.id,
      'user_id': widget.userId,
      'name': _productName,
      'brand': _brand ?? '',
      'unit': _unit ?? '',
      'price': _price,
      'quantity': _quantity,
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS
          ? Uri.parse('${backend_url}api/add_shop_product')
          : Uri.parse('${backend_url_with_fallback_ip}add_shop_product');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );

        // Clear the form
        _formKey.currentState!.reset();
        _nameController.clear();
        _brandController.clear();
        _unitController.clear();
        _priceController.clear();
        _quantityController.clear();
        _productName = null;
        _brand = null;
        _price = null;
        _quantity = null;

        Navigator.pop(context, true); // Return success
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Failed to add product: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred: ${e.message}');

      if (e.osError != null) {
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) &&
            useDNS) {
          debugPrint('DNS failed! Retrying with IP...');
          await _addSingleProduct(useDNS: false);
          return;
        }
      }
      _handleSocketException(e);
    } catch (e) {
      _showSnackBar('Error: $e');
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
    if (e.osError?.errorCode == 7 ||
        e.osError?.errorCode == 101 ||
        e.osError?.errorCode == 111) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: const Text(
              'Could not connect to the server. Please check your internet connection.'),
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
        content: const Text(
            'Could not connect to the server. Please check your internet connection.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label,
      {String? hint, IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: Colors.grey[600])
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.teal[700]!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red[300]!, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      labelStyle: TextStyle(
        color: Colors.grey[700],
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isLargeScreen,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isLargeScreen ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal[700]!,
            Colors.teal[500]!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.teal[200]!.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isLargeScreen ? 90 : 70,
            height: isLargeScreen ? 90 : 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: isLargeScreen ? 48 : 36,
              color: Colors.white,
            ),
          ),
          SizedBox(width: isLargeScreen ? 24 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 28 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: isLargeScreen ? 16 : 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.teal[50]!,
            Colors.teal[100]!.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.teal[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.store, color: Colors.teal[700], size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.shop.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.teal[800],
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        color: Colors.teal[600], size: 14),
                    const SizedBox(width: 4),
                    Text(
                      widget.shop.location,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.teal[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcelTabContent(bool isLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLargeScreen ? 32 : 16),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isLargeScreen ? 800 : double.infinity),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(
                icon: Icons.upload_file_rounded,
                title: 'Bulk Upload Products',
                subtitle: 'Upload an Excel file to add multiple products at once',
                isLargeScreen: isLargeScreen,
              ),
              const SizedBox(height: 24),
              _buildShopInfo(),
              const SizedBox(height: 24),
              // Excel File Picker Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.file_upload_outlined,
                              color: Colors.teal[700], size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Upload Excel File',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey[300]!, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[50],
                        ),
                        child: Column(
                          children: [
                            InkWell(
                              onTap: () async {
                                try {
                                  FilePickerResult? result =
                                      await FilePicker.platform.pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: ['xlsx', 'xls'],
                                  );

                                  if (result != null &&
                                      result.files.isNotEmpty) {
                                    PlatformFile platformFile =
                                        result.files.first;

                                    List<int> bytes;

                                    if (kIsWeb) {
                                      bytes = platformFile.bytes!;
                                    } else {
                                      File file = File(platformFile.path!);
                                      bytes = await file.readAsBytes();
                                    }

                                    final String? mimeType = lookupMimeType(
                                        platformFile.name,
                                        headerBytes: bytes);
                                    final String selectedFileName =
                                        platformFile.name;

                                    final bool isExcel = mimeType ==
                                            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
                                        mimeType ==
                                            'application/vnd.ms-excel' ||
                                        selectedFileName
                                            .toLowerCase()
                                            .endsWith('.xlsx') ||
                                        selectedFileName
                                            .toLowerCase()
                                            .endsWith('.xls');

                                    if (isExcel) {
                                      setState(() {
                                        fileType = lookupMimeType(
                                                platformFile.name) ??
                                            'application/octet-stream';
                                        fileName = platformFile.name;
                                        base64File = base64Encode(bytes);
                                      });

                                      _showSnackBar('File selected: $fileName');
                                    } else {
                                      _showSnackBar(
                                          'Please select a valid Excel file (.xls or .xlsx)');
                                    }
                                  }
                                } catch (e) {
                                  debugPrint('Error picking file: $e');
                                  _showSnackBar('Error selecting file: $e');
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 40, horizontal: 20),
                                child: Column(
                                  children: [
                                    Icon(Icons.insert_drive_file_outlined,
                                        size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 12),
                                    Text(
                                      fileName ?? 'Click to select Excel file',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: fileName != null
                                            ? Colors.teal[700]
                                            : Colors.grey[600],
                                        fontWeight: fileName != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (fileName != null) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.teal[50],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: Colors.teal[200]!),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle,
                                                color: Colors.teal[600],
                                                size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              'File ready',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.teal[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          color: Colors.grey[500], size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Supported formats: .xlsx, .xls',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Excel should have columns: name, brand, price, quantity',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Upload Button
              SizedBox(
                width: isLargeScreen ? 400 : double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _uploadExcelProducts,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.teal[700],
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Upload Products',
                              style: TextStyle(
                                fontSize: isLargeScreen ? 18 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSingleProductTabContent(bool isLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isLargeScreen ? 32 : 16),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isLargeScreen ? 800 : double.infinity),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(
                  icon: Icons.add_business_rounded,
                  title: 'Add Single Product',
                  subtitle: 'Add one product at a time',
                  isLargeScreen: isLargeScreen,
                ),
                const SizedBox(height: 24),
                _buildShopInfo(),
                const SizedBox(height: 24),
                // Form Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
                    child: Column(
                      children: [
                        // Product Name
                        TextFormField(
                          controller: _nameController,
                          decoration: _buildInputDecoration(
                            'Product Name',
                            hint: 'Enter product name',
                            prefixIcon: Icons.inventory_2,
                          ),
                          onSaved: (value) => _productName = value,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter product name';
                            }
                            if (value.length > 100) {
                              return 'Name must be 100 characters or less';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Product Brand
                        TextFormField(
                          controller: _brandController,
                          maxLines: 1,
                          decoration: _buildInputDecoration(
                            'Product Brand',
                            hint: 'Enter product brand (optional)',
                            prefixIcon: Icons.label,
                          ),
                          onSaved: (value) => _brand = value,
                          validator: (value) {
                            if (value != null && value.length > 20) {
                              return 'Product brand must be 20 characters or less';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Product Unit
                        TextFormField(
                          controller: _unitController,
                          maxLines: 1,
                          decoration: _buildInputDecoration(
                            'Unit',
                            hint: 'Enter unit (optional)',
                            prefixIcon: Icons.scale,
                          ),
                          onSaved: (value) => _unit = value,
                          validator: (value) {
                            if (value != null && value.length > 15) {
                              return 'Unit must be 15 characters or less';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Price
                        TextFormField(
                          controller: _priceController,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: _buildInputDecoration(
                            'Price (TZS)',
                            hint: 'Enter product price',
                            prefixIcon: Icons.attach_money,
                          ),
                          onSaved: (value) {
                            if (value != null && value.isNotEmpty) {
                              _price = double.tryParse(value);
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter price';
                            }
                            final price = double.tryParse(value);
                            if (price == null) {
                              return 'Please enter a valid number';
                            }
                            if (price < 0) {
                              return 'Price cannot be negative';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Quantity
                        TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            'Quantity',
                            hint: 'Enter quantity in stock',
                            prefixIcon: Icons.numbers,
                          ),
                          onSaved: (value) {
                            if (value != null && value.isNotEmpty) {
                              _quantity = int.tryParse(value);
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return null;
                            }
                            final quantity = int.tryParse(value);
                            if (quantity == null) {
                              return 'Please enter a valid number';
                            }
                            if (quantity < 0) {
                              return 'Quantity cannot be negative';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Add Product Button
                SizedBox(
                  width: isLargeScreen ? 400 : double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addSingleProduct,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.teal[700],
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: _isLoading
                        ? SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_circle_outline, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                'Add Product',
                                style: TextStyle(
                                  fontSize: isLargeScreen ? 18 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 768;
    final isMediumScreen =
        MediaQuery.of(context).size.width > 480 &&
        MediaQuery.of(context).size.width <= 768;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.shopping_bag_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'Add Products',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            color: Colors.teal[800],
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.teal[200],
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 14,
              ),
              tabs: [
                Tab(
                  icon: Icon(Icons.upload_file, size: 20),
                  text: isMediumScreen ? 'Bulk' : 'Bulk Upload',
                ),
                Tab(
                  icon: Icon(Icons.add_circle, size: 20),
                  text: isMediumScreen ? 'Single' : 'Add Single',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExcelTabContent(isLargeScreen),
          _buildSingleProductTabContent(isLargeScreen),
        ],
      ),
    );
  }
}