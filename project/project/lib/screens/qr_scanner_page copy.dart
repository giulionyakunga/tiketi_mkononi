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

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      if (!_isScanning) return;
      
      setState(() => _isScanning = false);
      
      // Handle the scanned QR code
      if (barcode.rawValue != null) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('QR Code detected: ${barcode.rawValue}')),
        // );
        
        // TODO: Process the QR code data
        // For example, if it's a ticket, validate it and show ticket details




          
        try {

          String url = '${backend_url}api/check_ticket/${widget.userId}';

          final response = await http.post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: '${barcode.rawValue}',
          );

          if (response.statusCode == 200) {
            // ScaffoldMessenger.of(context).showSnackBar(
            //   SnackBar(content: Text(response.body)),
            // );

          

            if(response.body == "Valid Ticket!" ){
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        size: 80,
                        Icons.check_circle, 
                        color: Colors.green
                      ), // Your icon
                      const SizedBox(width: 10), // Add some spacing
                      Expanded(child: Text(response.body)), // Prevent overflow
                    ],
                  ),
                  backgroundColor: Colors.black87, // Optional: Change background color
                  duration: const Duration(seconds: 3), // Optional: Set duration
                ),
              );
            }else if(response.body == "Used Ticket!" ){
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        size: 80,
                        Icons.cancel, 
                        color: Colors.red
                      ), // Cross icon
                      const SizedBox(width: 10),
                      Expanded(child: Text(response.body)),
                    ],
                  ),
                  backgroundColor: Colors.black87,
                  duration: const Duration(seconds: 3),
                ),
              );
            }else if(response.body == "Invalid Ticket!" ){
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        size: 80,
                        Icons.cancel, 
                        color: Colors.red
                      ), // Cross icon
                      const SizedBox(width: 10),
                      Expanded(child: Text(response.body)),
                    ],
                  ),
                  backgroundColor: Colors.black87,
                  duration: const Duration(seconds: 3),
                ),
              );
            } else if(response.body == "Action not permitted!" ){
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        size: 80,
                        Icons.cancel, 
                        color: Colors.red
                      ), // Cross icon
                      const SizedBox(width: 10),
                      Expanded(child: Text(response.body)),
                    ],
                  ),
                  backgroundColor: Colors.black87,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } else {
            if (response.body.contains("Unexpected token")) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(
                        size: 80,
                        Icons.cancel,
                        color: Colors.red
                      ), // Cross icon
                      SizedBox(width: 10),
                      Expanded(child: Text('Invalid Ticket!')),
                    ],
                  ),
                  backgroundColor: Colors.black87,
                  duration: Duration(seconds: 3),
                ),
              );
            }else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        size: 80,
                        Icons.cancel, 
                        color: Colors.red
                      ), // Cross icon
                      const SizedBox(width: 10),
                      Expanded(child: Text('Request not successful, Status Code: ${response.statusCode}')),
                    ],
                  ),
                  backgroundColor: Colors.black87,
                  duration: const Duration(seconds: 3),
                ),
              );
            }          
          }

        } catch (e) {
          // Handle network errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('An error occurred: $e')),
          ); 
        } finally {
          // setState(() {
          //   _isLoading = false; // Re-enable button after request completes
          // });
        }





        
        

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _isScanning = true); // Reset scanning flag
          }
        });

      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.off ? Icons.flash_off : Icons.flash_on,
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
                );
              },
            ),
            onPressed: () => cameraController.switchCamera(),
          ),
          // IconButton(
          //   icon: const Icon(Icons.close),
          //   onPressed: () => Navigator.pop(context),
          // ),
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
              decoration: const ShapeDecoration(
                shape: QrScannerOverlayShape(
                  borderColor: Colors.blue,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: 250,
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Align QR code within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                backgroundColor: Colors.black54,
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
      ..lineTo(
        rect.right,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.bottom,
      )
      ..lineTo(
        rect.left,
        rect.top,
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
  final width = rect.width;
  final height = rect.height;
  final borderOffset = borderWidth / 2;

  // Renaming to avoid conflict with class properties
  final double adjustedCutOutSize = cutOutSize < width ? cutOutSize : width - 25;
  final double adjustedBorderLength = borderLength > adjustedCutOutSize ? adjustedCutOutSize : borderLength;

  final backgroundPaint = Paint()
    ..color = overlayColor
    ..style = PaintingStyle.fill;

  final borderPaint = Paint()
    ..color = borderColor
    ..style = PaintingStyle.stroke
    ..strokeWidth = borderWidth;

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
    ..saveLayer(
      rect,
      backgroundPaint,
    )
    ..drawRect(
      rect,
      backgroundPaint,
    )
    ..drawRRect(
      RRect.fromRectAndRadius(
        cutOutRect,
        Radius.circular(borderRadius),
      ),
      boxPaint,
    )
    ..restore();

  // Draw corners
  final topLeft = cutOutRect.topLeft;
  final topRight = cutOutRect.topRight;
  final bottomLeft = cutOutRect.bottomLeft;
  final bottomRight = cutOutRect.bottomRight;

  // Top left corner
  canvas.drawPath(
    Path()
      ..moveTo(topLeft.dx - borderOffset, topLeft.dy - borderOffset + adjustedBorderLength)
      ..lineTo(topLeft.dx - borderOffset, topLeft.dy - borderOffset)
      ..lineTo(topLeft.dx - borderOffset + adjustedBorderLength, topLeft.dy - borderOffset),
    borderPaint,
  );

  // Top right corner
  canvas.drawPath(
    Path()
      ..moveTo(topRight.dx + borderOffset - adjustedBorderLength, topRight.dy - borderOffset)
      ..lineTo(topRight.dx + borderOffset, topRight.dy - borderOffset)
      ..lineTo(topRight.dx + borderOffset, topRight.dy - borderOffset + adjustedBorderLength),
    borderPaint,
  );

  // Bottom left corner
  canvas.drawPath(
    Path()
      ..moveTo(bottomLeft.dx - borderOffset, bottomLeft.dy + borderOffset - adjustedBorderLength)
      ..lineTo(bottomLeft.dx - borderOffset, bottomLeft.dy + borderOffset)
      ..lineTo(bottomLeft.dx - borderOffset + adjustedBorderLength, bottomLeft.dy + borderOffset),
    borderPaint,
  );

  // Bottom right corner
  canvas.drawPath(
    Path()
      ..moveTo(bottomRight.dx + borderOffset - adjustedBorderLength, bottomRight.dy + borderOffset)
      ..lineTo(bottomRight.dx + borderOffset, bottomRight.dy + borderOffset)
      ..lineTo(bottomRight.dx + borderOffset, bottomRight.dy + borderOffset - adjustedBorderLength),
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