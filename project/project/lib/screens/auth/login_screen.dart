import 'dart:convert';
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
          if (response.body == "Login failed, Plz check your credentials!") {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(response.body)),
            );
          } else {
            String token = jsonDecode(response.body)['token'];

            if (token != "") {
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

                await _storageService.saveUserProfile(profile);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to update profile ')),
                  );
                }
              }
              Navigator.pushReplacementNamed(context, '/home');
            } else {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Future<void> _handleGoogleSignIn() async {
  //   try {
  //     setState(() {
  //       _isLoading = true;
  //     });

  //     final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
  //     if (googleUser == null) return;

  //     final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

  //     // Here you would typically send the token to your backend for verification
  //     // and get your own JWT token in response
  //     // For example:
  //     String url = '${backend_url}api/google-login';
  //     final response = await http.post(
  //       Uri.parse(url),
  //       headers: <String, String>{
  //         'Content-Type': 'application/json; charset=UTF-8',
  //       },
  //       body: jsonEncode({
  //         'token': googleAuth.idToken,
  //         'email': googleUser.email,
  //         'name': googleUser.displayName,
  //       }),
  //     );

  //     if (response.statusCode == 200) {
  //       String token = jsonDecode(response.body)['token'];
  //       if (token.isNotEmpty) {
  //         // Create user profile from Google data
  //         final profile = UserProfile(
  //           id: jsonDecode(response.body)['id'] ?? 0,
  //           firstName: googleUser.displayName?.split(' ').first ?? '',
  //           lastName: googleUser.displayName?.split(' ').last ?? '',
  //           email: googleUser.email,
  //           phoneNumber: '',
  //           role: jsonDecode(response.body)['role'] ?? 'user',
  //           token: token,
  //           imageUrl: googleUser.photoUrl,
  //           // Add other fields as needed or as returned from your backend
  //         );

  //         await _storageService.saveUserProfile(profile);
  //         Navigator.pushReplacementNamed(context, '/home');
  //       }
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Google login failed: ${response.body}')),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Google sign in failed: $e')),
  //     );
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  // Future<void> _handleAppleSignIn() async {
  //   try {
  //     setState(() {
  //       _isLoading = true;
  //     });

  //     final credential = await SignInWithApple.getAppleIDCredential(
  //       scopes: [
  //         AppleIDAuthorizationScopes.email,
  //         AppleIDAuthorizationScopes.fullName,
  //       ],
  //     );

  //     // Here you would typically send the token to your backend for verification
  //     String url = '${backend_url}api/apple-login';
  //     final response = await http.post(
  //       Uri.parse(url),
  //       headers: <String, String>{
  //         'Content-Type': 'application/json; charset=UTF-8',
  //       },
  //       body: jsonEncode({
  //         'token': credential.identityToken,
  //         'email': credential.email,
  //         'name': '${credential.givenName} ${credential.familyName}',
  //       }),
  //     );

  //     if (response.statusCode == 200) {
  //       String token = jsonDecode(response.body)['token'];
  //       if (token.isNotEmpty) {
  //         // Create user profile from Apple data
  //         final profile = UserProfile(
  //           id: jsonDecode(response.body)['id'] ?? 0,
  //           firstName: credential.givenName ?? '',
  //           lastName: credential.familyName ?? '',
  //           email: credential.email ?? '',
  //           phoneNumber: '',
  //           role: jsonDecode(response.body)['role'] ?? 'user',
  //           token: token,
  //           // Apple doesn't provide a photo URL
  //           // Add other fields as needed or as returned from your backend
  //         );

  //         await _storageService.saveUserProfile(profile);
  //         Navigator.pushReplacementNamed(context, '/home');
  //       }
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text('Apple login failed: ${response.body}')),
  //       );
  //     }
  //   } catch (e) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('Apple sign in failed: $e')),
  //     );
  //   } finally {
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

 

//   void _handleGoogleSignIn() async {  // Changed return type to void
//   try {
//     setState(() => _isLoading = true);
//     final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
//     if (googleUser == null) return;
    
//     // Rest of your Google sign-in logic...
    
//   } catch (e) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Google sign in failed: $e')),
//     );
//   } finally {
//     if (mounted) {
//       setState(() => _isLoading = false);
//     }
//   }
// }




void _handleGoogleSignIn() async {
  if (_isLoading) return;
  
  try {
    setState(() => _isLoading = true);
    
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

    final GoogleSignInAuthentication googleAuth = 
        await googleUser.authentication;

    // Your backend API call
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.body)),
        );
      } else {
        String token = jsonDecode(response.body)['token'];

        if (token != "") {
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

            await _storageService.saveUserProfile(profile);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to update profile ')),
              );
            }
          }
          Navigator.pushReplacementNamed(context, '/home');
        } else {
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign in failed: $e')),
      );
    }
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}

void _handleAppleSignIn() async { }

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
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 6),
          Image.asset(
            imagePath,
            height: 24,
            width: 24,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSocialButton2({
    required String imagePath,
    required String text,
    required Color textColor,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            height: 24,
            width: 24,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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
                const SizedBox(height: 38),
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      colors: [Colors.blue, Colors.purple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds);
                  },
                  child: const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                const SizedBox(height: 20),
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
                        color: Colors.blue,
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
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
                        color: Colors.blue,
                        width: 2.0,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
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
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey[400],
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
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
                const SizedBox(height: 16),

                _buildSocialButton(
                  imagePath: 'assets/images/google_logo.png',
                  text: 'Continue with Google',
                  textColor: Colors.white,
                  color: Colors.black,
                  onPressed: _handleGoogleSignIn,
                ),
                const SizedBox(height: 12),
                _buildSocialButton2(
                  imagePath: 'assets/images/appleid_logo.png',
                  text: 'Continue with Apple',
                  textColor: Colors.black,
                  color: Colors.white,
                  onPressed: _handleAppleSignIn,
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/register');
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
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