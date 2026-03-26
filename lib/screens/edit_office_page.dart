import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:tiketi_mkononi/env.dart';

class EditOfficePage extends StatefulWidget {
  final int userId;
  final int companyId;
  final int officeId;
  final String officeName;
  final String officeLocation;

  const EditOfficePage({Key? key, required this.userId, required this.companyId, required this.officeId, required this.officeName, required this.officeLocation}) : super(key: key);

  @override
  _EditOfficePageState createState() => _EditOfficePageState();
}

class _EditOfficePageState extends State<EditOfficePage> {
  final TextEditingController _emailController = TextEditingController();
  Map<String, dynamic>? _userData;
  List<dynamic> officeAttendants = [];
  bool _isLoading = false;
  bool _isLoading2 = false;
  final TextEditingController _officeNameController = TextEditingController();
  final TextEditingController _officeLocationController = TextEditingController();
  bool _isOfficeAttendant = false;
  String _errorMessage = '';
  bool _searchPerformed = false;
  final _formKey = GlobalKey<FormState>();


  @override
  void initState() {
    super.initState();
    _officeNameController.text = widget.officeName;
    _officeLocationController.text = widget.officeLocation;
    getOfficeAttendants();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveOffice({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading2 = true);

    try {
      final uri = useDNS
          ? Uri.parse('${backend_url}api/edit_office/')
          : Uri.parse('${backend_url_with_fallback_ip}edit_office/');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'office_id': widget.officeId,
          'office_name': _officeNameController.text.trim(),
          'office_location': _officeLocationController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessDialog(); 
      } else {
        _showSnackBar('Failed to edit office');
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _saveOffice(useDNS: false);
        return;
      }
      _showSnackBar('Network error. Please check your connection');
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      setState(() => _isLoading2 = false);
    }
  }

  
  Future<void> _deleteOffice({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading2 = true);

    try {
      final uri = useDNS
          ? Uri.parse('${backend_url}api/delete_office/')
          : Uri.parse('${backend_url_with_fallback_ip}delete_office/');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': widget.userId,
          'office_id': widget.officeId,
        }),
      );

      if (response.statusCode == 200) {
        _showSuccessDialog2(); 
      } else {
        _showSnackBar('Failed to delete office');
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _saveOffice(useDNS: false);
        return;
      }
      _showSnackBar('Network error. Please check your connection');
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
            Text('Office Edited'),
          ],
        ),
        content: const Text('Your office has been edited successfully.'),
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

  void _showSuccessDialog2() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Office Deleted'),
          ],
        ),
        content: const Text('Your office has been deleted successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pop(context, true);
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


  Future<void> getOfficeAttendants({bool useDNS = true}) async {
    try {

      final Uri uri = useDNS ?   Uri.parse('${backend_url}api/office_attendants/${widget.officeId}') 
      : Uri.parse('${backend_url_with_fallback_ip}office_attendants/${widget.officeId}'); // Use IP

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint("Response : ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);

        setState(() {
          officeAttendants = jsonList;
        });
      } else {
        setState(() {
          officeAttendants = [];
        });
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
          await getOfficeAttendants(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to server';
        officeAttendants = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _searchUser({bool useDNS = true}) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an email address';
        _searchPerformed = true;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _searchPerformed = true;
    });

    final Uri uri = useDNS ?   Uri.parse('${backend_url}api/find_office_attendant_by_email/$email/${widget.officeId}') 
    : Uri.parse('${backend_url_with_fallback_ip}find_office_attendant_by_email/$email/${widget.officeId}'); // Use IP

    try {
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        debugPrint("Response 2 : ${response.body}");

        final data = json.decode(response.body);
        setState(() {
          _userData = data;
          _isOfficeAttendant = data['is_office_attendant'] ?? false;
        });
      } else {
        setState(() {
          _errorMessage = 'User not found';
          _userData = null;
        });
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
          await _searchUser(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to server';
        _userData = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleOfficeAttendantStatus(bool value, int officeAttendantId, {bool useDNS = true}) async {
    if (_userData == null) return;

    if(widget.userId == _userData!['id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are default attendant for this office'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/set_office_attendant/${widget.officeId}/${widget.companyId}/${widget.userId}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}set_office_attendant/${widget.officeId}/${widget.companyId}/${widget.userId}'); // Use IP

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'set_office_attendant': value, 'office_attendant_id': officeAttendantId }),
      );

      if (response.statusCode == 200) {
        if(response.body == "Office attendant added successfully!") {
          setState(() {
            _isOfficeAttendant = value;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_userData!['first_name']} is now an attendant for this office'),
              backgroundColor: Colors.green,
            ),
          );
        } else if(response.body == "Office attendant removed successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_userData!['first_name']} is no longer an attendant for this office'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.body),
              backgroundColor: Colors.black,
            ),
          );
        }        
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        throw Exception('Failed to update office attendant status');
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
          await _toggleOfficeAttendantStatus(value, officeAttendantId, useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update scanner status'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
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

    void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete'),
        content: const Text('Are you sure you want to delete this office?'),
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
              _deleteOffice();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Office'),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.delete,
              color: Colors.red,
            ),
            onPressed: () {
                _showDeleteConfirmation(context);
              }
      
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            /// ================== EDIT OFFICE ==================
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Edit Office Info',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Change office information.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  TextFormField(
                    controller: _officeNameController,
                    decoration: _buildInputDecoration(
                      'Office Name',
                      prefixIcon: Icons.apartment,
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Office name is required'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _officeLocationController,
                    decoration: _buildInputDecoration(
                      'Office Location',
                      prefixIcon: Icons.location_on,
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
                      onPressed: _isLoading2 ? null : _saveOffice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading2
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save Office',
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

            const SizedBox(height: 32),

            /// ================== SEARCH USER ==================
            Text(
              'Assign Office Attendant',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for a user by email to assign them as attendants for this office.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.blueGrey[600],
                  ),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _emailController,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: 'User Email',
                hintText: 'Enter user email address',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isLoading ? null : _searchUser,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Search User'),
            ),

            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 24),

            if (_searchPerformed &&
                _userData == null &&
                !_isLoading &&
                _errorMessage.isEmpty)
              const Center(child: Text('No user found')),

            if (_userData != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue[100],
                            child: Text(
                              _userData!['first_name'][0] +
                                  _userData!['last_name'][0],
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_userData!['first_name']} ${_userData!['last_name']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                _userData!['email'],
                                style:
                                    TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Phone: ${_userData!['phone_number'] ?? 'Not provided'}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Office Attendant Status:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _isOfficeAttendant,
                            onChanged: _isLoading
                                ? null
                                : (value) => _toggleOfficeAttendantStatus(
                                    value, _userData!['id']),
                            activeColor: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              Text(
                _isOfficeAttendant
                    ? 'This user can attend your office'
                    : 'This user cannot attend your office',
                style: TextStyle(
                  color: _isOfficeAttendant
                      ? Colors.green
                      : Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 32),

            /// ================== CURRENT ATTENDANTS ==================
            Text(
              'Current Office Attendants',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey[800],
                  ),
            ),

            const SizedBox(height: 16),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: officeAttendants.length,
              itemBuilder: (context, index) {
                final officeAttendant = officeAttendants[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue[100],
                                child: Text(
                                  officeAttendant['first_name'][0] +
                                      officeAttendant['last_name'][0],
                                  style: const TextStyle(
                                      color: Colors.blue),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${officeAttendant['first_name']} ${officeAttendant['last_name']}',
                                    style: const TextStyle(
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  Text(
                                    officeAttendant['email'],
                                    style: TextStyle(
                                        color:
                                            Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Text(
                            'Phone: ${officeAttendant['phone_number']}',
                            style:
                                TextStyle(color: Colors.grey[600]),
                          ),

                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Office Attendant Status:',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.bold),
                              ),
                              Switch(
                                value: (officeAttendant['office_id'] ==
                                    widget.officeId),
                                onChanged: _isLoading
                                    ? null
                                    : (value) =>
                                        _toggleOfficeAttendantStatus(
                                            value,
                                            officeAttendant[
                                                'id']),
                                activeColor: Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}