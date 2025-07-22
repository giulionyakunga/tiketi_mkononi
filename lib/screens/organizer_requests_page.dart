import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:url_launcher/url_launcher.dart';

class OrganizerRequestsPage extends StatefulWidget {
  final int userId;

  const OrganizerRequestsPage({super.key, required this.userId});

  @override 
  State<OrganizerRequestsPage> createState() => _OrganizerRequestsPageState();
}

class _OrganizerRequestsPageState extends State<OrganizerRequestsPage> {
  List<dynamic> _requests = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchOrganizerRequests();
  }

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

  Future<void> _launchEmailApp({ required String recipient, String? subject, String? body}) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: recipient,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );

    try {
      await launchUrl(
        launchUri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to launch email: $e')),
      );
    }
  }

  Future<void> _updateRequestStatus(int userId, int requestId, String status, {bool useDNS = true}) async {

    try {
      setState(() => _isLoading = true);

      final Uri uri = useDNS ? Uri.parse('${backend_url}api/update_organizer_request') // Original URL 
      : Uri.parse('${backend_url_with_fallback_ip}api/update_organizer_request'); // Use IP
      
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          "user_id": userId,
          "request_id": requestId,
          "status": status,
        }),
      );

      if (response.statusCode == 200) {
        if (response.body == "Request status updated successfully!") {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Request $status successfully')),
          );
        }
      } else if (response.statusCode == 302) {
        _handleHTTPRedirect();
      } else {
        _showSnackBar('Request failed: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await _updateRequestStatus(userId, requestId, status, useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    
    setState(() {
      _requests.firstWhere((req) => req['id'] == requestId)['status'] = status;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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

   /// Fetch get_organizer_requests from backend and cache them
  Future<void> fetchOrganizerRequests({bool useDNS = true}) async {

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/get_organizer_requests') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}api/get_organizer_requests'); // Use IP

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        
        List<dynamic> dataList = jsonDecode(response.body);

        if(dataList.length > 0) {
          setState(() {
            _requests = dataList.map((json) => json).toList();
          });
        }
      } else {
        throw Exception('Failed to load tickets');
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if (e.osError!.errorCode == 7 && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await fetchOrganizerRequests(useDNS: false); // Recursive retry
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
    }
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
                  '${request['user']['first_name']} ${request['user']['last_name']}',
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
            Text('Request Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(request['updatedAt']))}'),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.phone, color: Colors.orange[800]),
                  onPressed: () => _launchPhoneCall(request['user']['phone_number']),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _launchPhoneCall(request['user']['phone_number']),                  
                  child: Text(request['user']['phone_number']),
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.email, color: Colors.grey),
                  onPressed: () => _launchEmailApp(
                    recipient: request['user']['email'],
                    subject: 'Tiketi_Mkononi',
                    body: '',
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _launchEmailApp(
                    recipient: request['user']['email'],
                    subject: 'Tiketi_Mkononi',
                    body: '',
                  ),
                  child: Text(request['user']['email']),
                )

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
                    onPressed: () => _isLoading ? null : _updateRequestStatus(request['user']['id'], request['id'], 'approved'),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.cancel, size: 18),
                    label: const Text('Reject'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _isLoading ? null : _updateRequestStatus(request['user']['id'], request['id'], 'rejected'),
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
              fetchOrganizerRequests();
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
          : 
          ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                if(_requests[index]['user'] != null){
                  return  _buildRequestCard(_requests[index]);
                }
                return null;
              },
            ),
    );
  }
}
