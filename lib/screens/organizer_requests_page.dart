import 'package:flutter/material.dart';
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
                  icon: Icon(Icons.phone, color: Colors.orange[800]),
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





// import 'package:flutter/material.dart';
// import 'package:url_launcher/url_launcher.dart';

// class OrganizerRequestsPage extends StatefulWidget {
//   final int userId;

//   const OrganizerRequestsPage({super.key, required this.userId});

//   @override
//   State<OrganizerRequestsPage> createState() => _OrganizerRequestsPageState();
// }

// class _OrganizerRequestsPageState extends State<OrganizerRequestsPage> {
//   // Mock data - replace with your API data
//   final List<Map<String, dynamic>> _requests = [
//     {
//       'id': 1,
//       'user_name': 'John Nyakunga',
//       'phone': '+255123456789',
//       'email': 'john@example.com',
//       'status': 'pending',
//       'request_date': '2023-05-15',
//       'organization': 'Tanzania Events Ltd',
//       'description': 'Professional event organizer with 5 years experience',
//     },
//     {
//       'id': 2,
//       'user_name': 'Joff Sanga',
//       'phone': '+255987654321',
//       'email': 'joff@example.com',
//       'status': 'pending',
//       'request_date': '2023-05-16',
//       'organization': 'Safari Entertainment',
//       'description': 'Specializing in music festivals and cultural events',
//     },
//   ];

//   // Helper method to determine screen size
//   bool _isLargeScreen(BuildContext context) {
//     return MediaQuery.of(context).size.width > 768;
//   }

//   Future<void> _launchPhoneCall(String phoneNumber) async {
//     final Uri launchUri = Uri(
//       scheme: 'tel',
//       path: phoneNumber,
//     );
//     if (await canLaunchUrl(launchUri)) {
//       await launchUrl(launchUri);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Could not launch phone app')),
//       );
//     }
//   }

//   Future<void> _updateRequestStatus(int requestId, String status) async {
//     // Here you would call your API to update the status
//     setState(() {
//       _requests.firstWhere((req) => req['id'] == requestId)['status'] = status;
//     });
    
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Request $status successfully'),
//         behavior: SnackBarBehavior.floating,
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8),
//         ),
//         margin: EdgeInsets.symmetric(
//           horizontal: _isLargeScreen(context) ? 100 : 16,
//           vertical: 16,
//         ),
//       ),
//     );
//   }

//   Widget _buildRequestCard(Map<String, dynamic> request, bool isLargeScreen) {
//     return Card(
//       elevation: 4,
//       margin: EdgeInsets.symmetric(
//         vertical: 8,
//         horizontal: isLargeScreen ? 16 : 8,
//       ),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Padding(
//         padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
//         child: isLargeScreen
//             ? _buildDesktopRequestCard(request)
//             : _buildMobileRequestCard(request),
//       ),
//     );
//   }

//   Widget _buildDesktopRequestCard(Map<String, dynamic> request) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Expanded(
//               flex: 2,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _buildUserInfoSection(request),
//                   const SizedBox(height: 16),
//                   _buildContactInfoSection(request),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 24),
//             Expanded(
//               flex: 3,
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Organization: ${request['organization']}',
//                     style: const TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Description: ${request['description']}',
//                     style: const TextStyle(
//                       fontSize: 15,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             const SizedBox(width: 24),
//             _buildStatusAndActionsSection(request),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildMobileRequestCard(Map<String, dynamic> request) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildUserInfoSection(request),
//         const SizedBox(height: 12),
//         _buildContactInfoSection(request),
//         const SizedBox(height: 12),
//         Text(
//           'Organization: ${request['organization']}',
//           style: const TextStyle(
//             fontSize: 15,
//             fontWeight: FontWeight.w500,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Description: ${request['description']}',
//           style: const TextStyle(
//             fontSize: 14,
//             color: Colors.grey,
//           ),
//         ),
//         const SizedBox(height: 16),
//         _buildStatusAndActionsSection(request),
//       ],
//     );
//   }

//   Widget _buildUserInfoSection(Map<String, dynamic> request) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           request['user_name'],
//           style: const TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         Chip(
//           label: Text(
//             request['status'].toUpperCase(),
//             style: const TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           backgroundColor: _getStatusColor(request['status']),
//           side: BorderSide.none,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(8),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildContactInfoSection(Map<String, dynamic> request) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Request Date: ${request['request_date']}',
//           style: const TextStyle(
//             fontSize: 14,
//             color: Colors.grey,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Row(
//           children: [
//             IconButton(
//               icon: Icon(Icons.phone, color: Colors.orange[800]),
//               onPressed: () => _launchPhoneCall(request['phone']),
//             ),
//             const SizedBox(width: 4),
//             Text(
//               request['phone'],
//               style: const TextStyle(fontSize: 14),
//             ),
//           ],
//         ),
//         Row(
//           children: [
//             const Icon(Icons.email, color: Colors.grey, size: 20),
//             const SizedBox(width: 8),
//             Text(
//               request['email'],
//               style: const TextStyle(fontSize: 14),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildStatusAndActionsSection(Map<String, dynamic> request) {
//     if (request['status'] != 'pending') {
//       return Container(); // No actions needed if not pending
//     }

//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//       children: [
//         Expanded(
//           child: ElevatedButton.icon(
//             icon: const Icon(Icons.check_circle, size: 18),
//             label: const Text('Approve'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green,
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             onPressed: () => _updateRequestStatus(request['id'], 'approved'),
//           ),
//         ),
//         const SizedBox(width: 16),
//         Expanded(
//           child: ElevatedButton.icon(
//             icon: const Icon(Icons.cancel, size: 18),
//             label: const Text('Reject'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.red,
//               foregroundColor: Colors.white,
//               padding: const EdgeInsets.symmetric(vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//             onPressed: () => _updateRequestStatus(request['id'], 'rejected'),
//           ),
//         ),
//       ],
//     );
//   }

//   Color? _getStatusColor(String status) {
//     switch (status) {
//       case 'pending':
//         return Colors.orange[100];
//       case 'approved':
//         return Colors.green[100];
//       case 'rejected':
//         return Colors.red[100];
//       default:
//         return Colors.grey[100];
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final bool isLargeScreen = _isLargeScreen(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Organizer Requests'),
//         backgroundColor: Colors.deepPurple,
//         foregroundColor: Colors.white,
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             tooltip: 'Refresh',
//             onPressed: () {
//               // Add refresh functionality
//               ScaffoldMessenger.of(context).showSnackBar(
//                 const SnackBar(
//                   content: Text('Refreshing requests...'),
//                   behavior: SnackBarBehavior.floating,
//                 ),
//               );
//             },
//           ),
//         ],
//       ),
//       body: _requests.isEmpty
//           ? Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.people_alt_outlined,
//                     size: 64,
//                     color: Colors.grey[400],
//                   ),
//                   const SizedBox(height: 16),
//                   const Text(
//                     'No pending organizer requests',
//                     style: TextStyle(
//                       fontSize: 18,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 ],
//               ),
//             )
//           : ListView.builder(
//               padding: EdgeInsets.symmetric(
//                 vertical: 16,
//                 horizontal: isLargeScreen ? 32 : 8,
//               ),
//               itemCount: _requests.length,
//               itemBuilder: (context, index) {
//                 return _buildRequestCard(_requests[index], isLargeScreen);
//               },
//             ),
//     );
//   }
// }