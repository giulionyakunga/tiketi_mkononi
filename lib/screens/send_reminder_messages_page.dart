import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/card_view_page.dart';
import 'package:tiketi_mkononi/screens/event_tickets_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

class SendReminderMessagesPage extends StatefulWidget {
  final Event event;

  const SendReminderMessagesPage({super.key, required this.event});

  @override
  State<SendReminderMessagesPage> createState() => _SendReminderMessagesPageState();
}

class _SendReminderMessagesPageState extends State<SendReminderMessagesPage> with TickerProviderStateMixin {
  int userId = 0;
  String role = "";
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _familyNameController = TextEditingController();
  final _networkNameAccountNumber1Controller = TextEditingController();
  final _networkNameAccountNumber2Controller = TextEditingController();
  final _accountNameController = TextEditingController();
  final _accountName2Controller = TextEditingController();
  String? fileType;
  bool _isLoading = false;


  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String _ticketType = '';
  double _ticketPrice = 0.0;
  final Map<String, double> ticketTypePriceMap = {};

      // const { user_id, event_id, family_name, account_name_account_number_1, account_name_account_number_2, account_name, document_type, document_name, document_file } = req.body;


  
  bool useDNS = true;
  late TabController _tabController;

  String base64File = "";
  String? fileType2;
  String? fileName;

  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.event.name;
    _familyNameController.text = widget.event.familyName;
    _networkNameAccountNumber1Controller.text = widget.event.networkNameAccountNumber1;
    _networkNameAccountNumber2Controller.text = widget.event.networkNameAccountNumber2;
    _accountNameController.text = widget.event.accountName;
    _accountName2Controller.text = widget.event.accountName2;

