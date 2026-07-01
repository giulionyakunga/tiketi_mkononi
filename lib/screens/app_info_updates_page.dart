import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/models/server_metrics.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:http/http.dart' as http;
import 'package:tiketi_mkononi/widgets/server_metrics_card.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'platform_detector.dart';

class AppInfoUpdatesPage extends StatefulWidget {
  const AppInfoUpdatesPage({super.key});

  @override
  State<AppInfoUpdatesPage> createState() => _AppInfoUpdatesPageState();
}

class _AppInfoUpdatesPageState extends State<AppInfoUpdatesPage> {
  int userId = 0;
  String token = "";
  String role = "";
  String installedVersion = "";
  String latestVersion = "";
  String lastUpdate = "";
  bool _isNewVerionAvailable = false;
  late ServerMetrics serverMetrics;
  bool _hasReceivedServerMetrics = false;



  final _formKey = GlobalKey<FormState>();
  final _appVersionController = TextEditingController();
  late final StorageService _storageService;
  bool _isLoading = false;
  
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    checkForUpdates();
    getMobileApp();
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

      if(role == "admin") getServerMetrics();
    }
  }

  void getMobileApp() {
    if(kIsWeb && isAndroidWeb()) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Get App on Google Play"),
        content: const Text("Get the mobile app for a better experience and more features 🚀"),
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
            child: const Text("Get app"),
          ),
        ],
      ),
    );
    } else if(kIsWeb && isIOSWeb()) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Get App on the App Store"),
          content: const Text("Get the mobile app for a better experience and more features 🚀"),
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
              child: const Text("Get app"),
            ),
          ],
        ),
      );
    }
  }

   @override
  void dispose() {
    _appVersionController.dispose();
    super.dispose();
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

  Future<void> _handleAddApplicationInformation({bool useDNS = true}) async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() => _isLoading = true);

        final Uri uri = useDNS ? Uri.parse('${backend_url}api/add_application_information') // Original URL 
        : Uri.parse('${backend_url_with_fallback_ip}add_application_information'); // Use IP
        
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode({
            "user_id": userId,
            "app_version": _appVersionController.text,
          }),
        );

        if (response.statusCode == 200) {
          _showSnackBar(response.body);
          checkForUpdates();
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
          debugPrint('  - errorCode: ${e.osError!.errorCode}');
          debugPrint('  - useDNS: ${useDNS}');

          // Retry with IP if DNS fails (errno = 7) and not already retrying
          if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
            debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
            await _handleAddApplicationInformation(useDNS: false); // Recursive retry

            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('use_dns', false);
            return;
          }
        }
        _handleSocketException(e);
      } catch (e) {
        debugPrint('An error occurred: $e');
        _showSnackBar('An error occurred: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
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

  Widget _buildAppInformationForm(bool isLargeScreen) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 16),
          Text(
            'Update App version',
            style: TextStyle(
              fontSize: isLargeScreen ? 22 : 18,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          TextFormField(
            controller: _appVersionController,
            decoration: _buildInputDecoration(
              label: 'App version',
              icon: Icons.verified,
              isLargeScreen: isLargeScreen,
            ),
            style: TextStyle(fontSize: isLargeScreen ? 18 : 16),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Please enter app version';
              if (value.length > 10) return 'App version cannot exceed 10 characters';
              return null;
            },
          ),
          SizedBox(height: isLargeScreen ? 24 : 12),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleAddApplicationInformation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(vertical: isLargeScreen ? 20 : 16),
              elevation: 4,
            ),
            child: _isLoading
                ? const CircularProgressIndicator()
                : Text(
                    'Update',
                    style: TextStyle(
                      fontSize: isLargeScreen ? 18 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  
  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    bool isLargeScreen = false,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: isLargeScreen ? 18 : 16,
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.grey[600],
        size: isLargeScreen ? 24 : 20,
      ),
      suffixIcon: null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[400]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.orange[800]!, width: 2.0),
      ),
      filled: true,
      fillColor: Colors.grey[200],
      contentPadding: EdgeInsets.symmetric(
        vertical: isLargeScreen ? 20 : 16,
        horizontal: isLargeScreen ? 20 : 16,
      ),
    );
  }

  Future<void> checkForUpdates({bool useDNS = true}) async {
    setState(() {
      _isLoading = true;
    });
    
    // Get current app version
    final packageInfo = await PackageInfo.fromPlatform();
    String installedVersion2 = packageInfo.version;
    setState(() {
      installedVersion = packageInfo.version;
    });

    String _latestVersion = "";
    String operatingSystem = "";
    if(kIsWeb) {
      operatingSystem = 'web';
    } else {
      operatingSystem = Platform.operatingSystem; // Hardcoded for example
    }

    final Uri uri = useDNS ? Uri.parse('${backend_url}api/application_information/$userId/$installedVersion2/$operatingSystem') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}application_information/$userId/$installedVersion2/$operatingSystem'); // Use IP
        
    try {
      final response = await http.get(uri);

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
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await checkForUpdates(useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }

    if (installedVersion.compareTo(_latestVersion) < 0) {
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
    }
  }

  
  Future<void> getServerMetrics({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/metrics') // Original URL 
    : Uri.parse('${backend_url_with_fallback_ip}metrics'); // Use IP
        
    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {        
        setState(() {
          serverMetrics = ServerMetrics.fromJson(jsonDecode(response.body));
          serverMetrics.dnsResolution = useDNS;
          _hasReceivedServerMetrics = true;
        });      
        
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
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await getServerMetrics(useDNS: false); // Recursive retry

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

  Future<void> _launchStore() async {
    if(kIsWeb) return;

    const appStoreUrl = "https://apps.apple.com/app/id6746575990"; // iOS
    const playStoreUrl = "https://play.google.com/store/apps/details?id=com.telabs.tiketi_mkononi"; // Android

    Uri storeUrl;
    if(kIsWeb) {
      storeUrl = Uri.parse(
        isAndroidWeb() ? playStoreUrl : appStoreUrl,
      );
    }else {
      storeUrl = Uri.parse(
        Platform.isAndroid ? playStoreUrl : appStoreUrl,
      );
    }

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
        backgroundColor: const Color.fromARGB(255, 240, 244, 247),
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
                if(_hasReceivedServerMetrics) SizedBox(height: isLargeScreen ? 40 : 24),
                if(_hasReceivedServerMetrics) ServerMetricsCard(serverMetrics: serverMetrics, refreshMethod: getServerMetrics),
                
                SizedBox(height: isLargeScreen ? 40 : 24),

                if(role == "admin")
                _buildAppInformationForm(isLargeScreen),
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
        value: installedVersion,
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