import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:http/http.dart' as http;

class ApplyToBeOrganizerPage extends StatefulWidget {
  final int userId;

  const ApplyToBeOrganizerPage({super.key, required this.userId});

  @override
  State<ApplyToBeOrganizerPage> createState() => _ApplyToBeOrganizerPageState();
}

class _ApplyToBeOrganizerPageState extends State<ApplyToBeOrganizerPage> {
  int userId = 0;
  bool _isLoading = false;
  bool _applied = false;
  
  @override
  void initState() {
    super.initState();
    userId = widget.userId;
  }

  Future<void> _submitApplication() async {
    try {
      setState(() => _isLoading = true);

      final response = await http.post(
        Uri.parse('${backend_url}api/apply_to_be_organizer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId}),
      );

      if (response.statusCode == 200) {
        if (response.body == "Request received successfully!") {
          setState(() => _applied = true);
          _showSuccessDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.body),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } else {
        throw Exception('Request failed with status ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text(
              'Application Submitted',
              style: TextStyle(
                fontSize: 16
              ),
            ),

          ],
        ),
        content: const Text(
          'Your request to become an organizer has been received. '
          'We will review your application and get back to you soon.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become an Event Organizer'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Hero Section
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple.shade400, Colors.purple.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.event, size: 60, color: Colors.white),
                  const SizedBox(height: 16),
                  Text(
                    'Ready to Host Amaizing Events?',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Join our community of event organizers and share your passion with the world',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Benefits Section
            _buildFeatureCard(
              icon: Icons.monetization_on,
              color: Colors.amber.shade600,
              title: 'Earn Money',
              description: 'Sell tickets and generate revenue from your events',
            ),
            _buildFeatureCard(
              icon: Icons.monetization_on,
              color: Colors.amber.shade600,
              title: 'Track Ticket Sales',
              description: 'Monitor your ticket sales and revenue in real-time',
            ),
            _buildFeatureCard(
              icon: Icons.people,
              color: Colors.blue.shade600,
              title: 'Build Community',
              description: 'Connect with like-minded people and grow your audience',
            ),
            _buildFeatureCard(
              icon: Icons.star,
              color: Colors.pink.shade600,
              title: 'Showcase Talent',
              description: 'Highlight your skills and creativity through events',
            ),
            const SizedBox(height: 32),

            // Application Section
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'Ready to get started?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Submit your application and our team will review it within 2-3 business days',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _applied ? null : _submitApplication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _applied ? Colors.green : Theme.of(context).primaryColor,
                          disabledBackgroundColor: _applied ? Colors.green : Theme.of(context).primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2, // <-- moved this here, outside the shape block
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _applied ? Icons.check : Icons.send,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _applied ? 'Application Submitted' : 'Apply Now',
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'By applying, you agree to our Terms of Service',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
      ),
    );
  }
}