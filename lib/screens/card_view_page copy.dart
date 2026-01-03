import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/screens/event_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:tiketi_mkononi/services/SimpleCodec.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart';
// import 'dart:html' as html; // only for web

import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';


class CardViewPage extends StatefulWidget {
  final Event event;
  final bool useDNS;

  const CardViewPage({
    super.key,
    required this.event,
    required this.useDNS,
  });

  @override
  State<CardViewPage> createState() => _CardViewPageState(); 
}

class _CardViewPageState extends State<CardViewPage> {
  int userId = 0;
  Event? event2;
  double? _imageHeight;
  double? _imageWidth;
  final double _defaultExpandedHeight = 360;
  String organiser_name = "";
  String organiser_phone_number = "";
  int eventTicketsCount = 0;
  Map<String, dynamic> ticketTypesTicketsCount = {};
  late final StorageService _storageService;
  bool isDeepLink = false;
  img.Image? imageData;
  
  // State variables for position and size control
  int dstX = 50;      // QR Code X position
  int dstY = 50;      // QR Code Y position
  int dstX2 = 50;     // Text X position
  int dstY2 = 150;    // Text Y position
  int qrSize = 200;   // QR Code size

  @override
  void initState() {
    super.initState();
    _loadImageDimensions();
    _loadPreferences();
    _loadImage();
    _generateImageWithQr();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    try {
      final state = GoRouterState.of(context);
      isDeepLink = ((state.extra == null) && (state.fullPath == '/event/:id'));
      debugPrint("Extra : ${state.extra}");
      debugPrint("Path : ${state.uri.path}");
      debugPrint("FullPath : ${state.fullPath}");

      if (isDeepLink) {
        debugPrint("This page was opened from a link.");
      } else {
        debugPrint("This page was opened via in-app navigation.");
      }
    } catch (_) {
      isDeepLink = false;
    }
  }

  @override
  void dispose() {
    final container = ProviderScope.containerOf(context);
    container.read(selectedEventProvider.notifier).state = null;
    super.dispose();
  }

  // Load saved preferences
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
    
