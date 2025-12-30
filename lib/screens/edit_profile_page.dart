import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';
import 'package:tiketi_mkononi/screens/auth/login_screen.dart';
import 'package:tiketi_mkononi/services/api_service.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:flutter/services.dart';

// Custom formatter for card number spacing (XXXX XXXX XXXX XXXX)
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    // Remove all non-digit characters
    String input = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // If the input is empty after cleaning, return empty value
    if (input.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    
    StringBuffer formatted = StringBuffer();
    
    for (int i = 0; i < input.length; i++) {
      // Add space after every 4 digits
      if (i > 0 && i % 4 == 0) {
        formatted.write(' ');
      }
      formatted.write(input[i]);
    }
    
    // Calculate new cursor position
    int cursorPosition = formatted.length;
    
    // If the user is deleting, adjust cursor position accordingly
    if (oldValue.text.length > newValue.text.length) {
      // If the character before the cursor was a space, move back one more position
      final oldText = oldValue.text;
      final selectionStart = newValue.selection.start;
      
      if (selectionStart < oldText.length && oldText[selectionStart] == ' ') {
        cursorPosition = selectionStart - 1;
      } else {
        cursorPosition = newValue.selection.start;
      }
    }
    
    return TextEditingValue(
      text: formatted.toString(),
      selection: TextSelection.collapsed(offset: cursorPosition),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
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
  String? _selectedCardType = ''; // Default card type
  final _cardNumberController = TextEditingController();
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
        _selectedCardType = profile.selectedCardType;
        _cardNumberController.text = profile.cardNumber;
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
      _scrollToFirstError();
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
        selectedCardType: _selectedCardType,
        cardNumber: _cardNumberController.text.trim(),
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

  void _clearUserProfile() {
    _storageService.clearUserProfile();
  }

  Future<void> deleteAccount() async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    setState(() => _isLoading = true);

    try {
      String response = await _apiService.deleteUserProfile(user_id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response)),
        );
        
        if(response == "Your account is successfully deleted") {
          _clearUserProfile();

          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => LoginScreen()),
            (Route<dynamic> route) => false,
          );
        } 
      }
    } catch (e) {
      debugPrint('Error deleting user profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete profile')),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: colorScheme.primaryContainer,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete Account', style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
            onSelected: (String value) async {
              if (value == 'delete') {
                final confirmed = await showDialog(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: const Text('Confirm Deletion'),
                    content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                
                if (confirmed == true) {
                  await deleteAccount();
                }
              }
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isLargeScreen = constraints.maxWidth > 768;
          final double avatarRadius = isLargeScreen ? 80 : 60;
          final double horizontalPadding = isLargeScreen ? 32.0 : 16.0;
          final double verticalPadding = isLargeScreen ? 24.0 : 16.0;

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 1200 : double.infinity,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildAvatarSection(avatarRadius, colorScheme),
                      const SizedBox(height: 24),
                      if (isLargeScreen) ...[
                        _buildGridFormFields(colorScheme),
                      ] else ...[
                        _buildColumnFormFields(colorScheme),
                      ],
                      const SizedBox(height: 16),
                      _buildSaveButton(colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatarSection(double radius, ColorScheme colorScheme) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: radius,
              backgroundColor: colorScheme.primary.withOpacity(0.2),
              backgroundImage: _selectedImage != null
                  ? FileImage(File(_selectedImage!.path))
                  : null,
              child: _selectedImage == null
                  ? Icon(
                      Icons.person,
                      size: radius,
                      color: colorScheme.primary,
                    )
                  : null,
            ),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _pickImage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Update Profile Picture',
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildGridFormFields(ColorScheme colorScheme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 8,
      crossAxisSpacing: 16,
      mainAxisSpacing: 12,
      children: [
        _buildTextField(
          key: _firstNameKey,
          controller: _firstNameController,
          labelText: 'First Name',
          icon: Icons.person,
          colorScheme: colorScheme,
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
        _buildTextField(
          key: _middleNameKey,
          controller: _middleNameController,
          labelText: 'Middle Name',
          icon: Icons.person,
          colorScheme: colorScheme,
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
        _buildTextField(
          key: _lastNameKey,
          controller: _lastNameController,
          labelText: 'Last Name',
          icon: Icons.person,
          colorScheme: colorScheme,
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
        _buildTextField(
          key: _phoneNumberKey,
          controller: _phoneNumberController,
          labelText: 'Phone Number',
          icon: Icons.phone,
          colorScheme: colorScheme,
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
        _buildCardNumberInput(),
        _buildTextField(
          key: _emailKey,
          controller: _emailController,
          labelText: 'Email',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          colorScheme: colorScheme,
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
        const SizedBox.shrink(), // Empty space to balance the grid
        _buildPasswordField(
          key: _passwordKey,
          controller: _passwordController,
          labelText: 'Password',
          isPasswordVisible: _isPasswordVisible,
          colorScheme: colorScheme,
          onVisibilityChanged: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
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
        _buildPasswordField(
          key: _confirmPasswordKey,
          controller: _confirmPasswordController,
          labelText: 'Confirm Password',
          isPasswordVisible: _isConfirmPasswordVisible,
          colorScheme: colorScheme,
          onVisibilityChanged: () {
            setState(() {
              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
            });
          },
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
        _buildTextField(
          key: _regionKey,
          controller: _regionController,
          labelText: 'Region',
          icon: Icons.location_city,
          colorScheme: colorScheme,
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
        _buildTextField(
          key: _districtKey,
          controller: _districtController,
          labelText: 'District',
          icon: Icons.map,
          colorScheme: colorScheme,
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
        _buildTextField(
          key: _wardKey,
          controller: _wardController,
          labelText: 'Ward',
          icon: Icons.location_on,
          colorScheme: colorScheme,
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
        _buildTextField(
          key: _streetKey,
          controller: _streetController,
          labelText: 'Street',
          icon: Icons.home,
          colorScheme: colorScheme,
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
      ],
    );
  }

  Widget _buildColumnFormFields(ColorScheme colorScheme) {
    return Column(
      children: [
        _buildTextField(
          key: _firstNameKey,
          controller: _firstNameController,
          labelText: 'First Name',
          icon: Icons.person,
          colorScheme: colorScheme,
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
        const SizedBox(height: 12),
        _buildTextField(
          key: _middleNameKey,
          controller: _middleNameController,
          labelText: 'Middle Name',
          icon: Icons.person,
          colorScheme: colorScheme,
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
        const SizedBox(height: 12),
        _buildTextField(
          key: _lastNameKey,
          controller: _lastNameController,
          labelText: 'Last Name',
          icon: Icons.person,
          colorScheme: colorScheme,
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
        const SizedBox(height: 12),
        _buildTextField(
          key: _phoneNumberKey,
          controller: _phoneNumberController,
          labelText: 'Phone Number',
          icon: Icons.phone,
          colorScheme: colorScheme,
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
        const SizedBox(height: 12),
        _buildCardNumberInput(),
        const SizedBox(height: 12),
        _buildTextField(
          key: _emailKey,
          controller: _emailController,
          labelText: 'Email',
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
          colorScheme: colorScheme,
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
        const SizedBox(height: 12),
        _buildPasswordField(
          key: _passwordKey,
          controller: _passwordController,
          labelText: 'Password',
          isPasswordVisible: _isPasswordVisible,
          colorScheme: colorScheme,
          onVisibilityChanged: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
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
        const SizedBox(height: 12),
        _buildPasswordField(
          key: _confirmPasswordKey,
          controller: _confirmPasswordController,
          labelText: 'Confirm Password',
          isPasswordVisible: _isConfirmPasswordVisible,
          colorScheme: colorScheme,
          onVisibilityChanged: () {
            setState(() {
              _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
            });
          },
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
        const SizedBox(height: 12),
        _buildTextField(
          key: _regionKey,
          controller: _regionController,
          labelText: 'Region',
          icon: Icons.location_city,
          colorScheme: colorScheme,
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
        const SizedBox(height: 12),
        _buildTextField(
          key: _districtKey,
          controller: _districtController,
          labelText: 'District',
          icon: Icons.map,
          colorScheme: colorScheme,
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
        const SizedBox(height: 12),
        _buildTextField(
          key: _wardKey,
          controller: _wardController,
          labelText: 'Ward',
          icon: Icons.location_on,
          colorScheme: colorScheme,
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
        const SizedBox(height: 12),
        _buildTextField(
          key: _streetKey,
          controller: _streetController,
          labelText: 'Street',
          icon: Icons.home,
          colorScheme: colorScheme,
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
      ],
    );
  }

  Widget _buildTextField({
    required GlobalKey key,
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    required ColorScheme colorScheme,
    required String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.7),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          icon,
          color: colorScheme.primary,
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2.0,
          ),
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
        isDense: true,
      ),
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 15,
      ),
      validator: validator,
    );
  }

  Widget _buildPasswordField({
    required GlobalKey key,
    required TextEditingController controller,
    required String labelText,
    required bool isPasswordVisible,
    required ColorScheme colorScheme,
    required VoidCallback onVisibilityChanged,
    required String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      obscureText: !isPasswordVisible,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.7),
          fontSize: 14,
        ),
        prefixIcon: Icon(
          Icons.lock,
          color: colorScheme.primary,
          size: 20,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.5),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: colorScheme.outline.withOpacity(0.5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.0),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2.0,
          ),
        ),
        filled: true,
        fillColor: colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
        isDense: true,
        suffixIcon: IconButton(
          icon: Icon(
            isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: colorScheme.onSurface.withOpacity(0.6),
            size: 20,
          ),
          onPressed: onVisibilityChanged,
        ),
      ),
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 15,
      ),
      validator: validator,
    );
  }

  Widget _buildCardNumberInput() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Card Number',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          
          // Card Type Selection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[400]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCardType, // You'll need to define this variable
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.black54),
                items: const [
                  DropdownMenuItem(
                    value: 'Uhai Card',
                    child: Text('Uhai Card', style: TextStyle(fontSize: 16)),
                  ),
                  DropdownMenuItem(
                    value: 'NCard',
                    child: Text('NCard', style: TextStyle(fontSize: 16)),
                  ),
                ],
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCardType = newValue;
                    _cardNumberController.text = "";
                  });
                },
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Card Number Input
          TextFormField(
            controller: _cardNumberController, // You'll need to define this controller
            decoration: InputDecoration(
              hintText: 'Enter your card number',
              prefixIcon: const Icon(Icons.credit_card),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[400]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.orange[800]!, width: 2.0),
              ),
              filled: true,
              fillColor: Colors.grey[200],
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            style: const TextStyle(fontSize: 16),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(19), // Standard card number length
              CardNumberFormatter(), // You'll need to create this formatter for spacing
            ],
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your card number';
              }
              
              // Remove any spaces for validation
              final cleanedValue = value.replaceAll(' ', '');
              
              if (cleanedValue.length < 12) {
                return 'Card number is too short';
              }
              
              // Basic Luhn algorithm validation for card numbers
              if (!_isValidLuhn(cleanedValue)) {
                return 'Invalid card number';
              }
              
              return null;
            },
          ),
        ],
      ),
    );
  }

  // Luhn algorithm validator function
  bool _isValidLuhn(String cardNumber) {
    // Remove any spaces or non-digit characters
    String cleanedInput = cardNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanedInput.isEmpty) {
      return false;
    }
    
    int sum = 0;
    bool shouldDouble = false;
    
    // Process digits from right to left
    for (int i = cleanedInput.length - 1; i >= 0; i--) {
      int digit = int.parse(cleanedInput[i]);
      
      if (shouldDouble) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }
      
      sum += digit;
      shouldDouble = !shouldDouble;
    }
    
    return (sum % 10 == 0);
  }

  // Optional: Card type detection based on initial digits
  String? _detectCardType(String cardNumber) {
    // Remove any spaces or non-digit characters
    String cleanedInput = cardNumber.replaceAll(RegExp(r'[^\d]'), '');
    
    if (cleanedInput.isEmpty) {
      return null;
    }
    
    // Uhai Card pattern (example: starts with 4)
    if (cleanedInput.startsWith('4')) {
      return 'Uhai Card';
    }
    
    // NCard pattern (example: starts with 5)
    if (cleanedInput.startsWith('5')) {
      return 'NCard';
    }
    
    return null;
  }

  // Optional: Auto-format card number method
  String formatCardNumber(String input) {
    // Remove all non-digit characters
    String digitsOnly = input.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.isEmpty) {
      return '';
    }
    
    StringBuffer formatted = StringBuffer();
    
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted.write(' ');
      }
      formatted.write(digitsOnly[i]);
      
      // Limit to 16 digits (standard card length)
      if (i >= 15) {
        break;
      }
    }
    
    return formatted.toString();
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            elevation: 2,
            shadowColor: colorScheme.shadow,
          ),
          child: _isLoading 
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: colorScheme.onPrimary,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}