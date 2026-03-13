import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';

class AddOfficePage extends StatefulWidget {
  final int userId;
  final int companyId;

  const AddOfficePage({super.key, required this.userId, required this.companyId});

  @override
  State<AddOfficePage> createState() => _AddOfficePageState();
}

class _AddOfficePageState extends State<AddOfficePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _officeNameController = TextEditingController();
  final TextEditingController _officeLocationController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submitOffice({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final uri = useDNS
          ? Uri.parse('${backend_url}api/add_office/')
          : Uri.parse('${backend_url_with_fallback_ip}add_office/');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'company_id': widget.companyId,
          'office_name': _officeNameController.text.trim(),
          'office_location': _officeLocationController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessDialog();
      } else {
        _showSnackBar('Failed to add office');
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _submitOffice(useDNS: false);
        return;
      }
      _showSnackBar('Network error. Please check your connection');
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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
            Text('Office Added'),
          ],
        ),
        content: const Text('Your office has been added successfully.'),
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Office'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isLargeScreen ? 600 : double.infinity),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Office Information',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add a new office location for your cargo company.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _officeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Office Name',
                          hintText: 'e.g. Mwanza Main Office',
                          prefixIcon: Icon(Icons.apartment),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Office name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _officeLocationController,
                        decoration: const InputDecoration(
                          labelText: 'Office Location',
                          hintText: 'e.g. Mwanza',
                          prefixIcon: Icon(Icons.apartment),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Office location is required'
                            : null,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitOffice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Add Office',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold
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
        ),
      ),
    );
  }
}