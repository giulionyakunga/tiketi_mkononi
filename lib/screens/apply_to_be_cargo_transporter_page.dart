import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/privacy_security_page.dart';

class ApplyToBeCargoTransporterPage extends StatefulWidget {
  final int userId;

  const ApplyToBeCargoTransporterPage({super.key, required this.userId});

  @override
  State<ApplyToBeCargoTransporterPage> createState() =>
      _ApplyToBeCargoTransporterPageState();
}

class _ApplyToBeCargoTransporterPageState
    extends State<ApplyToBeCargoTransporterPage> {
  late int userId;
  bool _isLoading = false;
  bool _applied = false;

  final TextEditingController _companyNameController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    userId = widget.userId;
  }

  Future<void> _submitApplication({bool useDNS = true}) async {
    if (_companyNameController.text.trim().isEmpty) {
      _showSnackBar('Please enter your company name');
      return;
    }

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS
          ? Uri.parse('${backend_url}api/apply_to_be_cargo_transporter')
          : Uri.parse(
              '${backend_url_with_fallback_ip}apply_to_be_cargo_transporter');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'company_name': _companyNameController.text.trim(),
        }),
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
          'Your cargo transporter application has been received.\n\n'
          'Once approved, you will be able to register cargo, '
          'send SMS notifications to senders and receivers, '
          'and track parcels across offices using Tiketi Mkononi.',
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
        title: const Text('Become a Cargo Transporter'),
        backgroundColor: Colors.teal[800],
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
                  colors: [Color(0xFF00796B), Color(0xFF004D40)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: const [
                  Icon(Icons.local_shipping,
                      size: 72, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Digitize Cargo & Parcel Tracking',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Enable real-time cargo tracking and SMS notifications '
                    'for senders and receivers across your offices.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Company Name
            TextField(
              controller: _companyNameController,
              decoration: InputDecoration(
                labelText: 'Cargo Company Name',
                hintText: 'e.g. ABC Cargo & Logistics',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.business),
              ),
            ),

            const SizedBox(height: 28),

            _feature(
              Icons.notifications_active,
              'Automatic SMS Notifications',
              'Sender and receiver receive SMS when cargo is admitted and when it reaches destination.',
            ),
            _feature(
              Icons.location_on,
              'Office-to-Office Tracking',
              'Track cargo movement between origin and destination offices.',
            ),
            _feature(
              Icons.inventory_2,
              'Cargo Registration',
              'Digitally register parcels and reduce paperwork.',
            ),
            _feature(
              Icons.security,
              'Transparency & Trust',
              'Reduce disputes by keeping clear digital records.',
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
                      _applied ? Colors.green : Colors.teal[800],
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
                                : 'Apply as Cargo Transporter',
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
        backgroundColor: Colors.teal.withOpacity(0.1),
        child: Icon(icon, color: Colors.teal),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(desc),
    );
  }
}