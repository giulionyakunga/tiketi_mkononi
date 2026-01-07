import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import '../../env.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameKey = GlobalKey();
  final _middleNameKey = GlobalKey();
  final _lastNameKey = GlobalKey();
  final _phoneNumberKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _passwordKey = GlobalKey();
  final _confirmPasswordKey = GlobalKey();
  final _regionKey = GlobalKey();
  final _districtKey = GlobalKey();
  final _wardKey = GlobalKey();
  final _streetKey = GlobalKey();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();  
  final _confirmPasswordController = TextEditingController();
  final _regionController = TextEditingController();
  final _districtController = TextEditingController();
  final _wardController = TextEditingController();
  final _streetController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isConfirmPasswordVisible = false;
  late final StorageService _storageService;

  bool _isAccountCreated = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _regionController.dispose();
    _districtController.dispose();
    _wardController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  void _scrollToFirstError() {
    final focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      focusNode.requestFocus();
    });
  }

    Future<void> _saveUserProfile(Map<String, dynamic> user) async {
    try {
      debugPrint('User id 2: ${user['id']}');

      final profile = UserProfile(
        id: user['id'],
        firstName: user['first_name'],
        middleName: user['middle_name'],
        lastName: user['last_name'],
        email: user['email'],
        phoneNumber: user['phone_number'],
        role: user['role'],
        region: user['region'],
        district: user['district'],
        ward: user['ward'],
        street: user['street'],
        token: '',
        imageUrl: '',
         createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _storageService.saveUserProfile(profile);
    } catch (e) {
      if (mounted) _showSnackBar('Failed to update profile');
    }
  }

  Future<void> _handleRegister({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/add_new_user') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}add_new_user'); // Use IP
        
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: '{"first_name": "${_firstNameController.text.trim()}", "middle_name": "${_middleNameController.text.trim()}", "last_name": "${_lastNameController.text.trim()}", "email": "${_emailController.text.trim()}", "phone_number": "${_phoneNumberController.text.trim()}", "role": "user", "password": "${_passwordController.text.trim()}", "region": "${_regionController.text.trim()}", "district": "${_districtController.text.trim()}", "ward": "${_wardController.text.trim()}", "street": "${_streetController.text.trim()}"}',
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);

        if(responseData['message'] == "User added successfully!") {
          setState(() {
            _isAccountCreated = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Account Created Successfully!")),
          );

          await _saveUserProfile(responseData['data']['user']);

          context.go('/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
        }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Request failed: ${response.statusCode}');
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
          debugPrint('DNS failed! Retrying with IP here: ${backend_url_with_fallback_ip}...');
          await _handleRegister(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint(' An error occurred: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('An error occurred: $e')),
      // );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  Widget _buildFormField({
    required Key key,
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    bool isPasswordField = false,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        key: key,
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
          ),
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(color: Colors.grey[400]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: BorderSide(
              color: Colors.orange[800]!,
              width: 2.0,
            ),
          ),
          filled: true,
          fillColor: Colors.grey[200],
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
          suffixIcon: isPasswordField
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                  ),
                  onPressed: () {
                    setState(() {
                      if (labelText == 'Password') {
                        _isPasswordVisible = !_isPasswordVisible;
                      } else {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      }
                    });
                  },
                )
              : null,
        ),
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 16,
        ),
        validator: validator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWideScreen = constraints.maxWidth > 600;
            final double paddingValue = isWideScreen ? 40.0 : 24.0;

            return SingleChildScrollView(
              padding: EdgeInsets.all(paddingValue),
              child: Form(
                key: _formKey,
                child: isWideScreen
                    ? _buildWideScreenForm()
                    : _buildNormalScreenForm(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNormalScreenForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        _buildFormField(
          key: _firstNameKey,
          controller: _firstNameController,
          labelText: 'First Name',
          icon: Icons.person,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your first name';
            if (value.length > 100) return 'First name cannot exceed 100 characters';
            return null;
          },
        ),
        _buildFormField(
          key: _middleNameKey,
          controller: _middleNameController,
          labelText: 'Middle Name',
          icon: Icons.person,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your middle name';
            if (value.length > 100) return 'Middle name cannot exceed 100 characters';
            return null;
          },
        ),
        _buildFormField(
          key: _lastNameKey,
          controller: _lastNameController,
          labelText: 'Last Name',
          icon: Icons.person,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your last name';
            if (value.length > 100) return 'Last name cannot exceed 100 characters';
            return null;
          },
        ),
        _buildFormField(
          key: _phoneNumberKey,
          controller: _phoneNumberController,
          labelText: 'Phone Number',
          icon: Icons.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your phone number';
            }

            final phone = value.trim();

            if (phone.length > 15) {
              return 'Phone number cannot exceed 15 characters';
            }

            final regex = RegExp(r'^(0\d{9}|255\d{9})$');

            if (!regex.hasMatch(phone)) {
              return 'Invalid number format. Use 0XXXXXXXXX or 255XXXXXXXXX';
            }

            return null;
          },
        ),
        _buildFormField(
          key: _emailKey,
          controller: _emailController,
          labelText: 'Email',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your email';
            if (value.length > 100) return 'Email cannot exceed 100 characters';
            if (!value.contains('@')) return 'Please enter a valid email';
            return null;
          },
        ),
        _buildFormField(
          key: _passwordKey,
          controller: _passwordController,
          labelText: 'Password',
          icon: Icons.lock,
          obscureText: !_isPasswordVisible,
          isPasswordField: true,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter a password';
            if (value.length < 6) return 'Password must be at least 6 characters';
            if (value.length > 100) return 'Password cannot exceed 100 characters';
            return null;
          },
        ),
        _buildFormField(
          key: _confirmPasswordKey,
          controller: _confirmPasswordController,
          labelText: 'Confirm Password',
          icon: Icons.lock,
          obscureText: !_isConfirmPasswordVisible,
          isPasswordField: true,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please confirm your password';
            if (value.length > 100) return 'Password cannot exceed 100 characters';
            if (value != _passwordController.text.trim()) return 'Passwords do not match';
            return null;
          },
        ),
        _buildFormField(
          key: _regionKey,
          controller: _regionController,
          labelText: 'Region',
          icon: Icons.location_city,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your region';
            if (value.length > 100) return 'Region cannot exceed 100 characters';
            return null;
          },
        ),
        _buildFormField(
          key: _districtKey,
          controller: _districtController,
          labelText: 'District',
          icon: Icons.my_location,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your district';
            if (value.length > 100) return 'District cannot exceed 100 characters';
            return null;
          },
        ),
        _buildFormField(
          key: _wardKey,
          controller: _wardController,
          labelText: 'Ward',
          icon: Icons.my_location,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your ward';
            if (value.length > 100) return 'Ward cannot exceed 100 characters';
            return null;
          },
        ),
        _buildFormField(
          key: _streetKey,
          controller: _streetController,
          labelText: 'Street',
          icon: Icons.my_location,
          validator: (value) {
            if (value == null || value.isEmpty) return 'Please enter your street';
            if (value.length > 100) return 'Street cannot exceed 100 characters';
            return null;
          },
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: (_isAccountCreated || _isLoading) ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isAccountCreated ? Colors.green : Colors.orange[800],
            disabledBackgroundColor: _isAccountCreated ? Colors.green : Colors.orange[800],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 4,
          ),
          child: _isLoading ? const CircularProgressIndicator() :
          Text(
            _isAccountCreated ? 'Account Created' : 'Create Account',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.orange[800],
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: const Text('Already have an account? Sign In'),
        ),
      ],
    );
  }

  Widget _buildWideScreenForm() {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column (personal info)
            Expanded(
              child: Column(
                children: [
                  _buildFormField(
                    key: _firstNameKey,
                    controller: _firstNameController,
                    labelText: 'First Name',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your first name';
                      if (value.length > 100) return 'First name cannot exceed 100 characters';
                      return null;
                    },
                  ),
                  _buildFormField(
                    key: _middleNameKey,
                    controller: _middleNameController,
                    labelText: 'Middle Name',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your middle name';
                      if (value.length > 100) return 'Middle name cannot exceed 100 characters';
                      return null;
                    },
                  ),
                  _buildFormField(
                    key: _lastNameKey,
                    controller: _lastNameController,
                    labelText: 'Last Name',
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your last name';
                      if (value.length > 100) return 'Last name cannot exceed 100 characters';
                      return null;
                    },
                  ),
                  _buildFormField(
                    key: _phoneNumberKey,
                    controller: _phoneNumberController,
                    labelText: 'Phone Number',
                    icon: Icons.phone,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your phone number';
                      if (value.length > 15) return 'Phone number cannot exceed 15 characters';
                      final regex = RegExp(r'^\d{1,3}\d{9}$');
                      if (!regex.hasMatch(value.trim())) return 'Invalid number, Number format: 255xxxxxxxxxx';
                      return null;
                    },
                  ),
                  _buildFormField(
                    key: _emailKey,
                    controller: _emailController,
                    labelText: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your email';
                      if (value.length > 100) return 'Email cannot exceed 100 characters';
                      if (!value.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Right column (address and password)
            Expanded(
              child: Column(
                children: [
                  _buildFormField(
                    key: _passwordKey,
                    controller: _passwordController,
                    labelText: 'Password',
                    icon: Icons.lock,
                    obscureText: !_isPasswordVisible,
                    isPasswordField: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter a password';
                      if (value.length < 6) return 'Password must be at least 6 characters';
                      if (value.length > 100) return 'Password cannot exceed 100 characters';
                      return null;
                    },
                  ),
                  _buildFormField(
                    key: _confirmPasswordKey,
                    controller: _confirmPasswordController,
                    labelText: 'Confirm Password',
                    icon: Icons.lock,
                    obscureText: !_isConfirmPasswordVisible,
                    isPasswordField: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please confirm your password';
                      if (value.length > 100) return 'Password cannot exceed 100 characters';
                      if (value != _passwordController.text.trim()) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  _buildFormField(
                    key: _regionKey,
                    controller: _regionController,
                    labelText: 'Region',
                    icon: Icons.location_city,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your region';
                      if (value.length > 100) return 'Region cannot exceed 100 characters';
                      return null;
                    },
                  ),
                  _buildFormField(
                    key: _districtKey,
                    controller: _districtController,
                    labelText: 'District',
                    icon: Icons.my_location,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your district';
                      if (value.length > 100) return 'District cannot exceed 100 characters';
                      return null;
                    },
                  ),
                  _buildFormField(
                    key: _wardKey,
                    controller: _wardController,
                    labelText: 'Ward',
                    icon: Icons.my_location,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your ward';
                      if (value.length > 100) return 'Ward cannot exceed 100 characters';
                      return null;
                    },
                  ),
                  _buildFormField(
                    key: _streetKey,
                    controller: _streetController,
                    labelText: 'Street',
                    icon: Icons.my_location,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your street';
                      if (value.length > 100) return 'Street cannot exceed 100 characters';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 400, // Fixed width for the button on wide screens
          child: ElevatedButton(
            onPressed: _isAccountCreated ? null : _handleRegister,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isAccountCreated ? Colors.green : Colors.orange[800],
              disabledBackgroundColor: _isAccountCreated ? Colors.green : Colors.orange[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 4,
            ),
            child: Text(
              _isAccountCreated ? 'Account Created' : 'Create Account',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: Colors.orange[800],
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          child: const Text('Already have an account? Sign In'),
        ),
      ],
    );
  }
}