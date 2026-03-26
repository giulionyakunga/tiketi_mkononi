import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/screens/events_page.dart';
import 'package:tiketi_mkononi/services/storage_service.dart';
import 'package:tiketi_mkononi/widgets/category_grid.dart';
import 'package:tiketi_mkononi/widgets/category_grid2.dart';
import 'package:tiketi_mkononi/widgets/featured_events.dart';
import 'package:tiketi_mkononi/models/event.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'platform_detector.dart';

// Ad Model Class
class Ad {
  final String id;
  final String title;
  final String description;
  final String imageUrl;
  final String buttonText;
  final String? linkUrl;
  final String backgroundColor;
  final String accentColor;
  final int priority;
  final bool isActive;

  Ad({
    required this.id,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.buttonText,
    this.linkUrl,
    required this.backgroundColor,
    required this.accentColor,
    required this.priority,
    required this.isActive,
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['image_url'] ?? '',
      buttonText: json['button_text'] ?? 'Learn More',
      linkUrl: json['link_url'],
      backgroundColor: json['background_color'] ?? '#FF6B6B',
      accentColor: json['accent_color'] ?? '#FFFFFF',
      priority: json['priority'] ?? 0,
      isActive: json['is_active'] ?? true,
    );
  }

  Color get bgColor {
    try {
      return Color(int.parse(backgroundColor.replaceFirst('#', '0xff')));
    } catch (e) {
      return const Color(0xFFFF6B6B);
    }
  }

  Color get accentColorObj {
    try {
      return Color(int.parse(accentColor.replaceFirst('#', '0xff')));
    } catch (e) {
      return Colors.white;
    }
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String _searchQuery = '';
  List<Event> eventsList = [];
  late final StorageService _storageService;
  bool _isAppActive = true;
  bool _isNewVerionAvailable = false;
  int userId = 0;
  String role = '';
  int companyId = 0;
  int officeId = 0;
  int shopId = 0;
  String companyName = "";
  String userName = "";
  String userPhoneNumber = "";

  // Ad related variables
  late PageController _adPageController;
  int _currentAdIndex = 0;
  late Timer _adTimer;
    List<Ad> _ads = [
    Ad(
      id: '1',
      title: '🎉 Early Bird Special!',
      description: 'Get 20% off on all event tickets when you book 7 days in advance. Limited time offer!',
      imageUrl: 'https://via.placeholder.com/400x200/FF6B6B/FFFFFF?text=Early+Bird+Special',
      buttonText: 'Claim Offer',
      linkUrl: 'https://example.com/early-bird',
      backgroundColor: '#FFFF6B6B',
      accentColor: '#FFFFFF6B',  
      priority: 50, 
      isActive: true,
    ),
    Ad(
      id: '2',
      title: '🎪 Premium Events Access',
      description: 'Upgrade to VIP membership and get exclusive access to premium events, priority seating, and more!',
      imageUrl: 'https://via.placeholder.com/400x200/4ECDC4/FFFFFF?text=VIP+Access',
      buttonText: 'Learn More',
      linkUrl: 'https://example.com/vip',
      backgroundColor: '#FF4ECDC4',
      accentColor: '#FFFFFF6B',  
      priority: 50, 
      isActive: true,
    ),
    Ad(
      id: '3',
      title: '🎁 Refer & Earn',
      description: 'Invite friends to Tiketi Mkononi and earn 500 TZS for each successful ticket purchase!',
      imageUrl: 'https://via.placeholder.com/400x200/FFE66D/FFFFFF?text=Refer+and+Earn',
      buttonText: 'Refer Now',
      linkUrl: 'https://example.com/refer',
      backgroundColor: '#FFFFE66D',
      accentColor: '#FF2C3E50',
      priority: 50, 
      isActive: true,
    ),
  ];
  bool _isLoadingAds = true;
  String? _adsError;

  final TextEditingController _searchController = TextEditingController();
  bool useDNS_2 = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
    _initializeAdCarousel();
    
    if (!kIsWeb) checkForUpdates(context);
  }

  void _initializeAdCarousel() {
    _adPageController = PageController(initialPage: 0);
    _fetchAds(); // Fetch ads from backend
    _startAdTimer();
  }

