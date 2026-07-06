import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:tiketi_mkononi/l10n/app_localizations.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/card_view_page.dart';
import 'package:tiketi_mkononi/screens/event_tickets_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

class GenerateCardsPage extends StatefulWidget {
  final Event event;

  const GenerateCardsPage({super.key, required this.event});

  @override
  State<GenerateCardsPage> createState() => _GenerateCardsPageState();
}

class _GenerateCardsPageState extends State<GenerateCardsPage> with TickerProviderStateMixin {
  int userId = 0;
  String role = "";
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _imagePickerKey = GlobalKey();
  final _nameController = TextEditingController();
  XFile? _eventImage;
  Uint8List? _webImageBytes;
  String? fileType;
  bool _isLoading = false;
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _maxScanTimesController = TextEditingController();
  final _extraInfoController = TextEditingController();
  String _ticketType = '';
  double _ticketPrice = 0.0;
  final Map<String, double> ticketTypePriceMap = {};
  String selectedPaymentMethod = 'MIXX BY YAS';
  final List<String> paymentMethods = ['MIXX BY YAS', 'M-PESA', 'AIRTEL MONEY', 'HALOPESA', 'AZAMPESA'];
  int cardsBalance = 0;

  List<dynamic> cardPackages = [];
  
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
    _initializeServices();
    _loadNumberOfCards();

    _getTicketTypes(widget.event.ticketTypes);
    _tabController = TabController(length: 2, vsync: this);
  }

  void _getTicketTypes(List<TicketType> ticketTypes) {
    ticketTypes.forEach((ticketType) {
      setState(() {
        ticketTypePriceMap[ticketType.name] = ticketType.price;
      });
      _ticketType = ticketTypePriceMap.keys.first;

      _maxScanTimesController.text = ticketTypePriceMap.keys.first.trim().toUpperCase() == 'DOUBLE' ? '2' : '1';
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _maxScanTimesController.dispose();
    _extraInfoController.dispose();
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

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        String? mimeType;
        String fileExtension;

        if (kIsWeb) {
          // On web, use `image.name` instead of `image.path`
          fileExtension = path.extension(image.name).toLowerCase();
          mimeType = lookupMimeType(image.name);

          // Read image as bytes for web
          final bytes = await image.readAsBytes();
          _webImageBytes = bytes;
        } else {
          fileExtension = path.extension(image.path).toLowerCase();
          mimeType = lookupMimeType(image.path);
        }

        if (mimeType == null || !mimeType.startsWith('image/')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid file type. Please select a valid image.')),
          );
          return;
        }

        if (fileExtension != '.png' && fileExtension != '.jpg' && fileExtension != '.jpeg') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unsupported image format. Only PNG and JPEG are allowed.')),
          );
          return;
        }

        setState(() {
          _eventImage = image;
          fileType = fileExtension;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }
  
  Future<void> _generateTickets({bool useDNS = true}) async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    if (widget.event.cardUrl.isEmpty && _eventImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select event card')),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Scrollable.ensureVisible(
          _imagePickerKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      });
      return;
    }

    debugPrint('widget.event.cardUrl : ${widget.event.cardUrl}');
    debugPrint('document_type : ${fileType2}');
    debugPrint('document_name : ${fileName}');

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'event_id': widget.event.id,
      'name': widget.event.name,      
      'image_type': (_eventImage != null) ? fileType : null,
      'image_file': (_eventImage != null) ? kIsWeb ? _webImageBytes : base64Encode(await File(_eventImage!.path).readAsBytes()) : null,
      'document_type': fileType2,
      'document_name': fileName,
      'document_file': base64File,
    };

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/generate_cards') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}generate_cards'); // Use IP

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Event cards were generated successfully!") {
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

        // Clear the file selection
        setState(() {
          base64File = "";
          fileName = null;
          fileType = null;
          fileType2 = null;
        });
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
          await _generateTickets(useDNS: false); // Recursive retry

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

  Future<void> _addTicket({bool useDNS = true}) async {

    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Holder\'s names can\'t be empty')),
      );
      return;
    }

    if (_phoneNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Holder\'s phone number can\'t be empty')),
      );
      return;
    }

    String fullName = _fullNameController.text.trim();
    String phoneNumber = _phoneNumberController.text.trim();
    String maxScanTimes = _maxScanTimesController.text.trim();
    String extraInfo = _extraInfoController.text.trim();
    if(_ticketType.trim().toUpperCase() == 'DOUBLE') {
       maxScanTimes = '2';
    } else if(_ticketType.trim().toUpperCase() == 'SINGLE') {
       maxScanTimes = '1';
    } 

    final Map<String, dynamic> requestBody = {
      'user_id': userId,
      'event_id': widget.event.id,
      'user_name': fullName,
      'user_phone_number': phoneNumber,
      'ticket_type': _ticketType,
      'ticket_price': _ticketPrice,
      'extra_info': extraInfo,
      'max_scan_times': maxScanTimes,
    };

    try {
      setState(() {
        _isLoading = true;
      });

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/add_ticket') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}add_ticket'); // Use IP

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String message = responseData['message'];

        setState(() {
          cardsBalance = responseData['number_of_sms'] ?? 0;
        });

        _saveCardsBalance(cardsBalance);

        if (message.trim() == "Ticket added successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        } else if (message.trim() == "Kifurushi chako kimeisha!") {
          await getCardPackages();
          _payDialog();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message.trim())),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Response: $message')),
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
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _addTicket(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
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

  Widget _buildImagePicker(bool isLargeScreen) {
    return GestureDetector(
      key: _imagePickerKey,
      onTap: _pickImage,
      child: Container(
        height: isLargeScreen ? 300 : 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: _eventImage != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: kIsWeb ? 
            Image.memory(
              _webImageBytes!,
              fit: BoxFit.cover,
            ) :
            Image.file(
              File(_eventImage!.path),
              fit: BoxFit.cover,
            ),
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate, size: isLargeScreen ? 64 : 48),
              const SizedBox(height: 8),
              const Text('Add Event Card (700x1080)'),
            ],
          ),
      ),
    );
  }

  // Helper method for feature chips
