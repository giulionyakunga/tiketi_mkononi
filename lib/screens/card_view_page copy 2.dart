import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';


import 'dart:io';
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
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:tiketi_mkononi/models/ticket.dart';
import 'package:tiketi_mkononi/services/SimpleCodec.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;



class CardViewPage extends StatefulWidget {
  final Event event;

  const CardViewPage({super.key, required this.event});

  @override
  State<CardViewPage> createState() => _CardViewPageState();
}

class _CardViewPageState extends State<CardViewPage> {
  late OverlayConfig config;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    config = const OverlayConfig(
      qrOffset: Offset(40, 40),
      textOffset: Offset(40, 260),
      qrSize: 160,
    );
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      config = config.copyWith(
        qrOffset: Offset(
          p.getDouble('qrX') ?? 40,
          p.getDouble('qrY') ?? 40,
        ),
        textOffset: Offset(
          p.getDouble('txtX') ?? 40,
          p.getDouble('txtY') ?? 260,
        ),
        qrSize: p.getDouble('qrSize') ?? 160,
      );
    });
  }

  Future<void> _savePrefs({bool useDNS = true}) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble('qrX', config.qrOffset.dx);
    await p.setDouble('qrY', config.qrOffset.dy);
    await p.setDouble('txtX', config.textOffset.dx);
    await p.setDouble('txtY', config.textOffset.dy);
    await p.setDouble('qrSize', config.qrSize);


    final Map<String, dynamic> requestBody = {
      'event_id': widget.event.id,
      'dst_x': config.qrOffset.dx,
      'dst_y': config.qrOffset.dy,
      'dst_x2': config.textOffset.dx,
      'dst_y2': config.textOffset.dy,
      'qr_size': config.qrSize,
    };


    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/event_card_info') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/event_card_info'); // Use IP

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        if (response.body == "Event updated successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
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
            await _savePrefs(useDNS: false); // Recursive retry
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Card Editor'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.save, 
              color: Colors.orange[800]
            ),
            onPressed: () async {
              await _savePrefs();
              await ImageExportService.export(
                event: widget.event,
                config: config,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Image saved successfully')),
                );
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LivePreviewCanvas(
              imageUrl: '${backend_url}api/image/${widget.event.cardUrl}',
              config: config,
            ),
          ),
          EditorControls(
            config: config,
            onChanged: (c) => setState(() => config = c),
          ),
        ],
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




//live_preview_canvas.dart
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
    return Stack(
      children: [
        Positioned.fill(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
          ),
        ),

        /// QR CODE
        Positioned(
          left: config.qrOffset.dx,
          top: config.qrOffset.dy,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(6),
            child: QrImageView(
              data: 'https://telabs.co.tz/',
              size: config.qrSize,
            ),
          ),
        ),

        /// TEXT
        Positioned(
          left: config.textOffset.dx,
          top: config.textOffset.dy,
          child: const Text(
            'https://telabs.co.tz/',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red,
              shadows: [
                Shadow(color: Colors.black, blurRadius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}



// editor_controls.dart
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
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(blurRadius: 10)],
      ),
      child: Column(
        children: [
          _slider(
            'QR Size',
            config.qrSize,
            80,
            320,
            (v) => onChanged(config.copyWith(qrSize: v)),
          ),
          _offset('QR Position', config.qrOffset,
              (o) => onChanged(config.copyWith(qrOffset: o))),
          _offset('Text Position', config.textOffset,
              (o) => onChanged(config.copyWith(textOffset: o))),
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChange,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(value: value, min: min, max: max, onChanged: onChange),
      ],
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
        Row(
          children: [
            Expanded(
              child: Slider(
                value: offset.dx,
                min: 0,
                max: 500,
                onChanged: (v) => onChange(Offset(v, offset.dy)),
              ),
            ),
            Expanded(
              child: Slider(
                value: offset.dy,
                min: 0,
                max: 800,
                onChanged: (v) => onChange(Offset(offset.dx, v)),
              ),
            ),
          ],
        )
      ],
    );
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


// image_export_service.dart
class ImageExportService {
  static Future<void> export({
    required Event event,
    required OverlayConfig config,
  }) async {
    final baseImage = await ImageLoader.loadImage(
      '${backend_url}api/image/${event.cardUrl}',
    );

    if (baseImage == null) return;

    final qrPainter = QrPainter(
      data: 'https://telabs.co.tz/',
      version: QrVersions.auto,
    );

    final uiImg = await qrPainter.toImage(config.qrSize);
    final data =
        await uiImg.toByteData(format: ui.ImageByteFormat.png) as ByteData;

    final qr = img.decodePng(data.buffer.asUint8List())!;

    img.compositeImage(
      baseImage,
      qr,
      dstX: config.qrOffset.dx.toInt(),
      dstY: config.qrOffset.dy.toInt(),
    );

    img.drawString(
      baseImage,
      'https://telabs.co.tz/',
      font: img.arial24,
      x: config.textOffset.dx.toInt(),
      y: config.textOffset.dy.toInt(),
      color: img.ColorRgb8(255, 0, 0),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/final_card.jpg');
    await file.writeAsBytes(img.encodeJpg(baseImage, quality: 90));
  }
}




