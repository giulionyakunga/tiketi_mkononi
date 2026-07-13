import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/barcode_view_page.dart';
import 'package:tiketi_mkononi/screens/card_view_page.dart';
import 'package:tiketi_mkononi/screens/event_tickets_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';



import 'dart:ui' as ui;
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:barcode/barcode.dart';




class GenerateBarcodesPage extends StatefulWidget {
  const GenerateBarcodesPage({super.key});

  @override
  State<GenerateBarcodesPage> createState() => _GenerateBarcodesPageState();
}

class _GenerateBarcodesPageState extends State<GenerateBarcodesPage> with TickerProviderStateMixin {
  int userId = 0;
  String role = "";
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _imagePickerKey = GlobalKey();
  final _numberOfBarcodesController = TextEditingController();
  XFile? _mainImageFile;
  img.Image? barcodeImage;
  Uint8List? _webImageBytes;
  String? fileType;
  bool _isGenerating = false;
  bool _isBarcodesGenerated = false;
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _maxScanTimesController = TextEditingController();
  String barcodeFolder = "";
  
  late TabController _tabController;
  late final StorageService _storageService;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _numberOfBarcodesController.dispose();
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _maxScanTimesController.dispose();
    super.dispose();
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

        final Uint8List bytes = await image.readAsBytes();