  void _startAdTimer() {
    _adTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_adPageController.hasClients && _ads.isNotEmpty) {
        _currentAdIndex = (_currentAdIndex + 1) % _ads.length;
        _adPageController.animateToPage(
          _currentAdIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _fetchAds({bool useDNS = true}) async {
    if (!mounted) return;

    setState(() {
      _isLoadingAds = true;
      _adsError = null;
    });

    try {
      final Uri uri = useDNS 
          ? Uri.parse('${backend_url}api/ads') // Original URL
          : Uri.parse('${backend_url_with_fallback_ip}ads'); // Use IP

      final response = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> dataList = jsonDecode(response.body);
        final List<Ad> fetchedAds = dataList
            .map((json) => Ad.fromJson(json))
            .where((ad) => ad.isActive) // Only show active ads
            .toList()
          ..sort((a, b) => b.priority.compareTo(a.priority)); // Sort by priority (higher first)

        setState(() {
          _ads = fetchedAds;
          _isLoadingAds = false;
        });

        // Cache ads locally
        if (fetchedAds.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_ads', jsonEncode(dataList));
        }

        // Start timer only if we have ads
        if (_ads.isNotEmpty) {
          _startAdTimer();
        }
      } else {
        throw Exception('Failed to load ads: ${response.statusCode}');
      }
    } on SocketException catch (e) {
      debugPrint('Network error fetching ads: $e');
      
      // Try to load cached ads
      await _loadCachedAds();
      
      // Retry with IP if DNS fails and not already retrying
      if (useDNS && (e.osError?.errorCode == 11001 || e.osError?.errorCode == 7)) {
        debugPrint('DNS failed for ads! Retrying with IP...');
        await _fetchAds(useDNS: false);
        return;
      }
      
      setState(() {
        _isLoadingAds = false;
        _adsError = 'Network error. Please check your connection.';
      });
    } on TimeoutException catch (e) {
      debugPrint('Timeout fetching ads: $e');
      await _loadCachedAds();
      setState(() {
        _isLoadingAds = false;
        _adsError = 'Request timeout. Using cached ads.';
      });
    } catch (e) {
      debugPrint('Error fetching ads: $e');
      await _loadCachedAds();
      setState(() {
        _isLoadingAds = false;
        _adsError = 'Failed to load ads.';
      });
    }
  }

  Future<void> _loadCachedAds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedData = prefs.getString('cached_ads');
      
      if (cachedData != null) {
        final List<dynamic> dataList = jsonDecode(cachedData);
        final List<Ad> cachedAds = dataList
            .map((json) => Ad.fromJson(json))
            .where((ad) => ad.isActive)
            .toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));
        
        setState(() {
          _ads = cachedAds;
        });
        
