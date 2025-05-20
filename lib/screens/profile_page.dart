import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/screens/apply_to_be_organizer_page.dart';
import 'package:tiketi_mkononi/screens/edit_profile_page.dart';
import 'package:tiketi_mkononi/screens/help_support_page.dart';
import 'package:tiketi_mkononi/screens/language_settings_page.dart';
import 'package:tiketi_mkononi/screens/organizer_requests_page.dart';
import 'package:tiketi_mkononi/screens/qr_scanner_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int userId = 0;
  String role = "";
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  
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
        _firstNameController.text = profile.firstName;
        _lastNameController.text = profile.lastName;
        _emailController.text = profile.email;
      });
    }
  }

  void _clearUserProfile() {
    _storageService.clearUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.width > 768;
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
                        '${_firstNameController.text} ${_lastNameController.text}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailController.text,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      if (role.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          backgroundColor: Colors.orange[900],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildProfileAvatar(),
                const SizedBox(height: 16),
                Text(
                  '${_firstNameController.text} ${_lastNameController.text}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _emailController.text,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      role.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                    backgroundColor: Colors.orange[900],
                  ),
                ],
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
          'https://ui-avatars.com/api/?name=${_firstNameController.text}+${_lastNameController.text}&background=random',
        ),
      ),
    );
  }

  Widget _buildActionCards(BuildContext context, bool isLargeScreen) {
    final accountSettings = [
      _buildActionTile(
        context,
        icon: Icons.edit,
        iconColor: Colors.blue,
        title: 'Edit Profile',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditProfilePage(),
            ),
          );
          _loadUserProfile();
        },
      ),
      _buildActionTile(
        context,
        icon: Icons.history,
        iconColor: Colors.orange,
        title: 'Purchase History',
        onTap: () {
          // TODO: Implement purchase history
        },
      ),
      _buildActionTile(
        context,
        icon: Icons.favorite,
        iconColor: Colors.pink,
        title: 'Favorite Events',
        onTap: () {
          // TODO: Implement favorites
        },
      ),
    ];

    final appSettings = [
      _buildActionTile(
        context,
        icon: Icons.notifications,
        iconColor: Colors.purple,
        title: 'Notifications',
        onTap: () {
          // TODO: Implement notifications
        },
      ),
      _buildActionTile(
        context,
        icon: Icons.security,
        iconColor: Colors.teal,
        title: 'Privacy & Security',
        onTap: () {
          // TODO: Implement privacy
        },
      ),
      _buildActionTile(
        context,
        icon: Icons.help,
        iconColor: Colors.green,
        title: 'Help & Support',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const HelpSupportPage(),
            ),
          );
          _loadUserProfile();
        },
      ),
    ];

    return isLargeScreen
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildProfileCard(
                  context,
                  title: 'Account Settings',
                  items: accountSettings,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProfileCard(
                  context,
                  title: 'App Settings',
                  items: appSettings,
                ),
              ),
            ],
          )
        : Column(
            children: [
              _buildProfileCard(
                context,
                title: 'Account Settings',
                items: accountSettings,
              ),
              const SizedBox(height: 16),
              _buildProfileCard(
                context,
                title: 'App Settings',
                items: appSettings,
              ),
            ],
          );
  }

  Widget _buildProfileCard(BuildContext context, {required String title, required List<Widget> items}) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }

  Widget _buildSettingsMenu(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        _buildActionTile(
          context,
          icon: Icons.language,
          iconColor: Colors.blue,
          title: 'Language Settings',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSettingsPage(),
              ),
            );
          },
        ),
        if(role != "user")
        _buildActionTile(
          context,
          icon: Icons.qr_code_scanner,
          iconColor: Colors.purple,
          title: 'QR Code Scanner',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QRScannerPage(userId: userId),
              ),
            );
          },
        ),

        if(role == "user")
        _buildActionTile(
          context,
          icon: Icons.mic_external_on,
          iconColor: Colors.purple,
          title: 'Become Event Organizer',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ApplyToBeOrganizerPage(userId: userId),
              ),
            );
          },
        ),

        if(role == "admin")
        _buildActionTile(
          context,
          icon: Icons.edit,
          iconColor: Colors.green,
          title: 'Check Organizer Requests',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrganizerRequestsPage(userId: userId),
              ),
            );
          },
        ),
        
        const SizedBox(height: 8),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _clearUserProfile();
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final isLargeScreen = _isLargeScreen(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.normal)),
        centerTitle: false,
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                ),
                builder: (context) => _buildSettingsMenu(context),
              );
            },
          ),
        ],
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
                const SizedBox(height: 24),
                _buildActionCards(context, isLargeScreen),
                const SizedBox(height: 24),
                SizedBox(
                  width: isLargeScreen ? 400 : double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      _showLogoutConfirmation(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}