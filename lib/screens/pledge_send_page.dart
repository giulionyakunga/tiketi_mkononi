import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:tiketi_mkononi/models/pledge.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:contacts_service_plus/contacts_service_plus.dart';
// import 'dart:html' as html; // only for web

class PledgeSendPage extends ConsumerStatefulWidget {
  final Pledge pledge;
  final Event? event; // ← nullable

  const PledgeSendPage({
    super.key,
    required this.pledge,
    this.event,
  });

  @override
  ConsumerState<PledgeSendPage> createState() => _PledgeSendPageState();
}

class _PledgeSendPageState extends ConsumerState<PledgeSendPage> {
  late DateTime scannedAt;
  bool _isCardGenerated = false;
  String pledgeCardFilePath = '';
  Printer? selectedPrinter;
  late OverlayConfig config;
  bool _isContactSaved = false;
  String contactName = '';
  bool isWhatsappSent = false;
  Iterable<Contact> contactsList = [];

  @override
  void initState() {
    super.initState();
    config = const OverlayConfig(
      qrOffset: Offset(40, 40),
      textOffset: Offset(40, 260),
      qrSize: 160,
    );
    _loadPrefs();

    _loadSelectedPrinter();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      config = OverlayConfig(
        qrOffset: Offset(
          (p.getDouble('qrOffsetDx') ?? 0.1).clamp(0.1, 1.0),
          (p.getDouble('qrOffsetDy') ?? 0.1).clamp(0.1, 1.0),
        ),
        textOffset: Offset(
          (p.getDouble('textOffsetDx') ?? 0.1).clamp(0.1, 1.0),
          (p.getDouble('textOffsetDy') ?? 0.1).clamp(0.1, 1.0),
        ),
        qrSize: (p.getDouble('qrSize') ?? 0.1).clamp(0.1, 1.0),
      );
    });

    if(widget.event!.category.toUpperCase() == "WEDDING") {
      _generateImageWithQr();
    }

    await loadContacts();

  }

  Future<bool> requestContactsPermission() async {
    var status = await Permission.contacts.status;
    if (!status.isGranted) {
      status = await Permission.contacts.request();
    }
    return status.isGranted;
  }
  
  Future<void> loadContacts() async {
    bool granted = await requestContactsPermission();
    if (!granted) {
      debugPrint("Permission denied");
      _showSnackBar("Permission denied");
      return;
    }

    // Get all existing contacts
    Iterable<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);

    setState(() {
      contactsList = contacts;
    });
  }

  Future<void> addContactUnique(String givenName, String phoneNumber) async {
    bool granted = await requestContactsPermission();
    if (!granted) {
      debugPrint("Permission denied");
      _showSnackBar("Permission denied");
      return;
    }

    if(contactsList.isEmpty) {
      await loadContacts();
    }
    
    // Check if phone number already exists
    Contact? matchingContact;

    for (final c in contactsList) {
      if (c.phones != null && c.phones!.any((p) => p.value == phoneNumber)) {
        matchingContact = c;
        break;
      }
    }

    if (matchingContact != null) {
      print('Phone belongs to: ${matchingContact.displayName}');

      setState(() {
        contactName = matchingContact!.displayName!;
        _isContactSaved = true;
      });

      debugPrint("Contact '${matchingContact.displayName}' already exists!");
      _showSnackBar("Contact '${matchingContact.displayName}' already exists!");
      return;
    }

    Contact newContact = Contact(
      givenName: givenName,
      phones: [Item(label: "mobile", value: phoneNumber)],
    );

    await ContactsService.addContact(newContact);

    setState(() {
      contactName = givenName;
      _isContactSaved = true;
    });
    
    debugPrint("Contact saved as : $givenName");
    _showSnackBar("Contact saved as : $givenName");
  }

  String generateContactName(String eventName, String pledgeId, { int maxWords = 3 }) {
    final ignoreWords = {
      'ya', 'na', 'and', 'of', 'the', '&', 'a', 'an'
    };

    // Normalize
    final words = eventName
        .replaceAll(RegExp(r'[^\w\s]'), '') // remove symbols
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word.toLowerCase())
        .where((word) => !ignoreWords.contains(word))
        .toList();

    final buffer = StringBuffer();

    for (var i = 0; i < words.length && buffer.length < maxWords; i++) {
      buffer.write(words[i][0]);
    }
    String contactName = buffer.toString().toUpperCase() + '$pledgeId';
    return contactName;
  }

  Future<void> _generateImageWithQr() async {
    try {
      if (widget.event == null) return;

      final path = await ImageQrService.generateImageWithQr(
        pledge: widget.pledge,
        event: widget.event!,
        config: config,
      );

      if (!mounted) return;

      setState(() {
        pledgeCardFilePath = path;
        _isCardGenerated = true;
      });
    } on PathNotFoundException catch (e) {
      debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> Cache cleanup skipped (file already missing)');
      debugPrint('Path: ${e.path}');
      debugPrint('OS error: ${e.osError}');
    } catch (e) {
      debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 11 pledgeCardFilePath : $pledgeCardFilePath');
      debugPrint(' >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 11 Error sharing image: $e');

      if (!mounted) return;

      setState(() {
        _isCardGenerated = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing image: $e')),
      );
    }
  }

  Future<void> _loadSelectedPrinter() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? url = prefs.getString('selected_printer_url');
    String? name = prefs.getString('selected_printer_name');

    if (url != null && name != null) {
      setState(() {
        selectedPrinter = Printer(url: url, name: name);
      });
    }
  }

  Future<void> _saveSelectedPrinter(Printer printer) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_printer_url', printer.url);
    await prefs.setString('selected_printer_name', printer.name);
    setState(() {
      selectedPrinter = printer;
    });
  }

  Future<void> _refreshPrinters() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("selected_printer_url");
    await prefs.remove("selected_printer_name");

    setState(() {
      selectedPrinter = null;
    });

    await _selectPrinterDialog(); // fallback
  }
  
  Future<void> _selectPrinterDialog() async {
    final printers = await Printing.listPrinters();

    if (printers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No printers found.')),
      );
      return;
    }

    Printer? selected;

    await showDialog(
      context: context,
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isSmallScreen = constraints.maxWidth < 400;
            final dialogWidth = isSmallScreen ? constraints.maxWidth * 0.9 : 400.0;

            return AlertDialog(
              contentPadding: EdgeInsets.all(20),
              title: Text("Select a printer"),
              content: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: dialogWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: printers
                        .map(
                          (printer) => ListTile(
                            title: Text(printer.name),
                            subtitle: Text(printer.url),
                            onTap: () {
                              selected = printer;
                              Navigator.of(context).pop();
                            },
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      // Save selected printer
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedPrinterUrl', selected!.url);
      _saveSelectedPrinter(selected!);
      selectedPrinter = selected;    
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

  @override
  void dispose() {
    super.dispose();
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  String formatTo24HourManual(DateTime dateTime) {
    final localTime = dateTime.toLocal();
    final weekday = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][localTime.weekday-1];
    final month = ['January','February','March','April','May','June','July','August','September','October','November','December'][localTime.month-1];
    
    return '$weekday, $month ${localTime.day}, ${localTime.year} - '
          '${localTime.hour.toString().padLeft(2,'0')}:'
          '${localTime.minute.toString().padLeft(2,'0')}';
  }

  String _formatDate(String date) {
    final DateFormat inputFormat = DateFormat('dd-MM-yyyy');
    final DateTime dateTime = inputFormat.parse(date);
    final DateFormat outputFormat = DateFormat('EEEE, MMMM d, yyyy');
    return outputFormat.format(dateTime);
  }

  Widget _buildEventInfoSection(bool isLargeScreen) {
    return Column(
      children: [
        Text(
          widget.event!.name,
          style: TextStyle(
            fontSize: isLargeScreen ? 28 : 18,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
            widget.pledge.fullName,
            style: TextStyle(
              fontSize: isLargeScreen ? 20 : 14,
              fontWeight: FontWeight.bold,
            ),
        ),
        const SizedBox(height: 4),
        Text(
            !_isContactSaved ? widget.pledge.phoneNumber : contactName,
            style: TextStyle(
              fontSize: isLargeScreen ? 20 : 14,
              fontWeight: FontWeight.normal,
            ),
        ),
        const SizedBox(height: 8),
        if (widget.event != null)
        Center(
          child: Wrap(
          spacing: 16,
            children: [
              TextButton(
                onPressed: () => addContactUnique(generateContactName(widget.event!.name, widget.pledge.phoneNumber), widget.pledge.phoneNumber),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,  // Removed vertical padding
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Icon(
                  Icons.save_alt,
                  size: 40,
                  color: Colors.red
                ),
              ),

              TextButton(
                onPressed: () => _launchPhoneCall(widget.pledge.phoneNumber),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,  // Removed vertical padding
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Icon(
                  Icons.phone,
                  size: 40,
                  color: Colors.green
                ),
              ),
            ]
          )
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: isLargeScreen ? 24 : 16),
            const SizedBox(width: 8),
            Text(
              _formatDate(widget.event!.date),
              style: TextStyle(fontSize: isLargeScreen ? 20 : 14),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: isLargeScreen ? 24 : 16),
            const SizedBox(width: 8),
            Text(
              widget.event!.time,
              style: TextStyle(fontSize: isLargeScreen ? 20 : 14),
            ),
          ],
        ),
      ],
    );
  }

  String getEventNameAfterPrefix(String eventName) {
    // Pattern to match 'ya ' or 'of ' (case insensitive)
    final RegExp regex = RegExp(r'(?:ya|of)\s+(.+)', caseSensitive: false);
    final match = regex.firstMatch(eventName);
    
    if (match != null && match.groupCount > 0) {
      return match.group(1)!.trim();
    }
    return eventName; // Return original if no match
  }


  String getTimeOfDay(String time24) {
    // Parse "HH:mm"
    final parts = time24.split(':');
    if (parts.length != 2) return "Invalid time format";

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    // Validate
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 || 
        minute < 0 ||
        minute > 59) {
      return "Invalid time format";
    }

    // Determine time of day
    if (hour >= 5 && hour < 12) {
      return "Asubuhi"; // Morning
    } else if (hour >= 12 && hour < 17) {
      return "Mchana"; // Afternoon
    } else if (hour >= 17 && hour < 21) {
      return "Jioni"; // Evening
    } else {
      return "Usiku"; // Night (21:00–04:59)
    }
  }

  Future<void> _sendPledge() async {
 
    String extractedName = getEventNameAfterPrefix(widget.event!.name);

    String text = "${widget.event!.familyName} inayo furaha kukujulisha ${widget.pledge.fullName} kuwa kijana wao mpendwa ${extractedName}, anatarajia kufunga ndoa tarehe ${widget.event!.date}. Hivyo ukiwa kama ndugu, jamaa na rafiki wa karibu wa familia hii, tunaomba mchango wako wa hali na mali ili kufanikisha shughuli hii";
    
    // await Clipboard.setData(ClipboardData(text: text));
    await Clipboard.setData(ClipboardData(text: contactName));
    
    if (Platform.isWindows || kIsWeb) {
      // Share via WhatsApp/Email/etc
      await Share.shareXFiles(
        [XFile(pledgeCardFilePath)],
        // [XFile(filePath, mimeType: 'application/pdf')],
        text: text,
      );
    } else {
      // Share via WhatsApp/Email/etc
      await Share.shareXFiles(
        [XFile(pledgeCardFilePath)],
        // [XFile(filePath, mimeType: 'application/pdf')],
        text: text,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = _isLargeScreen(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Pledge'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 32 : 24,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLargeScreen ? 800 : double.infinity,
              ),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: EdgeInsets.all(isLargeScreen ? 32 : 24),
                  child: isLargeScreen
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  if (widget.event != null)
                                  Column(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _isCardGenerated ? _sendPledge : null,
                                        icon: const Icon(Icons.share),
                                        label: const Text("Send Pledge"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if ((Platform.isWindows || kIsWeb) && selectedPrinter != null)
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () {
                                          _refreshPrinters();
                                        },
                                        child: const Text(
                                          'Refresh Printers',
                                          style: TextStyle(
                                            color: Colors.green
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                            const SizedBox(width: 30),
                            Expanded(
                              child: _buildEventInfoSection(isLargeScreen),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildEventInfoSection(isLargeScreen),
                            const SizedBox(height: 8),
                            if (widget.event != null)
                            Column(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _isCardGenerated ? _sendPledge : null,
                                  icon: const Icon(Icons.share),
                                  label: const Text("Send Pledge"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),                               
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class OverlayConfig {
  final Offset qrOffset;
  final Offset textOffset;
  final double qrSize;

  const OverlayConfig({
    required this.qrOffset,
    required this.textOffset,
    required this.qrSize,
  });

  OverlayConfig copyWith({
    Offset? qrOffset,
    Offset? textOffset,
    double? qrSize,
  }) {
    return OverlayConfig(
      qrOffset: qrOffset ?? this.qrOffset,
      textOffset: textOffset ?? this.textOffset,
      qrSize: qrSize ?? this.qrSize,
    );
  }
}

class SimpleImageCacheManager {
  static const Duration _cacheDuration = Duration(days: 7);
  static const int _maxCacheSize = 1002424; // 100MB max cache

  static Future<String> _getCacheDirectory() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/image_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  static String _getCacheKey(String url) {
    final uri = Uri.parse(url);
    final fileName = uri.pathSegments.isNotEmpty 
        ? uri.pathSegments.last 
        : 'image_${DateTime.now().millisecondsSinceEpoch}';
    final safeUrl = url.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    return '${safeUrl.substring(0, safeUrl.length > 50 ? 50 : safeUrl.length)}_$fileName';
  }

  static Future<String> getCacheFilePath(String url) async {
    final cacheDir = await _getCacheDirectory();
    final key = _getCacheKey(url);
    return '$cacheDir/$key';
  }

  static Future<bool> isImageCached(String url) async {
    try {
      final filePath = await getCacheFilePath(url);
      final file = File(filePath);
      
      if (await file.exists()) {
        final lastModified = await file.lastModified();
        final now = DateTime.now();
        
        // Check if cache is expired
        if (now.difference(lastModified) > _cacheDuration) {
          await file.delete();
          return false;
        }
        
        // Verify file is not corrupted (has content)
        final stat = await file.stat();
        return stat.size > 0;
      }
      return false;
    } catch (e) {
      print('Cache check error: $e');
      return false;
    }
  }

  static Future<File> getCachedImage(String url) async {
    final filePath = await getCacheFilePath(url);
    return File(filePath);
  }

  static Future<File> cacheImage(String url, Uint8List bytes) async {
    try {
      final filePath = await getCacheFilePath(url);
      final file = File(filePath);
      
      // Create directory if it doesn't exist
      await file.parent.create(recursive: true);
      
      await file.writeAsBytes(bytes);
      
      // Clean up old cache if needed
      await _cleanupCache();
      
      return file;
    } catch (e) {
      print('Cache error: $e');
      rethrow;
    }
  }

  static Future<void> _cleanupCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final directory = Directory(cacheDir);
      
      if (!await directory.exists()) return;
      
      final files = await directory.list().where((file) => file is File).cast<File>().toList();
      
      // Calculate total size
      int totalSize = 0;
      final fileSizes = <File, int>{};
      
      for (final file in files) {
        final stat = await file.stat();
        final size = stat.size;
        fileSizes[file] = size;
        totalSize += size;
      }
      
      // Delete oldest files if over limit
      if (totalSize > _maxCacheSize) {
        for (final file in files) {
          final size = fileSizes[file]!;
          await file.delete();
          totalSize -= size;
          
          if (totalSize <= _maxCacheSize * 0.8) { // Keep at 80% of max
            break;
          }
        }
      }
      
      // Also delete expired files
      final now = DateTime.now();
      for (final file in files) {
        final lastModified = await file.lastModified();
        if (now.difference(lastModified) > _cacheDuration) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Cache cleanup error: $e');
    }
  }

  static Future<void> clearCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final directory = Directory(cacheDir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (e) {
      print('Clear cache error: $e');
    }
  }

  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final directory = Directory(cacheDir);
      
      if (!await directory.exists()) return 0;
      
      int totalSize = 0;
      await for (final file in directory.list(recursive: true)) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Get cache size error: $e');
      return 0;
    }
  }
}

class ImageQrService {
  static Future<String> generateImageWithQr({
    required Pledge pledge,
    required Event event,
    required  OverlayConfig config,
  }) async {
    String imageName = event.cardUrl;

    try {
      // Load base image
      debugPrint('Loading image');

      final image = await ImageLoader.loadImage(imageName);
      if (image == null) {
        throw Exception('Failed to load image');
      }

      final int textOffsetDx = (config.textOffset.dx * image.width).toInt();
      final int textOffsetDy = (config.textOffset.dy * image.height).toInt();

      img.BitmapFont font = img.arial24;

      final img.Color color = img.ColorRgb8(0, 0, 0); // Black

      // debugPrint('font.size : ${font.size}');

      int textWidth = 0;
      if (font.size == 14) {
        // arial14: ~9px per character
        textWidth = pledge.fullName.length * 9;
      } else if (font.size == 24) {
        // arial24: ~15px per character  
        textWidth = pledge.fullName.length * 15;
      } else if (font.size == 48) {
        // arial48: ~30px per character
        textWidth = pledge.fullName.length * 30;
      }else {
        textWidth = (pledge.fullName.length * font.size * 0.625).toInt();
      }
  
      final textHeight = font.lineHeight;
      
      // Calculate centered position
      final x2 = (image.width - textWidth) ~/ 2;
      final y2 = (image.height - textHeight) ~/ 2;

      img.drawString(
        image,
        pledge.fullName,
        font: font,
        x: textOffsetDx,
        y: textOffsetDy,
        color: color
      );

      /// 7️⃣ Save result
      final tempDir = await getTemporaryDirectory();
      final outputFile = File(
        '${tempDir.path}/image_with_qr.jpg',
      );

      final jpgBytes = img.encodeJpg(image, quality: 90);

      await outputFile.writeAsBytes(jpgBytes);
      debugPrint("image saved at: ${outputFile.path}");

      return outputFile.path;
    } catch (e) {
      rethrow;
    }
  }

}

class ImageLoader {
  static Future<img.Image?> loadImage(String imageName, {bool useDNS = true}) async { 
    try {
      String source = useDNS ? '${backend_url}api/image/${imageName}' 
      : '${backend_url_with_fallback_ip}image/${imageName}';

      print('🔍 Attempting to load image from: $source');
      
      // Check if source is a local file path
      if (_isLocalPath(source)) {
        print('📁 Detected local path');
        final image = await _loadLocalImage(source);
        if (image != null) {
          print('✅ Successfully loaded local image');
          return image;
        }
      }
      
      // Check if source is a network URL
      if (source.startsWith('http://') || source.startsWith('https://')) {
        print('🌐 Detected network URL');
        return await _loadNetworkImage(source);
      }
      
      // Try as local file first, then network (for ambiguous paths)
      print('🔍 Ambiguous path, trying as local then network...');
      final localImage = await _loadLocalImage(source);
      if (localImage != null) {
        print('✅ Loaded as local image');
        return localImage;
      }
      
      // Try as network URL
      return await _loadNetworkImage(source);
    } on SocketException catch (e) {
      debugPrint('  >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> 22 Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      var image;
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP at loadImage: ${backend_url_with_fallback_ip}...');
          image = await loadImage(imageName, useDNS: false); // Recursive retry
        } 
        
        return image;
      }
    } catch (e) {
      print('❌ Error loading image: $e');
      return null;
    }
    return null;
  }

  static bool _isLocalPath(String pathString) {
    // Check for common local file patterns
    return pathString.startsWith('/') || 
           pathString.startsWith('./') || 
           pathString.startsWith('../') ||
           pathString.startsWith('file://') ||
           pathString.contains(RegExp(r'^[A-Za-z]:[\\/]')) || // Windows path
           pathString.endsWith('.jpg') || 
           pathString.endsWith('.jpeg') ||
           pathString.endsWith('.png') ||
           pathString.endsWith('.gif') ||
           pathString.endsWith('.bmp') ||
           pathString.endsWith('.webp') ||
           File(pathString).existsSync(); // Direct file existence check
  }

  static Future<img.Image?> _loadLocalImage(String filePath) async {
    try {
      // Clean up file path
      String cleanPath = filePath;
      if (filePath.startsWith('file://')) {
        cleanPath = filePath.substring(7);
      }
      
      // Handle relative paths
      if (cleanPath.startsWith('./') || cleanPath.startsWith('../')) {
        final currentDir = Directory.current.path;
        cleanPath = path.normalize(path.join(currentDir, cleanPath));
      }
      
      final file = File(cleanPath);
      print('📂 Checking local file: $cleanPath');
      print('📊 File exists: ${await file.exists()}');
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        print('📦 File size: ${bytes.length} bytes');
        
        final image = img.decodeImage(bytes);
        if (image == null) {
          print('⚠️ Failed to decode image - file may be corrupted');
        }
        return image;
      }
      print('⚠️ Local file not found');
      return null;
    } catch (e) {
      print('❌ Error loading local image: $e');
      return null;
    }
  }

  static Future<img.Image?> _loadNetworkImage(String url, {bool useDNS = true}) async {
    try {
      print('🌐 Checking cache for URL: $url');
      
      // Check cache first
      if (await SimpleImageCacheManager.isImageCached(url)) {
        print('📦 Cache hit! Loading from cache...');
        final cachedFile = await SimpleImageCacheManager.getCachedImage(url);
        final bytes = await cachedFile.readAsBytes();
        print('📊 Cache file size: ${bytes.length} bytes');
        
        final image = img.decodeImage(bytes);
        if (image != null) {
          print('✅ Successfully loaded from cache');
          return image;
        }
        print('⚠️ Cached file corrupted, re-downloading...');
      }

      // Download from network
      print('⬇️ Downloading from network...');
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'image/*',
        },
      );
      
      print('📡 HTTP Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        print('📦 Downloaded ${bytes.length} bytes');
        
        // Decode image first to ensure it's valid
        final image = img.decodeImage(bytes);
        if (image == null) {
          print('❌ Downloaded image is not valid');
          throw Exception('Downloaded image is not a valid image file');
        }
        
        // Cache the image
        print('💾 Caching image...');
        await SimpleImageCacheManager.cacheImage(url, bytes);
        print('✅ Image cached successfully');
        
        return image;
      } else {
        print('❌ HTTP Error ${response.statusCode}');
        throw Exception('Failed to load image: HTTP ${response.statusCode}');
      }
    } on SocketException catch (e) {
      rethrow;
    } 
    catch (e) {
      print('❌ Error loading network image: $e');
      
      // Try to load from cache even if it might be expired
      try {
        final cachedFile = await SimpleImageCacheManager.getCachedImage(url);
        if (await cachedFile.exists()) {
          print('🔄 Falling back to cached file despite error');
          final bytes = await cachedFile.readAsBytes();
          return img.decodeImage(bytes);
        }
      } catch (cacheError) {
        print('⚠️ Cache fallback failed: $cacheError');
      }
      
      return null;
    }
  }

  static Future<File> loadAndCacheImage(String source) async {
    print('🔍 loadAndCacheImage called with: $source');
    
    img.Image? image;
    
    if (source.startsWith('http://') || source.startsWith('https://')) {
      // Network image
      print('🌐 Processing as network image');
      image = await _loadNetworkImage(source);
      if (image != null) {
        final cachedFile = await SimpleImageCacheManager.getCachedImage(source);
        print('✅ Network image loaded and cached at: ${cachedFile.path}');
        return cachedFile;
      }
    } else {
      // Local image
      print('📁 Processing as local image');
      image = await _loadLocalImage(source);
      if (image != null) {
        print('✅ Local image loaded from: $source');
        return File(source);
      }
    }
    
    print('❌ Failed to load image from: $source');
    throw Exception('Failed to load image from: $source');
  }
}