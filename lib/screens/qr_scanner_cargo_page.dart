import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:tiketi_mkononi/services/SimpleCodec.dart';

class QRScannerCargoPage extends StatefulWidget {
  final int userId;
  final int companyId;
  final int officeId;
  final String companyName;
  final String userName;
  final String userPhoneNumber;

  const QRScannerCargoPage({super.key, required this.userId, required this.companyId, required this.companyName, required this.officeId, required this.userName, required this.userPhoneNumber});


  @override
  State<QRScannerCargoPage> createState() => _QRScannerCargoPageState();
}

class _QRScannerCargoPageState extends State<QRScannerCargoPage> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isScanning = true;
  bool _isReceivingPackagesByCode = false;
  bool _isLoading = false;
  bool _isReceivingPackages = true;
  final TextEditingController _packageNumberController = TextEditingController();
  int receivedToday = 0;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _torchEnabled = false;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    checkPackagesReceiveStatus();
  }

  @override
  void dispose() {
    cameraController.dispose();
    _packageNumberController.dispose();
    super.dispose();
  }

  Future<void> checkPackagesReceiveStatus({bool useDNS = true}) async {
    final Uri uri = useDNS
        ? Uri.parse(
            '${backend_url}api/check_consignments_receive_status/${widget.officeId}') // Original URL
        : Uri.parse(
            '${backend_url_with_fallback_ip}check_consignments_receive_status/${widget.officeId}'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if ((responseData['received_today']) != null) {
          setState(() {
            receivedToday = responseData['received_today'];
          });
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
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) &&
            useDNS) {
          debugPrint(
              'DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await checkPackagesReceiveStatus(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching packages receive status: $e');
    }
  }

  Future<void> _onDetect(BarcodeCapture capture,
      {bool useDNS = true, bool isRetry = false}) async {
    if ((!_isScanning || _isLoading) && !isRetry) return;

    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      if (barcode.rawValue == null) return;

      setState(() {
        _isScanning = false;
        _isLoading = true;
      });

      try {
        // Include event ID if provided       

        String url = useDNS ? '${backend_url}api/receive_consignment/${widget.userId}/${widget.officeId}' : '${backend_url_with_fallback_ip}receive_consignment/${widget.userId}/${widget.officeId}';

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: SimpleCodec.decode(barcode.rawValue!),
        );

        debugPrint(' rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr response.body : ${response.body}');

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          String message = responseData['message'];

          if (message.trim() == "Consignment Received!") {
            setState(() {
              receivedToday = responseData['received_today'];
            });

            _showCustomDialog(context, message);
          } else if (message.trim() == "Consignment Already Received!") {
            String receivedAt = "N/A";
            if ((responseData['received_at']) != null) {
              receivedAt = responseData['received_at'];
            }
            _showCustomDialog(context, message, receivedAt: receivedAt);
          } else {
            _showCustomDialog(context, message);
          }
        } else if (response.statusCode == 302) {
          _handleHTTPRedirect();
        } else {
          if ((response.body.contains("Unexpected token")) ||
              (response.body.contains("Unexpected character"))) {
            _showCustomDialog(context, "Invalid Code!");
          } else {
            _showErrorSnackbar(
                context, 'Request failed with status: ${response.statusCode}');
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
          debugPrint('  - errorCode: ${e.osError!.errorCode}');
          debugPrint('  - useDNS: ${useDNS}');

          // Retry with IP if DNS fails (errno = 7) and not already retrying
          if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) &&
              useDNS) {
            debugPrint(
                'DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
            await _onDetect(capture,
                useDNS: false, isRetry: true); // Recursive retry

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('use_dns', false);
            return;
          }
        }

        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) setState(() => _isScanning = true);
        });
        if (showSocketException) _handleSocketException(e);
      } catch (e) {
        debugPrint('An error occurred: ${e.toString()}');

        if ((e.toString().contains("Unexpected token")) ||
            (e.toString().contains("Unexpected character"))) {
          _showCustomDialog(context, "Invalid Code!");
        } else {
          _showErrorSnackbar(context, 'An error occurred: ${e.toString()}');
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onDetect2(BarcodeCapture capture,
      {bool useDNS = true, bool isRetry = false}) async {
    if ((!_isScanning || _isLoading) && !isRetry) return;

    final List<Barcode> barcodes = capture.barcodes;

    for (final barcode in barcodes) {
      if (barcode.rawValue == null) return;

      setState(() {
        _isScanning = false;
        _isLoading = true;
      });

      try {
        

        int office_id = jsonDecode(SimpleCodec.decode(barcode.rawValue!))['eid'];

        if (widget.officeId != office_id) {
          _showCustomDialog(context, "Wrong Office!");
          return;
        }

        String url = useDNS ? '${backend_url}api/mark_as_delivered/${widget.userId}/${widget.officeId}' : '${backend_url_with_fallback_ip}mark_as_delivered/${widget.userId}/${widget.officeId}';

        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: SimpleCodec.decode(barcode.rawValue!),
        );

        debugPrint(' rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr response.body : ${response.body}');

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          String message = responseData['message'];

          if (message.trim() == "Consignment Delivered!") {
            setState(() {
              receivedToday = responseData['received_today'];
            });

            _showCustomDialog(context, message);
          } else if (message.trim() == "Consignment Already Delivered!") {
            String receivedAt = "N/A";
            if ((responseData['delivered_at']) != null) {
              receivedAt = responseData['delivered_at'];
            }
            _showCustomDialog(context, message, receivedAt: receivedAt);
          } else {
            _showCustomDialog(context, message);
          }
        } else if (response.statusCode == 302) {
          _handleHTTPRedirect();
        } else {
          if ((response.body.contains("Unexpected token")) ||
              (response.body.contains("Unexpected character"))) {
            _showCustomDialog(context, "Invalid Code!");
          } else {
            _showErrorSnackbar(
                context, 'Request failed with status: ${response.statusCode}');
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
          debugPrint('  - errorCode: ${e.osError!.errorCode}');
          debugPrint('  - useDNS: ${useDNS}');

          // Retry with IP if DNS fails (errno = 7) and not already retrying
          if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) &&
              useDNS) {
            debugPrint(
                'DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
            await _onDetect2(capture,
                useDNS: false, isRetry: true); // Recursive retry

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('use_dns', false);
            return;
          }
        }

        Future.delayed(const Duration(seconds: 10), () {
          if (mounted) setState(() => _isScanning = true);
        });
        if (showSocketException) _handleSocketException(e);
      } catch (e) {
        debugPrint('An error occurred: ${e.toString()}');

        if ((e.toString().contains("Unexpected token")) ||
            (e.toString().contains("Unexpected character"))) {
          _showCustomDialog(context, "Invalid Code!");
        } else {
          _showErrorSnackbar(context, 'An error occurred: ${e.toString()}');
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _receiveConsignmentByCode(
      {bool useDNS = true, bool isRetry = false}) async {
    if (_isLoading && !isRetry) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Include event ID if provided
      if (_packageNumberController.text.isEmpty) {
        setState(() {
          _isLoading = false;
        });

        _showErrorSnackbar(context, 'Please enter package number');
        return;
      }

      final Map<String, dynamic> requestBody = {
        'user_id': widget.userId,
        'office_id': widget.officeId,
        'package_number': _packageNumberController.text.trim(),
      };

      String url = useDNS ? '${backend_url}api/receive_consignment_by_code' : '${backend_url_with_fallback_ip}receive_consignment_by_code';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          String message = responseData['message'];

          if (message.trim() == "Consignment Received!") {
            setState(() {
              receivedToday = responseData['received_today'];
            });

            _showCustomDialog(context, message);
          } else if (message.trim() == "Consignment Already Received!") {
            String receivedAt = "N/A";
            if ((responseData['received_at']) != null) {
              receivedAt = responseData['received_at'];
            }
            _showCustomDialog(context, message, receivedAt: receivedAt);
          } else {
            _showCustomDialog(context, message);
          }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        if ((response.body.contains("Unexpected token")) ||
            (response.body.contains("Unexpected character"))) {
          _showCustomDialog(context, "Invalid Code!");
        } else {
          _showErrorSnackbar(
              context, 'Request failed with status: ${response.statusCode}');
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
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) &&
            useDNS) {
          debugPrint(
              'DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _receiveConsignmentByCode(
              useDNS: false, isRetry: true); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) setState(() => _isScanning = true);
      });
      if (showSocketException) _handleSocketException(e);
    } catch (e) {
      debugPrint('An error occurred: ${e.toString()}');

      if ((e.toString().contains("Unexpected token")) ||
          (e.toString().contains("Unexpected character"))) {
        _showCustomDialog(context, "Invalid Code!");
      } else {
        _showErrorSnackbar(context, 'An error occurred: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsDeliveredByCode(
      {bool useDNS = true, bool isRetry = false}) async {
    if (_isLoading && !isRetry) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Include event ID if provided
      if (_packageNumberController.text.isEmpty) {
        setState(() {
          _isLoading = false;
        });

        _showErrorSnackbar(context, 'Please enter package number');
        return;
      }

      final Map<String, dynamic> requestBody = {
        'user_id': widget.userId,
        'office_id': widget.officeId,
        'package_number': _packageNumberController.text.trim(),
      };

      String url = useDNS ? '${backend_url}api/mark_as_delivered_by_code' : '${backend_url_with_fallback_ip}mark_as_delivered_by_code';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String message = responseData['message'];

        if (message.trim() == "Consignment Delivered!") {
          setState(() {
            receivedToday = responseData['received_today'];
          });

          _showCustomDialog(context, message);
        } else if (message.trim() == "Consignment Already Delivered!") {
          String receivedAt = "N/A";
          if ((responseData['delivered_at']) != null) {
            receivedAt = responseData['delivered_at'];
          }
          _showCustomDialog(context, message, receivedAt: receivedAt);
        } else {
          _showCustomDialog(context, message);
        }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        if ((response.body.contains("Unexpected token")) ||
            (response.body.contains("Unexpected character"))) {
          _showCustomDialog(context, "Invalid Code!");
        } else {
          _showErrorSnackbar(
              context, 'Request failed with status: ${response.statusCode}');
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
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) &&
            useDNS) {
          debugPrint(
              'DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _markAsDeliveredByCode(
              useDNS: false, isRetry: true); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) setState(() => _isScanning = true);
      });
      if (showSocketException) _handleSocketException(e);
    } catch (e) {
      debugPrint('An error occurred: ${e.toString()}');

      if ((e.toString().contains("Unexpected token")) ||
          (e.toString().contains("Unexpected character"))) {
        _showCustomDialog(context, "Invalid Code!");
      } else {
        _showErrorSnackbar(context, 'An error occurred: ${e.toString()}');
      }
    } finally {
      setState(() => _isLoading = false);
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

  Future<void> playBeep(bool success) async {
    debugPrint('Trying to play: ${success ? 'success' : 'error'}');
    await _audioPlayer.play(AssetSource(success ? 'sounds/success.mp3' : 'sounds/error.mp3'));
  }

  void _showCustomDialog(BuildContext context, String message, {String receivedAt = ""}) {
    final isSuccess = (message == "Consignment Received!" || message == "Consignment Delivered!");
    final consignmentAlreadyReceived = message == "Consignment Already Received!";
    final wrongOffice = message == "Wrong Office!";

    playBeep(isSuccess);

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
            const SizedBox(height: 5),
            if (consignmentAlreadyReceived)
              Text(
                'Received On: $receivedAt',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            if (wrongOffice)
              Text(
                'Not Destined For This Office',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? Colors.green : Colors.red,
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
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

  PopupMenuItem<String> _buildMenuItem({
    required IconData icon,
    required String text,
    required String value,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 44,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Colors.grey.shade800,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isReceivingPackages ? 'Receiving Packages' : 'Delivering Packages',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
        titleSpacing: 0,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [Colors.deepPurple.shade800, Colors.purple.shade900]
                  : [Colors.teal[200]!, Colors.teal[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: () async {
              await cameraController.toggleTorch();
              setState(() {
                _torchEnabled = !_torchEnabled;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
              color: Colors.white,
            ),
            onPressed: () async {
              await cameraController.switchCamera();
              setState(() {
                _isFrontCamera = !_isFrontCamera;
              });
            },
          ),
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            tooltip: 'More Options',
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            icon: Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 22,
            ),
            onSelected: (value) {
              if ((value == 'delivere_packages') || (value == 'receive_packages')) {
                setState(() {
                  _isReceivingPackages = !_isReceivingPackages;
                });
              } else if (value == 'exit') {
                Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
              if (!_isReceivingPackages)
                _buildMenuItem(
                  icon: Icons.qr_code_scanner,
                  text: 'Receive Packages',
                  value: 'receive_packages',
                ),
              if (_isReceivingPackages)
                _buildMenuItem(
                  icon: Icons.person_off,
                  text: 'Deliver Packages',
                  value: 'delivere_packages',
                ),
              const PopupMenuDivider(),
              _buildMenuItem(
                icon: Icons.exit_to_app,
                text: 'Exit',
                value: 'exit',
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: cameraController,
            // onDetect: _onDetect,

            onDetect: (BarcodeCapture barcode) {
              if (_isReceivingPackages) {
                _onDetect(barcode);
              } else {
                _onDetect2(barcode);
              }
            },
          ),

          Positioned.fill(
            child: Container(
              decoration: ShapeDecoration(
                shape: QrScannerOverlayShape(
                  borderColor: Colors.teal[800]!,
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
                if (!_isReceivingPackagesByCode)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
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
                if (_isReceivingPackagesByCode)
                  Center(
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.6,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: TextField(
                        controller: _packageNumberController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Package Number',
                          hintStyle:
                              TextStyle(color: Colors.white.withOpacity(0.7)),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          prefixIcon: Icon(Icons.numbers,
                              color: Colors.white.withOpacity(0.7)),
                          suffixIcon: _packageNumberController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear,
                                      color: Colors.white.withOpacity(0.7)),
                                  onPressed: () {
                                    _packageNumberController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) => setState(() {}),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Center(
                  child: Wrap(
                    spacing: 16,
                    children: [
                      FloatingActionButton(
                        onPressed: () => Navigator.pop(context),
                        backgroundColor: Colors.red.shade400,
                        child: const Icon(Icons.close, color: Colors.white),
                      ),
                      FloatingActionButton(
                        onPressed: _isReceivingPackagesByCode
                            ? _isReceivingPackages
                                ? () => _receiveConsignmentByCode()
                                : () => _markAsDeliveredByCode()
                            : () => setState(() {
                                  _isReceivingPackagesByCode =
                                      !_isReceivingPackagesByCode;
                                }),
                        backgroundColor: Colors.green.shade400,
                        child: Icon(
                            _isReceivingPackagesByCode ? Icons.check : Icons.edit,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          if(_isReceivingPackages) 
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
                          'Received: $receivedToday',
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
