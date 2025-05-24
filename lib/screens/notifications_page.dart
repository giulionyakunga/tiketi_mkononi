import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  // Form state
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  // Notification preferences
  bool _emailNotifications = false;
  bool _smsNotifications = false;
  Set<String> _selectedEventCategories = {}; // Start with 'All' selected


  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? encodedList = prefs.getString('selected_event_categories');
    
    if (encodedList != null) {
      // Convert JSON string back to List<String>
      List<dynamic> decodedList = json.decode(encodedList);
      decodedList.forEach((item) {
        print("Item : $item"); // Prints each item one by one
        setState(() {
          _selectedEventCategories.add(item);
        });
      });
    }
  }

  // Available event categories
  final List<String> _eventCategories = [
    'All',
    'Comedy',
    'Bars & Grills',
    'Fun',
    'Concerts',
    'Theater',
    'Sports',
    'Training',
  ];

  // Loading state
  bool _isLoading = false;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleEventCategory(String category) {
    setState(() {
      if (category == 'All') {
        if (_selectedEventCategories.contains('All')) {
          // If 'All' was selected and is being toggled, select all categories
          _selectedEventCategories.clear();
        } else {
          // If 'All' is being selected, select all categories
          _selectedEventCategories.addAll(_eventCategories);
        }
      } else {
        // For other event categories
        if (_selectedEventCategories.contains(category)) {
          _selectedEventCategories.remove(category);
          // If any category is deselected, also remove 'All'
          _selectedEventCategories.remove('All');
        } else {
          _selectedEventCategories.add(category);
          // If all categories are selected, also add 'All'
          if (_selectedEventCategories.length == _eventCategories.length - 1) {
            _selectedEventCategories.add('All');
          }
        }
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEventCategories.isEmpty) return;

    setState(() {
      _isLoading = true;
      _isSuccess = false;
    });

    try {
      // Simulate API call
      await Future.delayed(const Duration(seconds: 2));

      // Cache the data locally
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String encodedList = json.encode(_selectedEventCategories.toList()); 
      await prefs.setString('selected_event_categories', encodedList);



      try {
        setState(() => _isLoading = true);
        
        final response = await http.post(
          Uri.parse('${backend_url}api/save_notification_preferences'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: encodedList,
        );

        if (response.statusCode == 200) {
          if (response.body == "Notification preferences saved successfully!") {
            // _showSnackBar(response.body);
          } else {
            _showSnackBar('Request failed: ${response.statusCode}');
          }
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
        }
      } on SocketException catch (e) {
        _handleSocketException(e);
      } catch (e) {
        debugPrint('An error occurred: $e');
        _showSnackBar('An error occurred: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }

      setState(() {
        _isSuccess = true;
      });

      // Clear form after successful submission
      if (_isSuccess) {
        _formKey.currentState!.reset();
        _emailController.clear();
        _phoneController.clear();
        setState(() {
          _emailNotifications = false;
          _smsNotifications = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting form: $e'),
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
    if (e.osError?.errorCode == 7 || e.osError?.errorCode == 111) {
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

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 768;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Preferences'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 64 : 24,
          vertical: 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stay Updated',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you want to receive notifications about new events',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Notification Category Selection
                  Text(
                    'Notification Methods',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildNotificationMethodToggle(
                    context,
                    title: 'Email Notifications',
                    value: _emailNotifications,
                    onChanged: (value) => setState(() => _emailNotifications = value!),
                  ),
                  const SizedBox(height: 12),
                  if (_emailNotifications) ...[
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: 'your@email.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (_emailNotifications && (value == null || value.isEmpty)) {
                          return 'Please enter your email';
                        }
                        if (value != null && value.isNotEmpty && !RegExp(
                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildNotificationMethodToggle(
                    context,
                    title: 'SMS Notifications',
                    value: _smsNotifications,
                    onChanged: (value) => setState(() => _smsNotifications = value!),
                  ),
                  const SizedBox(height: 12),
                  if (_smsNotifications) ...[
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        hintText: '255712345678',
                      ),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (value) {
                        if (_smsNotifications && (value == null || value.isEmpty)) {
                          return 'Please enter your phone number';
                        }
                        if (value != null && value.isNotEmpty && value.length < 9) {
                          return 'Please enter a valid phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Event Category Selection
                  const SizedBox(height: 24),
                  Text(
                    'Event Categories',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select which categories of events you want to be notified about',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildEventCategorySelection(isLargeScreen),
                  if (_selectedEventCategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Please select at least one event category',
                        style: TextStyle(
                          color: Colors.red[400],
                          fontSize: 14,
                        ),
                      ),
                    ),

                  // Submit Button
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isLoading || _selectedEventCategories.isEmpty) 
                          ? null 
                          : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSuccess
                            ? Colors.green
                            : theme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isSuccess
                                      ? Icons.check_circle_outline
                                      : Icons.notifications_active_outlined,
                                  size: 24,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isSuccess
                                      ? 'Preferences Saved!'
                                      : 'Save Preferences',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationMethodToggle(
    BuildContext context, {
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCategorySelection(bool isLargeScreen) {
    return isLargeScreen
        ? Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _eventCategories.map((category) {
              return FilterChip(
                label: Text(category),
                selected: _selectedEventCategories.contains(category),
                onSelected: (selected) => _toggleEventCategory(category),
                selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
                backgroundColor: Colors.grey[200],
                labelStyle: TextStyle(
                  color: _selectedEventCategories.contains(category)
                      ? Theme.of(context).primaryColor
                      : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(
                  color: _selectedEventCategories.contains(category)
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                ),
                showCheckmark: false,
              );
            }).toList(),
          )
        : Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ExpansionTile(
                  title: Text(
                    'Selected: ${_selectedEventCategories.length} ${_selectedEventCategories.length == 1 ? 'category' : 'categories'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  children: _eventCategories.map((category) {
                    return CheckboxListTile(
                      title: Text(category),
                      value: _selectedEventCategories.contains(category),
                      onChanged: (value) => _toggleEventCategory(category),
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Theme.of(context).primaryColor,
                      contentPadding: EdgeInsets.zero,
                    );
                  }).toList(),
                ),
              ),
            ],
          );
  }
}