    setState(() {
      dstX = prefs.getInt('dstX') ?? 50;
      dstY = prefs.getInt('dstY') ?? 50;
      dstX2 = prefs.getInt('dstX2') ?? 50;
      dstY2 = prefs.getInt('dstY2') ?? 150;
      qrSize = prefs.getInt('qrSize') ?? 200;
    });
    _loadUserProfile();
  }

  // Save preferences
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setInt('dstX', dstX);
    await prefs.setInt('dstY', dstY);
    await prefs.setInt('dstX2', dstX2);
    await prefs.setInt('dstY2', dstY2);
    await prefs.setInt('qrSize', qrSize);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Reset to default values
  Future<void> _resetToDefaults() async {
    setState(() {
      dstX = 50;
      dstY = 50;
      dstX2 = 50;
      dstY2 = 150;
      qrSize = 200;
    });
    
    await _savePreferences();
  }

  void _loadUserProfile() {
    final profile = _storageService.getUserProfile();
    if (profile != null) {
      setState(() {
        userId = profile.id;
      });
    }
  }

  void _loadImageDimensions() {
    final imageProvider = CachedNetworkImageProvider('${backend_url}api/image/${widget.event.imageUrl}');
    imageProvider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((info, _) {
        if (mounted) {
          setState(() {
            _imageHeight = info.image.height.toDouble();
            _imageWidth = info.image.width.toDouble();
          });
        }
      }, onError: (_, __) {
        if (mounted) {
          setState(() {
            _imageHeight = null;
            _imageWidth = null;
          });
        }
      }),
    );
  }

  Future<void> _loadImage() async {
      imageData = await  ImageLoader.loadImage('${backend_url}api/image/${widget.event.cardUrl}');
  }

  Future<void> _generateImageWithQr() async {
    try {
      if(widget.event != null) {
        await ImageQrService.generateImageWithQr(
          event:  widget.event!
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing image: $e')),
      );
    }
  }

  double _calculateExpandedHeight(BuildContext context) {
    if (_imageWidth == null || _imageHeight == null) {
      return _defaultExpandedHeight;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final aspectRatio = _imageWidth! / _imageHeight!;
    return screenWidth / aspectRatio;
  }

  bool existsTicketUpdatedAfterEvent(Event event) {
    return event.tickets.any((ticket) {
      final ticketUpdatedAt = ticket['updatedAt'] is DateTime 
          ? ticket['updatedAt'] as DateTime
          : DateTime.parse(ticket['updatedAt'] as String);
      return ticketUpdatedAt.isAfter(event.updatedAt);
    });
  }

  // Widget for position control with arrow buttons
  Widget _buildPositionControl({
    required String title,
    required int xValue,
    required int yValue,
    required Function(int, int) onChanged,
    Color? color,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color ?? Colors.blue[700],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            
            // Position display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text(
                      'X: $xValue',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Y: $yValue',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                
                // Arrow controls
                Column(
                  children: [
                    // Up button
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      onPressed: () => onChanged(xValue, yValue - 5),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    
                    Row(
                      children: [
                        // Left button
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_left),
                          onPressed: () => onChanged(xValue - 5, yValue),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Right button
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_right),
                          onPressed: () => onChanged(xValue + 5, yValue),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Down button
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      onPressed: () => onChanged(xValue, yValue + 5),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Fine adjustment buttons
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.remove, size: 16),
                  label: const Text('-1'),
                  onPressed: () => onChanged(xValue - 1, yValue),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('+1'),
                  onPressed: () => onChanged(xValue + 1, yValue),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Widget for size control
  Widget _buildSizeControl({
    required String title,
    required int value,
    required Function(int) onChanged,
    Color? color,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color ?? Colors.green[700],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            
            // Size display and controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$value px',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                
                Row(
                  children: [
                    // Decrease button
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      color: Colors.red,
                      onPressed: () => onChanged(value - 5),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Increase button
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.green,
                      onPressed: () => onChanged(value + 5),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            // Slider for fine control
            Slider(
              value: value.toDouble(),
              min: 50,
              max: 500,
              divisions: 45,
              label: '$value px',
              onChanged: (newValue) => onChanged(newValue.toInt()),
            ),
          ],
        ),
      ),
    );
  }

  // Action buttons
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Save Settings'),
            onPressed: _savePreferences,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset Defaults'),
            onPressed: _resetToDefaults,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.blue.shade300),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(Event event, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600;
    final isVeryLargeScreen = screenWidth > 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Editor'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePreferences,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isVeryLargeScreen ? 800 : (isLargeScreen ? 600 : double.infinity),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 24 : 16,
              vertical: 16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Hero(
                  tag: 'event-image-${event.id}',
                  child: CachedNetworkImage(
                    imageUrl: widget.useDNS ? '${backend_url}api/image/${event.imageUrl}' : '${backend_url_with_fallback_ip}api/image/${event.imageUrl}',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) {
                      return const Icon(Icons.error);
                    },
                  ),
                ),
                
                const SizedBox(height: 24),
                SingleChildScrollView(
                  child: Column(
                    children: [
                      // QR Code Position Control
                      _buildPositionControl(
                        title: 'QR Code Position',
                        xValue: dstX,
                        yValue: dstY,
                        onChanged: (newX, newY) {
                          setState(() {
                            dstX = newX.clamp(0, 1000);
                            dstY = newY.clamp(0, 1000);
                          });
                        },
                        color: Colors.blue[700],
                      ),
                      
                      // Text Position Control
                      _buildPositionControl(
                        title: 'Text Position',
                        xValue: dstX2,
                        yValue: dstY2,
                        onChanged: (newX, newY) {
                          setState(() {
                            dstX2 = newX.clamp(0, 1000);
                            dstY2 = newY.clamp(0, 1000);
                          });
                        },
                        color: Colors.purple[700],
                      ),
                      
                      // QR Size Control
                      _buildSizeControl(
                        title: 'QR Code Size',
                        value: qrSize,
                        onChanged: (newSize) {
                          setState(() {
                            qrSize = newSize.clamp(50, 500);
                          });
                        },
                        color: Colors.green[700],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Action Buttons
                      _buildActionButtons(),
                
                      // Preview info
                      const SizedBox(height: 20),
                      Card(
                        color: Colors.grey[50],
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Current Settings Preview:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('QR Code: Position ($dstX, $dstY), Size: $qrSize px'),
                              Text('Text: Position ($dstX2, $dstY2)'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileLayout(Event event, BuildContext context) {
    final imageHeight = _calculateExpandedHeight(context);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 🖼️ FIXED IMAGE (never scrolls, never collapses)
          SizedBox(
            height: imageHeight,
            width: double.infinity,
            child: Stack(
              children: [
                // 🖼️ Image
                Positioned.fill(
                  child: Hero(
                    tag: 'event-image-${event.id}',
                    child: 

                    (imageData != null) ?
                    Image.memory(
                        Uint8List.fromList(img.encodePng(imageData!)),
                        fit: BoxFit.cover,
                      )
                    : Text("image not found data"),

                  ),
                ),

                // 🔙 Back Button (always visible)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📜 SCROLLABLE CONTROLS (image always visible above)
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Image Editor Controls',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildPositionControl(
                      title: 'QR Code Position',
                      xValue: dstX,
                      yValue: dstY,
                      onChanged: (x, y) {
                        setState(() {
                          dstX = x.clamp(0, 1000);
                          dstY = y.clamp(0, 1000);
                        });
                      },
                      color: Colors.blue[700],
                    ),

                    _buildPositionControl(
                      title: 'Text Position',
                      xValue: dstX2,
                      yValue: dstY2,
                      onChanged: (x, y) {
                        setState(() {
                          dstX2 = x.clamp(0, 1000);
                          dstY2 = y.clamp(0, 1000);
                        });
                      },
                      color: Colors.purple[700],
                    ),

                    _buildSizeControl(
                      title: 'QR Code Size',
                      value: qrSize,
                      onChanged: (size) {
                        setState(() {
                          qrSize = size.clamp(50, 500);
                        });
                      },
                      color: Colors.green[700],
                    ),

                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var newEvent = widget.event;
    if (event2 != null) {
      newEvent = event2 as Event;
    }

    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return isDesktop
        ? _buildDesktopLayout(newEvent, context)
        : _buildMobileLayout(newEvent, context);
  }
}

class ImageQrService {
  static Future<String> generateImageWithQr({
    required Event event,
  }) async {
      String imageSource = '${backend_url}api/image/${event.cardUrl}';
      String qrData = 'https://telabs.co.tz/';
      int qrSize = 200;
      int borderSize = 10;

      try {
        // Load base image
        final image = await ImageLoader.loadImage(imageSource);
        if (image == null) {
          throw Exception('Failed to load image');
        }

      final painter = QrPainter(
        data: qrData,
        version: QrVersions.auto,
        gapless: true,
      );

      final ui.Image uiImage = await painter.toImage(qrSize.toDouble());

      final ByteData byteData =
          await uiImage.toByteData(format: ui.ImageByteFormat.png)
              as ByteData;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final img.Image resizedQr = img.decodePng(pngBytes)!;

      /// 4️⃣ Create white background (slightly larger)
      final bgSize = qrSize + (borderSize * 2);
      final whiteBackground = img.Image(
        width: bgSize,
        height: bgSize,
      );

      img.fill(whiteBackground, color: img.ColorRgb8(255, 255, 255));

      /// 5️⃣ Draw QR centered on white background
      img.compositeImage(
        whiteBackground,
        resizedQr,
        dstX: borderSize,
        dstY: borderSize,
      );

      /// ✅ Final QR image with white background
      final qrImage = whiteBackground;

      final x = (image.width - qrImage.width) ~/ 2;
      final y = (image.height - qrImage.height) ~/ 2;

      /// 6️⃣ Composite QR onto main image
      img.compositeImage(
        image,
        qrImage,
        dstX: x,
        dstY: y,
      );

      img.BitmapFont font = img.arial48;

      final img.Color color = img.ColorRgb8(255, 0, 0); // Red

      int textWidth = 0;
      if (font.size == 14) {
        // arial14: ~9px per character
        textWidth = qrData.length * 9;
      } else if (font.size == 24) {
        // arial24: ~15px per character  
        textWidth = qrData.length * 15;
      } else if (font.size == 48) {
        // arial48: ~30px per character
        textWidth = qrData.length * 30;
      }else {
        textWidth = (qrData.length * font.size * 0.625).toInt();
      }
  
      final textHeight = font.lineHeight;
      
      // Calculate centered position
      final x2 = (image.width - textWidth) ~/ 2;
      final y2 = (image.height - textHeight) ~/ 2;


      img.drawString(image, qrData, font: font, x:x2, y:y2, color: color);

      /// 7️⃣ Save result
      final tempDir = await getTemporaryDirectory();
      final outputFile = File(
        '${tempDir.path}/image_with_qr.jpg',
      );

      await outputFile.writeAsBytes(img.encodeJpg(image, quality: 90));
      debugPrint("image saved at: ${outputFile.path}");
      return outputFile.path;
    } catch (e) {
      rethrow;
    }
  }
}


class ImageLoader {
  static Future<img.Image?> loadImage(String source) async {
    try {
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
    } catch (e) {
      print('❌ Error loading image: $e');
      return null;
    }
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

  static Future<img.Image?> _loadNetworkImage(String url) async {
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
    } catch (e) {
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

  static Future<void> preloadImage(String source) async {
    try {
      print('🔍 Preloading image: $source');
      await loadImage(source);
      print('✅ Image preloaded successfully');
    } catch (e) {
      print('❌ Image preload failed: $e');
    }
  }
}



class SimpleImageCacheManager {
  static const Duration _cacheDuration = Duration(days: 7);
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB max cache

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