Widget _buildFeatureChip(IconData icon, String label) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.blue[50],
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.blue[100]!, width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.blue[700]),
        const SizedBox(width: 4),
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
                    Icons.insert_drive_file_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Excel File Processing',
                  style: TextStyle(
                    fontSize: isLargeScreen ? 28 : 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[900],
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 80 : 20),
                  child: Text(
                    'Efficiently create multiple cards by uploading an Excel File. Ensure your file follows the required format for best results.',
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
                    _buildFeatureChip(Icons.format_list_bulleted, 'Bulk Import'),
                    const SizedBox(width: 4),
                    _buildFeatureChip(Icons.speed_rounded, 'Fast Processing'),
                    const SizedBox(width: 4),
                    _buildFeatureChip(Icons.cloud_upload_rounded, 'Easy Upload'),
                  ],
                ),
              ],
            ),


            const SizedBox(height: 16),
            _buildImagePicker(isLargeScreen),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              enabled: false,
              maxLength: 100,
              decoration: _buildInputDecoration('Event Name', prefixIcon: Icons.emoji_events),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter event name';
                if (value.length > 100) return 'Name must be 100 characters or less';
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
                onPressed: _isLoading ? null : _generateTickets,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange[800],
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Generate Cards',
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
              Icons.person_add,
              size: 64,
              color: Colors.orange[800],
            ),
            const SizedBox(height: 16),
            Text(
              'Add One Card Manually',
              style: TextStyle(
                fontSize: isLargeScreen ? 24 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This feature allows you to add individual cards one at a time.',
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
                if (value.length > 100) return 'Name must be 100 characters or less';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullNameController,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Ticket Holder\'s Name',
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
                  return 'Please enter ticket holder\'s name';
                }
                if (value.length > 100) {
                  return 'Holder\'s name must be 100 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneNumberController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Ticket Holder\'s Phone Number',
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
                  return 'Please enter holder\'s phone number';
                }

                final phone = value.trim();

                if (phone.length > 15) {
                  return 'Phone number can\'t exceed 15 characters';
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
              controller: _extraInfoController,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Extra Info',
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.info,
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
                  return null;
                }
                if (value.length > 100) {
                  return 'Extra info must be 100 characters or less';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),







            const Text(
              'Ticket Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _ticketType,
              decoration: InputDecoration(
                labelText: 'Ticket Type',
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.grey[400]!,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.grey[400]!,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Colors.orange[800]!,
                    width: 2.0,
                  ),
                ),
                filled: true,
                fillColor: Colors.grey[200], // Light background color
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              ),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
              ),
              icon: Icon(
                Icons.arrow_drop_down,
                color: Colors.grey[600],
              ),
              iconSize: 24,

              items: ticketTypePriceMap.keys.map((String ticketType) {
                return DropdownMenuItem<String>(
                  value: ticketType,
                  child: Text(
                    ticketType,
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              }).toList(),
              onChanged: (String? value) {
                if (value == null) return;

                setState(() {
                  _ticketType = value;

                  // Get corresponding price
                  _ticketPrice = ticketTypePriceMap[value]!;

                  // Your existing logic
                  _maxScanTimesController.text = value.trim().toUpperCase() == 'DOUBLE' ? '2' : '1';
                });
              },
              validator: (value) =>
                  value == null ? 'Please select a ticket type' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxScanTimesController,
              maxLength: 100,
              decoration: InputDecoration(
                labelText: 'Maximum Scan Times',
                labelStyle: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
                prefixIcon: Icon(
                  Icons.numbers,
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
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter maximum scan times';
                }
                if (value.length > 2) {
                  return 'Maximum scan times must be 2 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _addTicket,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading ? const CircularProgressIndicator() :
                Text(
                  'Add Card',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.orange[800]!,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDarkMode, bool isLargeScreen) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Generate Cards'),
          centerTitle: false,
          titleSpacing: 0,
          backgroundColor: const Color.fromARGB(255, 240, 244, 247),
          actions: [
            if(role == 'admin')
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
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              tooltip: 'More Options',
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              icon: Icon(
                Icons.more_vert,
                color: Colors.orange[800],
                size: 22,
              ),
              onSelected: (value) async {
                if (value == 'view_cards') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventTicketsPage(event: widget.event),
                    ),
                  );
                } else if (value == 'topup_cards') {
                  await getCardPackages();
                  _payDialog();
                } else if (value == 'exit') {
                  Navigator.pop(context);
                }
              },
              itemBuilder: (context) => [   
                _buildMenuItem(
                  icon: Icons.receipt,
                  text: AppLocalizations.of(context)!.viewCards,
                  value: 'view_cards',
                ),           
                _buildMenuItem(
                  icon: Icons.account_balance_wallet,
                  text: AppLocalizations.of(context)!.cardsBalance(cardsBalance.toString()),
                  value: 'topup_cards',
                ),
                _buildMenuItem(
                  icon: Icons.add_card,
                  text: AppLocalizations.of(context)!.topupCards,
                  value: 'topup_cards',
                ),
                const PopupMenuDivider(),
                _buildMenuItem(
                  icon: Icons.exit_to_app,
                  text: AppLocalizations.of(context)!.exit,
                  value: 'exit',
                ),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'Use Excel'),
              Tab(text: 'Add One'),
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
          if(role == 'admin')
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
            label: Text('Tickets(${widget.event.soldTickets})', style: TextStyle(
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
                  _buildImagePicker(isLargeScreen),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    enabled: false,
                    maxLength: 100,
                    decoration: _buildInputDecoration('Event Name', prefixIcon: Icons.emoji_events),
                    style: const TextStyle(fontSize: 16),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter event name';
                      if (value.length > 100) return 'Name must be 100 characters or less';
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
                      onPressed: _isLoading ? null : _generateTickets,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange[800],
                      ),
                      child: _isLoading 
                          ? const CircularProgressIndicator()
                          : const Text(
                              'Generate Cards',
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

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String text,
    required String value,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade800,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> getCardPackages({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/receipt_packages_new/$role') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}receipt_packages_new/$role'); // Use IP

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        debugPrint("response.body : ${response.body}");

        final responseData = jsonDecode(response.body); // This is a List<dynamic>

        if(responseData.length > 0) {
          setState(() {
            cardPackages = responseData;
          });
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
          await getCardPackages(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting offices: $e');
    } finally {
      debugPrint('Process finished');
    }
  }

  Future<void> _payDialog() async {
    int? selectedReceiptPackages = cardPackages.isNotEmpty ? cardPackages[0]["number_of_receipts"] as int : null;
    int? selectedAmount = cardPackages.isNotEmpty ? cardPackages[0]["price"] as int : null;

    final TextEditingController phoneController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              title: const Text(
                "Chagua kifurushi",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    const Divider(height: 4),
                    
                    /// Packages
                    ...cardPackages
                    .map((pkg) {
                      return RadioListTile(
                        dense: true,  
                        visualDensity: const VisualDensity(vertical: -4),
                        title: Text(
                          "Kadi ${pkg["number_of_receipts"]} - TSH ${NumberFormat('#,##0').format(pkg["price"])}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: pkg["number_of_receipts"],
                        groupValue: selectedReceiptPackages,
                        onChanged: (value) {
                          setState(() {
                            selectedReceiptPackages = value;
                            selectedAmount = pkg["price"] as int;
                          });
                        },
                      );
                    }),

                    const SizedBox(height: 6),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Njia ya Malipo",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),

                    const Divider(height: 10),

                    /// Payment Methods
                    Column(
                      children: paymentMethods.map((method) {
                        return RadioListTile(
                          dense: true,
                          visualDensity: const VisualDensity(vertical: -4),
                          title: Text(method, style: const TextStyle(fontSize: 12)),
                          value: method,
                          groupValue: selectedPaymentMethod,
                          onChanged: (value) {
                            debugPrint('Selected payment method: $value');
                            debugPrint('SselectedPaymentMethod: $selectedPaymentMethod');
                            setState(() {
                              selectedPaymentMethod = value.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 6),

                    /// Phone
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: "Namba ya simu ya malipo",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 10),

                    /// Pay button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () async {
                          if(selectedReceiptPackages != null && selectedReceiptPackages! > 0) {
                            setState(() => _isLoading = true);

                            await _sendPaymentRequest(
                              phoneController.text.trim(),
                              selectedReceiptPackages,
                              selectedAmount,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Tafadhali chagua kifurushi")),
                            );
                          }
                        },
                        child: _isLoading ? const CircularProgressIndicator() : Text("Lipa"),
                      ),
                    ) 
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendPaymentRequest(
    String phone,
    int? receipts,
    int? amount,
    {bool useDNS = true}
  ) async {

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number cannot be empty')),
      );
      return;
    }

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/pay_daily_package/$userId') 
    : Uri.parse('${backend_url_with_fallback_ip}pay_daily_package/$userId'); // Use IP

      debugPrint('Selected payment method: $selectedPaymentMethod');

      String selectedPaymentMethod2 = '';
      if(selectedPaymentMethod == 'M-PESA') {
        selectedPaymentMethod2 = 'Mpesa';
      }else if(selectedPaymentMethod == 'MIXX BY YAS') {
        selectedPaymentMethod2 = 'Tigo';
      }else if(selectedPaymentMethod == 'AIRTEL MONEY') {
        selectedPaymentMethod2 = 'Airtel';
      }else if(selectedPaymentMethod == 'HALOPESA') {
        selectedPaymentMethod2 = 'Halopesa';
      }else if(selectedPaymentMethod == 'AZAMPESA') {
        selectedPaymentMethod2 = 'Azampesa';
      }

      debugPrint('Selected payment method 2: $selectedPaymentMethod2');

    try {
      setState(() => _isLoading = true);

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "phone_number": phone,
          "receipts": receipts,
          "amount": amount,
          'selected_payment_method': selectedPaymentMethod2,
        }),
      );

      debugPrint('phone_number: $phone');
      debugPrint('receipts: $receipts');
      debugPrint('amount: $amount');

      if (response.statusCode == 200) {
        if (response.body == "Processing payment!") { 
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Ombi la malipo limetumwa")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
        }

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Malipo yameshindwa")),
        );
      }
    }  on SocketException catch (e) {
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
          await _sendPaymentRequest(phone, receipts, amount, useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      print("Payment error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveCardsBalance(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('paid_sms_balance', value);
  }

  Future<void> _loadNumberOfCards() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      cardsBalance = prefs.getInt('paid_sms_balance') ?? 0;
    });
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