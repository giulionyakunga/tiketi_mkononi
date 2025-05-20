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
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 600; // Tablet or desktop
    final isVeryLargeScreen = screenWidth > 1200; // Desktop

    return Scaffold(
      appBar: AppBar(
        title: const Text('Become an Event Organizer'),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isVeryLargeScreen ? 1200 : (isLargeScreen ? 800 : double.infinity),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 40 : 24,
              vertical: isLargeScreen ? 32 : 24,
            ),
            child: Column(
              children: [
                // Hero Section
                Container(
                  padding: EdgeInsets.all(isLargeScreen ? 32 : 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange[200]!, Colors.orange[800]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.event, size: isLargeScreen ? 80 : 60, color: Colors.white),
                      SizedBox(height: isLargeScreen ? 24 : 16),
                      Text(
                        'Ready to Host Amazing Events?',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isLargeScreen ? 28 : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isLargeScreen ? 16 : 8),
                      Text(
                        'Join our community of event organizers and share your passion with the world',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70, 
                          fontSize: isLargeScreen ? 18 : 16,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isLargeScreen ? 48 : 32),

                // Benefits Section
                if (isLargeScreen) 
                  _buildFeatureGrid()
                else 
                  _buildFeatureList(),

                SizedBox(height: isLargeScreen ? 48 : 32),

                // Application Section
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isLargeScreen ? 32 : 20),
                    child: Column(
                      children: [
                        Text(
                          'Ready to get started?',
                          style: TextStyle(
                            fontSize: isLargeScreen ? 22 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isLargeScreen ? 16 : 12),
                        Text(
                          'Submit your application and our team will review it within 2-3 business days',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: isLargeScreen ? 16 : null,
                          ),
                        ),
                        SizedBox(height: isLargeScreen ? 32 : 24),
                        SizedBox(
                          width: isLargeScreen ? 400 : double.infinity,
                          height: isLargeScreen ? 60 : 50,
                          child: ElevatedButton(
                            onPressed: _applied ? null : _submitApplication,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _applied 
                                ? Colors.green 
                                : Theme.of(context).primaryColor,
                              disabledBackgroundColor: _applied 
                                ? Colors.green 
                                : Theme.of(context).primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
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
                                        size: isLargeScreen ? 24 : 20,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: isLargeScreen ? 12 : 8),
                                      Text(
                                        _applied ? 'Application Submitted' : 'Apply Now',
                                        style: TextStyle(
                                          fontSize: isLargeScreen ? 18 : 16,
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
                SizedBox(height: isLargeScreen ? 32 : 20),
                Text(
                  'By applying, you agree to our Terms of Service',
                  style: TextStyle(
                    color: Colors.grey, 
                    fontSize: isLargeScreen ? 14 : 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureList() {
    return Column(
      children: [
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
          icon: Icons.assignment_ind,
          color: Colors.deepPurple,
          title: 'Secure Attendee Authentication',  
          description: 'Prevent fraud and manage guest lists seamlessly with real-time digital ticket validation.',  
        ),
        _buildFeatureCard(
          icon: Icons.verified_user,
          color: Colors.blue,
          title: 'Streamlined Door Entry Management',
          description: 'Accelerate and secure guest verification with Tiketi Mkononi App.',
        ),
        _buildFeatureCard(
          icon: Icons.verified_user,
          color: Colors.blue,
          title: 'Effortless Attendee Check-In',  
          description: 'Speed up entry lines and reduce wait times with Tiketi Mkononi\'s instant QR verification.',  
        ),
        _buildFeatureCard(
          icon: Icons.rocket_launch,
          color: Colors.deepPurple,
          title: 'Elevate Your Event Experience',  
          description: 'Impress attendees with frictionless entry powered by Tiketi Mkononi.', 
        ),
        _buildFeatureCard(
          icon: Icons.people,
          color: Colors.orange[800]!,
          title: 'Build Community',
          description: 'Connect with like-minded people and grow your audience',
        ),
        _buildFeatureCard(
          icon: Icons.star,
          color: Colors.pink.shade600,
          title: 'Showcase Talent',
          description: 'Highlight your skills and creativity through events',
        ),
      ],
    );
  }

  Widget _buildFeatureGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 3,
      children: [
        _buildFeatureCard(
          icon: Icons.monetization_on,
          color: Colors.amber.shade600,
          title: 'Earn Money',
          description: 'Sell tickets and generate revenue from your events',
          isLargeScreen: true,
        ),
        _buildFeatureCard(
          icon: Icons.monetization_on,
          color: Colors.amber.shade600,
          title: 'Track Ticket Sales',
          description: 'Monitor your ticket sales and revenue in real-time',
          isLargeScreen: true,
        ),
        _buildFeatureCard(
          icon: Icons.assignment_ind,
          color: Colors.deepPurple,
          title: 'Secure Attendee Authentication',  
          description: 'Prevent fraud and manage guest lists seamlessly',  
          isLargeScreen: true,
        ),
        _buildFeatureCard(
          icon: Icons.verified_user,
          color: Colors.blue,
          title: 'Streamlined Entry',
          description: 'Accelerate guest verification with our app',
          isLargeScreen: true,
        ),
        _buildFeatureCard(
          icon: Icons.verified_user,
          color: Colors.blue,
          title: 'Effortless Check-In',  
          description: 'Speed up entry with instant QR verification',  
          isLargeScreen: true,
        ),
        _buildFeatureCard(
          icon: Icons.rocket_launch,
          color: Colors.deepPurple,
          title: 'Elevate Experience',  
          description: 'Impress attendees with frictionless entry', 
          isLargeScreen: true,
        ),
        _buildFeatureCard(
          icon: Icons.people,
          color: Colors.orange[800]!,
          title: 'Build Community',
          description: 'Connect with like-minded people',
          isLargeScreen: true,
        ),
        _buildFeatureCard(
          icon: Icons.star,
          color: Colors.pink.shade600,
          title: 'Showcase Talent',
          description: 'Highlight your skills and creativity',
          isLargeScreen: true,
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    bool isLargeScreen = false,
  }) {
    if (isLargeScreen) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
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
}