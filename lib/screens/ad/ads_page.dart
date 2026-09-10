// screens/my_ads.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/models/ad.dart';

import './ad_service.dart';
import './post_ad_page.dart';

class AdsPage extends StatefulWidget {
  final int userId;
  final String role;

  const AdsPage({
    Key? key,
    required this.userId,
    required this.role,
  }) : super(key: key);

  @override
  State<AdsPage> createState() => _AdsPageState();
}

class _AdsPageState extends State<AdsPage> {
  final AdService _adService = AdService();

  List<Ad> _ads = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _adService.getMyAds(widget.userId);

      if (!mounted) return;

      List<Ad> ads = [];

      ads = response;
    
      setState(() {
        _ads = ads;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _editAd(Ad ad) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostAdPage(
          userId: widget.userId,
          role: widget.role,
          adToEdit: ad,
        ),
      ),
    );

    await _loadAds();
  }

  void _createAd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostAdPage(
          userId: widget.userId,
          role: widget.role,
        ),
      ),
    ).then((_) {
      _loadAds();
    });
  }

  Color _parseColor(
    String colorString, {
    Color fallback = const Color(0xFF6366F1),
  }) {
    try {
      String value = colorString.trim().replaceFirst('#', '');

      if (value.length == 6) {
        value = 'FF$value';
      }

      return Color(int.parse(value, radix: 16));
    } catch (_) {
      return fallback;
    }
  }

  String _priorityLabel(int priority) {
    if (priority >= 70) return 'High';
    if (priority >= 40) return 'Medium';
    return 'Low';
  }

  Color _priorityColor(int priority) {
    if (priority >= 70) return Colors.red;
    if (priority >= 40) return Colors.orange;
    return Colors.green;
  }

  bool _isScheduled(Ad ad) {
    final now = DateTime.now();

    if (ad.startDate != null && now.isBefore(ad.startDate!)) {
      return true;
    }

    if (ad.endDate != null && now.isAfter(ad.endDate!)) {
      return true;
    }

    return false;
  }

  String _statusText(Ad ad) {
    final now = DateTime.now();

    if (!ad.isActive) {
      return 'Inactive';
    }

    if (ad.startDate != null && now.isBefore(ad.startDate!)) {
      return 'Scheduled';
    }

    if (ad.endDate != null && now.isAfter(ad.endDate!)) {
      return 'Expired';
    }

    return 'Active';
  }

  Color _statusColor(Ad ad) {
    switch (_statusText(ad)) {
      case 'Active':
        return Colors.green;
      case 'Scheduled':
        return Colors.blue;
      case 'Expired':
        return Colors.orange;
      case 'Inactive':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(Ad ad) {
    switch (_statusText(ad)) {
      case 'Active':
        return Icons.check_circle;
      case 'Scheduled':
        return Icons.schedule;
      case 'Expired':
        return Icons.event_busy;
      case 'Inactive':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        title: const Text(
          'My Ads',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadAds,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAd,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Create Ad',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAds,
        color: primaryColor,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(
            height: 300,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.cloud_off_rounded,
            size: 70,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Could not load your ads',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadAds,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ),
        ],
      );
    }

    if (_ads.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .primaryColor
                  .withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.campaign_outlined,
              size: 55,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'No Ads Yet',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Create your first advertisement and start\n'
              'reaching more users.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: ElevatedButton.icon(
              onPressed: _createAd,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Ad'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 700;

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeaderSummary(),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                isTablet ? 24 : 16,
                4,
                isTablet ? 24 : 16,
                100,
              ),
              sliver: isTablet
                  ? SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildAdCard(_ads[index]);
                        },
                        childCount: _ads.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 600,
                        mainAxisExtent: 420, // Fixed height for tablet cards
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _buildAdCard(_ads[index]),
                          );
                        },
                        childCount: _ads.length,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderSummary() {
    final activeAds = _ads.where((ad) {
      return _statusText(ad) == 'Active';
    }).length;

    final totalViews = _ads.fold<int>(
      0,
      (sum, ad) => sum + ad.viewCount,
    );

    final totalClicks = _ads.fold<int>(
      0,
      (sum, ad) => sum + ad.clickCount,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Advertisement Dashboard',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.campaign,
                  title: 'Total Ads',
                  value: '${_ads.length}',
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.check_circle,
                  title: 'Active',
                  value: '$activeAds',
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.visibility,
                  title: 'Views',
                  value: _formatNumber(totalViews),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryCard(
                  icon: Icons.touch_app,
                  title: 'Clicks',
                  value: _formatNumber(totalClicks),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdCard(Ad ad) {
    final backgroundColor = _parseColor(ad.backgroundColor);
    final accentColor = _parseColor(
      ad.accentColor,
      fallback: Colors.white,
    );

    final statusColor = _statusColor(ad);
    final statusText = _statusText(ad);
    final priorityColor = _priorityColor(ad.priority);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Important: prevents unbounded height
        children: [
          _buildAdImage(ad),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Important: prevents unbounded height
              children: [
                Row(
                  children: [
                    _buildStatusBadge(
                      icon: _statusIcon(ad),
                      text: statusText,
                      color: statusColor,
                    ),
                    const SizedBox(width: 8),
                    _buildPriorityBadge(
                      text: _priorityLabel(ad.priority),
                      color: priorityColor,
                    ),
                    const Spacer(),
                    Text(
                      '#${ad.id}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  ad.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  ad.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatsRow(ad),
                if (ad.startDate != null || ad.endDate != null) ...[
                  const SizedBox(height: 10),
                  _buildScheduleInfo(ad),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: backgroundColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            ad.buttonText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: backgroundColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton.icon(
                        onPressed: () => _editAd(ad),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 17,
                        ),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
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

  Widget _buildAdImage(Ad ad) {
    final backgroundColor = _parseColor(ad.backgroundColor);

    return SizedBox(
      height: 175,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (ad.imageUrl.isNotEmpty)
            Image.network(
              ad.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return _buildImagePlaceholder(backgroundColor);
              },
              loadingBuilder: (
                context,
                child,
                loadingProgress,
              ) {
                if (loadingProgress == null) {
                  return child;
                }

                return _buildImagePlaceholder(
                  backgroundColor,
                  loading: true,
                );
              },
            )
          else
            _buildImagePlaceholder(backgroundColor),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatNumber(ad.viewCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _formatNumber(ad.clickCount),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildImagePlaceholder(
    Color backgroundColor, {
    bool loading = false,
  }) {
    return Container(
      color: backgroundColor.withOpacity(0.85),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(
                color: Colors.white,
              )
            : const Icon(
                Icons.campaign_rounded,
                size: 55,
                color: Colors.white70,
              ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge({
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatsRow(Ad ad) {
    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            icon: Icons.visibility_outlined,
            label: 'Views',
            value: _formatNumber(ad.viewCount),
          ),
        ),
        Container(
          width: 1,
          height: 28,
          color: Colors.grey.shade200,
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.touch_app_outlined,
            label: 'Clicks',
            value: _formatNumber(ad.clickCount),
          ),
        ),
        Container(
          width: 1,
          height: 28,
          color: Colors.grey.shade200,
        ),
        Expanded(
          child: _buildStatItem(
            icon: Icons.ads_click,
            label: 'CTR',
            value: _calculateCtr(ad),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: Colors.grey.shade500,
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleInfo(Ad ad) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 15,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              '${_formatDate(ad.startDate)}'
              '  →  '
              '${_formatDate(ad.endDate)}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateCtr(Ad ad) {
    if (ad.viewCount <= 0) return '0%';

    final ctr = (ad.clickCount / ad.viewCount) * 100;

    if (ctr >= 10) {
      return '${ctr.toStringAsFixed(0)}%';
    }

    return '${ctr.toStringAsFixed(1)}%';
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    }

    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }

    return NumberFormat('#,##0').format(number);
  }
}