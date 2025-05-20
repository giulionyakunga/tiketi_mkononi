import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';
import 'package:tiketi_mkononi/services/api_service.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
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

  int user_id = 0;
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _passwordController = TextEditingController();  
  final _confirmPasswordController = TextEditingController();
  final _regionController = TextEditingController();
  final _districtController = TextEditingController();
  final _wardController = TextEditingController();
  final _streetController = TextEditingController();
  String token = "";
  String role = "";
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  
  final _apiService = ApiService(); 
  late final StorageService _storageService;
  XFile? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final profile = _storageService.getUserProfile();
    if (profile != null) {
      setState(() {
        user_id = profile.id;
        _firstNameController.text = profile.firstName;
        _middleNameController.text = profile.middleName;
        _lastNameController.text = profile.lastName;
        _emailController.text = profile.email;
        _phoneNumberController.text = profile.phoneNumber;
        _passwordController.text = "";
        _confirmPasswordController.text = "";
        _regionController.text = profile.region;
        _districtController.text = profile.district;
        _wardController.text = profile.ward;
        _streetController.text = profile.street;
        token = profile.token;
        role = profile.role;
      });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image')),
        );
      }
    }
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

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError(); // Scroll to the first error field
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profile = UserProfile(
        id: user_id,
        firstName: _firstNameController.text.trim(),
        middleName: _middleNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        role: role,
        region: _regionController.text.trim(),
        district: _districtController.text.trim(),
        ward: _wardController.text.trim(),
        street: _streetController.text.trim(),
        token: token,
        imageUrl: _selectedImage?.path,
      );

      String password = _passwordController.text.trim();
 
      String response = await _apiService.updateUserProfile(profile, password, _selectedImage?.path);
      await _storageService.saveUserProfile(profile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response)),
        );
        if(response == "User profile updated successfully!") {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Error editing profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _selectedImage != null
                        ? FileImage(File(_selectedImage!.path))
                        : const NetworkImage('https://example.com/profile.jpg') as ImageProvider,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                      ),
                      onPressed: _pickImage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
          
              TextFormField(
                key: _firstNameKey,
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.person,
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
                    return 'Please enter your first name';
                  }
                  if (value.length > 100) {
                    return 'First name cannot exceed 100 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: _middleNameKey,
                controller: _middleNameController,
                decoration: InputDecoration(
                  labelText: 'Middle Name',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.person,
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
                    return 'Please enter your middle name';
                  }
                  if (value.length > 100) {
                    return 'Middle name cannot exceed 100 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: _lastNameKey,
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last Name',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.person,
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
                    return 'Please enter your last name';
                  }
                  if (value.length > 100) {
                    return 'Last name cannot exceed 100 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: _phoneNumberKey,
                controller: _phoneNumberController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.phone,
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
                    return 'Please enter your phone number';
                  }
                  if (value.length > 15) {
                    return 'Phone number cannot exceed 15 characters';
                  }
                  final regex = RegExp(r'^\d{1,3}\d{9}$');
                  if (!regex.hasMatch(value)) {
                    return 'Invalid number, Number format: 255xxxxxxxxxx';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: _emailKey,
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
                  if (value.length > 100) {
                    return 'Email cannot exceed 100 characters';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: _passwordKey,
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
                    return null;
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
              const SizedBox(height: 16),
              TextFormField(
                key: _confirmPasswordKey,
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
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
                      _isConfirmPasswordVisible
                      ? Icons.visibility
                      : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
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
                    return null;
                  }

                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  if (value.length > 100) {
                    return 'Password cannot exceed 100 characters';
                  }

                  if (value != _passwordController.text.trim()) {
                    return 'Passwords do not match';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: _regionKey,
                controller: _regionController,
                decoration: InputDecoration(
                  labelText: 'Region',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.location_city,
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
                    return 'Please enter your region';
                  }
                  if (value.length > 100) {
                    return 'Region cannot exceed 100 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: _districtKey,
                controller: _districtController,
                decoration: InputDecoration(
                  labelText: 'District',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.my_location,
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
                    return 'Please enter your district';
                  }
                  if (value.length > 100) {
                    return 'District cannot exceed 100 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: _wardKey,
                controller: _wardController,
                decoration: InputDecoration(
                  labelText: 'Ward',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.my_location,
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
                    return 'Please enter your ward';
                  }
                  if (value.length > 100) {
                    return 'Ward cannot exceed 100 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: _streetKey,
                controller: _streetController,
                decoration: InputDecoration(
                  labelText: 'Street',
                  labelStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(
                    Icons.my_location,
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
                    return 'Please enter your street';
                  }
                  if (value.length > 100) {
                    return 'Street cannot exceed 100 characters';
                  }
                  return null;
                  },
                ),
                const SizedBox(height: 24),










              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}