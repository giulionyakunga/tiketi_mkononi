import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';

class EditCompanyPage extends StatefulWidget {
  final int userId;
  final int companyId;
  final String companyName;

  const EditCompanyPage({Key? key, required this.userId, required this.companyId, required this.companyName}) : super(key: key);

  @override
  _EditCompanyPageState createState() => _EditCompanyPageState();
}

class _EditCompanyPageState extends State<EditCompanyPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading2 = false;
  final TextEditingController _companyNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _companyNameController.text = widget.companyName;
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveCompany({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading2 = true);

    try {
      final uri = useDNS
          ? Uri.parse('${backend_url}api/edit_company/')
          : Uri.parse('${backend_url_with_fallback_ip}edit_company/');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'company_id': widget.companyId,
          'company_name': _companyNameController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        var profile = _storageService.getUserProfile();
        profile!.companyName = _companyNameController.text.trim();
        await _storageService.saveUserProfile(profile);

        _showSuccessDialog(); 
      }  else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Failed to edit company');
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _saveCompany(useDNS: false);
        return;
      }
      _handleSocketException(e);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() => _isLoading2 = false);
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
            Text('Company Edited'),
          ],
        ),
        content: const Text('Your company has been edited successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigator.pop(context, true);
            },
            child: const Text('OK'),
          )
        ],
      ),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Company'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            /// ================== EDIT COMPANY ==================
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Company Info',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Change company information.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _companyNameController,
                    decoration: _buildInputDecoration(
                      'Company Name',
                      prefixIcon: Icons.apartment,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Company name is required'
                        : null,
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading2 ? null : _saveCompany,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading2
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),           

            const SizedBox(height: 16),
           
          ],
        ),
      ),
    );
  }
}