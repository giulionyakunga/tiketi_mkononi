import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/screens/app_info_updates_page.dart';
import 'package:tiketi_mkononi/screens/apply_to_be_cargo_transporter_page.dart';
import 'package:tiketi_mkononi/screens/apply_to_be_organizer_page.dart';
import 'package:tiketi_mkononi/screens/apply_to_be_shop_owner_page.dart';
import 'package:tiketi_mkononi/screens/auth/login_screen2.dart';
import 'package:tiketi_mkononi/screens/add_consignment_page.dart';
import 'package:tiketi_mkononi/screens/book_of_accounts_page.dart';
// import 'package:tiketi_mkononi/screens/contact_page.dart';
import 'package:tiketi_mkononi/screens/edit_profile_page.dart';
import 'package:tiketi_mkononi/screens/event_organizers_page.dart';
import 'package:tiketi_mkononi/screens/favorite_events_page.dart';
import 'package:tiketi_mkononi/screens/generate_barcodes_page.dart';
import 'package:tiketi_mkononi/screens/help_support_page.dart';
import 'package:tiketi_mkononi/screens/language_settings_page.dart';
import 'package:tiketi_mkononi/screens/notifications_page.dart';
import 'package:tiketi_mkononi/screens/offices_page.dart';
import 'package:tiketi_mkononi/screens/privacy_security_page.dart';
import 'package:tiketi_mkononi/screens/purchase_history_page.dart';
import 'package:tiketi_mkononi/screens/requests_page.dart';
import 'package:tiketi_mkononi/screens/sales_book_page.dart';
import 'package:tiketi_mkononi/screens/shops_page.dart';
import 'package:tiketi_mkononi/screens/system_users_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:http/http.dart' as http;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with WidgetsBindingObserver {
  int userId = 0;
  int companyId = 0;
  int officeId = 0;
  int shopId = 0;
  String companyName = "";
  String shopName = "";
  String role = "user";
  String userName = "";
  String userPhoneNumber = "";
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
        companyId = profile.companyId;
        officeId = profile.officeId;
        companyName = profile.companyName;
        shopId = profile.shopId;
        role = profile.role;
        _firstNameController.text = profile.firstName;
        _lastNameController.text = profile.lastName;
        _emailController.text = profile.email;
      });
      getUserRole();
    }
  }

  void _clearUserProfile() {
    _storageService.clearUserProfile();
  }

   
  Future<void> getUserRole({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/get_user_role/$userId') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}get_user_role/$useDNS'); // Use IP
        
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        debugPrint('response.body : ${response.body}');
        setState(() {
          companyId = responseData['company_id'] ?? 0;
          officeId = responseData['office_id'] ?? 0;
          shopId = responseData['shop_id'] ?? 0;
          role = responseData['role'];
          companyName = responseData['company_name'];
          userName = '${responseData['first_name']} ${responseData['last_name']}';
          userPhoneNumber = '${responseData['phone_number']}';
        });
        var profile = _storageService.getUserProfile();
        profile!.role =  responseData['role'];
        profile.companyName =  responseData['company_name'];
        await _storageService.saveUserProfile(profile);
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
          await getUserRole(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting user role: $e');
    } finally {
      debugPrint('Process finished');
    }
  }

  Future<void> getCompanyInfo({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/company/$companyId') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}company/$companyId'); // Use IP
        
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if((companyId != responseData['name'])) {
          setState(() {
            companyId = responseData['id'];
            companyName = responseData['name'];
          });
          var profile = _storageService.getUserProfile();
          profile!.role =  responseData['role'];
          await _storageService.saveUserProfile(profile);
        }        
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
          await getCompanyInfo(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting server metrics: $e');
    } finally {
      debugPrint('Process finished');
    }
  }

  Future<void> getShopInfo({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/get_user_role/$userId') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}get_user_role/$useDNS'); // Use IP
        
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);   
        if((role != responseData['role'])) {
          setState(() {
            role = responseData['role'];
          });
          var profile = _storageService.getUserProfile();
          profile!.role =  responseData['role'];
          await _storageService.saveUserProfile(profile);
        }        
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
          await getShopInfo(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error getting server metrics: $e');
    } finally {
      debugPrint('Process finished');
    }
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
                const SizedBox(height: 6),
                Text(
                  '${_firstNameController.text} ${_lastNameController.text}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_emailController.text}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PurchasePistoryPage(userId: userId),
            ),
          );
          _loadUserProfile();
        },
      ),
      _buildActionTile(
        context,
        icon: Icons.favorite,
        iconColor: Colors.pink,
        title: 'Favorite Events',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FavoriteEventsPage(userId: userId),
            ),
          );
          _loadUserProfile();
        },
      ),
    ];

    final appSettings = [
      _buildActionTile(
        context,
        icon: Icons.notifications,
        iconColor: Colors.purple,
        title: 'Notifications',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NotificationsPage(userId: userId,),
            ),
          );
        },
      ),
      _buildActionTile(
        context,
        icon: Icons.security,
        iconColor: Colors.teal,
        title: 'Privacy & Security',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PrivacySecurityPage(),
            ),
          );
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
      _buildActionTile(
        context,
        icon: Icons.update,
        iconColor: Colors.blue,
        title: 'App Info & Updates',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AppInfoUpdatesPage(),
            ),
          );
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
                  title: 'About This App',
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
                title: 'About This App',
                items: appSettings,
              ),
            ],
          );
  }

  Widget _buildNonLoginUserActionCards(BuildContext context) {
    final appSettings = [
      _buildActionTile(
        context,
        icon: Icons.security,
        iconColor: Colors.teal,
        title: 'Privacy & Security',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PrivacySecurityPage(),
            ),
          );
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
      _buildActionTile(
        context,
        icon: Icons.update,
        iconColor: Colors.blue,
        title: 'App Info & Updates',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AppInfoUpdatesPage(),
            ),
          );
        },
      ),
    ];

    return Column(
      children: [
        _buildProfileCard(
          context,
          title: 'About This App',
          items: appSettings,
        ),
      ],
    );
  }

  Widget _buildOtherApps(BuildContext context) {
    final otherApps = [
      _buildActionTile(
        context,
        icon: Icons.security,
        iconColor: Colors.teal,
        title: 'My Book of Accounts',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookOfAccountsPage(userId: userId),
            ),
          );
        },
      ),
      if((role == "shop_attendant") && (shopId > 0))
      _buildActionTile(
        context,
        icon: Icons.security,
        iconColor: Colors.teal,
        title: 'Sales Book',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SalesBookPage(userId: userId, shopId: shopId),
            ),
          );
        },
      ),
      if((role == "cargo_office_attendant") && (companyId > 0) && (officeId > 0))
      _buildActionTile(
        context,
        icon: Icons.security,
        iconColor: Colors.teal,
        title: 'Cargo',
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddConsignmentPage(userId: userId, companyId: companyId, companyName:companyName, officeId: officeId, userName: userName, userPhoneNumber: userPhoneNumber),
            ),
          );
        },
      ),
    ];

    return Column(
      children: [
        _buildProfileCard(
          context,
          title: 'Other Apps',
          items: otherApps,
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

        if((role == "admin") || (role == "barcode_generator"))
        _buildActionTile(
          context,
          icon: Icons.qr_code_scanner,
          iconColor: Colors.purple,
          title: 'Barcode Generator',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GenerateBarcodesPage(),
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

        if(role == "user")
        _buildActionTile(
          context,
          icon: Icons.store,
          iconColor: Colors.blue,
          title: 'Become Shop Owner',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ApplyToBeShopOwnerPage(userId: userId),
              ),
            );
          },
        ),

        if(role == "shop_owner")
        _buildActionTile(
          context,
          icon: Icons.store,
          iconColor: Colors.blue,
          title: 'My Shops',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShopsPage(userId: userId),
              ),
            );
          },
        ),

        if(role == "cargo_transporter")
        _buildActionTile(
          context,
          icon: Icons.business,
          iconColor: Colors.teal,
          title: 'My Offices',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OfficesPage(userId: userId, companyId: companyId, companyName: companyName, role: role),
              ),
            );
          },
        ),

        if(role == "user")
        _buildActionTile(
          context,
          icon: Icons.business,
          iconColor: Colors.teal,
          title: 'Become Cargo Transporter',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ApplyToBeCargoTransporterPage(userId: userId),
              ),
            );
          },
        ),

        if(role == "admin")
        _buildActionTile(
          context,
          icon: Icons.edit,
          iconColor: Colors.green,
          title: 'Check Requests',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RequestsPage(userId: userId),
              ),
            );
          },
        ),

        if(role == "admin")
        _buildActionTile(
          context,
          icon: Icons.remove_red_eye,
          iconColor: Colors.orange[800]!,
          title: 'Event Organizers',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EventOrganizersPage(userId: userId),
              ),
            );
          },
        ),

        if(role == "admin")
        _buildActionTile(
          context,
          icon: Icons.remove_red_eye,
          iconColor:Colors.orange[800]!,
          title: 'System Users',
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SystemUsersPage(userId: userId),
              ),
            );
          },
        ),

        // if(role == "admin")
        // _buildActionTile(
        //   context,
        //   icon: Icons.remove_red_eye,
        //   iconColor:Colors.orange[800]!,
        //   title: 'Contacts',
        //   onTap: () {
        //     Navigator.pop(context);
        //     Navigator.push(
        //       context,
        //       MaterialPageRoute(
        //         builder: (context) => ContactPage(),
        //       ),
        //     );
        //   },
        // ),
        
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
              context.go('/login');
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
        title: Text('My Profile', style: TextStyle(fontWeight: FontWeight.normal)),
        centerTitle: false, 
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
        actions: [
          if(userId > 0)
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
        child: (userId > 0) ?
        ConstrainedBox(
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
                _buildOtherApps(context),
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
        )
        :
        ConstrainedBox(
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
                _buildNonLoginUserActionCards(context),
                const SizedBox(height: 24),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Please Login'),
                    ElevatedButton(
                      onPressed: () {
                        context.push('/login');
                      },
                      child: const Text(
                        'Login',
                        style: TextStyle(
                          color: Colors.green
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        )





        
      ),
    );
  }
}
