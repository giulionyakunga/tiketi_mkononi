import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import '../../env.dart';
import 'package:http/http.dart' as http;


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  late final StorageService _storageService;
  bool _isLoading = false;

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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {

    try {
        setState(() {
          _isLoading = true; // Disable button & show loader
        });

      String url = '${backend_url}api/login';

      final response = await http.post(
        Uri.parse(url),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: '{"email": "${_emailController.text}", "password": "${_passwordController.text}"}',
      );

      if (response.statusCode == 200) {
        if(response.body == "Login failed, Plz check your credentials!" ){
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
        }else {
          String token = jsonDecode(response.body)['token'];

          if(token != ""){
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(content: Text('${jsonDecode(response.body)}')),
            // );
            print("response.body : ${response.body}");

            int id = jsonDecode(response.body)['id'];
            String firstName = jsonDecode(response.body)['first_name'];
            String middleName = jsonDecode(response.body)['middle_name'];
            String lastName = jsonDecode(response.body)['last_name'];
            String email = jsonDecode(response.body)['email'];
            String phoneNumber = jsonDecode(response.body)['phone_number'];
            String role = jsonDecode(response.body)['role'];
            String region = jsonDecode(response.body)['region'];
            String district = jsonDecode(response.body)['district'];
            String ward = jsonDecode(response.body)['ward'];
            String street = jsonDecode(response.body)['street'];

            try {
              final profile = UserProfile(
                id: id,
                firstName: firstName,
                middleName: middleName,
                lastName: lastName,
                email: email,
                phoneNumber: phoneNumber,
                role: role,
                region: region,
                district: district,
                ward: ward,
                street: street,
                token: token,
                imageUrl: jsonDecode(response.body)['email'],
              );

              // Save locally
              await _storageService.saveUserProfile(profile);
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text('Profile Update successful')),
              // );

            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to update profile ')),
                );
              }
            }
            Navigator.pushReplacementNamed(context, '/home');
          }else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response.body)),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request not successful, Code: ${response.statusCode}')),
        );
      }
      
    } catch (e) {
      // Handle network errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      ); 
    } finally {
      setState(() {
        _isLoading = false; // Re-enable button after request completes
      });
    }


    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      colors: [Colors.blue, Colors.purple], // Gradient colors
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds);
                  },
                  child: const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white, // Text color must be white for gradient to show
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to continue',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.email,
                      color: Colors.grey[600],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: Colors.grey[400]!,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: Colors.grey[400]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(
                        color: Colors.blue, // Highlight color when focused
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200], // Light background color
                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    if (value.length > 100) {
                      return 'Email cannot exceed 100 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                    prefixIcon: Icon(
                      Icons.lock,
                      color: Colors.grey[600],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: Colors.grey[400]!,
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: Colors.grey[400]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: const BorderSide(
                        color: Colors.blue, // Highlight color when focused
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200], // Light background color
                    contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                  ),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    if (value.length > 100) {
                      return 'Password cannot exceed 100 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/forgot-password');
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, // Primary color
                    foregroundColor: Colors.white, // Text color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10), // Rounded corners
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4, // Subtle shadow for a raised effect
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue, // Highlight color
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Don\'t have an account? Sign Up'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}