import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';

class AddNewRecordPage extends StatefulWidget {
  final int userId;

  const AddNewRecordPage({super.key, required this.userId});

  @override
  State<AddNewRecordPage> createState() => _AddNewRecordPageState();
}

class _AddNewRecordPageState extends State<AddNewRecordPage> {
  final _formKey = GlobalKey<FormState>();

  final itemNameController = TextEditingController();
  final qtyController = TextEditingController();
  final priceController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = ['MIXX BY YAS', 'M-PESA', 'AIRTEL MONEY', 'HALOPESA', 'AZAMPESA'];
  bool _isLoading = false;


  Widget _buildDateTimePickers(bool isLargeScreen) {
    return
    Row(
      children: [
        Expanded(child: _buildDatePicker()),
        const SizedBox(width: 16),
        Expanded(child: _buildTimePicker()),
      ],
    );
  }

  
  Widget _buildDatePicker() {
    return TextButton.icon(
      onPressed: () => _selectDate(context),
      icon: Icon(Icons.calendar_today, color: Colors.orange[800]),
      label: Text(
        _selectedDate == null
            ? 'Select Date'
            : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
        style: TextStyle(
          color: _selectedDate == null ? Colors.grey[600] : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(
          color: _selectedDate == null ? Colors.grey[400]! : Colors.orange[800]!,
          width: 1.5,
        ),
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Widget _buildTimePicker() {
    return TextButton.icon(
      onPressed: () => _selectTime(context),
      icon: Icon(Icons.access_time, color: Colors.orange[800]),
      label: Text(
        _selectedTime == null
            ? 'Select Time'
            : _selectedTime!.format(context),
        style: TextStyle(
          color: _selectedTime == null ? Colors.grey[600] : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        side: BorderSide(
          color: _selectedTime == null ? Colors.grey[400]! : Colors.orange[800]!,
          width: 1.5,
        ),
        backgroundColor: Colors.grey[200],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

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

  
  Future<void> addNewRecord({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final Map<String, dynamic> requestBody = {
      'user_id': widget.userId,
      'item_name': itemNameController.text.trim(),
      'date': _selectedDate?.toIso8601String(),
      'time': '${_selectedTime!.hour}:${_selectedTime!.minute}',
      'quantity': qtyController.text.trim(),
      'unit_price': priceController.text.trim(),
      'payment_method': selectedPaymentMethod,
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/add_new_record') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}add_new_record'); // Use IP

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Account Record added successfully!") {
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
          await addNewRecord(useDNS: false); // Recursive retry

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



  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Record'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildDateTimePickers(isLargeScreen),
                  const SizedBox(height: 8), 
                  _input(itemNameController, 'Item Name'),
                  _input(qtyController, 'Quantity', keyboard: TextInputType.number),
                  _input(priceController, 'Unit Price', keyboard: TextInputType.number),
                  _buildPaymentMethodSelector(isLargeScreen),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Save Record'),
                      onPressed: _isLoading ? null : addNewRecord,
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _input(TextEditingController controller, String label,
      {TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
      ),
    );
  }
}