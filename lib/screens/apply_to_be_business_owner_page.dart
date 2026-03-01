import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/privacy_security_page.dart';

class ApplyToBeBusinessOwnerPage extends StatefulWidget {
  final int userId;

  const ApplyToBeBusinessOwnerPage({super.key, required this.userId});

  @override
  State<ApplyToBeBusinessOwnerPage> createState() =>
      _ApplyToBeBusinessOwnerPageState();
}

class _ApplyToBeBusinessOwnerPageState
    extends State<ApplyToBeBusinessOwnerPage> {
  late int userId;
  bool _isLoading = false;
  bool _applied = false;

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
  }

  Future<void> _submitApplication({bool useDNS = true}) async {
    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS
          ? Uri.parse('${backend_url}api/apply_to_be_business_owner')
          : Uri.parse(
              '${backend_url_with_fallback_ip}apply_to_be_business_owner');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200 &&
          response.body == "Request received successfully!") {
        setState(() => _applied = true);
        _showSuccessDialog();
      } else {
        _showSnackBar(response.body);
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) &&
          useDNS) {
        await _submitApplication(useDNS: false);
        return;
      }
      _showSnackBar('Network error. Please check your connection.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Text('Application Submitted'),
          ],
        ),
        content: const Text(
          'Your request to become a Business Owner on Tiketi Mkononi '
          'has been received. Our team will review and activate your account shortly.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Business Owner'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 40 : 20,
          vertical: 24,
        ),
        child: Column(
          children: [
            // Hero Section
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3F51B5), Color(0xFF1A237E)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: const [
                  Icon(Icons.storefront, size: 70, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Digitize Your Wholesale Business',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Track sales, manage Wingas, and pay commissions fairly — all in one app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Features
            _feature(
              Icons.bar_chart,
              'Track Total Sales',
              'Monitor daily, weekly, and monthly sales from all Wingas.',
            ),
            _feature(
              Icons.groups,
              'Manage Wingas',
              'View sales performance for each Winga clearly.',
            ),
            _feature(
              Icons.calculate,
              'Automatic Commission Calculation',
              'Pay Wingas proportionally based on recorded sales.',
            ),
            _feature(
              Icons.security,
              'Secure & Transparent',
              'All sales are recorded digitally to avoid disputes.',
            ),

            const SizedBox(height: 32),

            // Apply Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _applied ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _applied ? Colors.green : Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _applied ? Icons.check : Icons.send,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _applied
                                ? 'Application Submitted'
                                : 'Apply as Business Owner',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacySecurityPage(),
                ),
              ),
              child: const Text(
                'By applying, you agree to our Terms & Privacy Policy',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String title, String desc) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.indigo.withOpacity(0.1),
        child: Icon(icon, color: Colors.indigo),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
    );
  }
}