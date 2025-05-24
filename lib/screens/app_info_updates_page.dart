import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoUpdatesPage extends StatefulWidget {
  const AppInfoUpdatesPage({super.key});

  @override
  State<AppInfoUpdatesPage> createState() => _AppInfoUpdatesPageState();
}

class _AppInfoUpdatesPageState extends State<AppInfoUpdatesPage> {
  int userId = 0;
  String token = "";
  String role = "";
  String currentVersion = "";
  String latestVersion = "";
  String lastUpdate = "";
  bool _isNewVerionAvailable = false;
  
  late final StorageService _storageService;
  bool _isLoading = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    checkForUpdates();
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
        token = profile.token;
        role = profile.role;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> addApplicationInformation(String app_version) async {
    try {        
      final response = await http.post(
        Uri.parse('${backend_url}api/add_application_information'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          "app_version": app_version,
          "user_dd": userId
        }),
      );

      if (response.statusCode == 200) {
        debugPrint(response.body);
      }
    } finally {}
  }

  Future<void> checkForUpdates() async {
    setState(() {
      _isLoading = true;
    });
    
    // Get current app version
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      currentVersion = packageInfo.version;
    });

    String _latestVersion = "";

    try {
      final response = await http.get(Uri.parse('${backend_url}api/application_information'));
      if (response.statusCode == 200) {
        final applicationInformation = jsonDecode(response.body);
        if (applicationInformation['app_version'] != "") {
          _latestVersion = applicationInformation['app_version'];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          setState(() {
            lastUpdate = applicationInformation['updatedAt'];
            latestVersion = _latestVersion;
          });
          await prefs.setString('application_information', response.body);
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    if (currentVersion.compareTo(_latestVersion) < 0) {
      // New update available
      setState(() {
        _isNewVerionAvailable = true;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Update Available"),
            content: const Text("A new version of the app is available. Please update to enjoy the latest features."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Later"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _launchStore();
                },
                child: const Text("Update Now"),
              ),
            ],
          ),
        );
      }
    } else {
      // No update needed (optional: show a message)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're using the latest version")),
        );
      }
    }
  }

  Future<void> _launchStore() async {
    const appStoreUrl = "https://apps.apple.com/app/idYOUR_APP_ID"; // iOS
    const playStoreUrl = "https://play.google.com/store/apps/details?id=com.telabs.tiketi_mkononi"; // Android

    final Uri storeUrl = Uri.parse(
      Platform.isAndroid ? playStoreUrl : appStoreUrl,
    );

    if (!await launchUrl(storeUrl, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch app store: $storeUrl")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Info & Updates'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLargeScreen ? 800 : double.infinity,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isLargeScreen ? 32 : 16,
              vertical: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAppInfoCard(context, isLargeScreen),
                if (_isNewVerionAvailable) ...[
                  const SizedBox(height: 24),
                  _buildUpdateButton(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppInfoCard(BuildContext context, bool isLargeScreen) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isLargeScreen ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLargeScreen) ...[
              const Center(
                child: Icon(
                  Icons.info_outline_rounded,
                  size: 48,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              'Application Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            _buildAppInfoGrid(isLargeScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoGrid(bool isLargeScreen) {
    final items = [
      _AppInfoItem(
        icon: Icons.verified_rounded,
        title: 'Installed Version',
        value: currentVersion,
        color: Colors.blue,
      ),
      _AppInfoItem(
        icon: Icons.system_update_rounded,
        title: 'Latest Version',
        value: latestVersion,
        color: _isNewVerionAvailable ? Colors.orange : Colors.green,
      ),
      _AppInfoItem(
        icon: Icons.calendar_today_rounded,
        title: 'Last Updated On',
        value: lastUpdate.isNotEmpty 
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(lastUpdate))
            : 'N/A',
        color: Colors.purple,
      ),
      _AppInfoItem(
        icon: Icons.business_rounded,
        title: 'Developed By',
        value: 'Tanzania Electronics Labs Co, Ltd',
        color: Colors.teal,
      ),
    ];

    if (isLargeScreen) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 3,
        children: items.map((item) => _buildAppInfoTile(item)).toList(),
      );
    } else {
      return Column(
        children: items.map((item) => Column(
          children: [
            _buildAppInfoTile(item),
            const SizedBox(height: 12),
          ],
        )).toList(),
      );
    }
  }

  Widget _buildAppInfoTile(_AppInfoItem item) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          item.icon,
          color: item.color,
          size: 24,
        ),
      ),
      title: Text(
        item.title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.black54,
        ),
      ),
      subtitle: Text(
        item.value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildUpdateButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (_isLoading || _sent) ? null : _launchStore,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isNewVerionAvailable 
              ? Colors.orange.shade700 
              : Theme.of(context).primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : Icon(
                _sent ? Icons.check_circle_rounded : Icons.system_update_rounded,
                size: 24,
                color: Colors.white,
              ),
        label: Text(
          _isLoading ? 'Checking...' : 'Update Now',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _AppInfoItem {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  _AppInfoItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
}