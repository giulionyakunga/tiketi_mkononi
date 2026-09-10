import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tiketi_mkononi/env.dart';
import 'package:tiketi_mkononi/screens/ad/post_ad_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tiketi_mkononi/models/ad.dart';

class HomeAds extends StatefulWidget {
  final int userId;
  final String role;
  final List<Ad> ads;
  final bool useDNS;

  const HomeAds({
    super.key,
    required this.userId,
    required this.role,
    required this.ads,
    required this.useDNS,
  });

  @override
  State<HomeAds> createState() => _HomeAdsState();
}

class _HomeAdsState extends State<HomeAds> {
  int _currentPage = 0;

  PageController? _pageController;
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(
      viewportFraction: 0.92,
    );


    _startAutoPlay();

  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();

    if (widget.ads.length <= 1) return;

    _autoPlayTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!mounted || _pageController == null) return;

        _currentPage++;

        if (_currentPage >= widget.ads.length) {
          _currentPage = 0;
        }

        _pageController!.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
    );
  }

  Color _parseColor(String color) {
    try {
      String value = color.replaceAll('#', '');

      if (value.length == 6) {
        value = 'FF$value';
      }

      return Color(int.parse(value, radix: 16));
    } catch (_) {
      return Colors.orange;
    }
  }

   // Pause autoplay when an ad is clicked.
  void _pauseAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  Future<void> _openAd(Ad ad) async {
    // Pause autoplay immediately when the ad is clicked.
    _pauseAutoPlay();

    final link = ad.linkUrl;

    if (link == null || link.trim().isEmpty) {
      return;
    }

    final uri = Uri.tryParse(link);

    if (uri == null) { 
      return;
    }

    try {
      clickAd(ad.id, useDNS: widget.useDNS);
      
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Could not open ad link: $e');
    }
  }

  Future<void> _editAd(Ad ad) async {
    // Optional: also stop autoplay while editing.
    _pauseAutoPlay();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostAdPage(userId: widget.userId, role: widget.role, adToEdit: ad),
      ),
    );
    
    _startAutoPlay();
  }

  Future<void> clickAd(int adId, {bool useDNS = true}) async {
    final Uri uri = useDNS ? Uri.parse('${backend_url}api/update_click_count/${adId}')
    : Uri.parse('${backend_url_with_fallback_ip}update_click_count/${adId}');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        debugPrint('Ad click registered successfully for adId: $adId');
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
        debugPrint('  - errorCode: ${e.osError!.errorCode}');
        debugPrint('  - useDNS: ${useDNS}');

        // Retry with IP if DNS fails (errno = 7) and not already retrying
        if ((e.osError!.errorCode == 11001 || e.osError!.errorCode == 7) && useDNS) {
          debugPrint('DNS failed! Retrying with IP: ${backend_url_with_fallback_ip}...');
          await clickAd(adId, useDNS: false); // Recursive retry

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('use_dns', false);
          return;
        }
      }

      _handleSocketException(e);
    } catch (e) {
      debugPrint('Error fetching tickets: $e');
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildAdCard(Ad ad) {
    final backgroundColor = _parseColor(ad.backgroundColor);
    final accentColor = _parseColor(ad.accentColor);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: backgroundColor,
        child: InkWell(
          onTap: () => _openAd(ad),
          child: SizedBox(
            height: 185,
            child: Stack(
              children: [
                // Background image
                if (ad.imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      '${backend_url}api/image/${ad.imageUrl}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const SizedBox.shrink();
                      },
                      loadingBuilder: (
                        context,
                        child,
                        loadingProgress,
                      ) {
                        if (loadingProgress == null) {
                          return child;
                        }

                        return Container(
                          color: backgroundColor,
                        );
                      },
                    ),
                  ),

                // Dark gradient overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.black.withOpacity(0.78),
                          Colors.black.withOpacity(0.48),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      18,
                      20,
                      16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                ad.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.0,
                                ),
                              ),

                              const SizedBox(height: 4),

                              if (ad.description.isNotEmpty)
                                Text(
                                  ad.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accentColor.withOpacity(0.92),
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),

                              SizedBox(
                                height: (ad.userId == widget.userId) ? 4 : 10
                              ),

                              if(ad.userId == widget.userId)
                              // Views + Clicks
                              Row(
                                children: [
                                  Icon(
                                    Icons.visibility_rounded,
                                    size: 15,
                                    color: accentColor.withOpacity(0.85),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${ad.viewCount}',
                                    style: TextStyle(
                                      color: accentColor.withOpacity(0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  Icon(
                                    Icons.ads_click_rounded,
                                    size: 15,
                                    color: accentColor.withOpacity(0.85),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${ad.clickCount}',
                                    style: TextStyle(
                                      color: accentColor.withOpacity(0.9),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),

                              SizedBox(
                                height: (ad.userId == widget.userId) ? 4 : 10
                              ),

                              if (ad.buttonText.isNotEmpty)
                                SizedBox(
                                  height: 34,
                                  child: ElevatedButton(
                                    onPressed: ad.linkUrl == null ||
                                            ad.linkUrl!.trim().isEmpty
                                        ? null
                                        : () => _openAd(ad),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: accentColor,
                                      foregroundColor: backgroundColor,
                                      disabledBackgroundColor:
                                          accentColor.withOpacity(0.7),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 2
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: Text(
                                      ad.buttonText,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        SizedBox(
                          height: (ad.userId == widget.userId) ? 5 : 10
                        ),

                        // Small decorative icon
                        if (ad.imageUrl.isEmpty)
                          Expanded(
                            flex: 2,
                            child: Icon(
                              Icons.campaign_rounded,
                              size: 65,
                              color: accentColor.withOpacity(0.8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Top-right controls
                Positioned(
                  top: 10,
                  right: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Sponsored / AD label
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'AD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      if (ad.userId == widget.userId) ...[
                        const SizedBox(width: 6),

                        // Edit button
                        Material(
                          color: Colors.black.withOpacity(0.35),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _editAd(ad),
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    // Don't occupy space when there are no active ads.
    if (widget.ads.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 950,
            ),
            child: SizedBox(
              height: 201,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.ads.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _buildAdCard(widget.ads[index]),
                  );
                },
              ),
            ),
          ),
        ),

        if (widget.ads.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.ads.length,
              (index) {
                final selected = index == _currentPage;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: selected ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.orange[800]
                        : Colors.grey.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}