        setState(() {
          barcodeImage = img.decodeImage(bytes);
          _mainImageFile = image;
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

  Future<bool> requestStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }
  
  Future<void> _generateBarcodes() async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    try {

      // bool granted = await requestStoragePermission();
      // if (!granted) {
      //   debugPrint("Permission denied");
      //   _showSnackBar("Permission denied");
      //   return;
      // }

      int numberOfBarcodes = int.tryParse(_numberOfBarcodesController.text.trim()) ?? 0;
      
      if (numberOfBarcodes <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Number Of Barcodes must be greater than 0')),
        );
        return;
      }

      setState(() {
        _isGenerating = true;
      });

      if (barcodeImage == null) {
        throw Exception('Failed to load image');
      }

      int currentTime = DateTime.now().millisecondsSinceEpoch;
      String status = '';
      String folderName= DateFormat('yyyy-MM-dd_HH_mm_ss').format(DateTime.now());
      for(int i = 1; i <= numberOfBarcodes; i++ ) {
        status = await ImageQrService.generateBarcodeImage(barcodeImage!, currentTime, i, folderName);
      }

      if(status == "Barcode Generated Successfully") {
        _showSnackBar("Successfully Generated $numberOfBarcodes Barcodes");
        setState(() {
          barcodeFolder = ImageQrService.barcodeFolder;
          _isBarcodesGenerated = true;
        });
      }

    }  catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isGenerating = false);
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
        child: _mainImageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb ? 
                Image.memory(
                  _webImageBytes!,
                  fit: BoxFit.cover,
                ) :
                Image.file(
                  File(_mainImageFile!.path),
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
                  'Bulk Barcode Generator',
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
                    'Efficiently create multiple Barcode by uploading a template image. Ensure your file follows the required format for best results.',
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
                    _buildFeatureChip(Icons.format_list_bulleted, 'Bulk Generation'),
                    const SizedBox(width: 4),
                    _buildFeatureChip(Icons.speed_rounded, 'Fast Processing'),
                    const SizedBox(width: 4),
                    _buildFeatureChip(Icons.cloud_upload_rounded, 'Easy Generation'),
                  ],
                ),
              ],
            ),


            const SizedBox(height: 16),
            _buildImagePicker(isLargeScreen),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberOfBarcodesController,
              maxLength: 3,
              decoration: _buildInputDecoration('Number Of Barcodes', prefixIcon: Icons.emoji_events),
              style: const TextStyle(fontSize: 16),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Please enter number of barcodes';
                if (value.length > 100) return 'Number of barcodes must be 3 characters or less';
                return null;
              },
            ),
            const SizedBox(height: 16),            
            SizedBox(
              width: isLargeScreen ? 400 : double.infinity,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateBarcodes,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.orange[800],
                ),
                child: _isGenerating 
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Generate Barcode',
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
              controller: _numberOfBarcodesController,
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
            const Text(
              'Ticket Type',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
                onPressed: _generateBarcodes,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isGenerating ? const CircularProgressIndicator() :
                Text(
                  'Generate Barcode',
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
          title: const Text('Generate Barcodes'),
          centerTitle: false,
          titleSpacing: 0,
          backgroundColor: const Color.fromARGB(255, 240, 244, 247),
          actions: [
            IconButton(
              icon: Icon(
                Icons.remove_red_eye,
                color: Colors.orange[800],
              ),
              onPressed: () {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(
                //     builder: (context) => BarcodeViewPage(event: widget.event),
                //   ),
                // );
              },
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
          IconButton(
            icon: Icon(
              Icons.remove_red_eye,
              color: Colors.orange[800],
            ),
            onPressed: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => BarcodeViewPage(event: widget.event),
              //   ),
              // );
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
                    controller: _numberOfBarcodesController,
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
                  SizedBox(
                    width: isLargeScreen ? 400 : double.infinity,
                    child: ElevatedButton(
                      onPressed: _isGenerating ? null : _generateBarcodes,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.orange[800],
                      ),
                      child: _isGenerating 
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = MediaQuery.of(context).size.width > 768;

    final isDesktop = MediaQuery.of(context).size.width >= 768;
    return isDesktop ? _buildDesktopLayout(isDarkMode, isLargeScreen) : _buildMobileLayout(isDarkMode, isLargeScreen);
  }
}


class ImageQrService {
  static String barcodeFolder = "";
  static Future<String> generateBarcodeImage(img.Image mainImage, int currentTime, int index, String folderName) async {

    String barcodeData = "$index$currentTime";

    const int width = 400;
    const int height = 100;

    final barcode = Barcode.code128();

    final String svgString = barcode.toSvg(
      barcodeData,
      width: width.toDouble(),
      height: height.toDouble(),
      drawText: true,
    );

    // Convert SVG → Picture
    final PictureInfo pictureInfo = await vg.loadPicture(
      SvgStringLoader(svgString),
      null,
    );

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = Colors.white,
    );

    canvas.drawPicture(pictureInfo.picture);

    final ui.Image image =
        await recorder.endRecording().toImage(width, height);

    final ByteData byteData =
        await image.toByteData(format: ui.ImageByteFormat.png) as ByteData;

    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final img.Image barcodeImage = img.decodePng(pngBytes)!;


    final int borderSize = 2; // quiet zone in pixels

    // Create larger white background
    final int finalWidth = width + 2 * borderSize;
    final int finalHeight = height + 2 * borderSize;
    final img.Image barcodeWithBorder = img.Image(
      width: finalWidth,
      height: finalHeight,
    );
    img.fill(barcodeWithBorder, color: img.ColorRgb8(255, 255, 255));

    // Center QR on white background
    img.compositeImage(
      barcodeWithBorder,
      barcodeImage,
      dstX: borderSize,
      dstY: borderSize,
    );

    /// 6️⃣ Composite QR onto main image
    img.compositeImage(
      mainImage,
      barcodeWithBorder,
      dstX: 20,
      dstY: 20,
    );


    // You can save or use the barcodeImage as needed
    var directory = await getApplicationDocumentsDirectory();

    if (Platform.isAndroid) {
      String publicDownloadsPath = '/storage/emulated/0/Download';
      directory = Directory(publicDownloadsPath);
    }

    // Use path.join for cross-platform compatibility
    final barcodesPath = p.join(directory.path, 'barcodes', folderName);
    final barcodesDir = Directory(barcodesPath);

    if (!await barcodesDir.exists()) {
      await barcodesDir.create(recursive: true);
    }

    final filePath = p.join(barcodesDir.path, '$barcodeData.png');
    final file = File(filePath);
    await file.writeAsBytes(img.encodePng(mainImage));

    debugPrint("Barcode saved as : ${barcodesDir.path}/${barcodeData}.png");

    barcodeFolder = "Barcode saved at : ${barcodesDir.path}/${barcodeData}.png";

    return 'Barcode Generated Successfully';
  }
}
