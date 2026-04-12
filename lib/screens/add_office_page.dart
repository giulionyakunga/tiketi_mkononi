import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/l10n/app_localizations.dart';

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
  List<String> regions = [];

  @override
  void initState() {
    super.initState();
    getRegions();
  }

  Future<void> getRegions({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/tanzania_regions') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}tanzania_regions'); // Use IP

    debugPrint('Fetching regions from: ${uri.toString()}');
        
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {

        debugPrint("tanzania_regions : ${response.body}");

        final responseData = jsonDecode(response.body); // This is a List<dynamic>
        
        List<String> regionsList = [];

        // Loop through each office
        for (var office in responseData) {
          // Add name to regionsList
          regionsList.add(office['name']);
        }

        if(regionsList.isNotEmpty) {
          setState(() {
            regions = regionsList;
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
          await getRegions(useDNS: false); // Recursive retry

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

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.addOffice),
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
                      Text(
                        AppLocalizations.of(context)!.officeInformation,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.addANewOfficeLocation,
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _officeNameController,
                        decoration: _buildInputDecoration(AppLocalizations.of(context)!.officeName, prefixIcon: Icons.apartment),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Office name is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Autocomplete<String>(
                        initialValue: TextEditingValue(text: _officeLocationController.text),

                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return regions;
                          }
                          return regions.where((office) =>
                              office.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                        },

                        onSelected: (String selection) {
                          _officeLocationController.text = selection;
                          if(_officeLocationController.text.isEmpty) {
                            _officeLocationController.text = selection;
                          }
                        },

                        fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                          controller.text = _officeLocationController.text;

                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: _buildInputDecoration(
                              AppLocalizations.of(context)!.officeLocation,
                              prefixIcon: Icons.business,
                            ),
                            onChanged: (value) {
                              _officeLocationController.text = value;
                              if(_officeLocationController.text.isEmpty) {
                                _officeLocationController.text = value;
                              }
                            },
                            validator: (value) => value == null || value.trim().isEmpty
                            ? AppLocalizations.of(context)!.pleaseEnterOfficeLocation
                            : null,
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
                              : Text(
                                  AppLocalizations.of(context)!.addOffice,
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