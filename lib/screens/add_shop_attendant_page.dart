import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:tiketi_mkononi/env.dart';

class AddShopAttendantPage extends StatefulWidget {
  final int userId;
  final int shopId;

  const AddShopAttendantPage({Key? key, required this.userId, required this.shopId}) : super(key: key);

  @override
  _AddShopAttendantPageState createState() => _AddShopAttendantPageState();
}

class _AddShopAttendantPageState extends State<AddShopAttendantPage> {
  final TextEditingController _emailController = TextEditingController();
  Map<String, dynamic>? _userData;
  List<dynamic> shopAttendants = [];
  bool _isLoading = false;
  bool _isShopAttendant = false;
  String _errorMessage = '';
  bool _searchPerformed = false;

  @override
  void initState() {
    super.initState();
    getShopAttendants();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> getShopAttendants({bool useDNS = true}) async {
    try {

      final Uri uri = useDNS ?   Uri.parse('${backend_url}api/shop_attendants/${widget.shopId}') 
      : Uri.parse('${backend_url_with_fallback_ip}shop_attendants/${widget.shopId}'); // Use IP

      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint("Response : ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);

        setState(() {
          shopAttendants = jsonList;
        });
      } else {
        setState(() {
          shopAttendants = [];
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
          await getShopAttendants(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error connecting to server';
        shopAttendants = [];
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

    final Uri uri = useDNS ?   Uri.parse('${backend_url}api/find_shop_attendant_by_email/$email/${widget.shopId}') 
    : Uri.parse('${backend_url_with_fallback_ip}find_shop_attendant_by_email/$email/${widget.shopId}'); // Use IP

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
          _isShopAttendant = data['is_shop_attendant'] ?? false;
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

  Future<void> _toggleShopAttendantStatus(bool value, {bool useDNS = true}) async {
    if (_userData == null) return;

    if(widget.userId == _userData!['id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are default attendant for this shop'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/set_shop_attendant/${widget.shopId}/${widget.userId}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}set_shop_attendant/${widget.shopId}/${widget.userId}'); // Use IP

    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'set_shop_attendant': value, 'shop_attendant_id': _userData!['id'] }),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isShopAttendant = value;
        });

        if(response.body == "Shop attendant added successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_userData!['first_name']} is now an attendant for this shop'),
              backgroundColor: Colors.green,
            ),
          );
        }else if(response.body == "Shop attendant removed successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_userData!['first_name']} is no longer an attendant for this shop'),
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
        throw Exception('Failed to update shop attendant status');
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
          await _toggleShopAttendantStatus(value, useDNS: false); // Recursive retry

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
        title: const Text('Assign Shop Attendant'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Assign Shop Attendant',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for a user by email to assign them as attendants for this shop.',
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
                            'Shop Attendant Status:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _isShopAttendant,
                            onChanged: _isLoading
                                ? null
                                : (value) => _toggleShopAttendantStatus(value),
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
                _isShopAttendant
                    ? 'This user can attendant your shop'
                    : 'This user cannot attendant your shop',
                style: TextStyle(
                  color: _isShopAttendant ? Colors.green : Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: shopAttendants.length,
                itemBuilder: (context, index) {
                  final shopAttendant = shopAttendants[index];
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
                                    shopAttendant['first_name'][0] +
                                        shopAttendant['last_name'][0],
                                    style: const TextStyle(color: Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${shopAttendant['first_name']} ${shopAttendant['last_name']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      shopAttendant['email'],
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Phone: ${shopAttendant['phone_number']}',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Shop Attendant Status:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Switch(
                                  value: (shopAttendant['shop_id'] == widget.shopId),
                                  onChanged: _isLoading
                                      ? null
                                      : (value) => _toggleShopAttendantStatus(value),
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