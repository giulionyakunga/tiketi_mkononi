import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/screens/privacy_security_page.dart';

class ApplyToBeTransporterPage extends StatefulWidget {
  final int userId;

  const ApplyToBeTransporterPage({super.key, required this.userId});

  @override
  State<ApplyToBeTransporterPage> createState() =>
      _ApplyToBeTransporterPageState();
}

class _ApplyToBeTransporterPageState
    extends State<ApplyToBeTransporterPage> {
  late int userId;
  bool _isLoading = false;
  bool _applied = false;

  final TextEditingController _companyNameController = TextEditingController();

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
          ? Uri.parse('${backend_url}api/apply_to_be')
          : Uri.parse(
              '${backend_url_with_fallback_ip}apply_to_be');

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'type': 'transporter',
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
            Text(
              'Application Submitted',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Your transporter application has been received.\n\n'
          'Once approved, you will be able to sell bus tickets, '
          'send digital tickets via SMS to your customers, '
          'manage passenger bookings, and also handle cargo and parcel services '
          'with tracking across your offices using Tiketi Mkononi.',
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
        title: const Text('Become a Transporter'),
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
                  Icon(Icons.directions_bus, size: 72, color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Sell Bus Tickets & Manage Transport Services',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Enable customers to book bus tickets and receive digital tickets via SMS, '
                    'while also managing cargo and parcel transportation services efficiently.',
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
              maxLength: 40,
              decoration: InputDecoration(
                labelText: 'Transport Company Name',
                hintText: 'e.g. ABC Transport Services',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.business),
              ),
            ),

            const SizedBox(height: 28),

           _feature(
              Icons.confirmation_number,
              'Sell Bus Tickets',
              'Allow customers to book and pay for bus tickets easily through the platform.',
            ),
            _feature(
              Icons.sms,
              'Digital Tickets via SMS',
              'Passengers receive ticket confirmations instantly via SMS after booking.',
            ),
            _feature(
              Icons.local_shipping,
              'Cargo & Parcel Services',
              'Manage cargo registration, delivery, and tracking across your offices.',
            ),
            _feature(
              Icons.location_on,
              'Real-Time Tracking',
              'Track both passengers and cargo movement across routes and destinations.',
            ),
            _feature(
              Icons.security,
              'Transparency & Trust',
              'Maintain clear digital records to reduce disputes and improve customer confidence.',
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
                            _applied ? 'Application Submitted' : 'Apply as Transporter',
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