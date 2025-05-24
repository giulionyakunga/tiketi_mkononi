import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/services/api_service.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameKey = GlobalKey();
  final _phoneNumberKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _messageKey = GlobalKey();

  int user_id = 0;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _messageController = TextEditingController();
  
  String token = "";
  String role = "";
  
  final _apiService = ApiService(); 
  late final StorageService _storageService;
  bool _isLoading = false;
  bool _sent = false;

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
        _nameController.text = profile.firstName;
        _emailController.text = profile.email;
        _phoneNumberController.text = profile.phoneNumber;        
        token = profile.token;
        role = profile.role;
      });
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

  Future<void> sendMessage() async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError(); // Scroll to the first error field
      return;
    }

    setState(() => _isLoading = true);

    try {
      String response = await _apiService.sendMessage(
        user_id, 
        _nameController.text.trim(), 
        _phoneNumberController.text.trim(), 
        _emailController.text.trim(), 
        _messageController.text.trim()
      );

      if (mounted) {
        if(response == "Your message was Sent successfully!") {
          setState(() => _sent = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response)),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sending the message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
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
    _nameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  Future<void> _launchEmailApp({ required String recipient, String? subject, String? body}) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: recipient,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );

    try {
      await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch email: $e')),
      );
    }
  }


  // Helper method to determine if the screen is considered "large"
  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 600;
  }

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = _isLargeScreen(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 800 : double.infinity,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 32 : 16,
              vertical: 16,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLargeScreen) ...[
                    const Text(
                      'Contact Us',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Fill out the form below to get in touch with our support team.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _buildInputField(
                    context: context,
                    key: _firstNameKey,
                    controller: _nameController,
                    label: 'First Name',
                    icon: Icons.person,
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
                  _buildInputField(
                    context: context,
                    key: _phoneNumberKey,
                    controller: _phoneNumberController,
                    label: 'Phone Number',
                    icon: Icons.phone,
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
                  _buildInputField(
                    context: context,
                    key: _emailKey,
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
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
                  _buildMessageField(context),
                  const SizedBox(height: 24),
                  _buildSubmitButton(context),
                  const SizedBox(height: 32),
                  _buildContactInfoSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required BuildContext context,
    required GlobalKey key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 16,
        ),
        prefixIcon: Icon(
          icon,
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
          borderSide: BorderSide(
            color: Colors.orange[800]!,
            width: 2.0,
          ),
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16.0,
          horizontal: 16.0,
        ),
      ),
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 16,
      ),
      validator: validator,
    );
  }

  Widget _buildMessageField(BuildContext context) {
    return TextFormField(
      key: _messageKey,
      controller: _messageController,
      maxLength: 1000,
      decoration: InputDecoration(
        labelText: 'Message',
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontSize: 16,
        ),
        hintText: 'Enter the message here...',
        hintStyle: TextStyle(
          color: Colors.grey[500],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Colors.grey[400]!,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Colors.orange[800]!,
            width: 2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: Colors.grey[400]!,
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: Colors.grey[200],
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 12,
        ),
      ),
      maxLines: 5,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter message';
        }
        if (value.length > 1000) {
          return 'message must be 1000 characters or less';
        }
        return null;
      },
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: (_isLoading || _sent) ? null : sendMessage,
        style: ElevatedButton.styleFrom(
          backgroundColor: _sent ? Colors.green : Theme.of(context).primaryColor,
          disabledBackgroundColor: _sent ? Colors.green : Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: _isLoading
            ? const CircularProgressIndicator()
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _sent ? Icons.check : Icons.send,
                    size: 20,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _sent ? 'Message Sent' : 'Send Message',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Other Ways to Reach Us',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        _buildContactInfoItem(
          icon: Icons.location_on,
          title: 'Call Us',
          subtitle: '+255 766 032 160',
          contactType: "phone number",
        ),
        const SizedBox(height: 12),
        _buildContactInfoItem(
          icon: Icons.email,
          title: 'Email Us',
          subtitle: 'tiketimkononi@telabs.co.tz',
          contactType: "email",
        ),
        const SizedBox(height: 12),
        _buildContactInfoItem(
          icon: Icons.location_on,
          title: 'Visit Us',
          subtitle: 'Uganda Street, Dar es Salaam, Tanzania',
          contactType: "",
        ),
      ],
    );
  }

  Widget _buildContactInfoItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String contactType,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.orange[800],
          size: 24,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if(contactType == "phone number")
              TextButton(
                onPressed: () => _launchPhoneCall(subtitle),               
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if(contactType == "email")
              TextButton(
                onPressed: () => _launchEmailApp(
                  recipient: subtitle,
                  subject: 'App Feedback',
                  body: 'Hello, I would like to share some feedback about your app...',
                ),               
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (contactType == "")
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        )
      ],
    );
  }
}