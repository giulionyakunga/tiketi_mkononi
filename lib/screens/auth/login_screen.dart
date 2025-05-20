import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import '../../env.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
// import 'package:sign_in_with_apple/sign_in_with_apple.dart';

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
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

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

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
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

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() => _isLoading = true);
        
        final response = await http.post(
          Uri.parse('${backend_url}api/login'),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            "email": _emailController.text,
            "password": _passwordController.text
          }),
        );

        if (response.statusCode == 200) {
          if (response.body == "Login failed, Plz check your credentials!") {
            _showSnackBar(response.body);
          } else {
            final responseData = jsonDecode(response.body);
            if (responseData['token'] != "") {
              await _saveUserProfile(responseData);
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              _showSnackBar(response.body);
            }
          }
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
        }
      } on SocketException catch (e) {
        _handleSocketException(e);
      } catch (e) {
        debugPrint('URL: ${backend_url}api/login');
        debugPrint('An error occurred: $e');
        _showSnackBar('An error occurred: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveUserProfile(Map<String, dynamic> responseData) async {
    try {
      final profile = UserProfile(
        id: responseData['id'],
        firstName: responseData['first_name'],
        middleName: responseData['middle_name'],
        lastName: responseData['last_name'],
        email: responseData['email'],
        phoneNumber: responseData['phone_number'],
        role: responseData['role'],
        region: responseData['region'],
        district: responseData['district'],
        ward: responseData['ward'],
        street: responseData['street'],
        token: responseData['token'],
        imageUrl: responseData['email'],
      );
      await _storageService.saveUserProfile(profile);
    } catch (e) {
      if (mounted) _showSnackBar('Failed to update profile');
    }
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

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;
    
    try {
      setState(() => _isLoading = true);
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      final response = await http.post(
        Uri.parse('${backend_url}api/google_login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': googleAuth.idToken,
          'email': googleUser.email,
          'name': googleUser.displayName,
        }),
      );

      if (response.statusCode == 200) {
        if (response.body == "Login failed, Plz check your credentials!") {
          _showSnackBar(response.body);
        } else {
          await _saveUserProfile(jsonDecode(response.body));
          Navigator.pushReplacementNamed(context, '/home');
        }      
      } else {
        _showSnackBar('Request failed: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      _handleSocketException(e);
    } catch (e) {
      if (mounted) _showSnackBar('Google sign in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleAppleSignIn() async {
    // Implement Apple Sign In logic here
  }

  // void _handleAppleSignIn() async {  // Changed return type to void
//   try {
//     setState(() => _isLoading = true);
//     final credential = await SignInWithApple.getAppleIDCredential(
//       scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
//     );
    
//     // Rest of your Apple sign-in logic...
    
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Apple sign in failed: $e')),
//     );
//   } finally {
//     if (mounted) {
//       setState(() => _isLoading = false);
//     }
//   }
// }

// void _handleAppleSignIn() async {
//   if (_isLoading) return;  // Early return if already loading
  
//   try {
//     setState(() => _isLoading = true);
    
//     final credential = await SignInWithApple.getAppleIDCredential(
//       scopes: [
//         AppleIDAuthorizationScopes.email,
//         AppleIDAuthorizationScopes.fullName,
//       ],
//     );

//     // Send to your backend
//     final response = await http.post(
//       Uri.parse('${backend_url}api/apple-login'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({
//         'token': credential.identityToken,
//         'email': credential.email,
//         'name': '${credential.givenName} ${credential.familyName}',
//       }),
//     );

//     if (response.statusCode == 200) {
//       // final profile = UserProfile(
//       //   id: jsonDecode(response.body)['id'] ?? 0,
//       //   firstName: credential.givenName ?? '',
//       //   lastName: credential.familyName ?? '',
//       //   email: credential.email ?? '',
//       //   token: jsonDecode(response.body)['token'],
//       //   // Other fields as needed
//       // );
      
//       // await _storageService.saveUserProfile(profile);
//       if (mounted) Navigator.pushReplacementNamed(context, '/home');
//     }
//   } catch (e) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Apple sign in failed: $e')),
//       );
//     }
//   } finally {
//     if (mounted) setState(() => _isLoading = false);
//   }
// }

  Widget _buildSocialButton({
    required String imagePath,
    required String text,
    required Color textColor,
    required Color color,
    required VoidCallback onPressed,
    bool isLargeScreen = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(
          vertical: isLargeScreen ? 16 : 12,
          horizontal: isLargeScreen ? 24 : 12,
        ),
        elevation: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            height: isLargeScreen ? 28 : 24,
            width: isLargeScreen ? 28 : 24,
          ),
          SizedBox(width: isLargeScreen ? 16 : 12),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: isLargeScreen ? 16 : 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isLargeScreen) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _buildInputDecoration(
              label: 'Email',
              icon: Icons.email,
              isLargeScreen: isLargeScreen,
            ),
            style: TextStyle(fontSize: isLargeScreen ? 18 : 16),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter your email';
              if (!value.contains('@')) return 'Please enter a valid email';
              if (value.length > 100) return 'Email cannot exceed 100 characters';
              return null;
            },
          ),
          SizedBox(height: isLargeScreen ? 24 : 16),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            decoration: _buildInputDecoration(
              label: 'Password',
              icon: Icons.lock,
              isLargeScreen: isLargeScreen,
              isPasswordField: true,
              onVisibilityPressed: () {
                setState(() => _isPasswordVisible = !_isPasswordVisible);
              },
            ),
            style: TextStyle(fontSize: isLargeScreen ? 18 : 16),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter a password';
              if (value.length < 6) return 'Password must be at least 6 characters';
              if (value.length > 100) return 'Password cannot exceed 100 characters';
              return null;
            },
          ),
          SizedBox(height: isLargeScreen ? 16 : 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Forgot Password?',
                style: TextStyle(
                  color: Colors.orange[800],
                  fontSize: isLargeScreen ? 16 : 14,
                ),
              ),
            ),
          ),
          SizedBox(height: isLargeScreen ? 24 : 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 20 : 16),
              elevation: 4,
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
                : Text(
                    'Sign In',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 18 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    bool isLargeScreen = false,
    bool isPasswordField = false,
    VoidCallback? onVisibilityPressed,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: isLargeScreen ? 18 : 16,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.grey[600],
        size: isLargeScreen ? 24 : 20,
      ),
      suffixIcon: isPasswordField
          ? IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                size: isLargeScreen ? 24 : 20,
              ),
              onPressed: onVisibilityPressed,
            )
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.orange[800]!, width: 2.0),
      ),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: EdgeInsets.symmetric(
        vertical: isLargeScreen ? 20 : 16,
        horizontal: isLargeScreen ? 20 : 16,
      ),
    );
  }

  Widget _buildSocialLoginSection(bool isLargeScreen) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: Colors.grey[400],
                thickness: 1,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 16 : 8),
              child: Text(
                'OR',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: isLargeScreen ? 16 : 14,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: Colors.grey[400],
                thickness: 1,
              ),
            ),
          ],
        ),
        SizedBox(height: isLargeScreen ? 24 : 16),
        if (Platform.isAndroid) ...[
          _buildSocialButton(
            imagePath: 'assets/images/google_logo.png',
            text: 'Continue with Google',
            textColor: Colors.white,
            color: Colors.black,
            onPressed: _handleGoogleSignIn,
            isLargeScreen: isLargeScreen,
          ),
          SizedBox(height: isLargeScreen ? 16 : 12),
        ],
        if (Platform.isIOS) ...[
          _buildSocialButton(
            imagePath: 'assets/images/appleid_logo.png',
            text: 'Continue with Apple',
            textColor: Colors.black,
            color: Colors.white,
            onPressed: _handleAppleSignIn,
            isLargeScreen: isLargeScreen,
          ),
          SizedBox(height: isLargeScreen ? 16 : 12),
        ],
      ],
    );
  }

  Widget _buildRegisterSection(bool isLargeScreen) {
    return TextButton(
      onPressed: () => Navigator.pushNamed(context, '/register'),
      style: TextButton.styleFrom(
        foregroundColor: Colors.orange[800],
        textStyle: TextStyle(
          fontSize: isLargeScreen ? 18 : 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: const Text('Don\'t have an account? Sign Up'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = _isLargeScreen(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 32 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 600 : double.infinity,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        colors: [Colors.orange[200]!, Colors.orange[800]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: isLargeScreen ? 48 : 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.0,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: isLargeScreen ? 16 : 8),
                  Text(
                    'Sign in to continue',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 22 : 18,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isLargeScreen ? 40 : 24),
                  _buildLoginForm(isLargeScreen),
                  SizedBox(height: isLargeScreen ? 32 : 24),
                  _buildSocialLoginSection(isLargeScreen),
                  SizedBox(height: isLargeScreen ? 32 : 24),
                  _buildRegisterSection(isLargeScreen),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}