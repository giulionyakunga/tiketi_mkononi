import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/models/user_profile.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class UserInformationPage extends StatefulWidget {
   final UserProfile user;

  const UserInformationPage({super.key, required this.user});

  @override
  State<UserInformationPage> createState() => _UserInformationPageState();
}

class _UserInformationPageState extends State<UserInformationPage> with WidgetsBindingObserver {
  int userId = 0;
  String role = "";
  late final StorageService _storageService;

    @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _storageService = StorageService(prefs);
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final profile = _storageService.getUserProfile();
    if (profile != null) {
      setState(() {
        userId = profile.id;
        role = profile.role;
      });
    }
  }


  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = _isLargeScreen(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'User Information',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        foregroundColor: Colors.black,
        elevation: 4,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 1000 : double.infinity,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 32 : 16,
              vertical: 16,
            ),
            child: Column(
              children: [
                _buildProfileHeader(context, isDarkMode, isLargeScreen),
                _buildUserInfoCard(context),
                _buildContactCard(context),
                _buildAddressCard(context),
                _buildAccountMetadataCard(context),
              ],
            ),
          ),
        )
      ),
    );
  }

    Widget _buildProfileHeader(BuildContext context, bool isDarkMode, bool isLargeScreen) { 
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 32 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode 
            ? [Colors.orange[200]!, Colors.orange[800]!]
            : [Colors.orange[200]!, Colors.orange[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: isLargeScreen
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProfileAvatar(),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.user.firstName} ${widget.user.lastName}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(
                          widget.user.role.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        backgroundColor: Colors.orange[900],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildProfileAvatar(),
                const SizedBox(height: 6),
                Text(
                  '${widget.user.firstName} ${widget.user.lastName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.user.email,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Chip(
                  label: Text(
                    widget.user.role.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                  ),
                  backgroundColor: Colors.orange[900],
                ),
              ],
            ),
    );
  }






  Widget _buildProfileAvatar() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            spreadRadius: 1,
          )
        ],
      ),
      child: CircleAvatar(
        radius: 50,
        backgroundColor: Colors.white,
        backgroundImage: NetworkImage(
          'https://ui-avatars.com/api/?name=${widget.user.firstName}+${widget.user.lastName}&background=random',
        ),
      ),
    );
  }

  Color _getRoleColor() {
    switch (widget.user.role.toLowerCase()) {
      case 'admin':
        return Colors.red[400]!;
      case 'manager':
        return Colors.orange[400]!;
      case 'user':
        return Colors.green[400]!;
      default:
        return Colors.blue[400]!;
    }
  }

  Widget _buildUserInfoCard(BuildContext context,) {
    return _buildCard(
      title: 'Personal Information',
      icon: Icons.person_outline,
      children: [
        _buildInfoRow(
          context: context,
          label: 'User ID',
          value: widget.user.id.toString(),
          icon: Icons.badge_outlined,
        ),
        _buildInfoRow(
          context: context,
          label: 'Full Name',
          value: '${widget.user.firstName} ${widget.user.middleName} ${widget.user.lastName}',
          icon: Icons.person,
        ),
        _buildInfoRow(
          context: context,
          label: 'Role',
          value: widget.user.role,
          icon: Icons.work_outline,
          valueColor: _getRoleColor(),
        ),
      ],
    );
  }

  Widget _buildContactCard(BuildContext context,) {
    return _buildCard(
      title: 'Contact Information',
      icon: Icons.contact_mail_outlined,
      children: [
        _buildInfoRow(
          context: context,
          label: 'Email',
          value: widget.user.email,
          icon: Icons.email_outlined,
          isEmail: true,
        ),
        _buildInfoRow(
          context: context,
          label: 'Phone',
          value: widget.user.phoneNumber,
          icon: Icons.phone_outlined,
          isPhone: true,
        ),
      ],
    );
  }

  Widget _buildAddressCard(BuildContext context,) {
    return _buildCard(
      title: 'Address Information',
      icon: Icons.location_on_outlined,
      children: [
        _buildInfoRow(
          context: context,
          label: 'Region',
          value: widget.user.region,
          icon: Icons.location_city_outlined,
        ),
        _buildInfoRow(
          context: context,
          label: 'District',
          value: widget.user.district,
          icon: Icons.location_city_outlined,
        ),
        _buildInfoRow(
          context: context,
          label: 'Ward',
          value: widget.user.ward,
          icon: Icons.account_balance_outlined,
        ),
        _buildInfoRow(
          context: context,
          label: 'Street',
          value: widget.user.street,
          icon: Icons.home_outlined,
        ),
      ],
    );
  }

    Widget _buildAccountMetadataCard(BuildContext context,) {
    return _buildCard(
      title: 'Account Metadata',
      icon: Icons.location_on_outlined,
      children: [
        _buildInfoRow(
          context: context,
          label: 'Created',
          value: widget.user.createdAt!.toIso8601String(),
          icon: Icons.calendar_today_rounded,
          copyable: (role == "admin") ? true : false,
        ),
        _buildInfoRow(
          context: context,
          label: 'Updated',
          value: widget.user.updatedAt!.toIso8601String(),
          icon: Icons.update,
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Header
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Divider
            Divider(
              color: Colors.grey[200],
              height: 1,
              thickness: 1,
            ),
            
            const SizedBox(height: 16),
            
            // Info Items
            Column(
              children: children,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
    bool isEmail = false,
    bool isPhone = false,
    bool copyable = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: Colors.blue[700],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Label and Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: copyable
                            ? () {
                                Clipboard.setData(ClipboardData(text: widget.user.password));
                              }
                            : null,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: valueColor ?? Colors.grey[800],
                          ),
                        ),
                      ),
                    ),
                    if (isEmail)
                      IconButton(
                        icon: Icon(
                          Icons.email_outlined,
                          size: 18,
                          color: Colors.blue[600],
                        ),
                        onPressed: () {
                          _launchEmailApp(context: context, recipient: widget.user.phoneNumber);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (isPhone)
                      IconButton(
                        icon: Icon(
                          Icons.phone_outlined,
                          size: 18,
                          color: Colors.blue[600],
                        ),
                        onPressed: () {
                          _launchPhoneCall(context, widget.user.phoneNumber);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    if (copyable)
                      IconButton(
                        icon: Icon(
                          Icons.copy_outlined,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        onPressed: () {
                          // Implement copy to clipboard
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  
  Future<void> _launchPhoneCall(BuildContext context, String phoneNumber) async {
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

  Future<void> _launchEmailApp({ required BuildContext context, required String recipient, String? subject, String? body}) async {
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
}