import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:tiketi_mkononi/env.dart';

class SetScannerPage extends StatefulWidget {
  final int userId;
  final int eventId;

  const SetScannerPage({Key? key, required this.userId, required this.eventId}) : super(key: key);

  @override
  _SetScannerPageState createState() => _SetScannerPageState();
}

class _SetScannerPageState extends State<SetScannerPage> {
  final TextEditingController _emailController = TextEditingController();
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  bool _isScanner = false;
  String _errorMessage = '';
  bool _searchPerformed = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _searchUser() async {
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

    try {
      final response = await http.get(
        Uri.parse('${backend_url}api/user_with_scanner_status_by_email/$email/${widget.eventId}'),
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint("Response : ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userData = data;
          _isScanner = data['is_scanner'] ?? false;
        });
      } else {
        setState(() {
          _errorMessage = 'User not found';
          _userData = null;
        });
      }
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

  Future<void> _toggleScannerStatus(bool value) async {
    if (_userData == null) return;

    if(widget.userId == _userData!['id']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are default scanner for this event'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('${backend_url}api/set_event_scanner/${widget.eventId}/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'is_scanner': value, 'ticket_scanner_id': _userData!['id'] }),
      );

      debugPrint("_userData!['id'] : ${_userData!['id']}");
      debugPrint("Response : ${response.body}");

      if (response.statusCode == 200) {
        setState(() {
          _isScanner = value;
        });

        if(response.body == "Event scanner added successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User is now a scanner for this event'),
              backgroundColor: Colors.green,
            ),
          );
        }else if(response.body == "Event scanner removed successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('User is no longer a scanner for this event'),
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
      } else {
        throw Exception('Failed to update scanner status');
      }
    } catch (e) {
      debugPrint("Exception : ${e}");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Scanner'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Assign Ticket Scanner',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey[800],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for a user by email to assign them as a ticket scanner for this event.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.blueGrey[600],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
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
                            'Scanner Status:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Switch(
                            value: _isScanner,
                            onChanged: _isLoading
                                ? null
                                : (value) => _toggleScannerStatus(value),
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
                _isScanner
                    ? 'This user can scan tickets for your event'
                    : 'This user cannot scan tickets',
                style: TextStyle(
                  color: _isScanner ? Colors.green : Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}