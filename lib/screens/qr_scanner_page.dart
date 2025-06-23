import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
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
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? qrController;
  bool _isScanning = true;
  bool _isLoading = false;
  final TextEditingController _eventIdController = TextEditingController();
  final FocusNode _eventIdFocusNode = FocusNode();
  int scannnedToday = 0;
  DateTime _selectedDate = DateTime.now();

  // Torch and camera controls for qr_code_scanner
  bool _isFlashOn = false;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    if(widget.eventId != 0) _eventIdController.text = '${widget.eventId}';
    checkTicketsScanStatus();
  }

  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      qrController?.pauseCamera();
    }
    qrController?.resumeCamera();
  }

  @override
  void dispose() {
    qrController?.dispose();
    _eventIdController.dispose();
    _eventIdFocusNode.dispose();
    super.dispose();
  }

  void _onQRViewCreated(QRViewController controller) {
    qrController = controller;
    controller.scannedDataStream.listen((scanData) async {
      if (!_isScanning || _isLoading) return;
      setState(() {
        _isScanning = false;
        _isLoading = true;
      });
      await _onDetect(scanData.code);
    });
  }

  Future<void> checkTicketsScanStatus({bool useDNS = true}) async {

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/check_tickets_scan_status/${widget.eventId}') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/check_tickets_scan_status/${widget.eventId}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if((responseData['scanned_today']) != null){
          setState(() {
            scannnedToday = responseData['scanned_today'];
          });
        }
        
      }
    }on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await checkTicketsScanStatus(useDNS: false); // Recursive retry
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching check tickets scan status: $e');
    }
  }

  String formatDateTime(String dateString) {
    List<String> parts = dateString.split('-');

    // Parse components (day, month, year)
    DateTime dateTime = DateTime(
        int.parse(parts[2]), // Year (2025)
        int.parse(parts[1]), // Month (5)
        int.parse(parts[0]) // Day (23)
        );

    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    DateTime localTime = dateTime.isUtc ? dateTime.toLocal() : dateTime;

    return '${weekdays[localTime.weekday - 1]}, '
        '${months[localTime.month - 1]} ${localTime.day}, '
        '${localTime.year} - '
        '${localTime.hour.toString().padLeft(2, '0')}:'
        '${localTime.minute.toString().padLeft(2, '0')}';
  }

  bool isSameDay(String dateString) {
    try {
      // Parse the input string into DateTime (assuming format: DD-MM-YYYY)
      final List<String> parts = dateString.split('-');
      final int day = int.parse(parts[0]);
      final int month = int.parse(parts[1]);
      final int year = int.parse(parts[2]);
      final DateTime inputDate = DateTime(year, month, day);

      final DateTime dayDateOnly =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

      // Compare if the dates are the same
      return inputDate == dayDateOnly;
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
      final DateTime todayDateOnly =
          DateTime(today.year, today.month, today.day);

      // Check if input date is before today
      return inputDate.isBefore(todayDateOnly);
    } catch (e) {
      // Handle parsing errors (invalid date format)
      return false;
    }
  }

  Future<void> _onDetect(String? rawValue) async {
    if (rawValue == null) return;

    setState(() {
      _isScanning = false;
      _isLoading = true;
    });

    try {
      String url = '${backend_url}api/check_ticket/${widget.userId}';

      // Include event ID if provided
      if (_eventIdController.text.isNotEmpty) {
        url += '?event_id=${_eventIdController.text}';
      } else {
        _showErrorSnackbar(context, 'Please enter event ID');
        return;
      }

      String eventId = _eventIdController.text;
      int event_id = jsonDecode(rawValue)['event_id'];
      String event_date = jsonDecode(rawValue)['date'];

      if (int.tryParse(eventId) != event_id) {
        _showCustomDialog(context, "Invalid Ticket!");
        return;
      }

      if (!isSameDay(event_date)) {
        String event_time = jsonDecode(rawValue)['time'];
        String message = "Wrong Day Ticket!";
        _showCustomDialog(context, message,
            ticketDate: '${formatDateTime(event_date)} - $event_time');
        return;
      }

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: rawValue,
      );

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          String message = responseData['message'];

          if (message.trim() == "Valid Ticket!") {

            if((responseData['scanned_today']) != null){
              setState(() {
                scannnedToday = responseData['scanned_today'];
              });
            }

            _showCustomDialog(context, message);
          } else if (message.trim() == "Used Ticket!") {
            String scannedAt = "N/A";
            if((responseData['scanned_at']) != null){
              debugPrint('Formatted Date (debug): $scannedAt'); // For Flutter debug output
              scannedAt = responseData['scanned_at'];
            }

            _showCustomDialog(context, message, scannedAt:scannedAt);
          } else if (message.trim() == "Ticket Already Used!") {
            String scannedAt = "N/A";
            if((responseData['scanned_at']) != null){
              debugPrint('Formatted Date (debug): $scannedAt'); // For Flutter debug output
              scannedAt = responseData['scanned_at'];
            }

            _showCustomDialog(context, message, scannedAt:scannedAt);
          } else {
            _showCustomDialog(context, message);
          }

        } else if (response.statusCode == 302) {
          _handleHTTPRedirect();
        } else {
          if((response.body.contains("Unexpected token")) || (response.body.contains("Unexpected character"))) {
            _showCustomDialog(context, "Invalid Ticket!");
          } else {
            _showErrorSnackbar(context, 'Request failed with status: ${response.statusCode}');
          }
        }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
        debugPrint('- Exception type: ${e.runtimeType}');
        debugPrint('- Message: ${e.message}');
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');

        bool showSocketException = true;
        
        if (e.osError != null) {
          debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
          debugPrint('  - OS message: ${e.osError!.message}');

          // Retry with IP if DNS fails (errno = 7) and not already retrying
          if (e.osError!.errorCode == 7) {
            debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');

            String url = '${backend_url_with_fallback_ip}api/check_ticket/${widget.userId}';
            url += '?event_id=${_eventIdController.text}';

            final response = await http.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: barcode.rawValue,
            );

            if (response.statusCode == 200) {
              final responseData = jsonDecode(response.body);
              String message = responseData['message'];

              if (message.trim() == "Valid Ticket!") {

                if((responseData['scanned_today']) != null){
                  setState(() {
                    scannnedToday = responseData['scanned_today'];
                  });
                }

                _showCustomDialog(context, message);
              } else if (message.trim() == "Used Ticket!") {
                String scannedAt = "N/A";
                if((responseData['scanned_at']) != null){
                  debugPrint('Formatted Date (debug): $scannedAt'); // For Flutter debug output
                  scannedAt = responseData['scanned_at'];
                }

                _showCustomDialog(context, message, scannedAt:scannedAt);
              } else if (message.trim() == "Ticket Already Used!") {
                String scannedAt = "N/A";
                if((responseData['scanned_at']) != null){
                  debugPrint('Formatted Date (debug): $scannedAt'); // For Flutter debug output
                  scannedAt = responseData['scanned_at'];
                }

                _showCustomDialog(context, message, scannedAt:scannedAt);
              } else {
                _showCustomDialog(context, message);
              }

              showSocketException = false;
            } else if (response.statusCode == 302) {
              _handleHTTPRedirect();
              showSocketException = false;
            } else {
              if((response.body.contains("Unexpected token")) || (response.body.contains("Unexpected character"))) {
                _showCustomDialog(context, "Invalid Ticket!");
                showSocketException = false;
              } else {
                _showErrorSnackbar(context, 'Request failed with status: ${response.statusCode}');
              }
            }
          }
        }

        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) setState(() => _isScanning = true);
        });
        if(showSocketException) _handleSocketException(e);
    } catch (e) {
      debugPrint('An error occurred: ${e.toString()}');

      if ((e.toString().contains("Unexpected token")) ||
          (e.toString().contains("Unexpected character"))) {
        _showCustomDialog(context, "Invalid Ticket!");
      } else {
        _showErrorSnackbar(context, 'An error occurred: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
      // Future.delayed(const Duration(seconds: 10), () {
      //   if (mounted) setState(() => _isScanning = true);
      // });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _handleSocketException(SocketException e) {
    if (e.osError?.errorCode == 7 ||
        e.osError?.errorCode == 101 ||
        e.osError?.errorCode == 111) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: const Text(
              'Could not connect to the server. Please check your internet connection.'),
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
        content: const Text(
            'Could not connect to the server. Please check your internet connection.'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showCustomDialog(BuildContext context, String message, {String ticketDate = "", String scannedAt = "", bool isWarning = false}) {
    final isSuccess = message == "Valid Ticket!";
    final isUsedTicket = message == "Used Ticket!";
    final ticketAlreadyUsed = message == "Ticket Already Used!";
    final wrongDayTicket = message == "Wrong Day Ticket!";

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


              if(isUsedTicket || ticketAlreadyUsed)
              const SizedBox(height: 5),
              if(isUsedTicket || ticketAlreadyUsed)
              Text(
                'Used On: $scannedAt',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              if(isUsedTicket || ticketAlreadyUsed)
              const SizedBox(height: 5),

              
              if(wrongDayTicket)
              const SizedBox(height: 5),
              if(wrongDayTicket)
              Text(
                'Booked For: $ticketDate',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              if(wrongDayTicket)
              const SizedBox(height: 5),



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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2025), // Allow dates as early as year 2000
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      if ((picked != _selectedDate)) {
        setState(() {
          _selectedDate = picked;
        });
      }
    }
  }

  Widget _buildDatePicker() {
    return TextButton.icon(
      onPressed: () => _selectDate(context),
      icon: Icon(
        Icons.calendar_today,
        size: 18,
        color: Colors.white.withOpacity(0.7),
      ),
      label: Text(
        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontWeight: FontWeight.w500,
          fontSize: 14, // Smaller font size for compactness
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 0), // Near-zero vertical padding
        minimumSize: const Size(
            0, 30), // Set a small fixed height (e.g., 30 logical pixels)
        tapTargetSize: MaterialTapTargetSize
            .shrinkWrap, // Reduces touch target to content size
        visualDensity: VisualDensity.compact, // Squeezes elements closer
        backgroundColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.black.withOpacity(0.4), width: 1.5),
        ),
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
          'Scan Ticket',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(),
        actions: [
          IconButton(
            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off,
                color: Colors.white),
            onPressed: _toggleFlash,
          ),
          IconButton(
            icon: Icon(_isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                color: Colors.white),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus(); // Dismiss the keyboard
        },
        child: Stack(
          children: [
            QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
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
              top: 10,
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
                      prefixIcon:
                          Icon(Icons.event, color: Colors.white.withOpacity(0.7)),
                      suffixIcon: _eventIdController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear,
                                  color: Colors.white.withOpacity(0.7)),
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

            Positioned(
              top: 75,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14), // Match TextField's vertical padding
                      child: Row(
                        children: [
                          Icon(Icons.qr_code_scanner,
                              color: Colors.white
                                  .withOpacity(0.7)), // Same prefix icon
                          const SizedBox(width: 10), // Default icon spacing
                          Text(
                            'Scanned: $scannnedToday',
                            style: TextStyle(
                              color: Colors.white
                                  .withOpacity(0.7), // Match hint style
                            ),
                          ),
                        ],
                      ),
                    )),
              ),
            ),

            Positioned(
              top: 140,
              left: 20,
              right: 20,
              child: Center(
                child: _buildDatePicker(),
              ),
            ),
          ],
        ),
      )
    );
  }

  void _toggleFlash() async {
    await qrController?.toggleFlash();
    bool? flashStatus = await qrController?.getFlashStatus();
    setState(() {
      _isFlashOn = flashStatus ?? false;
    });
  }

  void _switchCamera() async {
    await qrController?.flipCamera();
    var info = await qrController?.getCameraInfo();
    setState(() {
      _isFrontCamera = info == CameraFacing.front;
    });
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
    this.borderColor = Colors.orange[800]!,
    this.borderWidth = 8,
    this.overlayColor = Colors.black.withOpacity(0.5),
    this.borderRadius = 15,
    this.borderLength = 40,
    this.cutOutSize = 280,
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
    final adjustedBorderLength =
        borderLength > adjustedCutOutSize ? adjustedCutOutSize : borderLength;

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
    final borderAnimationValue =
        0.5; // This would come from an animation controller
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