        if (_ads.isNotEmpty) {
          _startAdTimer();
        }
      }
    } catch (e) {
      debugPrint('Error loading cached ads: $e');
    }
  }

  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    useDNS_2 = await prefs.getBool('use_dns') ?? true;

    await _loadCachedEvents();

    _storageService = StorageService(prefs);
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final profile = _storageService.getUserProfile();
    if (profile != null) {
      setState(() {
        userId = profile.id;
        role = profile.role;
        companyId = profile.companyId;
        officeId = profile.officeId;
        shopId = profile.shopId;
        companyName = profile.companyName;
        userName = profile.firstName;
        userPhoneNumber = profile.phoneNumber;
      });
      getUserRole();
      fetchEvents();
    } else {
      fetchEvents();
    }
  }

  void _reloadUserProfile() {
    final profile = _storageService.getUserProfile();
    if (profile != null) {
      setState(() {
        userId = profile.id;
        role = profile.role;
        companyId = profile.companyId;
        officeId = profile.officeId;
        shopId = profile.shopId;
        companyName = profile.companyName;
        userName = profile.firstName;
        userPhoneNumber = profile.phoneNumber;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _adPageController.dispose();
    _adTimer.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isAppActive = state == AppLifecycleState.resumed;
    });
    if (state == AppLifecycleState.resumed && _ads.isNotEmpty) {
      _startAdTimer();
    } else if (state == AppLifecycleState.paused) {
      _adTimer.cancel();
    }
  }

  Future<void> _loadCachedEvents() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedData = prefs.getString('cached_events');

    if (cachedData != null) {
      List<dynamic> dataList = jsonDecode(cachedData);
      setState(() {
        eventsList = dataList.map((json) => Event.fromJson(json)).toList();
      });
    }
  }

  Future<void> getUserRole({bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/get_user_role/$userId') 
        : Uri.parse('${backend_url_with_fallback_ip}get_user_role/$useDNS');
        
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
          companyName = responseData['company_name'] ?? '';
          userName = responseData['first_name'];
          userPhoneNumber = '${responseData['phone_number']}';
        });
        var profile = _storageService.getUserProfile();
        if (profile != null) {
          profile.role = responseData['role'];
          profile.companyName = responseData['company_name'] ?? '';
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

        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await getUserRole(useDNS: false);
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

  Future<void> fetchEvents({bool useDNS = true}) async {
    if (!_isAppActive) return;

    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/events/$userId')
          : Uri.parse('${backend_url_with_fallback_ip}events/$userId');
            
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        List<dynamic> dataList = jsonDecode(response.body);
        List<Event> events = dataList.map((json) => Event.fromJson(json)).toList();

        setState(() => eventsList = events);

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_events', jsonEncode(dataList));

        if(useDNS){
          if(!useDNS_2) {
            await prefs.setBool('use_dns', true);
            setState(() {
              useDNS_2 = true;
            });
          }
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

          if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
            debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
            await fetchEvents(useDNS: false);
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('use_dns', false);
            return;
          }
        }
      } catch (e) {
      debugPrint('Error fetching events: $e');
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

  void refreshMethod() {
    fetchEvents();
    _fetchAds(); // Also refresh ads
  }

  List<Event> _getFilteredEvents() {
    return _searchQuery.isEmpty
        ? eventsList.where((event) => event.visibility == 'public').toList()
        : eventsList.where((event) => (event.name.toLowerCase().contains(_searchQuery.toLowerCase()) && event.visibility == 'public')).toList();
  }

  Future<void> checkForUpdates(BuildContext context, {bool useDNS = true}) async {
    final packageInfo = await PackageInfo.fromPlatform();
    String installedVersion = packageInfo.version;

    String latestVersion = "";
    String operatingSystem = "";
    if(kIsWeb) {
      operatingSystem = 'web';
    } else {
      operatingSystem = Platform.operatingSystem;
    }

    try {
      final Uri uri = useDNS ? Uri.parse('${backend_url}api/application_information/$userId/$installedVersion/$operatingSystem')
          : Uri.parse('${backend_url_with_fallback_ip}application_information/$userId/$installedVersion/$operatingSystem');

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final applicationInformation = jsonDecode(response.body);
        if (applicationInformation['app_version'] != "") {
          latestVersion = applicationInformation['app_version'];
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('application_information', response.body);
        }

        if(useDNS){
          if(!useDNS_2) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('use_dns', true);
            setState(() {
              useDNS_2 = true;
            });
          }
        }
      }
    } on SocketException catch (e) {
      debugPrint('Network error occurred:');
      debugPrint('- Exception type: ${e.runtimeType}');
      debugPrint('- Message: ${e.message}');
      
      if (e.osError != null) {
        debugPrint('  - Error number (errno): ${e.osError!.errorCode}');
        debugPrint('  - OS message: ${e.osError!.message}');

        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await checkForUpdates(context, useDNS: false);
          return;
        }
      }
    } catch (e) {}

    if (installedVersion.compareTo(latestVersion) < 0) {
      setState(() {
        _isNewVerionAvailable = true;
      });
      showNewUpdateAvailableDialog();
    }
  }

  Future<void> _launchStore() async {  
    const appStoreUrl = "https://apps.apple.com/app/id6746575990";
    const playStoreUrl = "https://play.google.com/store/apps/details?id=com.telabs.tiketi_mkononi";

    Uri storeUrl;
    if(kIsWeb) {
      storeUrl = Uri.parse(
        isAndroidWeb() ? playStoreUrl : appStoreUrl,
      );
    } else {
      storeUrl = Uri.parse(
        Platform.isAndroid ? playStoreUrl : appStoreUrl,
      );
    }

    if (!await launchUrl(storeUrl, mode: LaunchMode.externalApplication)) {
      throw Exception("Could not launch $storeUrl");
    }
  }

  void showNewUpdateAvailableDialog() {
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

  Widget _buildAdCarousel() {
    if (_isLoadingAds) {
      return Container(
        height: 180,
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Loading offers...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_adsError != null && _ads.isEmpty) {
      return Container(
        height: 180,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 40,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
                  Text(
                'No promotions available',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (_adsError != null)
                TextButton(
                  onPressed: () => _fetchAds(),
                  child: const Text('Retry'),
                ),
            ],
          ),
        ),
      );
    }

    if (_ads.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 180,
      child: PageView.builder(
        controller: _adPageController,
        onPageChanged: (index) {
          setState(() {
            _currentAdIndex = index;
          });
        },
        itemCount: _ads.length,
        itemBuilder: (context, index) {
          final ad = _ads[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: InkWell(
              onTap: () {
                if (ad.linkUrl != null && ad.linkUrl!.isNotEmpty) {
                  _launchAdUrl(ad.linkUrl!);
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      ad.bgColor,
                      ad.bgColor.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background pattern
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -30,
                      bottom: -30,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Image Section
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: ad.imageUrl.isNotEmpty
                                  ? Image.network(
                                      ad.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.local_offer,
                                          size: 50,
                                          color: ad.accentColorObj,
                                        );
                                      },
                                    )
                                  : Icon(
                                      Icons.local_offer,
                                      size: 50,
                                      color: ad.accentColorObj,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  ad.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: ad.accentColorObj,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  ad.description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ad.accentColorObj.withOpacity(0.9),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ad.accentColorObj,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    ad.buttonText,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: ad.bgColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdIndicator() {
    if (_ads.length <= 1) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _ads.length,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentAdIndex == index
                  ? Colors.orange[800]
                  : Colors.grey[300],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchAdUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not launch the link');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final filteredEvents = _getFilteredEvents();
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: isWideScreen
          ? null
          : AppBar(
              title: Text(
                'Tiketi Mkononi',
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 24,
                  color: Colors.orange[800],
                ),
              ),
              centerTitle: false,
              elevation: 0,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(255, 240, 244, 247),
                      Color.fromARGB(255, 240, 244, 247)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              actions: [
                if(!kIsWeb && _isNewVerionAvailable)
                  IconButton(
                    icon: const Icon(Icons.system_update_rounded),
                    color: Colors.blue,
                    onPressed: () => showNewUpdateAvailableDialog(),
                  ),
                if(kIsWeb && isAndroidWeb())
                  IconButton(
                    icon: const Icon(Icons.system_update_rounded),
                    color: Colors.blue,
                    onPressed: () => showDialog(
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
                    ),
                  ),
                if(kIsWeb && isIOSWeb())
                  IconButton(
                    icon: const Icon(Icons.system_update_rounded),
                    color: Colors.green,
                    onPressed: () => showDialog(
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
                    ),
                  ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          await fetchEvents();
          await _fetchAds();
        },
        color: Colors.orange[800],
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (isWideScreen)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 240, 244, 247),
                        Color.fromARGB(255, 240, 244, 247)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Tiketi Mkononi',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 28,
                          color: Colors.orange[800],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 400,
                        child: _buildSearchBar(isDarkMode),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isWideScreen ? 40 : 16,
                vertical: isWideScreen ? 0 : 16,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (!isWideScreen) _buildSearchBar(isDarkMode),
                  const SizedBox(height: 5),
                  // Dynamic Ads Section from Backend
                  _buildAdCarousel(),
                  _buildAdIndicator(),
                  const SizedBox(height: 10),
                  _buildFeaturedEventsSection(isDarkMode, filteredEvents, isWideScreen),
                  const SizedBox(height: 10),
                  _buildCategoriesSection(isDarkMode, filteredEvents, isWideScreen),
                  const SizedBox(height: 10),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: isDarkMode
            ? Colors.black.withOpacity(0.3)
            : Colors.white.withOpacity(0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.2)
              : Colors.grey.withOpacity(0.3),
        ),
      ),
      child: SearchBar(
        controller: _searchController,
        hintText: 'Search events...',
        hintStyle: WidgetStateTextStyle.resolveWith(
          (states) => TextStyle(
            color: isDarkMode ? Colors.white70 : Colors.grey[600],
          ),
        ),
        backgroundColor: WidgetStateProperty.all(
          isDarkMode ? Colors.transparent : Colors.white.withOpacity(0.7),
        ),
        elevation: WidgetStateProperty.all(0),
        side: WidgetStateProperty.all(BorderSide.none),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 16),
        ),
        leading: Icon(
          Icons.search,
          color: isDarkMode ? Colors.white70 : Colors.orange[800],
        ),
        trailing: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close,
                color: isDarkMode ? Colors.white70 : Colors.orange[800],
              ),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
        ],
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildFeaturedEventsSection(bool isDarkMode, List<Event> filteredEvents, bool isWideScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Featured Events',
                style: TextStyle(
                  fontSize: isWideScreen ? 24 : 20,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EventsPage(),
                    ),
                  );
                },
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: isWideScreen ? 18 : null,
                    color: isDarkMode ? Colors.purpleAccent : Colors.orange[800],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        FeaturedEvents(
          events: filteredEvents,
          userId: userId,
          role: role,
          refreshMethod: refreshMethod,
          useDNS: useDNS_2,
        ),
      ],
    ); 
  }

  Widget _buildCategoriesSection(bool isDarkMode, List<Event> filteredEvents, bool isWideScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Categories',
            style: TextStyle(
              fontSize: isWideScreen ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 10),
        (!isWideScreen) ? CategoryGrid(
          userId: userId, role: role, companyId: companyId, officeId: officeId, companyName: companyName, userName: userName, userPhoneNumber: userPhoneNumber, refreshMethod: _reloadUserProfile
        ) :
        CategoryGrid2(
          events: filteredEvents,
          userId: userId, role: role, companyId: companyId, officeId: officeId, companyName: companyName, userName: userName, userPhoneNumber: userPhoneNumber, refreshMethod: _reloadUserProfile
        ),
      ],
    );
  }
}