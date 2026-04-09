import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:path/path.dart' as path;


/// ===============================
/// CONFIG (NORMALIZED VALUES)
/// ===============================
class OverlayConfig {
  final Offset qrOffset; // 0.0 – 1.0
  final Offset textOffset; // 0.0 – 1.0
  final double qrSize; // 0.0 – 1.0 (relative to image width)

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

/// ===============================
/// PAGE
/// ===============================
class CardViewPage extends StatefulWidget {
  final Event event;

  const CardViewPage({super.key, required this.event});

  @override
  State<CardViewPage> createState() => _CardViewPageState();
}

class _CardViewPageState extends State<CardViewPage> {
  late OverlayConfig config;

  @override
  void initState() {
    super.initState();
    config = const OverlayConfig(
      qrOffset: Offset(0.1, 0.1),
      textOffset: Offset(0.1, 0.4),
      qrSize: 0.25,
    );
    _loadPrefs();
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
  }

 





  Future<void> _savePrefs({bool useDNS = true}) async {
    final p = await SharedPreferences.getInstance(); 
    await p.setDouble('qrOffsetDx', config.qrOffset.dx); 
    await p.setDouble('qrOffsetDy', config.qrOffset.dy); 
    await p.setDouble('textOffsetDx', config.textOffset.dx); 
    await p.setDouble('textOffsetDy', config.textOffset.dy);
    await p.setDouble('qrSize', config.qrSize);

    final Map<String, dynamic> requestBody = {
      'event_id': widget.event.id,
      'qr_offset_dx': config.qrOffset.dx,
      'qr_offset_dy': config.qrOffset.dy,
      'text_offset_dx': config.textOffset.dx,
      'text_offset_dy': config.textOffset.dy,
      'qr_size': config.qrSize,
    };
    
    try {

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/event_card_info') : 
      Uri.parse('${backend_url_with_fallback_ip}event_card_info'); // Use IP 
      final response = await http.post( 
        uri, 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody), 
      ); 
      
      if (response.statusCode == 200) { 
        if (response.body == "Event updated successfully!") { 
          ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(response.body)), ); 
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
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _savePrefs(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
      _handleSocketException(e);
    } catch (e)  { 
      debugPrint('- Exception type: ${e.runtimeType}');
    } 
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _savePrefs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Live preview takes remaining space
          Expanded(
            child: LivePreviewCanvas(
              imageUrl: '${backend_url}api/image/${widget.event.cardUrl}',
              config: config,
            ),
          ),

          // Editor controls - make scrollable
          SizedBox(
            height: 300, // or whatever fixed height you want
            child: SingleChildScrollView(
              child: EditorControls(
                config: config,
                onChanged: (c) => setState(() => config = c),
              ),
            ),
          ),
        ],
      ),

    );
  }
}

class LivePreviewCanvas extends StatelessWidget {
  final String imageUrl;
  final OverlayConfig config;

  const LivePreviewCanvas({
    super.key,
    required this.imageUrl,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        final qrX = config.qrOffset.dx * w;
        final qrY = config.qrOffset.dy * h;
        final qrSize = config.qrSize * w;

        final txtX = config.textOffset.dx * w;
        final txtY = config.textOffset.dy * h;

        return Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain, // 🔥 IMPORTANT
              ),
            ),

            /// QR
            Positioned(
              left: qrX,
              top: qrY,
              child: Container(
                color: Colors.white,
                padding: EdgeInsets.zero,
                child: QrImageView(
                  data: 'https://telabs.co.tz/',
                  size: qrSize,
                ),
              ),
            ),

            /// TEXT
            Positioned(
              left: txtX,
              top: txtY,
              child: const Text(
                'Firstname Lastname',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class EditorControls extends StatelessWidget {
  final OverlayConfig config;
  final ValueChanged<OverlayConfig> onChanged;

  const EditorControls({
    super.key,
    required this.config,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text('QR Size'),
          Slider(
            min: 0.01,
            max: 1.0,
            value: config.qrSize,
            onChanged: (v) =>
                onChanged(config.copyWith(qrSize: v)),
          ),
          _offset('QR Position', config.qrOffset,
              (o) => onChanged(config.copyWith(qrOffset: o))),
          _offset('Text Position', config.textOffset,
              (o) => onChanged(config.copyWith(textOffset: o))),
        ],
      ),
    );
  }

  Widget _offset(
    String label,
    Offset offset,
    ValueChanged<Offset> onChange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          min: 0,
          max: 1,
          value: offset.dx,
          onChanged: (v) => onChange(Offset(v, offset.dy)),
        ),
        Slider(
          min: 0,
          max: 1,
          value: offset.dy,
          onChanged: (v) => onChange(Offset(offset.dx, v)),
        ),
      ],
    );
  }
}

class ImageExportService {
  static Future<void> export({
    required Event event,
    required OverlayConfig config,
  }) async {
    final baseImage = await ImageLoader.loadImage(
      '${backend_url}api/image/${event.cardUrl}',
    );
    if (baseImage == null) return;

    final imgW = baseImage.width;
    final imgH = baseImage.height;

    final qrX = (config.qrOffset.dx * imgW).round();
    final qrY = (config.qrOffset.dy * imgH).round();
    final qrSize = (config.qrSize * imgW).round();

    final qrPainter = QrPainter(
      data: 'https://telabs.co.tz/',
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
      gapless: true,
    );

    final ui.Image qrUi = await qrPainter.toImage(qrSize.toDouble());
    final byteData =
        await qrUi.toByteData(format: ui.ImageByteFormat.png) as ByteData;
    final qr = img.decodePng(byteData.buffer.asUint8List())!;

    /// White padding (same as preview)
    final padded = img.Image(
      width: qr.width + 1,
      height: qr.height + 1,
    );
    img.fill(padded, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(padded, qr, dstX: 6, dstY: 6);

    img.compositeImage(
      baseImage,
      padded,
      dstX: qrX,
      dstY: qrY,
    );

    img.drawString(
      baseImage,
      'https://telabs.co.tz/',
      font: img.arial24,
      x: (config.textOffset.dx * imgW).round(),
      y: (config.textOffset.dy * imgH).round(),
      color: img.ColorRgb8(255, 0, 0),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/final_card.jpg');
    await file.writeAsBytes(img.encodeJpg(baseImage, quality: 90));
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
