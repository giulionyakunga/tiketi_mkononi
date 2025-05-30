import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;

class QRScannerPage extends StatefulWidget {
  final int userId;
  final int eventId;
  const QRScannerPage({super.key, required this.userId, required this.eventId});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isLoading = false;
  final TextEditingController _eventIdController = TextEditingController();
  final FocusNode _eventIdFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if(widget.eventId != 0) _eventIdController.text = '${widget.eventId}';
  }

  @override
  void dispose() {
    cameraController.dispose();
    _eventIdController.dispose();
    _eventIdFocusNode.dispose();
    super.dispose();
  }

  bool isToday(String dateString) {
    try {
      // Parse the input string into DateTime (assuming format: DD-MM-YYYY)
      final List<String> parts = dateString.split('-');
      final int day = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int year = int.parse(parts[2]);
      final DateTime inputDate = DateTime(year, month, day);

      // Get today's date (without time, to compare only dates)
      final DateTime today = DateTime.now();
      final DateTime todayDateOnly = DateTime(today.year, today.month, today.day);

      // Compare if the dates are the same
      return inputDate == todayDateOnly;
    } catch (e) {
      // Handle parsing errors (invalid date format)
      return false;
    }
  }

  bool isDateInPast(String dateString) {
    try {
      // Parse the input string into DateTime (assuming format: DD-MM-YYYY)
      final List<String> parts = dateString.split('-');
      final int day = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int year = int.parse(parts[2]);
      final DateTime inputDate = DateTime(year, month, day);

      // Get today's date (without time, to compare only dates)
      final DateTime today = DateTime.now();
      final DateTime todayDateOnly = DateTime(today.year, today.month, today.day);

      // Check if input date is before today
      return inputDate.isBefore(todayDateOnly);
    } catch (e) {
      // Handle parsing errors (invalid date format)
      return false;
    }
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

        String url = '${backend_url}api/check_ticket/${widget.userId}';

        // Include event ID if provided
        if (_eventIdController.text.isNotEmpty) {
          url += '?event_id=${_eventIdController.text}';
        }else {
          _showErrorSnackbar(context, 
            'Please enter event ID'
          );
          return;
        }

        String eventId = _eventIdController.text;
        int event_id = jsonDecode(barcode.rawValue!)['event_id'];
        String event_date = jsonDecode(barcode.rawValue!)['date'];
        
        if (int.tryParse(eventId) != event_id) {
          _showCustomDialog(context, "Invalid Ticket!");
          return;
        }

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: barcode.rawValue,
        );

        if (response.statusCode == 200) {
          if(!isToday(event_date) && !isDateInPast(event_date)) {
            debugPrint(">>>>>>>>>>>>>>>>>>>>>>>>>>>> not today and is not past");
            _showCustomDialog(context, response.body);
          }else if(!isToday(event_date) && isDateInPast(event_date)) {
            debugPrint(">>>>>>>>>>>>>>>>>>>>>>>>>>>> not today and is past");
            _showCustomDialog(context, response.body, isWarning:true);
          }else {
            _showCustomDialog(context, response.body);
          }
        } else if (response.statusCode == 302) {
          _handleHTTPRedirect();
        } else {
          _showErrorSnackbar(context, 
            response.body.contains("Unexpected token") 
              ? 'Invalid Ticket!' 
              : 'Request failed with status: ${response.statusCode}'
          );
        }
      } on SocketException catch (e) {
        debugPrint('Network error occurred:');
        debugPrint('- Exception type: ${e.runtimeType}');
        debugPrint('- Message: ${e.message}');
        
        if (e.osError != null) {
          debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
          debugPrint('  - OS message: ${e.osError!.message}');

          // Retry with IP if DNS fails (errno = 7) and not already retrying
          if (e.osError!.errorCode == 7) {
            debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');

            String url = '${backend_url_with_fallback_ip}api/check_ticket/${widget.userId}';

            // Include event ID if provided
            if (_eventIdController.text.isNotEmpty) {
              url += '?event_id=${_eventIdController.text}';
            }else {
              _showErrorSnackbar(context, 
                'Please enter event ID'
              );
              return;
            }

            String eventId = _eventIdController.text;
            int event_id = jsonDecode(barcode.rawValue!)['event_id'];
          
            if (int.tryParse(eventId) != event_id) {
              _showCustomDialog(context, "Invalid Ticket!");
              return;
            }

            final response = await http.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: barcode.rawValue,
            );


            if (response.statusCode == 200) {
              _showCustomDialog(context, response.body);
            } else if (response.statusCode == 302) {
              _handleHTTPRedirect();
            } else {
              _showErrorSnackbar(context, 
                response.body.contains("Unexpected token") 
                  ? 'Invalid Ticket!' 
                  : 'Request failed with status: ${response.statusCode}'
              );
            }
            
            return;
          }
        }

        _handleSocketException(e);
      } catch (e) {
        _showCustomDialog(context, "Invalid Ticket!");
        // _showErrorSnackbar(context, 'An error occurred: ${e.toString()}');
      } finally {
        setState(() => _isLoading = false);
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) setState(() => _isScanning = true);
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  void _showCustomDialog(BuildContext context, String message, {bool isWarning = false}) {
    final isSuccess = message == "Valid Ticket!";

    if(!isWarning) {
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
    }else {
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
                Icons.check_circle,
                color: Colors.yellow,
                size: 80,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.yellow,
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

          // Event ID input field at top center
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.5,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: TextField(
                  controller: _eventIdController,
                  focusNode: _eventIdFocusNode,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Event ID',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    prefixIcon: Icon(Icons.event, color: Colors.white.withOpacity(0.7)),
                    suffixIcon: _eventIdController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.white.withOpacity(0.7)),
                            onPressed: () {
                              _eventIdController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => setState(() {}),
                ),
              ),
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