import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';
import 'package:tiketi_mkononi/screens/UserInformation.dart';
import 'package:url_launcher/url_launcher.dart';

class SystemUsersPage extends StatefulWidget {
  final int userId;

  const SystemUsersPage({super.key, required this.userId});

  @override 
  State<SystemUsersPage> createState() => _SystemUsersPageState();
}

class _SystemUsersPageState extends State<SystemUsersPage> {
  List<UserProfile> users = [];

  @override
  void initState() {
    super.initState();
    fetchUsers();
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

   /// Fetch users from backend
  Future<void> fetchUsers({bool useDNS = true}) async {

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/get_users_only_by_admin/${widget.userId}')
    : Uri.parse('${backend_url_with_fallback_ip}get_users_only_by_admin/${widget.userId}');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        
        List<dynamic> dataList = jsonDecode(response.body);

        if(dataList.length > 0) {
          setState(() {
            users = dataList.map((json) => UserProfile.fromJson2(json)).toList();
          });
        }
      } else {
        throw Exception('Failed to load users');
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
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await fetchUsers(useDNS: false); // Recursive retry

          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error fetching users: $e');
    }
  }


  Widget _buildRequestCard(UserProfile user) {
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
                  '${user.firstName} ${user.lastName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(
                    user.role.toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: (user.role.toUpperCase() == 'ADMIN') ? Colors.green[100] : (user.role.toUpperCase() == 'ORGANIZER') ? Colors.orange[100] : Colors.blue[100],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Joined On: ${DateFormat('dd MMM yyyy').format(DateTime.parse(user.createdAt!.toIso8601String()))}'),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.phone, color: Colors.orange[800]),
                  onPressed: () => _launchPhoneCall(user.phoneNumber),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _launchPhoneCall(user.phoneNumber),                  
                  child: Text(user.phoneNumber),
                )
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.email, color: Colors.grey),
                  onPressed: () => _launchEmailApp(
                    recipient: user.email,
                    subject: 'Tiketi_Mkononi',
                    body: '',
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _launchEmailApp(
                    recipient: user.email,
                    subject: 'Tiketi_Mkononi',
                    body: '',
                  ),
                  child: Text(user.email),
                )

              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('More'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserInformationPage(user: user),
                      ),
                    );
                  }
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
        title: Text(
          'System Users (${users.length})',
          style: TextStyle(fontSize: 18),
        ),
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Refreshing users...')),
              );
              fetchUsers();
            },
          ),
        ],
      ),
      body: users.isEmpty
          ? const Center(
              child: Text(
                'No user found',
                style: TextStyle(fontSize: 18),
              ),
            )
          : 
          ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              itemBuilder: (context, index) {
                return  _buildRequestCard(users[index]);
              },
            ),
    );
  }
}