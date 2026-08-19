import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/models/product.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  final int userId;

  const EditProductPage({
    super.key,
    required this.product,
    required this.userId,
  });

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _unitController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();

  bool _isLoading = false;
  bool useDNS = true;

  // Edited product data
  String? _editedName;
  String? _editedBrand;
  String? _editedUnit;
  double? _editedPrice;
  int? _editedQuantity;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _populateFields();
  }

  @override
  void dispose() {
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

  void _populateFields() {
    _nameController.text = widget.product.name;
    _brandController.text = widget.product.brand;
    _unitController.text = widget.product.unit;
    _priceController.text = widget.product.price.toString();
    _quantityController.text = widget.product.quantity.toString();

    _editedName = widget.product.name;
    _editedBrand = widget.product.brand;
    _editedUnit = widget.product.unit;
    _editedPrice = widget.product.price;
    _editedQuantity = widget.product.quantity;
  }

  Future<void> _updateProduct({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    if (_editedName == null || _editedName!.isEmpty) {
      _showSnackBar('Please enter product name');
      return;
    }

    if (_editedPrice == null || _editedPrice! <= 0) {
      _showSnackBar('Please enter a valid price');
      return;
    }

    if (_editedQuantity == null || _editedQuantity! < 0) {
      _showSnackBar('Please enter a valid quantity');
      return;
    }

    final Map<String, dynamic> requestBody = {
      'product_id': widget.product.id,
      'shop_id': widget.product.shopId,
      'user_id': widget.userId,
      'name': _editedName,
      'brand': _editedBrand ?? '',
      'unit': _editedUnit ?? '',
      'price': _editedPrice,
      'quantity': _editedQuantity,
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS
          ? Uri.parse('${backend_url}api/update_shop_product')
          : Uri.parse('${backend_url_with_fallback_ip}update_shop_product');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Product updated successfully!');
        Navigator.pop(context, true); // Return success
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Failed to update product: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred: ${e.message}');

      if (e.osError != null) {
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) &&
            useDNS) {
          debugPrint('DNS failed! Retrying with IP...');
          await _updateProduct(useDNS: false);
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

  Future<void> _deleteProduct({bool useDNS = true}) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text(
          'Are you sure you want to delete "${widget.product.name}"? This action cannot be undone.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmDelete != true) return;

    try {
      setState(() => _isLoading = true);

      final Map<String, dynamic> requestBody = {
        'product_id': widget.product.id,
        'user_id': widget.userId,
      };

      final Uri uri = useDNS
          ? Uri.parse('${backend_url}api/delete_shop_product')
          : Uri.parse('${backend_url_with_fallback_ip}delete_shop_product');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        _showSnackBar('Product deleted successfully!');
        Navigator.pop(context, true); // Return success
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Failed to delete product: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred: ${e.message}');

      if (e.osError != null) {
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) &&
            useDNS) {
          debugPrint('DNS failed! Retrying with IP...');
          await _deleteProduct(useDNS: false);
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

  Widget _buildHeader(bool isLargeScreen) {
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
              Icons.edit_note_rounded,
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
                  'Edit Product',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 28 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Update product details',
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

  Widget _buildProductInfoCard(bool isLargeScreen) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
        child: Column(
          children: [
            // Product ID and Date Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoChip(
                        Icons.tag,
                        'Product ID',
                        '#${widget.product.id}',
                        Colors.blue,
                      ),
                      _buildInfoChip(
                        Icons.store,
                        'Shop ID',
                        '#${widget.product.shopId}',
                        Colors.purple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoChip(
                        Icons.calendar_today,
                        'Created',
                        _formatDate(widget.product.createdAt),
                        Colors.green,
                      ),
                      _buildInfoChip(
                        Icons.update,
                        'Updated',
                        _formatDate(widget.product.updatedAt),
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Product Name
            TextFormField(
              controller: _nameController,
              decoration: _buildInputDecoration(
                'Product Name',
                hint: 'Enter product name',
                prefixIcon: Icons.inventory_2,
              ),
              onSaved: (value) => _editedName = value,
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
              onSaved: (value) => _editedBrand = value,
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
              onSaved: (value) => _editedUnit = value,
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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: _buildInputDecoration(
                'Price (TZS)',
                hint: 'Enter product price',
                prefixIcon: Icons.attach_money,
              ),
              onSaved: (value) {
                if (value != null && value.isNotEmpty) {
                  _editedPrice = double.tryParse(value);
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
                  _editedQuantity = int.tryParse(value);
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
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
            Icon(Icons.edit_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'Edit Product',
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
        actions: [
          // Delete Button
          IconButton(
            onPressed: _isLoading ? null : _deleteProduct,
            icon: Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 24,
            ),
            tooltip: 'Delete Product',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isLargeScreen ? 32 : 16),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isLargeScreen ? 800 : double.infinity,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isLargeScreen),
                  const SizedBox(height: 24),
                  _buildProductInfoCard(isLargeScreen),
                  const SizedBox(height: 24),
                  // Action Buttons
                  Row(
                    children: [
                      // Update Button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _updateProduct,
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
                                    Icon(Icons.save_outlined, size: 22),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Update Product',
                                      style: TextStyle(
                                        fontSize: isLargeScreen ? 18 : 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      if (!isMediumScreen && !isLargeScreen) ...[
                        const SizedBox(width: 12),
                        // Delete Button (Mobile)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _deleteProduct,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.red[400]!),
                              foregroundColor: Colors.red[400],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete_outline, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // Cancel Button
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.grey[600],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 16 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}