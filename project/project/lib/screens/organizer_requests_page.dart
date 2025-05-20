import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:url_launcher/url_launcher.dart';

class OrganizerRequestsPage extends StatefulWidget {
  final int userId;

  const OrganizerRequestsPage({super.key, required this.userId});

  @override
  State<OrganizerRequestsPage> createState() => _OrganizerRequestsPageState();
}

class _OrganizerRequestsPageState extends State<OrganizerRequestsPage> {
  // Mock data - replace with your API data
  final List<Map<String, dynamic>> _requests = [
    {
      'id': 1,
      'user_name': 'John Nyakunga',
      'phone': '+255123456789',
      'email': 'john@example.com',
      'status': 'pending',
      'request_date': '2023-05-15',
    },
    {
      'id': 2,
      'user_name': 'Joff Sanga',
      'phone': '+255987654321',
      'email': 'joff@example.com',
      'status': 'pending',
      'request_date': '2023-05-16',
    },
  ];

  Future<void> _launchPhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone app')),
      );
    }
  }

  Future<void> _updateRequestStatus(int requestId, String status) async {
    // Here you would call your API to update the status
    setState(() {
      _requests.firstWhere((req) => req['id'] == requestId)['status'] = status;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request $status successfully')),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  request['user_name'],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    request['status'].toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: request['status'] == 'pending'
                      ? Colors.orange[100]
                      : request['status'] == 'approved'
                          ? Colors.green[100]
                          : Colors.red[100],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Request Date: ${request['request_date']}'),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.blue),
                  onPressed: () => _launchPhoneCall(request['phone']),
                ),
                const SizedBox(width: 8),
                Text(request['phone']),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email, color: Colors.grey),
                const SizedBox(width: 8),
                Text(request['email']),
              ],
            ),
            const SizedBox(height: 16),
            if (request['status'] == 'pending')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _updateRequestStatus(request['id'], 'approved'),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _updateRequestStatus(request['id'], 'rejected'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizer Requests'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Add refresh functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing requests...')),
              );
            },
          ),
        ],
      ),
      body: _requests.isEmpty
          ? const Center(
              child: Text(
                'No pending organizer requests',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                return _buildRequestCard(_requests[index]);
              },
            ),
    );
  }
}