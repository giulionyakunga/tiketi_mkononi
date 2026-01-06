import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/card_view_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';

class GenerateCardsPage extends StatefulWidget {
  final Event event;

  const GenerateCardsPage({super.key, required this.event});

  @override
  State<GenerateCardsPage> createState() => _GenerateCardsPageState();
}

class _GenerateCardsPageState extends State<GenerateCardsPage> {
  int userId = 0;
  String role = "";
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _imagePickerKey = GlobalKey();
  final _nameController = TextEditingController();
  XFile? _eventImage;
  Uint8List? _webImageBytes;
  String? fileType;
  bool _isLoading = false;
  bool useDNS = true;


  String base64File = "";
  String? fileType2;
  String? fileName;

  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.event.name;
    _initializeServices();
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

      if(profile.role == "user") {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sorry! You can't generate cards")),
        );
      }

    }
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
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
  
  Future<void> _submitEvent({bool useDNS = true}) async {
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

    // if()

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
      : Uri.parse('${backend_url_with_fallback_ip}api/generate_cards'); // Use IP

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
        }else {
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
        if(response.statusCode == 413){
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

          // Retry with IP if DNS fails (errno = 7) and not already retrying
          if (e.osError!.errorCode == 7 && useDNS) {
            debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
            await _submitEvent(useDNS: false); // Recursive retry
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
                  const Text('Add Event Card'),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = _isLargeScreen(context);

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
        ]
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
                    label: Text( (fileName != null) ? 'Selected: $fileName' : 'Choose Files'),
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
                      onPressed: _isLoading ? null : _submitEvent,
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
}