import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;

class QRScannerPage extends StatefulWidget {
  final int userId;
  const QRScannerPage({super.key, required this.userId});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isLoading = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_isScanning || _isLoading) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      if (barcode.rawValue == null) return;
      
      setState(() {
        _isScanning = false;
        _isLoading = true;
      });
      
      try {
        final url = '${backend_url}api/check_ticket/${widget.userId}';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: barcode.rawValue,
        );

        if (response.statusCode == 200) {
          _showCustomDialog(context, response.body);
        } else {
          _showErrorSnackbar(context, 
            response.body.contains("Unexpected token") 
              ? 'Invalid Ticket!' 
              : 'Request failed with status: ${response.statusCode}'
          );
        }
    } on SocketException catch (e) {
      if (e.osError?.errorCode == 7) {  // Connection refused
        // Show user-friendly message
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Connection Error'),
            content: Text('Could not connect to the server. Please check your internet connection.'),
          ),
        );
      } else if (e.osError?.errorCode == 111) {  // Connection refused
        // Show user-friendly message
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text('Connection Error'),
            content: Text('Could not connect to the server. Please try again later.'),
          ),
        );
      } else {
        _showSnackBar('Connection Error occurred: ${e.message}');
      }
    } catch (e) {
        _showErrorSnackbar(context, 'An error occurred: ${e.toString()}');
      } finally {
        setState(() => _isLoading = false);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isScanning = true);
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCustomDialog(BuildContext context, String message) {
    final isSuccess = message == "Valid Ticket!";
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: Colors.white,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isSuccess ? Colors.green : Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? Colors.green : Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isScanning = true);
              },
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'QR Code Scanner',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [Colors.deepPurple.shade800, Colors.purple.shade900]
                  :  [Colors.orange[200]!, Colors.orange[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.off ? Icons.flash_off : Icons.flash_on,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                return Icon(
                  state == CameraFacing.front
                      ? Icons.camera_front
                      : Icons.camera_rear,
                  color: Colors.white,
                );
              },
            ),
            onPressed: () => cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          Positioned.fill(
            child: Container(
              decoration: ShapeDecoration(
                shape: QrScannerOverlayShape(
                  borderColor: Colors.orange[800]!,
                  borderRadius: 15,
                  borderLength: 40,
                  borderWidth: 8,
                  cutOutSize: 280,
                  overlayColor: isDarkMode 
                    ? Colors.black.withOpacity(0.5) 
                    : Colors.black.withOpacity(0.4),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Align QR code within the frame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FloatingActionButton(
                  onPressed: () => Navigator.pop(context),
                  backgroundColor: Colors.red.shade400,
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final adjustedCutOutSize = cutOutSize < width ? cutOutSize : width - 25;
    final adjustedBorderLength = borderLength > adjustedCutOutSize 
      ? adjustedCutOutSize 
      : borderLength;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeJoin = StrokeJoin.round;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - adjustedCutOutSize / 2,
      rect.top + height / 2 - adjustedCutOutSize / 2,
      adjustedCutOutSize,
      adjustedCutOutSize,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(
          cutOutRect,
          Radius.circular(borderRadius),
        ),
        boxPaint,
      )
      ..restore();

    // Draw animated border (conceptual - would need animation controller for real animation)
    final borderAnimationValue = 0.5; // This would come from an animation controller
    final animatedBorderLength = adjustedBorderLength * borderAnimationValue;

    // Draw corners with slight animation effect
    final topLeft = cutOutRect.topLeft;
    final topRight = cutOutRect.topRight;
    final bottomLeft = cutOutRect.bottomLeft;
    final bottomRight = cutOutRect.bottomRight;

    // Top left corner
    canvas.drawPath(
      Path()
        ..moveTo(topLeft.dx, topLeft.dy + animatedBorderLength)
        ..lineTo(topLeft.dx, topLeft.dy)
        ..lineTo(topLeft.dx + animatedBorderLength, topLeft.dy),
      borderPaint,
    );

    // Top right corner
    canvas.drawPath(
      Path()
        ..moveTo(topRight.dx - animatedBorderLength, topRight.dy)
        ..lineTo(topRight.dx, topRight.dy)
        ..lineTo(topRight.dx, topRight.dy + animatedBorderLength),
      borderPaint,
    );

    // Bottom left corner
    canvas.drawPath(
      Path()
        ..moveTo(bottomLeft.dx, bottomLeft.dy - animatedBorderLength)
        ..lineTo(bottomLeft.dx, bottomLeft.dy)
        ..lineTo(bottomLeft.dx + animatedBorderLength, bottomLeft.dy),
      borderPaint,
    );

    // Bottom right corner
    canvas.drawPath(
      Path()
        ..moveTo(bottomRight.dx - animatedBorderLength, bottomRight.dy)
        ..lineTo(bottomRight.dx, bottomRight.dy)
        ..lineTo(bottomRight.dx, bottomRight.dy - animatedBorderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}