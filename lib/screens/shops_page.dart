import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:tiketi_mkononi/models/shop.dart';
import 'package:tiketi_mkononi/screens/add_shop_page.dart';
import 'package:tiketi_mkononi/screens/edit_shop_page.dart';
import 'package:tiketi_mkononi/screens/orders_page.dart';
import 'package:tiketi_mkononi/screens/products_page.dart';
import '../env.dart';

class ShopsPage extends StatefulWidget {
  final int userId;
  final String role;
  final String userName;
  final String userPhoneNumber;

  const ShopsPage({
    super.key, 
    required this.userId, 
    required this.role, 
    required this.userName, 
    required this.userPhoneNumber
  });

  @override
  State<ShopsPage> createState() => _ShopsPageState();
}

class _ShopsPageState extends State<ShopsPage> {
  bool _loading = true;
  String? _error;
  List<Shop> _shops = [];
  int orderCount = 0;
  int wingasCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchShops();
  }

  Future<void> _fetchShops({bool useDNS = true}) async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      String dateStr = DateFormat('d-M-yyyy').format(DateTime.now());
      DateTime _orderDate = DateFormat('d-M-yyyy').parse(dateStr);

      final uri = useDNS 
        ? Uri.parse('${backend_url}api/shops/${widget.userId}/${DateFormat('d-M-yyyy').format(_orderDate)}')
        : Uri.parse('${backend_url_with_fallback_ip}shops/${widget.userId}/${DateFormat('d-M-yyyy').format(_orderDate)}');

      final response = await http.get(uri);
      debugPrint("response.body : ${response.body}");

      if (response.statusCode == 200) {
        final dynamic responseData = jsonDecode(response.body);
      
        List<Shop> shops = [];
        
        if (responseData is List) {
          shops = responseData.map((json) => Shop.fromJson(json)).toList();
        } else if (responseData is Map && responseData.containsKey('data')) {
          shops = (responseData['data'] as List)
              .map((json) => Shop.fromJson(json))
              .toList();
        }

        if (shops.isNotEmpty) {
          setState(() {
            _shops = shops;
          });
        } else {
          setState(() {
            _error = 'No shop data found';
          });
        }

        debugPrint('Loaded ${_shops.length} shops');
      } else {
        _error = 'Failed to load shops';
      }
    } on SocketException catch (e) {
      if ((e.osError?.errorCode == 7 || e.osError?.errorCode == 11001) && useDNS) {
        await _fetchShops(useDNS: false);
        return;
      } 
      _error = 'Network error. Please check your connection.';
    } catch (e) {
      _error = 'An error occurred. Please try again later.';
      debugPrint('An error occurred: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Determine the number of grid columns based on screen width
  int _getGridColumnCount(double width) {
    if (width < 600) return 1; // Mobile
    if (width < 900) return 2; // Tablet
    if (width < 1200) return 3; // Small desktop
    return 4; // Large desktop
  }

  // Get responsive font sizes
  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final double width = MediaQuery.of(context).size.width;
    final double height = MediaQuery.of(context).size.height;
    
    // Adjust based on both width and height
    double scale = (width / 375.0 + height / 812.0) / 2;
    
    // Clamp the scale to reasonable bounds
    scale = scale.clamp(0.8, 1.4);
    
    return baseSize * scale;
  }

  // Check if we should use grid view
  bool _shouldUseGridView(double width) {
    return width >= 600;
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final bool useGridView = _shouldUseGridView(screenWidth);
    final int gridColumns = _getGridColumnCount(screenWidth);
    
    // Adjust padding based on screen size
    final double horizontalPadding = screenWidth < 600 ? 16.0 : 24.0;
    final double verticalPadding = screenHeight < 700 ? 12.0 : 16.0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Shops',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 20),
          ),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchShops,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _errorState()
                : _shops.isEmpty
                    ? _emptyState()
                    : Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: verticalPadding,
                        ),

                        child: useGridView ? GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridColumns,
                            crossAxisSpacing: screenWidth < 900 ? 10 : 14, // Reduced from 12 and 16
                            mainAxisSpacing: screenWidth < 900 ? 10 : 14, // Reduced from 12 and 16
                            childAspectRatio: screenWidth < 900 ? 1.6 : 1.8, // Increased for shorter cards (was 1.2 and 1.1)
                          ),
                          itemCount: _shops.length,
                          itemBuilder: (_, index) {
                            final Shop shop = _shops[index];
                            return _shopCard2(shop, compact: true);
                          },
                        )
                        : ListView.builder(
                          padding: EdgeInsets.all(horizontalPadding),
                          itemCount: _shops.length,
                          itemBuilder: (_, index) {
                            final Shop shop = _shops[index];
                            return _shopCard(shop, compact: false);
                          },
                        ),
                       
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddShopPage(userId: widget.userId),
            ),
          );
        },
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _shopCard(Shop shop, {bool compact = false}) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrdersPage(
              userId: widget.userId, 
              shopId: shop.id, 
              shopName: shop.name, 
              userName: widget.userName, 
              userPhoneNumber: widget.userPhoneNumber, 
              role: widget.role
            ),
          ),
        );
        _fetchShops();
      },
      child: Card(
        margin: EdgeInsets.only(
          bottom: compact ? 8 : 16,
        ),
        elevation: compact ? 2 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: compact ? _compactShopCardContent(shop, screenWidth, screenHeight) 
                       : _expandedShopCardContent(shop, screenWidth, screenHeight),
      ),
    );
  }

  Widget _shopCard2(Shop shop, {bool compact = false}) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrdersPage(
              userId: widget.userId, 
              shopId: shop.id, 
              shopName: shop.name, 
              userName: widget.userName, 
              userPhoneNumber: widget.userPhoneNumber, 
              role: widget.role
            ),
          ),
        );
        _fetchShops();
      },
      child: Card(
        margin: EdgeInsets.only(
          bottom: compact ? 6 : 16,
        ),
        elevation: compact ? 1 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
        ),
        child: compact 
          ? _compactShopCardContent2(shop, screenWidth, screenHeight) 
          : _expandedShopCardContent(shop, screenWidth, screenHeight),
      ),
    );
  }

  Widget _compactShopCardContent2(Shop shop, double screenWidth, double screenHeight) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), // Reduced vertical padding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Important: minimizes column height
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16, // Reduced from 20
                backgroundColor: Colors.indigo.withOpacity(0.1),
                child: const Icon(
                  Icons.store,
                  color: Colors.teal,
                  size: 18, // Reduced from 22
                ),
              ),
              const SizedBox(width: 10), // Reduced from 12
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shop.name,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 14), // Reduced from 16
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      shop.location,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 11), // Reduced from 12
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if ((widget.userId == shop.userId))
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductsPage(
                          userId: widget.userId,
                          shop: shop,
                        ),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                    size: 18, // Reduced from 20
                  ),
                )
            ],
          ),
          const SizedBox(height: 6), // Reduced from 8
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _chip2(
                icon: Icons.inventory,
                label: '${shop.productCount}',
                screenWidth: screenWidth,
                compact: true,
              ),
              _chip2(
                icon: Icons.trending_up,
                label: '${shop.orderCount}',
                screenWidth: screenWidth,
                compact: true,
              ),
              if ((widget.userId == shop.userId))
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditShopPage(
                          userId: widget.userId,
                          shop: shop,
                        ),
                      ),
                    );
                    _fetchShops();
                  },
                  child: const Icon(
                    Icons.edit,
                    size: 14, // Reduced from 16
                    color: Colors.grey,
                  ),
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip2({
    required IconData icon, 
    required String label, 
    required double screenWidth,
    bool compact = false,
  }) {
    final double fontSize = compact 
      ? _getResponsiveFontSize(context, 9) // Reduced from 10
      : _getResponsiveFontSize(context, 11);
    
    final double iconSize = compact ? 9 : 12; // Reduced from 10
    final double paddingHorizontal = compact ? 5 : 10; // Reduced from 6
    final double paddingVertical = compact ? 3 : 6; // Reduced from 4
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: paddingHorizontal, 
        vertical: paddingVertical
      ),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: Colors.indigo),
          const SizedBox(width: 3), // Reduced from 4
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize, 
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _expandedShopCardContent(Shop shop, double screenWidth, double screenHeight) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.indigo.withOpacity(0.1),
                child: const Icon(
                  Icons.store,
                  color: Colors.teal,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      shop.location,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 14),
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _chip(
                          icon: Icons.inventory,
                          label: '${shop.productCount} Products',
                          screenWidth: screenWidth,
                        ),
                        const SizedBox(width: 5),
                        _chip(
                          icon: Icons.trending_up,
                          label: 'Orders: ${shop.orderCount}',
                          screenWidth: screenWidth,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if ((widget.userId == shop.userId))
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductsPage(
                          userId: widget.userId,
                          shop: shop,
                        ),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                  ),
                )
            ],
          ),
        ),
        if ((widget.userId == shop.userId))
          Padding(
            padding: const EdgeInsets.only(
              top: 0,
              left: 16,
              right: 16,
              bottom: 4,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditShopPage(
                          userId: widget.userId,
                          shop: shop,
                        ),
                      ),
                    );
                    _fetchShops();
                  },
                  child: const Icon(
                    Icons.edit,
                    size: 14,
                    color: Colors.grey,
                  ),
                )
              ],
            ),
          ),
        const SizedBox(height: 10),
      ],
    );
  }

  Widget _compactShopCardContent(Shop shop, double screenWidth, double screenHeight) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.indigo.withOpacity(0.1),
                child: const Icon(
                  Icons.store,
                  color: Colors.teal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 16),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      shop.location,
                      style: TextStyle(
                        fontSize: _getResponsiveFontSize(context, 12),
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if ((widget.userId == shop.userId))
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductsPage(
                          userId: widget.userId,
                          shop: shop,
                        ),
                      ),
                    );
                  },
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.grey,
                    size: 20,
                  ),
                )
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _chip(
                icon: Icons.inventory,
                label: '${shop.productCount}',
                screenWidth: screenWidth,
                compact: true,
              ),
              _chip(
                icon: Icons.trending_up,
                label: '${shop.orderCount}',
                screenWidth: screenWidth,
                compact: true,
              ),
              if ((widget.userId == shop.userId))
                InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditShopPage(
                          userId: widget.userId,
                          shop: shop,
                        ),
                      ),
                    );
                    _fetchShops();
                  },
                  child: const Icon(
                    Icons.edit,
                    size: 16,
                    color: Colors.grey,
                  ),
                )
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon, 
    required String label, 
    required double screenWidth,
    bool compact = false,
  }) {
    final double fontSize = compact 
      ? _getResponsiveFontSize(context, 10)
      : _getResponsiveFontSize(context, 11);
    
    final double iconSize = compact ? 10 : 12;
    final double paddingHorizontal = compact ? 6 : 10;
    final double paddingVertical = compact ? 4 : 6;
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: paddingHorizontal, 
        vertical: paddingVertical
      ),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: Colors.indigo),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize, 
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return ListView(
      children: [
        SizedBox(height: screenHeight * 0.15),
        Icon(
          Icons.store_mall_directory, 
          size: _getResponsiveFontSize(context, 80),
          color: Colors.grey,
        ),
        SizedBox(height: screenHeight * 0.02),
        Center(
          child: Text(
            'No shops found',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(height: screenHeight * 0.01),
        Center(
          child: Text(
            'Shops you own will appear here',
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              color: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return ListView(
      children: [
        SizedBox(height: screenHeight * 0.15),
        const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
        SizedBox(height: screenHeight * 0.02),
        Center(
          child: Text(
            _error!,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 16),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(height: screenHeight * 0.02),
        Center(
          child: ElevatedButton.icon(
            onPressed: _fetchShops,
            icon: const Icon(Icons.refresh),
            label: Text(
              'Retry',
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}