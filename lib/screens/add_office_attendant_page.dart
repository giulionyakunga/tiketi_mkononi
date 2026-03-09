import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:tiketi_mkononi/env.dart';

class AddOfficeAttendantPage extends StatefulWidget {
  final int userId;
  final int companyId;
  final int officeId;

  const AddOfficeAttendantPage({Key? key, required this.userId, required this.companyId, required this.officeId}) : super(key: key);

  @override
  _AddOfficeAttendantPageState createState() => _AddOfficeAttendantPageState();
}

class _AddOfficeAttendantPageState extends State<AddOfficeAttendantPage> {
  final TextEditingController _emailController = TextEditingController();
  Map<String, dynamic>? _userData;
  List<dynamic> officeAttendants = [];
  bool _isLoading = false;
  bool _isOfficeAttendant = false;
  String _errorMessage = '';
  bool _searchPerformed = false;

  @override
  void initState() {
    super.initState();
    getOfficeAttendants();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
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
        setState(() {
          _isOfficeAttendant = value;
        });

        if(response.body == "Office attendant added successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_userData!['first_name']} is now an attendant for this office'),
              backgroundColor: Colors.green,
            ),
          );
        }else if(response.body == "Office attendant removed successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_userData!['first_name']} is no longer an attendant for this office'),
              backgroundColor: Colors.green,
            ),
          );
        }else if(response.body == "Action not allowed!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Action not allowed!'),
              backgroundColor: Colors.red,
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Office Attendant'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              autofillHints: [AutofillHints.email],
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
            if (_searchPerformed && _userData == null && !_isLoading && _errorMessage.isEmpty)
              const Center(
                child: Text('No user found'),
              ),
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
                              _userData!['first_name'][0] + _userData!['last_name'][0],
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                _userData!['email'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Phone: ${_userData!['phone_number'] ?? 'Not provided'}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
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
                                : (value) => _toggleOfficeAttendantStatus(value, _userData!['id']),
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
                    : 'This user cannot attendant your office',
                style: TextStyle(
                  color: _isOfficeAttendant ? Colors.green : Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            Text(
              'Current Office Attendants',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue[100],
                                  child: Text(
                                    officeAttendant['first_name'][0] +
                                        officeAttendant['last_name'][0],
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${officeAttendant['first_name']} ${officeAttendant['last_name']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      officeAttendant['email'],
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Phone: ${officeAttendant['phone_number']}',
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
                                  value: (officeAttendant['office_id'] == widget.officeId),
                                  onChanged: _isLoading
                                      ? null
                                      : (value) => _toggleOfficeAttendantStatus(value, officeAttendant['id']),
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
            ),
          ],
        ),
      ),
    );
  }
}