    _initializeServices();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _fullNameController.dispose();
    _familyNameController.dispose();
    _networkNameAccountNumber1Controller.dispose();
    _networkNameAccountNumber2Controller.dispose();
    _accountNameController.dispose();
    _accountName2Controller.dispose();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      useDNS = prefs.getBool('use_dns') ?? true;
    });

    _storageService = StorageService(prefs);
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final profile = _storageService.getUserProfile();
    if (profile != null) {
      setState(() {
        userId = profile.id;
        role = profile.role;
      });

      if (profile.role == "user") {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sorry! You can't generate cards")),
        );
      }
    }
  }

  void _scrollToFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }
  
  Future<void> _sendReminserMessages({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    debugPrint('document_type : ${fileType2}');
    debugPrint('document_name : ${fileName}');

    String familyName = _familyNameController.text.trim();
    if (familyName.isNotEmpty) {
      final lower = familyName.toLowerCase();

      if (!lower.startsWith('family') && !lower.startsWith('familia')) {
        familyName = 'Familia ya $familyName';
      }
    }
    String networkNameAccountNumber1 = _networkNameAccountNumber1Controller.text.trim(); 
    String networkNameAccountNumber2 = _networkNameAccountNumber2Controller.text.trim();
    String accountName = _accountNameController.text.trim();
    String accountName2 = _accountName2Controller.text.trim();

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'event_id': widget.event.id,
      'family_name': familyName,
      'network_name_account_number_1': networkNameAccountNumber1,
      'network_name_account_number_2': networkNameAccountNumber2,
      'account_name': accountName,
      'account_name_2': accountName2,
      'document_type': fileType2,
      'document_name': fileName,
      'document_file': base64File,
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/send_reminder_messages') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}send_reminder_messages'); // Use IP

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Reminder messages were sent successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
          Navigator.pop(context);
        } else {
          try {
            final Uint8List bytes = response.bodyBytes;

            // Get temp directory
            final directory = await getTemporaryDirectory();

            final filePath = '${directory.path}/updated_file_${DateTime.now().millisecondsSinceEpoch}.xlsx';

            final file = File(filePath);

            await file.writeAsBytes(bytes, flush: true);

            // Open the Excel file
            final result = await OpenFilex.open(filePath);

            debugPrint('Open result: ${result.message}');
          } catch (e) {
            debugPrint('Failed to open Excel file: $e');
          }
        }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        if (response.statusCode == 413) {
          _showSnackBar('Request failed: Image is Too Large');
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
        }
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
          await _sendReminserMessages(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendIndividualReminserMessage({bool useDNS = true}) async {

    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipient name can\'t be empty')),
      );
      return;
    }

    if (_phoneNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recipient phone number can\'t be empty')),
      );
      return;
    }

    if (_familyNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Family name can\'t be empty')),
      );
      return;
    }

    if (_networkNameAccountNumber1Controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NetworkName:AccountNumber can\'t be empty')),
      );
      return;
    }

    if (_accountNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account name can\'t be empty')),
      );
      return;
    }

    if (_networkNameAccountNumber2Controller.text.trim().isEmpty && _accountName2Controller.text.trim().isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NetworkName:AccountNumber2 can\'t be empty')),
      );
      return;
    }

    String familyName = _familyNameController.text.trim();
    if (familyName.isNotEmpty) {
      final lower = familyName.toLowerCase();

      if (!lower.startsWith('family') && !lower.startsWith('familia')) {
        familyName = 'Familia ya $familyName';
      }
    }
    String fullName = _fullNameController.text.trim();
    String phoneNumber = _phoneNumberController.text.trim();
    String networkNameAccountNumber1 = _networkNameAccountNumber1Controller.text.trim(); 
    String networkNameAccountNumber2 = _networkNameAccountNumber2Controller.text.trim();
    String accountName = _accountNameController.text.trim();
    String accountName2 = _accountName2Controller.text.trim();

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'event_id': widget.event.id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'family_name': familyName,
      'network_name_account_number_1': networkNameAccountNumber1,
      'network_name_account_number_2': networkNameAccountNumber2,
      'account_name': accountName,
      'account_name_2': accountName2,
      'document_type': fileType2,
      'document_name': fileName,
      'document_file': base64File,
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/send_individual_reminder_message') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}send_individual_reminder_message'); // Use IP

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Reminder message was sent successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
          Navigator.pop(context);
        } else {
          try {
            final Uint8List bytes = response.bodyBytes;

            // Get temp directory
            final directory = await getTemporaryDirectory();

            final filePath = '${directory.path}/updated_file_${DateTime.now().millisecondsSinceEpoch}.xlsx';

            final file = File(filePath);

            await file.writeAsBytes(bytes, flush: true);

            // Open the Excel file
            final result = await OpenFilex.open(filePath);

            debugPrint('Open result: ${result.message}');
          } catch (e) {
            debugPrint('Failed to open Excel file: $e');
          }
        }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        if (response.statusCode == 413) {
          _showSnackBar('Request failed: Image is Too Large');
        } else {
          _showSnackBar('Request failed: ${response.statusCode}');
        }
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
          await _sendIndividualReminserMessage(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
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

  InputDecoration _buildInputDecoration(String label, {String? prefixText, IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      prefixIcon: (prefixIcon != null) ? Icon(
        prefixIcon,
        color: Colors.grey[600],
      ) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.orange[800]!, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    );
  }

  // Helper method for feature chips
  Widget _buildFeatureChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue[100]!, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.blue[700]),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExcelTabContent(bool isLargeScreen) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isLargeScreen ? 32 : 16,
        vertical: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.orange[700]!,
                        Colors.orange[900]!,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.notifications_active,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Send Contribution Reminders',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 28 : 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[900],
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 80 : 20),
                  child: Text(
                    'Remind your invited guests to contribute to your wedding collection (mchango) by sending polite and timely reminder messages.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isLargeScreen ? 16 : 14,
                      color: Colors.grey[600],
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFeatureChip(Icons.group_rounded, 'Group Reminders'),
                    const SizedBox(width: 2),
                    _buildFeatureChip(Icons.notifications_active_rounded, 'Timely Alerts'),
                    const SizedBox(width: 2),
                    _buildFeatureChip(Icons.send_rounded, 'Easy Sending'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              enabled: false,
              maxLength: 100,
              decoration: _buildInputDecoration('Event Name', prefixIcon: Icons.emoji_events),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter event name';
                if (value.length > 100) return 'Event name must be 100 characters or less';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _familyNameController,
              maxLength: 50,
              decoration: _buildInputDecoration('Family Name', prefixIcon: Icons.emoji_events),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter family name';
                if (value.length > 50) return 'Family must be 50 characters or less';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _networkNameAccountNumber1Controller,
              maxLength: 50,
              decoration: _buildInputDecoration('NetworkName:AccountNumber', prefixIcon: Icons.emoji_events),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter account name and number';
                if (value.length > 50) return 'Account name and number must be 50 characters or less';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNameController,
              maxLength: 50,
              decoration: _buildInputDecoration('Account Name', prefixIcon: Icons.emoji_events),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter account name';
                if (value.length > 50) return 'Account name must be 50 characters or less';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _networkNameAccountNumber2Controller,
              maxLength: 50,
              decoration: _buildInputDecoration('NetworkName:AccountNumber2', prefixIcon: Icons.emoji_events),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter account name and number';
                if (value.length > 50) return 'Account name and number must be 50 characters or less';
                return null;
              },
            ),
            const SizedBox(height: 16),
             TextFormField(
              controller: _accountName2Controller,
              maxLength: 50,
              decoration: _buildInputDecoration('Account Name', prefixIcon: Icons.emoji_events),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter account name';
                if (value.length > 50) return 'Account name must be 50 characters or less';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  FilePickerResult? result = await FilePicker.platform.pickFiles();

                  if (result != null && result.files.isNotEmpty) {
                    PlatformFile platformFile = result.files.first;
                    
                    List<int> bytes;
                    
                    if (kIsWeb) {
                      // For web - use the bytes directly from platformFile
                      bytes = platformFile.bytes!;
                    } else {
                      // For mobile/desktop - read from file path
                      File file = File(platformFile.path!);
                      bytes = await file.readAsBytes();
                    }

                    final String? mimeType = lookupMimeType(platformFile.name, headerBytes: bytes);
                    final String selectedfileName = platformFile.name;

                    // Check if it's an Excel file
                    final bool isExcel = mimeType == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' || 
                    mimeType == 'application/vnd.ms-excel' ||
                    selectedfileName.toLowerCase().endsWith('.xlsx') ||
                    selectedfileName.toLowerCase().endsWith('.xls');

                    if (isExcel) {
                      setState(() {
                        fileType2 = lookupMimeType(platformFile.name) ?? 'application/octet-stream';
                        fileName = platformFile.name;
                        base64File = base64Encode(bytes);
                      });
                    } else {
                      debugPrint('Selected file is NOT an Excel file: $selectedfileName');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a valid Excel file (.xls or .xlsx).')),
                      );
                    }

                    debugPrint('File selected: $fileName, Size: ${bytes.length} bytes, type: $fileType2');
                  } else {
                    debugPrint('No file selected');
                  }
                } catch (e) {
                  debugPrint('Error picking file: $e');
                  // Show error to user if needed
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error selecting file: $e'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.attach_file, size: 20),
              label: Text((fileName != null) ? 'Selected: $fileName' : 'Choose Excel File'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey[400]!),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: isLargeScreen ? 400 : double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendReminserMessages,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  backgroundColor: Colors.orange[800],
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Send Reminder Messages',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOneTabContent(bool isLargeScreen) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_active, 
              size: 64,
              color: Colors.orange[800],
            ),
            const SizedBox(height: 16),
            Text(
              'Send Individual Reminder',
              style: TextStyle(
                fontSize: isLargeScreen ? 24 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send a polite reminder message to a single guest about the wedding contribution (mchango).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isLargeScreen ? 16 : 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nameController,
              enabled: false,
              maxLength: 100,
              decoration: _buildInputDecoration('Event Name', prefixIcon: Icons.emoji_events),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter event name';
                if (value.length > 100) return 'Event name must be 100 characters or less';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullNameController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Recipient Name',
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
                  borderSide: BorderSide(
                    color: Colors.orange[800]!,
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 16.0),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter recipient name';
                }
                if (value.length > 50) {
                  return 'Recipient name must be 50 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneNumberController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Recipient Phone Number',
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
                  borderSide: BorderSide(
                    color: Colors.orange[800]!,
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 16.0),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter recipient phone number';
                }

                final phone = value.trim();

                if (phone.length > 15) {
                  return 'Recipient phone number can\'t exceed 15 characters';
                }

                final regex = RegExp(r'^(0\d{9}|255\d{9})$');

                if (!regex.hasMatch(phone)) {
                  return 'Invalid number format. Use 0XXXXXXXXX or 255XXXXXXXXX';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),              
            TextFormField(
              controller: _familyNameController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Family Name',
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
                  borderSide: BorderSide(
                    color: Colors.orange[800]!,
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 16.0),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter family name';
                }

                final familyName = value.trim();

                if (familyName.length > 50) {
                  return 'Family name can\'t exceed 50 characters';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _networkNameAccountNumber1Controller,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Network Name:Account Number',
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
                  borderSide: BorderSide(
                    color: Colors.orange[800]!,
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 16.0),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter network name:account number';
                }

                final networkNameAccountNumber = value.trim();

                if (networkNameAccountNumber.length > 50) {
                  return 'Network name:account number exceed 50 characters';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
             TextFormField(
              controller: _accountNameController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Account name',
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
                  borderSide: BorderSide(
                    color: Colors.orange[800]!,
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 16.0),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter account name';
                }

                final accountName = value.trim();

                if (accountName.length > 50) {
                  return 'Account name can\'t exceed 50 characters';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _networkNameAccountNumber2Controller,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Network Name:Account Number',
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
                  borderSide: BorderSide(
                    color: Colors.orange[800]!,
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 16.0),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return null;
                }

                final networkNameAccountNumber = value.trim();

                if (networkNameAccountNumber.length > 50) {
                  return 'Network name:account number exceed 50 characters';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountName2Controller,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Account name',
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
                  borderSide: BorderSide(
                    color: Colors.orange[800]!,
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 16.0),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter account name';
                }

                final accountName = value.trim();

                if (accountName.length > 50) {
                  return 'Account name can\'t exceed 50 characters';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: isLargeScreen ? 400 : double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendIndividualReminserMessage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  backgroundColor: Colors.orange[800],
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Send Reminder Message',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      )
    );
  }

  Widget _buildMobileLayout(bool isDarkMode, bool isLargeScreen) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Send Reminder Messages',
            style: TextStyle(
              fontSize: 18,
            )
          ),
          centerTitle: false,
          titleSpacing: 0,
          backgroundColor: const Color.fromARGB(255, 240, 244, 247),
          actions: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.remove_red_eye,
                color: Colors.orange[800],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CardViewPage(event: widget.event),
                  ),
                );
              },
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.receipt,
                color: Colors.orange[800],
              ),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EventTicketsPage(event: widget.event),
                  ),
                );
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Use Excel'),
              Tab(text: 'Send One'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Use Excel tab
            _buildExcelTabContent(isLargeScreen),
            
            // Add One tab (you'll implement this)
            _buildAddOneTabContent(isLargeScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(bool isDarkMode, bool isLargeScreen) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Cards'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          IconButton(
            icon: Icon(
              Icons.remove_red_eye,
              color: Colors.orange[800],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CardViewPage(event: widget.event),
                ),
              );
            },
          ),
          ElevatedButton.icon(
            icon: Icon(
              Icons.logout,
            ),
            label: Text(
              'Tickets(${widget.event.soldTickets})', 
              style: TextStyle(
                fontSize: 14,
              )
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange[800],
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => EventTicketsPage(event: widget.event),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 1000 : double.infinity,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 32 : 16,
              vertical: 1,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLargeScreen) ...[
                    const Text(
                      'Generate cards',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    enabled: false,
                    maxLength: 100,
                    decoration: _buildInputDecoration('Event Name', prefixIcon: Icons.emoji_events),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter event name';
                      if (value.length > 100) return 'Event name must be 100 characters or less';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        FilePickerResult? result = await FilePicker.platform.pickFiles();

                        if (result != null && result.files.isNotEmpty) {
                          PlatformFile platformFile = result.files.first;
                          
                          List<int> bytes;
                          
                          if (kIsWeb) {
                            // For web - use the bytes directly from platformFile
                            bytes = platformFile.bytes!;
                          } else {
                            // For mobile/desktop - read from file path
                            File file = File(platformFile.path!);
                            bytes = await file.readAsBytes();
                          }

                          final String? mimeType = lookupMimeType(platformFile.name, headerBytes: bytes);
                          final String selectedfileName = platformFile.name;

                          // Check if it's an Excel file
                          final bool isExcel = mimeType == 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' || 
                          mimeType == 'application/vnd.ms-excel' ||
                          selectedfileName.toLowerCase().endsWith('.xlsx') ||
                          selectedfileName.toLowerCase().endsWith('.xls');

                          if (isExcel) {
                            setState(() {
                              fileType2 = lookupMimeType(platformFile.name) ?? 'application/octet-stream';
                              fileName = platformFile.name;
                              base64File = base64Encode(bytes);
                            });
                          } else {
                            debugPrint('Selected file is NOT an Excel file: $selectedfileName');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please select a valid Excel file (.xls or .xlsx).')),
                            );
                          }

                          debugPrint('File selected: $fileName, Size: ${bytes.length} bytes, type: $fileType2');
                        } else {
                          debugPrint('No file selected');
                        }
                      } catch (e) {
                        debugPrint('Error picking file: $e');
                        // Show error to user if needed
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error selecting file: $e'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.attach_file, size: 20),
                    label: Text((fileName != null) ? 'Selected: $fileName' : 'Choose Files'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[100],
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  SizedBox(
                    width: isLargeScreen ? 400 : double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendReminserMessages,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange[800],
                      ),
                      child: _isLoading 
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Send Reminder Messages',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return isDesktop ? _buildDesktopLayout(isDarkMode, isLargeScreen) : _buildMobileLayout(isDarkMode, isLargeScreen);
  }
}